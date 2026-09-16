"""Fail-closed PLAN-V2 implementation/evidence freeze and verification."""
from pathlib import Path
import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / '06_Circuit_Simulations/FOUR_WAY_V2'
DESIGN = 'FOUR-WAY-EMI-PLAN-V2'


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(data)
    return h.hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def identity(path):
    path = Path(path).resolve()
    return {'path': str(path), 'sha256': sha(path)}


def inventory():
    files = set()
    for folder in ['03_MATLAB', '06_Circuit_Simulations/FOUR_WAY_V2',
                   '06_Circuit_Simulations/RECEIVER_V2', '06_Circuit_Simulations/SC01A/functions']:
        for path in (ROOT / folder).rglob('*'):
            if path.is_file() and path.suffix in ('.m', '.cpp', '.h', '.py', '.json') and not {'work', 'results', '__pycache__'} & set(path.relative_to(ROOT / folder).parts):
                files.add(path)
    for name in ('four_way_emi_freeze_manifest.json', 'four_way_emi_v2_freeze_manifest.json'):
        manifest = ROOT / '04_EMI_Models' / name
        files.add(manifest)
        for entry in json.loads(manifest.read_text(encoding='utf-8'))['files']:
            path = ROOT / entry['path']
            require(sha(path) == entry['sha256'], f'Frozen protocol input changed: {entry["path"]}')
            files.add(path)
    files.add(ROOT / '06_Circuit_Simulations/SC01A/models/EMI_SC01A_Finite_Edge.slx')
    source = BASE / 'functions/fourway_v2_exact_mex.cpp'
    binaries = list((BASE / 'work').glob('*' + sha(source)[:16] + '*.mexw64'))
    require(len(binaries) == 1, 'Exactly one source-identified V2 binary is required')
    files.add(binaries[0])
    return sorted(files)


