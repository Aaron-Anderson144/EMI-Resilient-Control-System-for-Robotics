# Phase 2B Sensitivity Study

Completed: 2026-09-09 12:24:38 UTC. MATLAB 26.1.0.3276743 (R2026a) Update 3. Parameter set: `REPRESENTATIVE-ACTUATOR-V0.2`.

The parameter-sensitivity milestone is complete for the existing reduced-order model. The study identifies which assumptions matter within the chosen ranges, preserves reproducible inputs and results, and defines the evidence needed for the next circuit model. No hardware parameters were identified or experimentally validated.

## Execution and verification

| Check | Result |
|---|---:|
| Study simulations | 1886 |
| Parameter controls screened | 26 |
| One-at-a-time runs, both contexts | 506 |
| Stratified parameter sets | 512, each in two contexts |
| Two interaction grids | 264 runs |
| Low/nominal/high no-fault regressions | 78 passed |
| Automated project tests | 45 / 45 passed |
| Selected MATLAB/Simulink comparisons | 11 / 11 passed |
| Largest checked numerical difference | 2.2751e-12 |
| Numerical tolerance | 1e-9 in each logged quantity's unit |
| Analytical study runtime (excluding tests/plotting/Simulink) | 63.3 s |

All study trajectories were finite. Every study run matched the clean trajectory before the shared analysis window. The no-fault parameter checks had a largest position/received-measurement/command difference of 0. Selected Simulink checks used 1,501 samples each, all 29 logged channels plus time, and exact discrete diagnostics. The selected comparisons are representative checks, not Simulink execution of every sweep point.

## Which assumptions changed position the most?

This ranking holds all other inputs at their nominal values and uses loss-free communication. It ranks the largest whole-record position change from the nominal faulted trajectory. It depends on the chosen ranges and is not a normalized or universal importance ranking.

| Assumption | Explored range | Largest change from nominal (deg) |
|---|---|---:|
| Ground common-mode offset | -0.5 to 0.5 V | 0.664393 |
| Equivalent voltage-to-angle gain | 1 to 50 deg/V | 0.445557 |
| Ground CM-to-DM factor | 0 to 0.5 1 | 0.442929 |
| Receiver-equivalent envelope frequency | 5 to 400 Hz | 0.433181 |
| Shared-return CM-to-DM factor | 0 to 0.5 1 | 0.032476 |
| Shared-return inductance | 2 to 100 nH | 0.025981 |
| Current rise time | 50 to 800 ns | 0.025596 |
| Inductive imbalance | -15 to 15 nH | 0.012700 |
| Commutation current step | 0.5 to 6 A | 0.010156 |
| Equivalent baseband bandwidth | 30 to 1e+07 Hz | 0.008634 |

Ground-reference disturbance, conversion into differential error, the assumed voltage-to-angle bridge and the envelope frequency deserve early attention in this design. The bridge is phenomenological: its strong sensitivity is a reason to replace it with receiver/decoder evidence before interpreting angular error as a real prediction. The measured transfer of ground/common-mode disturbance should be characterized alongside it.

At the nominal source slope, the shared-return equation contains a 75 mV resistive term and a 300 mV inductive term before differential conversion. Independent tests confirmed the expected 1.2x total after doubling resistance alone and 1.8x after doubling inductance alone. This 20%/80% split is conditional on the assumed 3 A commutation step and 200 ns rise time.

## Combined assumptions reveal larger modeled errors

Both contexts use the same **[0.70, 1.15) s** analysis window and matched no-fault baseline. The fixed communication realization can amplify or partly cancel physical disturbances; a smaller metric in one case is not evidence that packet faults improve the system.

| Measure | Physical channels only | With fixed communication faults |
|---|---:|---:|
| Nominal active peak position delta (deg) | 0.111389 | 0.128035 |
| Largest sampled active peak position delta (deg) | 11.828475 | 13.557830 |
| Largest sampled active position RMSE (deg) | 8.067279 | 8.224780 |
| Largest sampled receiver differential peak (V) | 1.758116 | 1.758116 |
| Cases without observed recovery by record end | 48 / 512 | 54 / 512 |
| Cases crossing the assumed 0.20 V diagnostic margin | 183 / 512 | 183 / 512 |
| Cases with active/post-window command saturation | 0 | 0 |

The extrema in different rows may come from different parameter sets. All 512 input vectors and their matched results are saved; selected extreme time histories are also exported. These are finite, assumed exploration ranges. Counts in this table are not real-world probabilities, and the largest sampled result is not a guaranteed worst case. A 0.20 V diagnostic crossing does not trigger a count error in this model. Finite unsaturated trajectories do not establish a stability guarantee.

Recovery uses a 0.05-degree tolerance sustained for 50 samples. The record ends at 1.50 s, leaving 0.35 s after the study window. Censored recovery means that required dwell was not observed in this record; it does not prove permanent failure. A zero value means the response already meets the configured tolerance.

## Model limitations exposed by the sweep

- Noise margin and common-mode limit change flags only; they do not change controller feedback.
- Receiver differential capacitance changes a reported pole but does not filter the waveform.
- PWM frequency, fall time, pulse-width setting and count cap are inactive. Equal changes to both line capacitances or both mutual inductances preserve the differential imbalance. Their negligible effects here are implementation facts, not physical conclusions.
- Receiver bandwidth acts at the envelope frequency. The low-bandwidth cases describe a hypothetical baseband filter, not measured nanosecond receiver behavior.
- Fixed phases and a largely settled step trajectory limit generalization; moving-trajectory and phase studies remain future work.

## Next engineering work

1. Identify the ground-to-differential transfer and receiver/encoder behavior; record intended signal levels, common-mode movement and decoded counts against an independent position reference.
2. Identify shared-return impedance, actual source edges and paired-line imbalance. Use independently measured transfer data to avoid fitting several confounded scalar factors from the same position trace.
3. Implement the proposed **SC-01A finite-edge electrical harness** with explicit loading and return paths, then establish numerical convergence. The companion circuit specification contains the required evidence and primary-source references.

The SC-01 specification is prepared; the circuit is not yet implemented. Supply interruption remains a separate unfinished Phase 2 mechanism. Phase 3 fault detection and resilient control are still future work.

## Files and rerun

Run `phase2b_sensitivity_main` from `03_MATLAB`. The workflow recreates the tests, design, metrics, figure, selected Simulink comparisons, MAT archive and this summary in `results/sensitivity`.

- `phase2b_sensitivity_catalog.csv`: exact ranges, units, scale and implementation roles.
- `phase2b_sensitivity_oat.csv` and `phase2b_sensitivity_ranking.csv`: one-at-a-time results.
- `phase2b_sensitivity_global_inputs.csv` and `phase2b_sensitivity_global_metrics.csv`: paired design and results.
- `phase2b_sensitivity_interaction_grids.csv`: controlled response surfaces.
- `phase2b_sensitivity_study.mat`: full input structures, metrics and validation case definitions.
- `phase2b_sensitivity_case_*.csv`: selected time histories.
- `phase2b_sensitivity_tests.csv`, `phase2b_sensitivity_no_fault_regression.csv`, and `phase2b_sensitivity_simulink_validation.csv`: verification evidence.
- `phase2b_sensitivity_overview.png`: checked four-panel figure.
- `04_EMI_Models/Phase2B_Sensitivity_Method.md`: design and metric definitions.
- `04_EMI_Models/Parameter_Identification_and_Switching_Case.md`: input-evidence plan and proposed next circuit.
