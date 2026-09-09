# SC-01A Finite-Edge Circuit Validation

Run: 2026-09-09 13:09:11 UTC. MATLAB 26.1.0.3276743 (R2026a) Update 3. Parameter set: `SC01A-ASSUMED-V1`.

**SC-01A is implemented and numerically verified.** The native Simscape model resolves prescribed finite switching edges through an explicit two-line receiver circuit and a loaded shared return. The model, source data, raw refined traces, threshold records, solver-refinement evidence and repeatable workflow are saved. This is circuit-model verification with assumed inputs; no hardware measurements or transistor switching-source validation are claimed.

## What was built

- Two explicit aggressor-to-line coupling capacitors (10/9 pF nominal).
- Behavioral series induced-voltage sources from 20/17 nH times prescribed commutation-current slope. These are not a reciprocal mutual-inductor device model.
- A physical 25 milliohm / 20 nH shared return carrying actual return current, including receiver/driver loading.
- A 120 ohm / 100 pF differential receiver load, 47/53 ohm source resistances, 50/70 pF line-to-ground capacitances, and 10/20 kilohm bias returns.
- Intended open-circuit differential source levels of +2 or -2 V at 2.5 V common mode, with finite victim transitions. The loaded nominal high differential is approximately 1.085917 V.
- Actual conserving-port voltage/current sensors and an independent three-state, piecewise-exact affine circuit reference.

All new circuit values remain declared assumptions. The old scalar path-transfer factors, common-mode conversion factors and volts-to-radians mapping are not applied to this circuit. The 24 V / 100 ns and 3 A / 200 ns ramps are independent bench excitations. Negative-edge tests use signed perturbations from zero to -24 V / -3 A; they are not selected-device turn-off waveforms.

## Verification results

| Check | Result |
|---|---:|
| Existing + new automated tests | 67 / 67 passed |
| Deterministic circuit cases | 16 |
| Native circuit simulations | 51 |
| Native simulation warnings | 0 (all runs reached stop time) |
| Step refinements, 1 to 0.5 to 0.25 ns | 32 / 32 passed |
| Tenfold tolerance refinements | 3 / 3 passed |
| Native symmetry, zero-input and superposition checks | 5 / 5 passed |
| Last-period waveform/state comparisons, 10 versus 20 PWM periods | 3 / 3 passed |
| Largest refined differential reference error | 1.77359e-05 V |
| Largest refined common-mode reference error | 4.78097e-05 V |
| Largest refined ground reference error, away from exact source corners | 4.94087e-05 V |
| Largest refined return-current reference error | 2.2746e-06 A |

The native variable-step solver is `ode23t`, with local fixed-step solving and input filtering disabled. Explicit duplicate-time left/right values mark rectangular induced-voltage and derivative-source discontinuities without smoothing them. An early pilot with zero-order-held jumps produced minimum-step warnings; the explicit event encoding corrected that issue before the final campaign. The final campaign records zero simulation warnings and completed stop times for every recorded run. The adapter retains engine diagnostics and rejects any warning; an intentionally injected warning was also checked to confirm that this rejection path works.

Every standard case uses maximum integration steps of 1, 0.5 and 0.25 ns with relative tolerance 1e-5 and absolute tolerance 1e-9. Three representative cases repeat 0.25 ns with tolerances 1e-6 and 1e-10. These are actual integration settings, not just exported sample spacing. All outputs are finite and the loaded DC initialization is checked independently. Short-record reference checks use every native solver point; long records use 100,001 selected native points plus source-corner neighborhoods. Exact algebraic source-corner timestamps are excluded only from pointwise ground-voltage comparison because left/right values differ. State voltages and return current remain checked at every selected point.

## Refined circuit results

Differential and common-mode disturbances subtract the matching intended-only loaded-circuit response. The threshold columns use the **total** differential receiver input; +/-0.20 V is an illustrative diagnostic band, not a selected receiver model.

