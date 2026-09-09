"""Independent NumPy audit of exported SC01B records; no MATLAB imports.

Products of linearly interpolated signals are integrated by Simpson's rule
on each native interval (exact for those quadratic products). Gate commands
are reconstructed from parameters, with all command corners inserted.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np

SC01B_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RESULTS = SC01B_ROOT / 'results/verification'


def product(t, a, b):
    midpoint_product = (a[:-1] + a[1:]) * (b[:-1] + b[1:]) / 4
    return float(np.sum(np.diff(t) * (a[:-1]*b[:-1] + 4*midpoint_product + a[1:]*b[1:]) / 6))


def corners(p):
    control, driver = p['control'], p['driver']
    high_on = np.atleast_1d(control['highOn_s']) + driver['riseDelay_s']
    high_off = np.atleast_1d(control['highOff_s']) + driver['fallDelay_s']
    low_on = np.atleast_1d(control['highOff_s']) + control['deadTime_s'] + driver['riseDelay_s']
    low_off = np.atleast_1d(control['highOn_s']) - control['deadTime_s'] + driver['fallDelay_s']
    return high_on, high_off, low_on, low_off


def commands(t, p):
    high_on, high_off, low_on, low_off = corners(p)
    h = np.full_like(t, float(p['control']['initialHigh']))
    l = 1 - h
    ramp = p['driver']['commandRamp_s']
    for event in high_on: h += np.clip((t-event)/ramp, 0, 1)
    for event in high_off: h -= np.clip((t-event)/ramp, 0, 1)
    for event in low_on: l += np.clip((t-event)/ramp, 0, 1)
    for event in low_off: l -= np.clip((t-event)/ramp, 0, 1)
    return h*p['driver']['voltage_V'], l*p['driver']['voltage_V']


def window(raw, p):
    a, b = p['validation']['startTime_s'], p['simulation']['stopTime_s']
    source_events = np.concatenate(corners(p))
    grid = np.unique(np.concatenate(([a, b], raw['time_s'], source_events,
                                    source_events+p['driver']['commandRamp_s'])))
    grid = grid[(grid >= a) & (grid <= b)]
    assert raw['time_s'][0] <= a and raw['time_s'][-1] >= b-1e-14
    return {name: np.interp(grid, raw['time_s'], raw[name]) for name in raw.dtype.names} | {'time_s': grid}


def roots(t, y):
    left, right = y[:-1], y[1:]
    crossing = left*right < 0
    return t[:-1][crossing] - left[crossing]*np.diff(t)[crossing]/(right[crossing]-left[crossing])


def channel_metrics(v):
    if 'highChannelCurrent_A' not in v: return None
    t, h, l = v['time_s'], v['highChannelCurrent_A'], v['lowChannelCurrent_A']
    threshold = max(1e-3, 1e-3*float(np.max(np.abs(v['loadCurrent_A']))))
    grid = np.unique(np.concatenate((t, roots(t, h), roots(t, l), roots(t, h-l),
                                     roots(t, h-threshold), roots(t, l-threshold))))
    h = np.interp(grid, t, h); l = np.interp(grid, t, l)
    common = np.maximum(0, np.minimum(h, l))
    mid_h = (h[:-1]+h[1:])/2; mid_l = (l[:-1]+l[1:])/2
    duration = np.sum(np.diff(grid)*((mid_h > threshold) & (mid_l > threshold)))
    return {
        'current_convention': 'Internal modeled channel drain-to-source current; simultaneous positive conduction.',
        'peak_high_channel_A': float(np.max(h)),
        'peak_low_channel_A': float(np.max(l)),
        'peak_common_positive_channel_A': float(np.max(common)),
        'time_peak_common_s': float(grid[np.argmax(common)]),
        'common_positive_charge_C': float(np.sum(np.diff(grid)*(common[:-1]+common[1:])/2)),
        'overlap_threshold_A': threshold,
        'duration_both_channels_above_threshold_s': float(duration),
        'method': 'Exact piecewise-linear envelope/interval integration, with signal-zero and channel-intersection knots inserted.'
    }


def audit_engine(raw, p):
    v = window(raw, p)
    t = v['time_s']; ih = v['highCurrent_A']; il = v['lowCurrent_A']
    load = v['loadCurrent_A']; feed = v['feedCurrent_A']
    igh = v['highGateCurrent_A']; igl = v['lowGateCurrent_A']
    uh, ul = commands(t, p)
    rb = p['bus']; rg = p['driver']['outputResistance_Ohm']+p['driver']['externalResistance_Ohm']
    icap = feed-ih
    vcap = v['bus_V']-rb['capacitorESR_Ohm']*icap
    ones = np.ones_like(t)
    dc_work = product(t, rb['voltage_V']*ones, feed)
    high_drive_work = product(t, uh, igh); low_drive_work = product(t, ul, igl)
    losses = {
        'feed_resistor_J': rb['feedResistance_Ohm']*product(t, feed, feed),
        'capacitor_esr_J': rb['capacitorESR_Ohm']*product(t, icap, icap),
        'load_resistor_J': p['load']['resistance_Ohm']*product(t, load, load),
        'gate_resistors_J': rg*(product(t, igh, igh)+product(t, igl, igl)),
    }
    device = {
        'high_drain_J': product(t, v['highVds_V'], ih),
        'high_gate_J': product(t, v['highVgs_V'], igh),
        'low_drain_J': product(t, v['lowVds_V'], il),
        'low_gate_J': product(t, v['lowVgs_V'], igl),
    }
    storage = {
        'feed_inductor_change_J': .5*rb['feedInductance_H']*(feed[-1]**2-feed[0]**2),
        'load_inductor_change_J': .5*p['load']['inductance_H']*(load[-1]**2-load[0]**2),
        'dc_link_capacitor_change_J': .5*rb['capacitance_F']*(vcap[-1]**2-vcap[0]**2),
    }
    total_source = dc_work+high_drive_work+low_drive_work
    total_loss = sum(losses.values()); total_device = sum(device.values()); delta_storage = sum(storage.values())
    residual = total_source-total_loss-total_device-delta_storage
    # Independently declared conservative throughput scale uses changes only,
    # never the large absolute preloaded inductor energy.
    scale = max(abs(total_source), abs(total_loss)+abs(total_device)+abs(delta_storage))
    energy_limit = max(.1e-9, .001*scale)
    return {
        'samples_in_csv': len(raw), 'initial_load_A': float(raw['loadCurrent_A'][0]),
        'window_s': [float(t[0]), float(t[-1])],
        'max_abs_switch_kcl_A': float(np.max(np.abs(ih-il-load))),
        'max_abs_high_voltage_identity_V': float(np.max(np.abs(v['highVds_V']+v['switch_V']-v['bus_V']))),
        'max_abs_low_voltage_identity_V': float(np.max(np.abs(v['lowVds_V']-v['switch_V']))),
        'max_abs_high_gate_kvl_V': float(np.max(np.abs(uh-v['highVgs_V']-rg*igh))),
        'max_abs_low_gate_kvl_V': float(np.max(np.abs(ul-v['lowVgs_V']-rg*igl))),
        'load_flux_balance_residual_Vs': product(t, v['switch_V']-p['load']['resistance_Ohm']*load, ones)-p['load']['inductance_H']*(load[-1]-load[0]),
        'feed_flux_balance_residual_Vs': product(t, rb['voltage_V']-rb['feedResistance_Ohm']*feed-v['bus_V'], ones)-rb['feedInductance_H']*(feed[-1]-feed[0]),
        'capacitor_charge_residual_C': product(t, icap, ones)-rb['capacitance_F']*(vcap[-1]-vcap[0]),
        'energy': {
            'dc_source_work_J': dc_work, 'high_drive_work_J': high_drive_work, 'low_drive_work_J': low_drive_work,
            'external_resistor_losses': losses, 'signed_device_terminal_energies': device,
            'external_storage_changes': storage, 'source_total_J': total_source,
            'resistor_total_J': total_loss, 'device_total_J': total_device, 'storage_change_total_J': delta_storage,
            'closure_residual_J': residual, 'independent_throughput_scale_J': scale,
            'independent_0p1pct_or_0p1nJ_limit_J': energy_limit, 'closure_within_independent_limit': bool(abs(residual)<=energy_limit),
            'meaning': 'Signed terminal transfer including stored charge, not semiconductor dissipated heat.'
        },
        'channel': channel_metrics(v),
    }


def compare(native, spice, p):
    a, b = p['validation']['startTime_s'], p['simulation']['stopTime_s']
    t = np.unique(np.concatenate(([a, b], native['time_s'], spice['time_s'])))
    t = t[(t>=a) & (t<=b)]
    rows = {}
    for name in spice.dtype.names:
        if name == 'time_s': continue
        x = np.interp(t, native['time_s'], native[name]); y = np.interp(t, spice['time_s'], spice[name])
        difference = np.abs(x-y); at = int(np.argmax(difference))
        peak = float(np.max(np.abs(y))); limit = max(.01, .01*peak)
        rows[name] = {'max_abs_difference': float(difference[at]), 'time_of_max_difference_s': float(t[at]),
                      'reference_peak_absolute': peak, 'allowance': limit,
                      'difference_to_allowance': float(difference[at]/limit), 'pass': bool(difference[at]<=limit)}
    return {'reference': 'Original-SPICE CSV', 'time_alignment': 'Unshifted union of both CSV integration grids; linear interpolation.',
            'comparison_knots': len(t), 'all_waveforms_pass': all(v['pass'] for v in rows.values()), 'signals': rows}


def audit_case(name, results):
    folder = results/name
    paths = [folder/'parameters.json', folder/'native_finest.csv', folder/'spice_finest.csv']
    p = json.loads(paths[0].read_text(encoding='utf-8-sig'))
    native, spice = [np.genfromtxt(path, delimiter=',', names=True, encoding='utf-8-sig') for path in paths[1:]]
    for raw in [native, spice]:
        assert np.all(np.diff(raw['time_s'])>0)
        assert all(np.all(np.isfinite(raw[name])) for name in raw.dtype.names)
    return {'input_sha256': {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in paths},
            'native': audit_engine(native, p), 'spice': audit_engine(spice, p), 'cross_engine': compare(native, spice, p)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('cases', nargs='*', default=['nominal'],
                        help='Case directory names to audit; defaults to nominal.')
    parser.add_argument('--results', type=Path, default=DEFAULT_RESULTS,
                        help='Folder containing case directories; defaults to SC01B/results/verification.')
    parser.add_argument('--output', type=Path,
                        help='JSON output; defaults to <results>/supplemental/independent_csv_audit.json.')
    args = parser.parse_args()
    results = args.results.expanduser().resolve()
    output = (args.output if args.output is not None else results/'supplemental/independent_csv_audit.json').expanduser().resolve()
    record = json.loads(output.read_text(encoding='utf-8-sig')) if output.exists() else {'scope': 'Independent exported-CSV check; no MATLAB execution or production code imports.', 'cases': {}}
    record['numpy_version'] = np.__version__
    for name in args.cases:
        record['cases'][name] = audit_case(name, results)
        item = record['cases'][name]
        print(json.dumps({'case': name, 'native_kcl_A': item['native']['max_abs_switch_kcl_A'],
                          'spice_kcl_A': item['spice']['max_abs_switch_kcl_A'],
                          'native_closure_nJ': item['native']['energy']['closure_residual_J']*1e9,
                          'spice_closure_nJ': item['spice']['energy']['closure_residual_J']*1e9,
                          'waveforms_pass': item['cross_engine']['all_waveforms_pass'],
                          'native_channel': item['native']['channel']}, indent=2))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(record, indent=2, allow_nan=False)+'\n', encoding='utf-8')
    print(f'Audit saved to {output}')
