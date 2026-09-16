import unittest
import numpy as np
import audit_v2_records as audit


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.fixtures = [{'fixture_id': f'V2DEV{i:02d}', 'stage': 'development'} for i in (1, 2)]
        self.index = []
        self.metrics = []
        for f in self.fixtures:
            for v in audit.VARIANTS:
                for arm in audit.ARMS:
                    self.metrics.append({'Fixture': f['fixture_id'], 'Variant': v, 'Arm': arm, 'Partition': 'development'})
                    for kind in audit.KINDS:
                        self.index.append({'Record': f"{f['fixture_id']}_{v}_{arm}_{kind}", 'Fixture': f['fixture_id'], 'Variant': v, 'Arm': arm, 'Kind': kind})

    def test_complete_variant_coverage(self):
        got = audit.coverage(self.index, self.metrics, 'development', self.fixtures)
        self.assertEqual(got['expected_records'], 256)
        self.assertEqual(got['expected_pairs'], 128)

    def test_duplicate_metric_cannot_replace_missing_pair(self):
        self.metrics[-1] = self.metrics[0]
        with self.assertRaises(ValueError):
            audit.coverage(self.index, self.metrics, 'development', self.fixtures)

    def test_duplicate_variant_cannot_replace_missing_variant(self):
        for row in self.index:
            if row['Variant'] == 'V16':
                row['Variant'] = 'V15'
        with self.assertRaises(ValueError):
            audit.coverage(self.index, self.metrics, 'development', self.fixtures)

    def test_gray_invalid_resynchronizes_without_repair(self):
        events = [
            dict(time_s='1', A='1', B='1', previous_A='0', previous_B='0', increment='0', count='0', invalid='1'),
            dict(time_s='2', A='0', B='1', previous_A='1', previous_B='1', increment='1', count='1', invalid='0'),
        ]
        t, count, _ = audit.reconstruct_decoder(events)
        np.testing.assert_array_equal(audit.sample_events(t, count, np.array([0, 1, 2, 3])), [0, 0, 1, 1])
        events[1]['count'] = '3'
        with self.assertRaises(ValueError):
            audit.reconstruct_decoder(events)

    def test_signed_domain_and_stress_are_separate(self):
        events = [
            dict(time_s='1', kind='5', threshold_V='18', direction='1'),
            dict(time_s='2', kind='4', threshold_V='-15', direction='-1'),
            dict(time_s='2.5', kind='4', threshold_V='-15', direction='1'),
        ]
        self.assertEqual(audit.operating_exit_times(events), [2.0])

    def test_shared_denominator_screen_is_variant_specific(self):
        metrics = []
        for variant in audit.VARIANTS:
            for i in range(12):
                for arm in audit.ARMS:
                    metrics.append(dict(Variant=variant, Fixture=f'F{i:02d}', Arm=arm,
                                        WindowPairedRMSE_deg='.099' if arm == 'COMBINED' else '.1',
                                        WindowPairedPeak_deg='.1', PeakCurrent_A='.1',
                                        ExecutionGuardPass='1', TaskSuccess='0' if arm == 'BASELINE' else '1'))
        screens = audit.per_variant_screens(metrics)
        self.assertEqual(len(screens), 16)
        self.assertTrue(all(not s['aggregate_gate'] for s in screens))
        self.assertTrue(all(not s['combined_benefit_demonstrated'] for s in screens))

    def test_short_pulse_law_cannot_be_substituted_silently(self):
        threshold = [dict(time_s='0', kind='1', threshold_V='-.1', direction='1'),
                     dict(time_s='1e-8', kind='1', threshold_V='-.13', direction='-1')]
        requests = [dict(time_s='0', kind='1', A='1'), dict(time_s='1e-8', kind='1', A='0')]
        outputs = [dict(time_s='2.5e-8', kind='2', A='1'), dict(time_s='3.5e-8', kind='2', A='0')]
        variant = dict(rise_V=-.1, fall_V=-.13, latencyRise_s=25e-9, latencyFall_s=25e-9, pulseLaw='inertial')
        self.assertTrue(audit.audit_logic(threshold, requests, variant))
        self.assertFalse(audit.audit_logic(threshold, requests + outputs, variant))
        variant['pulseLaw'] = 'transport'
        self.assertTrue(audit.audit_logic(threshold, requests + outputs, variant))


if __name__ == '__main__':
    unittest.main()
