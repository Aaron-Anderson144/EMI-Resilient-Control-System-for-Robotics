"""Independent PLAN-V2 CSV reconstruction, coverage and scoring audit.

This script does not invoke the MATLAB metrics or receiver engine. It verifies
all indexed record/variant/arm pairs, reconstructs Gray counts and causal packet
values, checks latched operating-domain failures, and recomputes paired scores.
It never opens evaluation fixtures except when explicitly given an evaluation
campaign. Verification of rejected data is distinct from acceptance for scoring.
"""
from __future__ import annotations
import argparse
from collections import Counter
import csv
import hashlib
import json
import math
from pathlib import Path
import numpy as np

ARMS = ('BASELINE', 'EM_ONLY', 'SW_ONLY', 'COMBINED')
KINDS = ('clean', 'exposed')
GRAY = {(0, 0): 0, (1, 0): 1, (1, 1): 2, (0, 1): 3}
VARIANTS = tuple(f'V{i:02d}' for i in range(1, 17))
PROJECT = Path(__file__).resolve().parents[3]


def rows(path):
    with Path(path).open(encoding='utf-8-sig', newline='') as stream:
        return list(csv.DictReader(stream))


def numbers(data, key):
    return np.asarray([float(r[key]) for r in data], dtype=float)


def boolean(value):
    if str(value).lower() in ('1', 'true'):
        return True
    if str(value).lower() in ('0', 'false'):
        return False
    raise ValueError(f'Not a boolean: {value!r}')


def bools(data, key):
    return np.asarray([boolean(r[key]) for r in data])


def close(a, b, absolute=1e-10):
    return bool((math.isnan(a) and math.isnan(b)) or math.isclose(a, b, rel_tol=1e-9, abs_tol=absolute))


def rms(values):
    return float(np.sqrt(np.mean(np.square(values))))