| Case | Peak differential disturbance (mV) | Peak common-mode disturbance (mV) | Total input minimum (V) | Time inside +/-0.20 V band (ns) |
|---|---:|---:|---:|---:|
| `baseline` | 0.00000 | 0.00000 | 1.085917 | 0.00000 |
| `capacitive_rise` | 7.19365 | 113.31166 | 1.078724 | 0.00000 |
| `inductive_rise` | 29.98022 | 277.07299 | 1.080124 | 0.00000 |
| `shared_rise` | 17.12290 | 372.31598 | 1.068795 | 0.00000 |
| `combined_rise` | 51.73392 | 725.33851 | 1.063824 | 0.00000 |
| `combined_fall` | 51.73580 | 725.33851 | 1.034182 | 0.00000 |
| `balanced_combined` | 0.00000 | 725.39252 | 1.088929 | 0.00000 |
| `zero_coupling` | 0.00000 | 0.00000 | 1.085917 | 0.00000 |
| `zero_source` | 0.00000 | 0.00000 | 1.085917 | 0.00000 |
| `logic_low` | 51.73715 | 725.33851 | -1.113572 | 0.00000 |
| `transition_leads` | 51.73893 | 725.33851 | -1.091477 | 18.38061 |
| `transition_coincident` | 51.73607 | 725.33849 | -1.091477 | 18.38927 |
| `transition_lags` | 51.73715 | 725.33854 | -1.091477 | 18.38124 |
| `stress_fall` | 1823.45903 | 2370.89866 | -0.737542 | 15.39399 |
| `pwm_10` | 51.82132 | 725.33851 | 1.034096 | 0.00000 |
| `pwm_20` | 51.82144 | 725.33851 | 1.034096 | 0.00000 |

`stress_fall` increases the positive-line aggressor capacitance to 300 pF and reduces the negative-line value to 5 pF while applying a negative bench edge. These are exploratory stress settings, not measurements. The transition cases deliberately change the intended signal; their diagnostic-band residence is partly an intended transition and is not counted as a receiver failure. Event CSVs record level, direction, time and whether the crossing belongs to noise delta or total receiver input.

## Numerical acceptance and what it establishes

Successive peak changes must stay below the larger of 1% of the refined disturbance peak or 0.1 mV. Absolute integrated-disturbance changes use the larger of 1% of the refined area or 0.1 mV times the 100 ns source-ramp duration (1e-11 V*s). Matched crossing-time and exposure-duration changes must be below 1 ns, with identical crossing classifications. Near-threshold extrema or plateaus are flagged as grazing and cannot silently pass. The complete ratios and differences are in the convergence tables.

The original passive network is held fixed for source-decomposition superposition. Zero coupling is a separate topology test: zero-valued coupling capacitors are physically omitted. The balanced case removes all paired-line asymmetries, not only capacitor or mutual-term imbalance. For PWM settling, corresponding final complete periods are compared at a common time grid; twice-longer total areas are not mistaken for a settling comparison.

These results verify the deterministic circuit implementation and numerical resolution. They do not predict a real receiver output glitch, an encoder count error, a communication error rate, an EMC limit or robot stability under measured interference. The model still omits selected-device switching charge, a reciprocal multi-conductor inductance network, nonlinear input clamps, distributed cable propagation and a complete receiver/decoder.

## Files and rerun

From `06_Circuit_Simulations/SC01A`, run `sc01a_main`. The workflow runs the existing 45 control/sensitivity tests, the new circuit/threshold tests, the native case matrix, refinement checks, figures and this report. The saved `models/EMI_SC01A_Finite_Edge.slx` includes nominal default inputs and parameters for standalone Run.

- `models/EMI_SC01A_Finite_Edge.slx` and its PNG diagram: actual native conserving circuit.
- `sc01a_parameters.json`: parameter set and assumed provenance.
- `sc01a_case_manifest.json` and CSV: complete case parameters and a compact case-input table.
- `sc01a_case_metrics.csv`: solver settings, metrics, reference errors, sample counts and runtimes.
- `sc01a_convergence.csv`, `sc01a_tolerance_refinement.csv`, `sc01a_native_invariants.csv`, `sc01a_period_settling.csv`: numerical checks.
- `sc01a_tests.csv`: automated test evidence.
- `sc01a_*_events.csv`: interpolated threshold-crossing records.
- `sc01a_*_timeseries.csv`: full refined short-case traces; `sc01a_pwm_*_last_period.csv`: last-period views.
- `raw/sc01a_*.mat`: full native refined traces and complete case/source definitions, including long PWM runs.
- `sc01a_study.mat`: campaign metrics, comparisons and representative examples.
- `sc01a_overview.png`: checked result overview.
- `sc01a_refinement_overlay.png` and `sc01a_combined_rise_refinement_*_ns.csv`: three retained native-grid waveform refinements.

## Next work

SC-01A is complete. SC-01B will replace the prescribed sources with a device-parameterized half-bridge after driver, MOSFET/diode, charge/capacitance and commutation-loop data are selected and recorded. Receiver/decoder identification and measured circuit comparison remain necessary for physical validation. Supply interruption and Phase 3 resilient control remain separate unfinished project work.
