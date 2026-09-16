"""Isolated negative tests; synthetic receipts never authorize real runs."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import verify_v2_acceptance as gate


SUITES = ['TestFourWayV2Contracts', 'TestFourwayV2Independent', 'TestFourwayV2Receiver',
          'TestFourWayContracts', 'TestFourWayMetrics', 'TestFourWayNativeEvents', 'TestFourWayPlantEvents',
          'TestPhase3ExternalMeasurement', 'TestPhase3Control', 'TestPhase3Observer', 'TestPhase3Supervisor',
          'TestPhase3StopHoldStep', 'TestPhase3ReferenceGovernor']


class EvidenceGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='codex-v2-gate-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.patch = patch.object(gate, 'BASE', self.base)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.files = {}
        for name in ('functions/fourway_v2_exact_mex.cpp', 'audit/audit_v2_records.py',
                     'control.m', 'raw_native.mat', 'controller.csv', 'test_results.csv'):
            path = self.base / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('SYNTHETIC NEGATIVE TEST FIXTURE\n')
            self.files[name] = path
        engine = 'fourway_v2_exact_' + gate.sha(self.files['functions/fourway_v2_exact_mex.cpp'])[:16]
        causal = [self.files['control.m'], self.files['functions/fourway_v2_exact_mex.cpp']]
        for name in (engine + '.mexw64', 'simulate_fourway_v2_actuator.m', 'fourway_v2_receiver_init.m',
                     'fourway_v2_receiver_advance.m', 'fourway_v2_metrics.m', 'phase3_loop_step.m', 'fourway_plant_events.m'):
            path = self.base / name
            path.write_text('SYNTHETIC SOURCE IDENTITY FOR NEGATIVE TEST\n')
            causal.append(path)
        native_identity = self.base / 'native_identity.json'
        native_identity.write_text(json.dumps(dict(inputFiles=[gate.identity(self.files['raw_native.mat'])] * 24,
                                                     implementationFiles=[gate.identity(self.files['functions/fourway_v2_exact_mex.cpp'])])))
        names = [f'{suite}/test{i}' for suite, count in [(s, 7 if s == SUITES[0] else 2 if s == SUITES[1] else 9 if s == SUITES[2] else 1) for s in SUITES] for i in range(count)]
        self.reports = {
            'development': dict(design_id=gate.DESIGN, partition='development', complete=True,
                                all_execution_clean_guards_pass=True, logical_records=256, unique_executions=256,
                                paired_results=128, failed_records=0, failed_pairs=0,
                                execution_identity=dict(engine=engine, files=[gate.identity(p) for p in causal])),
            'native': dict(designId=gate.DESIGN, gate='C', independentKCLPassed=True, passed=True, integerCountsExact=True,
                           domainRejectedNativeRuns=0, domainRejectedVariantRuns=0, grazingUnresolvedVariantRuns=0,
                           engine=engine, sourceIdentityFile=str(native_identity), sourceIdentitySHA256=gate.sha(native_identity)),
            'tests': dict(passed=True, tests=len(names), failed=0, incomplete=0, suites=SUITES[:], test_names=names,
                          input_files=[gate.identity(self.files['test_results.csv'])], implementation_files=[gate.identity(self.files['control.m'])]),
            'independent_audit': dict(all_passed=True, partition='development', all_execution_clean_guards_pass=True,
                                      records=[dict(checks=1, failed=[]) for _ in range(256)],
                                      pairs=[dict(checks=1, failed=[]) for _ in range(128)],
                                      audited_input_files=[gate.identity(self.files['controller.csv'])] * (256 * 8),
                                      auditor_sha256=gate.sha(self.files['audit/audit_v2_records.py'])),
        }
        for suffix, count in [('NativeRuns', 24), ('VariantRuns', 384), ('Refinements', 256)]:
            self.reports['native'].update({p + suffix: count for p in ('required', 'executed', 'passed')})

    def receipts(self):
        evidence = {}
        for role, data in self.reports.items():
            path = self.base / f'{role}.json'
            path.write_text(json.dumps(data))
            evidence[role] = gate.identity(path)
        return evidence

    def test_valid_isolated_receipts_reach_validation(self):
        self.assertEqual(set(gate.verify_evidence(self.receipts())), set(self.reports))

    def test_changed_record_after_audit_rejected(self):
        evidence = self.receipts()
        self.files['controller.csv'].write_text('CHANGED AFTER AUDIT')
        with self.assertRaisesRegex(ValueError, 'Audited record changed'):
            gate.verify_evidence(evidence)

    def test_changed_controller_after_development_rejected(self):
        evidence = self.receipts()
        self.files['control.m'].write_text('CHANGED AFTER DEVELOPMENT')
        with self.assertRaisesRegex(ValueError, 'Development implementation changed'):
            gate.verify_evidence(evidence)

    def test_changed_native_trace_rejected(self):
        evidence = self.receipts()
        self.files['raw_native.mat'].write_text('CHANGED AFTER NATIVE AUDIT')
        with self.assertRaisesRegex(ValueError, 'Native input/implementation changed'):
            gate.verify_evidence(evidence)

    def test_incomplete_variant_matrix_rejected(self):
        self.reports['native']['passedVariantRuns'] = 383
        with self.assertRaisesRegex(ValueError, 'VariantRuns coverage'):
            gate.verify_evidence(self.receipts())

    def test_missing_receiver_suite_rejected(self):
        self.reports['tests']['suites'].remove('TestFourwayV2Receiver')
        with self.assertRaisesRegex(ValueError, 'suites are missing'):
            gate.verify_evidence(self.receipts())

    def test_consistently_audited_rejection_cannot_open_evaluation(self):
        self.reports['independent_audit']['all_execution_clean_guards_pass'] = False
        with self.assertRaisesRegex(ValueError, 'Independent record audit failed'):
            gate.verify_evidence(self.receipts())


if __name__ == '__main__':
    unittest.main()
