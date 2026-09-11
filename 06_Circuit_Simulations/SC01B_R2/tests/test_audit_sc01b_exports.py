"""Analytic independent-audit checks, runnable with Python and NumPy only."""
import importlib.util
from pathlib import Path
import unittest
import numpy as np

SOURCE = Path(__file__).resolve().parents[1]/'scripts/audit_sc01b_exports.py'
SPEC = importlib.util.spec_from_file_location('audit_sc01b_exports', SOURCE)
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


class AuditTests(unittest.TestCase):
    def test_split_resistor_work_inserts_current_zero(self):
        # I=t-2 A on [0,4] s; integral I^2 on each half is 8/3 A^2 s.
        self.assertAlmostEqual(AUDIT.gate_work(np.array([0., 4.]), np.array([-2., 2.]), 5., 2.), 56/3)

    def test_split_resistor_reduces_to_symmetric_resistor(self):
        t = np.array([0., 0.4, 1., 3.]); current = np.array([2., -1., 3., -2.])
        self.assertAlmostEqual(AUDIT.gate_work(t, current, 7., 7.), 7*AUDIT.product(t, current, current))

    def test_negative_off_bias_and_full_command_span(self):
        p = {'control': {'highOn_s': [4.], 'highOff_s': [2.], 'initialHigh': True, 'deadTime_s': .3},
             'driver': {'riseDelay_s': .02, 'fallDelay_s': .019, 'commandRamp_s': .02,
                        'voltage_V': 12., 'offVoltage_V': -1.5}}
        h, l = AUDIT.commands(np.array([0., 2.029, 3., 5.]), p)
        np.testing.assert_allclose(h, [12., 5.25, -1.5, 12.], atol=1e-12)
        np.testing.assert_allclose(l, [-1.5, -1.5, 12., -1.5], atol=1e-12)

    def test_channel_peak_between_native_knots_is_found(self):
        result = AUDIT.channel_metrics({'time_s': np.array([0., 2.]),
                                        'highChannelCurrent_A': np.array([0., 2.]),
                                        'lowChannelCurrent_A': np.array([2., 0.]),
                                        'loadCurrent_A': np.zeros(2)})
        self.assertAlmostEqual(result['peak_common_positive_channel_A'], 1.)
        self.assertAlmostEqual(result['common_positive_charge_C'], 1.)
        self.assertAlmostEqual(result['duration_both_channels_above_threshold_s'], 1.998)


if __name__ == '__main__':
    unittest.main()
