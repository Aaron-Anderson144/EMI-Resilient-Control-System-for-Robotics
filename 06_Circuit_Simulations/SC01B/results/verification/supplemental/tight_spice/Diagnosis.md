# Tight-tolerance ngspice diagnosis

All tests were isolated copies. No production deck, vendor model, tolerance gate or circuit parameter was changed. The baseline uses reltol=1e-5, abstol=1e-9 and vntol=1e-7; the requested tighter check uses 1e-6, 1e-10 and 1e-8. The original 0.125 ns maximum step is retained except for the explicit half-step test.

| Trial | Complete | Final time (us) | Runtime (s) | Numerical controls |
|---|---|---:|---:|---|
| absolute_only | False | 2.019 | 4.80 | `.options reltol=1e-5 abstol=1e-10 vntol=1e-7 method=trap gminsteps=0 srcsteps=1` |
| baseline_repeat | True | 5 | 11.38 | `.options reltol=1.0000000000000001e-05 abstol=1.0000000000000001e-09 vntol=9.9999999999999995e-08 method=trap gminsteps=0 srcsteps=1` |
| gear_itl4_100 | False | 2.019 | 4.52 | `.options reltol=9.9999999999999995e-07 abstol=1e-10 vntol=1e-08 method=gear gminsteps=0 srcsteps=1 itl4=100` |
| gear_order1 | False | 2.019 | 4.39 | `.options reltol=9.9999999999999995e-07 abstol=1e-10 vntol=1e-08 method=gear maxord=1 gminsteps=0 srcsteps=1 itl4=100` |
| relative_only | False | 2.019 | 4.72 | `.options reltol=1e-6 abstol=1e-9 vntol=1e-7 method=trap gminsteps=0 srcsteps=1` |
| strict_changed_output_step | False | 2.019 | 5.00 | `.options reltol=1e-6 abstol=1e-10 vntol=1e-8 method=trap gminsteps=0 srcsteps=1` |
| strict_dc_iteration | False | 2.019 | 4.88 | `.options reltol=1e-6 abstol=1e-10 vntol=1e-8 method=trap gminsteps=0 srcsteps=1 itl1=1000` |
| trap_fixed_source_steps | False | 2.019 | 4.95 | `.options reltol=9.9999999999999995e-07 abstol=1e-10 vntol=1e-08 method=trap gminsteps=0 srcsteps=100 itl1=1000 itl4=100` |
| trap_half_step | False | 2.019 | 9.39 | `.options reltol=9.9999999999999995e-07 abstol=1e-10 vntol=1e-08 method=trap gminsteps=0 srcsteps=1 itl4=100` |
| trap_hundredfold | False | 2.019 | 6.28 | `.options reltol=1e-7 abstol=1e-11 vntol=1e-9 method=trap gminsteps=0 srcsteps=1 itl4=100` |
| trap_itl4_100 | False | 2.019 | 3.86 | `.options reltol=9.9999999999999995e-07 abstol=1e-10 vntol=1e-08 method=trap gminsteps=0 srcsteps=1 itl4=100` |
| trap_itl4_1000 | False | 2.019 | 5.19 | `.options reltol=9.9999999999999995e-07 abstol=1e-10 vntol=1e-08 method=trap gminsteps=0 srcsteps=1 itl4=1000` |
| trap_pivot | False | 2.019 | 4.58 | `.options reltol=9.9999999999999995e-07 abstol=1e-10 vntol=1e-08 method=trap gminsteps=0 srcsteps=1 itl4=100 pivtol=1e-18 pivrel=1e-6` |
| trap_tight_charge | False | 2.019 | 4.58 | `.options reltol=9.9999999999999995e-07 abstol=1e-10 vntol=1e-08 method=trap gminsteps=0 srcsteps=1 itl4=100 chgtol=1e-16 trtol=1` |
| voltage_only | True | 5 | 12.06 | `.options reltol=1e-5 abstol=1e-9 vntol=1e-8 method=trap gminsteps=0 srcsteps=1` |

The original baseline repeat and the voltage-only refinement completed to 5 us with no warning/error/abort diagnostics. All other attempts stopped at 2.019 us, the first gate-command corner, with a timestep-too-small diagnostic; a successful process return code did not indicate a complete simulation.

All copied decks match the baseline in every non-option line. Their normalized electrical-deck SHA-256 is `0fa25ef97378c8b46f200c13ad6c9e43a2f941d9fbd4c1092463dec37b214230`. The installed supplement retains each exact run/deck, log and JSON summary. Exploratory partial waveforms remain in the local work archive and are not accepted source evidence.

The retained pre-edge comparison covers only 1.000-2.018 us and is saved in preamble_comparison.json. It cannot validate switching waveforms for aborted runs because they contain no completed switching edge. No variant qualifies as a replacement for the failed frozen all-tolerances-tightened check.

## One-tolerance decomposition

- Relative-only: reltol=1e-6, with original abstol/vntol, failed at the first gate corner.
- Current-absolute-only: abstol=1e-10, with original reltol/vntol, failed there.
- Voltage-only: vntol=1e-8, with original reltol/abstol, completed 5 us with zero diagnostics and 40,210 samples. All 12 direct waveform comparisons to the repeated baseline pass the existing amplitude gates; maximum switch difference is 26.3 microvolts and branch-current difference is 29.2 microamps. Detailed values are in voltage_only/summary.json.
- The all-tight check still failed with DC iteration budget itl1=1000, and when the tran output step changed to 0.1 ns while TMAX stayed at 0.125 ns. Exact tran controls are saved in trial_summary.csv.

This decomposition identifies sensitivity to the relative and current-absolute convergence criteria; it does not establish the internal numerical root cause. The isolated voltage-only result is additional diagnostic evidence, not a substitute pass for the frozen all-tight refinement.

The numerical integration, charge/LTE, pivoting and iteration controls were checked against the [ngspice manual](https://ngspice.sourceforge.io/docs/ngspice-41-manual.pdf). Failure at the same source corner across methods suggests a circuit/model/solver numerical limitation beyond a simple transient iteration budget; this is an inference, not an established root cause.