def verify_evidence(evidence):
    reports = {}
    require(set(evidence) == {'development', 'native', 'tests', 'independent_audit'}, 'All four evidence roles are required')
    require(len({str(Path(v['path']).resolve()) for v in evidence.values()}) == 4, 'Evidence roles must be distinct')
    for role, entry in evidence.items():
        require(sha(entry['path']) == entry['sha256'], f'{role} evidence changed')
        reports[role] = json.loads(Path(entry['path']).read_text(encoding='utf-8'))
    d, n, t, a = (reports[r] for r in ('development', 'native', 'tests', 'independent_audit'))
    require(d['design_id'] == DESIGN and d['partition'] == 'development', 'Wrong development identity')
    require(d['complete'] is True and d['all_execution_clean_guards_pass'] is True, 'Development gates failed')
    require(d['logical_records'] == d['unique_executions'] == 256 and d['paired_results'] == 128 and d['failed_records'] == d['failed_pairs'] == 0, 'Development evidence incomplete')
    require(n['designId'] == DESIGN and n['gate'] == 'C' and n['independentKCLPassed'] is True, 'Native identity/KCL failed')
    require(n['passed'] is True and n['integerCountsExact'] is True, 'Independent native acceptance failed')
    for suffix, count in [('NativeRuns', 24), ('VariantRuns', 384), ('Refinements', 256)]:
        require(all(n[prefix + suffix] == count for prefix in ('required', 'executed', 'passed')), f'Native {suffix} coverage failed')
    require(n['domainRejectedNativeRuns'] == n['domainRejectedVariantRuns'] == n['grazingUnresolvedVariantRuns'] == 0, 'Native domain/grazing rejection')
    require(n['engine'] == 'fourway_v2_exact_' + sha(BASE / 'functions/fourway_v2_exact_mex.cpp')[:16], 'Native engine differs from current implementation')
    require(d['execution_identity']['engine'] == n['engine'], 'Development/native engines differ')
    require(d['execution_identity']['files'], 'Development source identities are empty')
    development_names = {Path(e['path']).name for e in d['execution_identity']['files']}
    require({'fourway_v2_exact_mex.cpp', n['engine'] + '.mexw64', 'simulate_fourway_v2_actuator.m',
             'fourway_v2_receiver_init.m', 'fourway_v2_receiver_advance.m', 'fourway_v2_metrics.m',
             'phase3_loop_step.m', 'fourway_plant_events.m'} <= development_names, 'Development identity omits required causal code')
    for entry in d['execution_identity']['files']:
        # Native-only evidence helpers are not called by the closed-loop run.
        if 'fourway_v2_native_' not in Path(entry['path']).name and 'run_fourway_v2_native_' not in Path(entry['path']).name:
            require(sha(entry['path']) == entry['sha256'], f'Development implementation changed: {entry["path"]}')
    require(sha(n['sourceIdentityFile']) == n['sourceIdentitySHA256'], 'Native provenance changed')
    native_identity = json.loads(Path(n['sourceIdentityFile']).read_text(encoding='utf-8'))
    require(len(native_identity['inputFiles']) >= 24 and native_identity['implementationFiles'], 'Native provenance is empty/incomplete')
    for entry in native_identity['inputFiles'] + native_identity['implementationFiles']:
        require(sha(entry['path']) == entry['sha256'], f'Native input/implementation changed: {entry["path"]}')
    require(t['passed'] is True and t['tests'] > 0 and t['failed'] == t['incomplete'] == 0, 'Implementation/regression tests failed')
    require(a['all_passed'] is True and a['partition'] == 'development' and a['all_execution_clean_guards_pass'] is True, 'Independent record audit failed')
    require(len(a['records']) == 256 and len(a['pairs']) == 128, 'Independent audit incomplete')
    require(all(r['checks'] > 0 and not r['failed'] for r in a['records'] + a['pairs']), 'Independent audit has failed/vacuous checks')
    require(len(a['audited_input_files']) >= 256 * 8, 'Audited record identities are empty/incomplete')
    for entry in a['audited_input_files']:
        require(sha(entry['path']) == entry['sha256'], f'Audited record changed: {entry["path"]}')
    require(a['auditor_sha256'] == sha(BASE / 'audit/audit_v2_records.py'), 'Independent auditor changed')
    required_suites = {'TestFourWayV2Contracts', 'TestFourwayV2Independent', 'TestFourwayV2Receiver',
                       'TestFourWayContracts', 'TestFourWayMetrics', 'TestFourWayNativeEvents', 'TestFourWayPlantEvents',
                       'TestPhase3ExternalMeasurement', 'TestPhase3Control', 'TestPhase3Observer', 'TestPhase3Supervisor',
                       'TestPhase3StopHoldStep', 'TestPhase3ReferenceGovernor'}
    require(required_suites <= set(t['suites']), 'Required implementation/regression suites are missing')
    require(t['input_files'] and t['implementation_files'], 'Test provenance is empty')
    for suite, minimum in [('TestFourWayV2Contracts', 7), ('TestFourwayV2Independent', 2), ('TestFourwayV2Receiver', 9)]:
        require(sum(name.startswith(suite + '/') for name in t['test_names']) >= minimum, f'{suite} is incomplete')
    for entry in t['input_files'] + t['implementation_files']:
        require(sha(entry['path']) == entry['sha256'], f'Tested input/implementation changed: {entry["path"]}')
    return reports


def verify(path):
    acceptance = json.loads(Path(path).read_text(encoding='utf-8'))
    require(acceptance['schema_version'] == 2 and acceptance['design_id'] == DESIGN and acceptance['passed'] is True, 'Wrong or rejected acceptance')
    current = inventory()
    require([str(p) for p in current] == [e['path'] for e in acceptance['files']], 'Implementation inventory changed')
    for entry in acceptance['files']:
        require(sha(entry['path']) == entry['sha256'], f'Implementation changed: {entry["path"]}')
    verify_evidence(acceptance['evidence'])
    return acceptance


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--acceptance', type=Path, required=True)
    parser.add_argument('--create', action='store_true')
    for role in ('development', 'native', 'tests', 'independent-audit'):
        parser.add_argument('--' + role, type=Path)
    args = parser.parse_args()
    try:
        if args.create:
            require(not args.acceptance.exists(), 'Acceptance output already exists')
            evidence = {role: identity(getattr(args, role)) for role in ('development', 'native', 'tests', 'independent_audit')}
            verify_evidence(evidence)
            report = {'schema_version': 2, 'design_id': DESIGN, 'passed': True,
                      'frozen_utc': datetime.now(timezone.utc).isoformat(), 'physical_validation': False,
                      'files': [identity(p) for p in inventory()], 'evidence': evidence}
            args.acceptance.parent.mkdir(parents=True, exist_ok=True)
            with args.acceptance.open('x', encoding='utf-8') as stream:
                json.dump(report, stream, indent=2)
        verify(args.acceptance)
        print(json.dumps({'passed': True, 'design_id': DESIGN, 'acceptance': str(args.acceptance)}))
        return 0
    except (ValueError, KeyError, OSError, TypeError) as error:
        print(json.dumps({'passed': False, 'reason': str(error)}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