def hash_file(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def coverage(index, metrics, partition, fixture_rows):
    fixtures = {r['fixture_id'] for r in fixture_rows if r['stage'] == partition}
    expected = {(f, v, a, k) for f in fixtures for v in VARIANTS for a in ARMS for k in KINDS}
    actual = Counter((r['Fixture'], r['Variant'], r['Arm'], r['Kind']) for r in index)
    if set(actual) != expected or any(n != 1 for n in actual.values()):
        raise ValueError(f'Record coverage differs: expected {len(expected)}, actual {len(index)}, '
                         f'missing {len(expected - set(actual))}, extra {len(set(actual) - expected)}')
    if len({r['Record'] for r in index}) != len(index):
        raise ValueError('Duplicate exported record path')
    if any(r.get('Status', 'passed') != 'passed' for r in index):
        raise ValueError('At least one indexed record failed execution')
    wanted = {x[:3] for x in expected}
    paired = Counter((r['Fixture'], r['Variant'], r['Arm']) for r in metrics)
    if set(paired) != wanted or any(n != 1 for n in paired.values()):
        raise ValueError('Missing, duplicate or unexpected paired metric identities')
    if any(r['Partition'] != partition for r in metrics):
        raise ValueError('Metric partition does not match requested audit partition')
    return {'expected_records': len(expected), 'expected_pairs': len(wanted), 'variants': len(VARIANTS)}


def reconstruct_decoder(events):
    previous = (0, 0)
    count = 0
    times, counts, increments = [], [], []
    for e in events:
        now = (int(float(e['A'])), int(float(e['B'])))
        reported_previous = (int(float(e['previous_A'])), int(float(e['previous_B'])))
        step = (GRAY[now] - GRAY[previous]) % 4
        increment = {0: 0, 1: 1, 2: 0, 3: -1}[step]
        invalid = int(step == 2)
        count += increment
        if reported_previous != previous or increment != float(e['increment']) or invalid != float(e['invalid']) or count != float(e['count']):
            raise ValueError('Decoder event does not follow independent Gray transition rule')
        previous = now
        times.append(float(e['time_s']))
        counts.append(count)
        increments.append(increment)
    times = np.asarray(times)
    if not (np.isfinite(times).all() and (np.diff(times) > 0).all() and (times >= 0).all() and (times <= 3 + 1e-12).all()):
        raise ValueError('Noncausal or invalid decoder timestamps')
    return times, np.asarray(counts), np.asarray(increments)


def sample_events(times, counts, samples):
    # A small arithmetic allowance is much smaller than the 1 ps joint rule.
    return np.r_[0, counts][np.searchsorted(times, samples + 1e-14, side='right')]


def operating_exit_times(events):
    if not events:
        return []
    kind_key = next((k for k in events[0] if k.lower().startswith('kind')), None)
    if kind_key is None:
        raise ValueError('Missing documented threshold-event kind column')
    exits = []
    for e in events:
        kind, level, direction = int(float(e[kind_key])), float(e['threshold_V']), float(e['direction'])
        if kind in (2, 3, 4) and abs(level) == 15 and level * direction > 0:
            exits.append(float(e['time_s']))
        if kind in (2, 3, 4) and abs(level) != 15:
            raise ValueError('Operating event has unexpected voltage threshold')
        if kind in (5, 6, 7) and abs(level) != 18:
            raise ValueError('Stress event has unexpected voltage threshold')
    return exits


def clean_decoder_check(folder, receiver_events, data):
    intended = rows(folder / 'intended_AB.csv')
    previous, count = (0, 0), 0
    times, increments, counts = [], [], []
    for event in intended:
        now = (int(float(event['A'])), int(float(event['B'])))
        if now == previous:
            continue
        step = (GRAY[now] - GRAY[previous]) % 4
        if step not in (1, 3):
            return False, False, math.nan
        inc = 1 if step == 1 else -1
        count += inc
        times.append(float(event['time_s']))
        increments.append(inc)
        counts.append(count)
        previous = now
    rt, rc, ri = reconstruct_decoder(receiver_events)
    sequence = np.array_equal(rc, counts) and np.array_equal(ri, increments) and not bools(receiver_events, 'invalid').any()
    if not sequence:
        return False, False, math.nan
    delay = rt - times
    maximum = max([0.0, *delay])
    return True, bool((delay >= -1e-12).all() and (delay <= 1e-6).all()), float(maximum)


def independent_motor(data, intervals):
    """Closed-form two-state motor, independent of saved interval extrema."""
    dt = .001
    # Frozen representative motor; zero applied load for PLAN-V2.
    motor = np.array([[-.0001 / .00015, .08 / .00015], [-.08 / .0025, -1.2 / .0025]])
    forcing = np.array([0., 1 / .0025])
    eigenvalues, eigenvectors = np.linalg.eig(motor)
    inv_vectors = np.linalg.inv(eigenvectors)
    steady_per_volt = -np.linalg.solve(motor, forcing)
    x = np.column_stack((numbers(data, 'velocity_rad_s'), numbers(data, 'current_A')))
    theta = numbers(data, 'position_rad')
    command = numbers(data, 'command_V')[:-1]
    steady = command[:, None] * steady_per_volt
    amplitudes = (x[:-1] - steady) @ inv_vectors.T
    exp_step = np.exp(eigenvalues * dt)
    predicted = steady + np.real((amplitudes * exp_step) @ eigenvectors.T)
    integrals = np.real((amplitudes * (np.expm1(eigenvalues * dt) / eigenvalues)) @ eigenvectors.T)
    predicted_theta = theta[:-1] + steady[:, 0] * dt + integrals[:, 0]
    current_modes = amplitudes * eigenvectors[1]
    current_integral = steady[:, 1] ** 2 * dt
    current_integral += 2 * steady[:, 1] * np.real(np.sum(current_modes * (np.expm1(eigenvalues * dt) / eigenvalues), axis=1))
    for j in range(2):
        for k in range(2):
            rate = eigenvalues[j] + eigenvalues[k]
            current_integral += np.real(current_modes[:, j] * current_modes[:, k] * np.expm1(rate * dt) / rate)

    def peak(row):
        coeffs = amplitudes * eigenvectors[row]
        output = np.maximum(np.abs(x[:-1, row]), np.abs(predicted[:, row]))
        for n, coefficients in enumerate(coeffs):
            candidates = []
            derivative = coefficients * eigenvalues
            if np.max(np.abs(np.imag(eigenvalues))) < 1e-10:
                if abs(derivative[0]) > 1e-30:
                    ratio = -derivative[1] / derivative[0]
                    if np.real(ratio) > 0:
                        root = float(np.real(np.log(ratio) / (eigenvalues[0] - eigenvalues[1])))
                        if 0 < root < dt:
                            candidates.append(root)
            else:
                j = int(np.argmax(np.imag(eigenvalues)))
                beta = float(np.imag(eigenvalues[j]))
                phase = float(np.angle(derivative[j]))
                low = math.ceil((phase - np.pi / 2) / np.pi)
                high = math.floor((beta * dt + phase - np.pi / 2) / np.pi)
                candidates.extend((np.pi / 2 + k * np.pi - phase) / beta for k in range(low, high + 1))
            for root in candidates:
                value = steady[n, row] + np.real(np.sum(coefficients * np.exp(eigenvalues * root)))
                output[n] = max(output[n], abs(value))
        return output

    peaks_v, peaks_i = peak(0), peak(1)
    return {
        'motor_state_recursion': np.max(np.abs(predicted - x[1:])) < 1e-8 and np.max(np.abs(predicted_theta - theta[1:])) < 1e-10,
        'independent_peak_speed': len(intervals) == len(command) and np.allclose(peaks_v, numbers(intervals, 'peakAbsVelocity_rad_s'), atol=1e-8, rtol=1e-8),
        'independent_peak_current': len(intervals) == len(command) and np.allclose(peaks_i, numbers(intervals, 'peakAbsCurrent_A'), atol=1e-8, rtol=1e-8),
        'independent_current_squared_integral': len(intervals) == len(command) and np.allclose(current_integral, numbers(intervals, 'currentSquaredIntegral_A2s'), atol=1e-10, rtol=1e-8),
    }


def expected_variant(identifier):
    config = json.loads((PROJECT / '06_Circuit_Simulations/RECEIVER_V2/receiver_characterization_config.json').read_text())
    number = 0
    for pair in config['receiver']['thresholdPairs']:
        for delay in config['receiver']['postThresholdLatency_s']:
            for law in config['receiver']['pulseLaws']:
                number += 1
                if identifier == f'V{number:02d}':
                    return dict(id=identifier, threshold_id=pair['id'], rise_V=pair['rise_V'], fall_V=pair['fall_V'],
                                latencyRise_s=delay, latencyFall_s=delay, pulseLaw=law)
    raise ValueError('Unknown variant')


def audit_logic(thresholds, logic, variant):
    kind_key = next((k for k in (thresholds[0] if thresholds else {}) if k.lower().startswith('kind')), None)
    requested, inputs = 0, []
    for e in thresholds:
        if int(float(e[kind_key])) != 1:
            continue
        level, direction = float(e['threshold_V']), float(e['direction'])
        state = requested
        if level == variant['rise_V'] and direction > 0:
            state = 1
        if level == variant['fall_V'] and direction < 0:
            state = 0
        if state != requested:
            inputs.append((float(e['time_s']), state))
            requested = state
    comparator = [(float(e['time_s']), int(float(e['A']))) for e in logic if int(float(e['kind'])) == 1]
    outputs = [(float(e['time_s']), int(float(e['A']))) for e in logic if int(float(e['kind'])) == 2]
    if len(comparator) != len(inputs) or any(a != b for a, b in zip(comparator, inputs)):
        return False
    generated, pending, output_state = [], None, 0
    if variant['pulseLaw'] == 'transport':
        generated = [(t + variant['latencyRise_s' if state else 'latencyFall_s'], state) for t, state in inputs]
    else:
        for time, state in inputs:
            if pending is not None and pending[0] <= time:
                generated.append(pending)
                output_state = pending[1]
                pending = None
            pending = None if state == output_state else (time + variant['latencyRise_s' if state else 'latencyFall_s'], state)
        if pending is not None:
            generated.append(pending)
    generated = [x for x in generated if x[0] <= 3]
    if len(outputs) != len(generated):
        return False
    return all(actual[1] == expected[1] and abs(actual[0] - expected[0]) <= 1e-14 for actual, expected in zip(outputs, generated))


def decoder_alignment(receiver, shadow, allowance=1e-6):
    """Apply the explicitly declared one-to-one, directed-transition policy."""
    def signature(event):
        return tuple(float(event[k]) for k in ('A', 'B', 'previous_A', 'previous_B'))
    i = j = extra = missing = matched = 0
    while i < len(receiver) and j < len(shadow):
        ri, sj = receiver[i], shadow[j]
        tr, ts = float(ri['time_s']), float(sj['time_s'])
        if signature(ri) == signature(sj) and abs(tr - ts) <= allowance:
            matched += 1
            i += 1
            j += 1
        elif tr < ts - allowance:
            extra += 1
            i += 1
        elif ts < tr - allowance:
            missing += 1
            j += 1
        elif i + 1 < len(receiver) and signature(receiver[i + 1]) == signature(sj) and abs(float(receiver[i + 1]['time_s']) - ts) <= allowance:
            extra += 1
            i += 1
        else:
            missing += 1
            j += 1
    return {'ObservedTransitions': len(receiver), 'ShadowTransitions': len(shadow),
            'ExtraTransitions': extra + len(receiver) - i, 'MissingTransitions': missing + len(shadow) - j,
            'InvalidTransitions': sum(float(e['invalid']) for e in receiver), 'EventMatchingAllowance_s': allowance}


def audit_record(folder, identity, fixture):
    data = rows(folder / 'controller.csv')
    t = numbers(data, 'time_s')
    delta = 2 * np.pi / 4096
    count = numbers(data, 'decodedCount')
    ideal = numbers(data, 'idealCount')
    shadow = numbers(data, 'shadowDecodedCount')
    position = numbers(data, 'position_rad')
    mode = numbers(data, 'mode')
    command = numbers(data, 'command_V')
    checks = {
        'complete_grid': len(t) == 3001 and np.max(np.abs(t - np.arange(3001) * .001)) < 1e-12,
        'finite_plant_command': all(np.isfinite(numbers(data, k)).all() for k in ('position_rad', 'velocity_rad_s', 'current_A', 'command_V')),
        'fresh_packets': np.array_equal(numbers(data, 'sourceIndex'), np.arange(1, len(t) + 1)) and bools(data, 'sampleReceived').all(),
        'quantization_bins': np.max(np.abs(position - ideal * delta)) <= delta / 2 + 1e-12,
        'decoded_measurement': np.max(np.abs(numbers(data, 'receivedMeasurement_rad') - count * delta)) < 2e-13,
        'count_error_identity': np.array_equal(ideal - count, numbers(data, 'idealMinusDecodedCount')),
        'separate_shadow': np.array_equal(count - shadow, numbers(data, 'emiCountError')),
        'bounded_command': (np.abs(command) <= 24 + 1e-12).all() and (np.abs(command) <= numbers(data, 'commandLimit_V') + 1e-12).all(),
        'stopped_command_zero': (command[mode == 4] == 0).all(),
    }
    metadata = json.loads((folder / 'fixture.json').read_text(encoding='utf-8-sig'))
    variant = expected_variant(identity['Variant'])
    expected_cd = 1000 if identity['Arm'] in ('EM_ONLY', 'COMBINED') else 100
    checks['frozen_fixture_identity'] = metadata['id'] == identity['Fixture'] and metadata['arm'] == identity['Arm'] \
        and metadata['partition'] == fixture['stage'] and bool(metadata['exposed']) == (identity['Kind'] == 'exposed') \
        and metadata['variant'] == variant and metadata['Ccp_pF'] == float(fixture['Ccp_pF']) \
        and metadata['Ccn_pF'] == float(fixture['Ccn_pF']) and metadata['Cdiff_pF'] == expected_cd \
        and metadata['task_sign'] == float(fixture['task_sign']) and metadata['design']['design_id'] == 'FOUR-WAY-EMI-PLAN-V2'
    receiver_events = None
    for name, expected in (('receiver', count), ('shadow', shadow)):
        receiver_meta = json.loads((folder / f'{name}_metadata.json').read_text(encoding='utf-8-sig'))
        parameter = receiver_meta['parameters']
        checks[f'{name}_variant_and_loading'] = receiver_meta['variant'] == variant \
            and close(parameter['coupling']['Cp_F'], float(fixture['Ccp_pF']) * 1e-12, 1e-23) \
            and close(parameter['coupling']['Cn_F'], float(fixture['Ccn_pF']) * 1e-12, 1e-23) \
            and close(parameter['receiver']['Cdiff_F'], expected_cd * 1e-12, 1e-22)
        events = rows(folder / f'{name}_decoder_events.csv')
        et, ec, _ = reconstruct_decoder(events)
        checks[f'{name}_causal_gray_packets'] = np.array_equal(sample_events(et, ec, t), expected)
        if name == 'receiver':
            receiver_events = events
        threshold = rows(folder / f'{name}_threshold_events.csv')
        logic = rows(folder / f'{name}_logic_events.csv')
        checks[f'{name}_independent_schmitt_and_delay'] = audit_logic(threshold, logic, variant)
        exits = operating_exit_times(threshold)
        expected_domain = t >= min(exits) - 1e-14 if exits else np.zeros(len(t), dtype=bool)
        if name == 'receiver':
            checks['latched_operating_domain'] = np.array_equal(expected_domain, bools(data, 'receiverDomainFailed'))
        else:
            checks['shadow_inside_operating_domain'] = not exits
        packets = rows(folder / f'{name}_packets.csv')
        checks[f'{name}_exported_packets'] = len(packets) == len(t) and np.array_equal(numbers(packets, 'count'), expected)
    source = json.loads((folder / 'receiver_source.json').read_text(encoding='utf-8-sig'))
    origins = np.asarray(source['pulse_origins_s'], dtype=float).reshape(-1)
    exposed = identity['Kind'] == 'exposed'
    checks['exposure_identity'] = bool(source['exposed']) == exposed
    checks['source_identity'] = source['sha256'] == '1ecdd83ee4f4846b70e2d40ba04f4b3188e737c94f08300a5bbbfcc36acb9cd5'
    checks['source_phase'] = close(float(source['phase_s']), float(fixture['phase_ns']) * 1e-9, 1e-15)
    checks['source_closure'] = close(float(source['closure_s']), 1e-7, 1e-16)
    if exposed:
        expected_origins = np.r_[.25 + float(fixture['phase_ns']) * 1e-9 - 2.019e-6 + np.arange(100) * 50e-6,
                                 1.7 + float(fixture['phase_ns']) * 1e-9 - 2.019e-6 + np.arange(100) * 50e-6]
        checks['all_200_original_pulse_origins'] = len(origins) == 200 and np.max(np.abs(origins - expected_origins)) < 1e-12
    else:
        checks['clean_no_exposure'] = len(origins) == 0
        checks['clean_sampled_count_guard'] = np.max(np.abs(ideal - count)) <= 1
        sequence, delay, maximum = clean_decoder_check(folder, receiver_events, data)
        checks['clean_sequence'] = sequence
        checks['clean_delay'] = delay
    checks.update(independent_motor(data, rows(folder / 'plant_interval_metrics.csv')))
    checks = {k: bool(v) for k, v in checks.items()}
    return {'record': identity['Record'], 'checks': len(checks), 'check_results': checks,
            'failed': [k for k, v in checks.items() if not v]}, data, source


def recompute_pair(a, b, source, arm):
    t = numbers(a, 'time_s')
    pair = np.rad2deg(numbers(a, 'position_rad') - numbers(b, 'position_rad'))
    request = np.rad2deg(numbers(a, 'position_rad') - numbers(a, 'requestedReference_rad'))
    shaped = np.rad2deg(numbers(a, 'position_rad') - numbers(a, 'reference_rad'))
    clean_request = np.rad2deg(numbers(b, 'position_rad') - numbers(b, 'requestedReference_rad'))
    window = ((t >= .24) & (t < .4)) | ((t >= 1.69) & (t < 1.85))
    tail = t >= 2.9
    command = numbers(a, 'command_V')
    expected = {
        'WindowPairedRMSE_deg': rms(pair[window]), 'WindowPairedPeak_deg': float(np.max(np.abs(pair[window]))),
        'FullPairedRMSE_deg': rms(pair), 'FullPairedPeak_deg': float(np.max(np.abs(pair))),
        'RequestedRMSE_deg': rms(request), 'ShapedRMSE_deg': rms(shaped),
        'FinalRequestedError_deg': abs(float(request[-1])), 'TailRequestedRMSE_deg': rms(request[tail]),
        'TailPairedRMSE_deg': rms(pair[tail]), 'FinalPairedError_deg': abs(float(pair[-1])),
        'FinalShapedError_deg': abs(float(shaped[-1])), 'TailShapedRMSE_deg': rms(shaped[tail]),
        'CleanFinalRequestedError_deg': abs(float(clean_request[-1])), 'CleanTailRequestedRMSE_deg': rms(clean_request[tail]),
        'CommandEnergy_V2s': float(np.sum(command[:-1] ** 2) * .001),
        'CommandVariation_V': float(np.sum(np.abs(np.diff(command)))), 'CommandPeak_V': float(np.max(np.abs(command))),
        'IdealMinusDecodedPeak_counts': float(np.max(np.abs(numbers(a, 'idealMinusDecodedCount')))),
        'IdealMinusDecodedFinal_counts': float(numbers(a, 'idealMinusDecodedCount')[-1]),
        'EMICountPeak_counts': float(np.max(np.abs(numbers(a, 'emiCountError')))),
        'EMICountFinal_counts': float(numbers(a, 'emiCountError')[-1]),
        'CleanSampledCountPeak_counts': float(np.max(np.abs(numbers(b, 'idealMinusDecodedCount')))),
        'AlarmSamples': float(np.count_nonzero(numbers(a, 'alarm'))),
        'NonnormalSamples': float(np.count_nonzero(numbers(a, 'mode'))),
        'CleanAlarmSamples': float(np.count_nonzero(numbers(b, 'alarm'))),
        'CleanNonnormalSamples': float(np.count_nonzero(numbers(b, 'mode'))),
    }
    for burst in (1, 2):
        end = np.asarray(source['last_nonzero_dVa_dt_s']).reshape(-1)[burst * 100 - 1]
        good = np.abs(pair) <= .5
        if arm in ('SW_ONLY', 'COMBINED'):
            good &= numbers(a, 'mode') == 0
        delay = math.nan
        for k in range(np.searchsorted(t, end), len(t) - 50):
            if good[k:k + 51].all():
                delay = float(t[k] - end)
                break
        expected[f'Burst{burst}Recovery_s'] = delay
    alarm = numbers(a, 'alarm') != 0
    active = numbers(a, 'emiCountError') != 0
    onsets = alarm & ~np.r_[False, alarm[:-1]]
    expected['CorruptionEpisodes'] = float(np.count_nonzero(active & ~np.r_[False, active[:-1]]))
    expected['FalseAlarmEpisodes'] = float(np.count_nonzero(onsets & ~active))
    expected['NoncorruptionAlarmSamples'] = float(np.count_nonzero(alarm & ~active))
    return expected


def per_variant_screens(metrics):
    screens = []
    for variant in VARIANTS:
        selected = [m for m in metrics if m['Variant'] == variant]
        fixtures = sorted({m['Fixture'] for m in selected})
        by = {(m['Fixture'], m['Arm']): m for m in selected}
        baseline = [by[f, 'BASELINE'] for f in fixtures]
        combined = [by[f, 'COMBINED'] for f in fixtures]
        b = np.asarray([float(m['WindowPairedRMSE_deg']) for m in baseline])
        c = np.asarray([float(m['WindowPairedRMSE_deg']) for m in combined])
        d = np.maximum(b, .25)
        guards = all(boolean(m['ExecutionGuardPass']) for m in selected)
        gate = float(np.mean(c / d)) <= .9 * float(np.mean(b / d))
        position = all(float(crow[key]) <= float(brow[key]) + max(.1 * float(brow[key]), .25)
                       for brow, crow in zip(baseline, combined) for key in ('WindowPairedRMSE_deg', 'WindowPairedPeak_deg'))
        current = all(float(crow['PeakCurrent_A']) <= float(brow['PeakCurrent_A']) + max(.1 * float(brow['PeakCurrent_A']), .05)
                      for brow, crow in zip(baseline, combined))
        rescues = sum(not boolean(brow['TaskSuccess']) and boolean(crow['TaskSuccess']) for brow, crow in zip(baseline, combined))
        screens.append({'variant': variant, 'fixtures': len(fixtures), 'all_execution_clean_guards': guards,
                        'baseline_normalized_mean': float(np.mean(b / d)), 'combined_normalized_mean': float(np.mean(c / d)),
                        'aggregate_gate': gate, 'position_guards': position, 'current_guard': current,
                        'rescued_failures': rescues, 'combined_benefit_demonstrated': bool(guards and gate and position and current and rescues >= 1)})
    return screens


def audit_campaign(path, partition):
    index = rows(path / 'record_index.csv')
    metrics = rows(path / 'metrics.csv')
    fixtures = rows(PROJECT / '04_EMI_Models/four_way_emi_v2_fixtures.csv')
    result = {'scope': 'Independent exported numerical/identity audit, not hardware validation',
              'partition': partition, 'campaign': str(path), 'coverage': coverage(index, metrics, partition, fixtures)}
    fixture_by = {f['fixture_id']: f for f in fixtures}
    indexed = {(r['Fixture'], r['Variant'], r['Arm'], r['Kind']): r for r in index}
    folders = {p.parent.name for p in path.glob('*/controller.csv')}
    if folders != {r['Record'] for r in index}:
        raise ValueError('Record folders and index disagree')
    record_reports, pair_reports = [], []
    for metric in metrics:
        pair = []
        paired_reports = []
        for kind in KINDS:
            identity = indexed[metric['Fixture'], metric['Variant'], metric['Arm'], kind]
            report, data, source = audit_record(path / identity['Record'], identity, fixture_by[metric['Fixture']])
            record_reports.append(report)
            paired_reports.append(report)
            pair.append((data, source))
        expected = recompute_pair(pair[1][0], pair[0][0], pair[1][1], metric['Arm'])
        exposed_folder = path / indexed[metric['Fixture'], metric['Variant'], metric['Arm'], 'exposed']['Record']
        expected.update(decoder_alignment(rows(exposed_folder / 'receiver_decoder_events.csv'), rows(exposed_folder / 'shadow_decoder_events.csv')))
        failed = [key for key, value in expected.items() if not close(value, float(metric[key]))]
        a, b = pair[1][0], pair[0][0]
        ac, bc = paired_reports[1]['check_results'], paired_reports[0]['check_results']
        clean_guard = all(bc[k] for k in ('complete_grid', 'finite_plant_command', 'fresh_packets', 'bounded_command',
                                         'stopped_command_zero', 'clean_sequence', 'clean_delay', 'clean_sampled_count_guard')) \
            and not bools(b, 'receiverDomainFailed').any() and not bools(b, 'receiverNumericalRejected').any() \
            and not bools(b, 'shadowNumericalRejected').any() and not bools(a, 'shadowDomainFailed').any() \
            and not bools(b, 'shadowDomainFailed').any() \
            and expected['CleanFinalRequestedError_deg'] <= .5 and expected['CleanTailRequestedRMSE_deg'] <= .5 \
            and (metric['Arm'] not in ('SW_ONLY', 'COMBINED') or (expected['CleanAlarmSamples'] == 0 and expected['CleanNonnormalSamples'] == 0))
        execution = all(ac[k] for k in ('complete_grid', 'finite_plant_command', 'fresh_packets', 'bounded_command', 'stopped_command_zero')) \
            and not bools(a, 'receiverDomainFailed').any() and not bools(a, 'receiverNumericalRejected').any() \
            and not bools(a, 'shadowNumericalRejected').any() and clean_guard
        task = execution and expected['WindowPairedRMSE_deg'] <= .5 and expected['WindowPairedPeak_deg'] <= 2 \
            and expected['FinalRequestedError_deg'] <= .5 and expected['TailRequestedRMSE_deg'] <= .5 \
            and all(math.isfinite(expected[f'Burst{k}Recovery_s']) and expected[f'Burst{k}Recovery_s'] <= .5 for k in (1, 2))
        for key, value in {'CleanGuardPass': clean_guard, 'ExecutionGuardPass': execution, 'TaskSuccess': task,
                           'ReceiverDomainPass': not bools(a, 'receiverDomainFailed').any()}.items():
            if boolean(metric[key]) != bool(value):
                failed.append(key)
        plant = rows(path / indexed[metric['Fixture'], metric['Variant'], metric['Arm'], 'exposed']['Record'] / 'plant_interval_metrics.csv')
        independent_interval_metrics = {'PeakSpeed_rad_s': float(np.max(numbers(plant, 'peakAbsVelocity_rad_s'))),
                                        'PeakCurrent_A': float(np.max(numbers(plant, 'peakAbsCurrent_A'))),
                                        'CurrentSquaredIntegral_A2s': float(np.sum(numbers(plant, 'currentSquaredIntegral_A2s')))}
        failed += [key for key, value in independent_interval_metrics.items() if not close(value, float(metric[key]))]
        pair_reports.append({'fixture': metric['Fixture'], 'variant': metric['Variant'], 'arm': metric['Arm'],
                             'checks': len(expected) + len(independent_interval_metrics), 'failed': failed})
    result['records'] = record_reports
    result['pairs'] = pair_reports
    result['all_passed'] = not any(r['failed'] for r in record_reports + pair_reports)
    result['all_execution_clean_guards_pass'] = all(boolean(m['ExecutionGuardPass']) for m in metrics)
    result['physical_validation'] = False
    result['identity_inputs'] = {p.name: hash_file(p) for p in (path / 'record_index.csv', path / 'metrics.csv')}
    audited = {path / 'record_index.csv', path / 'metrics.csv'}
    for entry in index:
        audited.update(p for p in (path / entry['Record']).iterdir() if p.suffix.lower() in ('.csv', '.json'))
    result['audited_input_files'] = [{'path': str(p.resolve()), 'sha256': hash_file(p)} for p in sorted(audited)]
    if partition == 'evaluation':
        result['per_variant_screens'] = per_variant_screens(metrics)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('campaign', type=Path)
    parser.add_argument('--partition', required=True, choices=('development', 'evaluation'))
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Choose a new output path; previous evidence is preserved')
    try:
        report = audit_campaign(args.campaign, args.partition)
    except (AssertionError, KeyError, ValueError, OSError, IndexError) as error:
        report = {'all_passed': False, 'campaign': str(args.campaign), 'error': f'{type(error).__name__}: {error}'}
    report['auditor_sha256'] = hash_file(Path(__file__))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(report, stream, indent=2)
    print(json.dumps({'all_passed': report['all_passed'], 'output': str(args.output), 'error': report.get('error')}))
    return 0 if report['all_passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
