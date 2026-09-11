# Phase 3 controller tuning and separate evaluation

**Study completed locally on 10 September 2026. The historical defaults are retained. The faster candidate improves tracking in several fixtures, but does not satisfy the complete comparative requirements.** The declared clean-operation guard also fails in one newly introduced reversal fixture under all three evaluation policies; overall study execution/clean acceptance is **false**. The software tests and independent-plant integration checks pass.

None of the nine policies met all predeclared tuning requirements. **G100_F020 was frozen for diagnostic evaluation only** because it had the lowest nonhistorical tracking score. Its mean normalized window tracking score improves by **17.35%** on the eight tuning cases and **29.37%** on the twelve separate evaluation cases. It passes all per-case comparative gates in **5/8 tuning cases** and **4/12 evaluation cases**. An aggregate improvement does not override a failed case gate.

The selected settings use a 100% degraded controller tuning target and a 20 ms degraded/recovery reference filter. The grid retains the existing voltage caps, slew limits, anti-windup, observer thresholds and stop/reset rules. These targets are assumed-model tuning settings, not measured closed-loop bandwidths.

## Local verification

| Check | Result |
|---|---|
| Full project tests | **315/315 passed**, including 33 new tuning tests |
| Numerical study | **226 executions**: 113 fault/matched-clean pairs |
| Fixed grid and evaluation | 9 policies × 8 tuning cases; historical, frozen candidate and relaxed-extra-constraint comparator × 12 evaluation cases |
| Additional single-limit comparisons | 5 new pairs; 3 existing pairs reused in the 8-row limiter comparison |
| Independent-plant Simulink comparisons | **20/20 passed** across all 34 numeric plant/loop channels |
| Previously verified MATLAB sources and saved models | **122 files unchanged**, checked by SHA-256 |
| Independent Python audit | **7,336/7,336 checks passed**, including faithful reproduction of the rejected study outcome |

Finite state/command, effective command/supply bounds, zero commanded voltage in stop, stopped-only re-anchor commits and qualified reset release checks pass throughout. The declared `eval_benign_noise_reversal` clean guard fails under historical, selected and relaxed-extra-constraint policies. Thus `executionAccepted=false` is retained separately from the failed candidate tuning eligibility. The Python audit verifies those failures and also checks the matched-clean exported records.

All Simulink runs completed without warnings. Discrete profiles and missing-innovation masks match exactly; the largest absolute numeric-channel difference is **7.8e-13**, below the declared 1e-9 threshold. Simulink has an independently evolving plant and shares the tested control/observer helpers; it is an integration comparison, not a second independent detector implementation. All simulations, tests, plots and export audits ran on this computer.

## Frozen selection and observed tradeoffs

The design and source identity were recorded before the grid. The selection was written before evaluation and was not changed using evaluation results. Each metric uses a declared calendar window `[start, stop)` against the original commanded reference; a stopped policy does not receive a shorter scoring interval. Every faulted run has its own clean counterpart. The primary score averages window RMSE divided by `max(historical window RMSE, 0.25°)`.

| Policy | Score / historical | Aggregate improvement | All gates per case | Eligible |
|---|---:|---:|---:|---|
| G050_F000 | 0.9709 | 2.91% | 6/8 | No |
| G050_F020 | 0.9813 | 1.87% | 7/8 | No |
| G050_F050 | 1.0000 | 0.00% | 8/8 | No |
| G075_F000 | 0.8776 | 12.24% | 5/8 | No |
| G075_F020 | 0.8785 | 12.15% | 5/8 | No |
| G075_F050 | 0.9006 | 9.94% | 6/8 | No |
| G100_F000 | 0.8333 | 16.67% | 5/8 | No |
| G100_F020 | 0.8265 | 17.35% | 5/8 | No |
| G100_F050 | 0.8415 | 15.85% | 6/8 | No |

![Frozen nine-policy comparison](phase3_tuning_grid.png)

In the motion-freeze tuning window, the frozen selection changes tracking RMSE from **20.138° to 5.491°**, while window peak current changes from **0.1188 A to 0.2429 A**. In reversal during recovery, RMSE changes from **34.956° to 21.425°**, with window peak current changing from **0.2017 A to 0.8489 A**. These fixed windows differ from the original Phase 3 ablation windows; their RMSE values should not be mixed.

Selected-policy tuning failures:

| Fixture | Failed comparative checks |
|---|---|
| freeze_during_motion | window peak current |
| reversal_during_recovery | window peak current |
| capped_reversal | window peak current |

The provisional gates permit the larger of +10% or +0.25° for tracking/disturbance RMSE, +5% or +0.5° for peak error, +10% or +0.05 A for peak current, and +10% or +0.5° for final error. Existing alarms cannot be lost or delayed more than 1 ms; recorded recovery and final normal mode must be preserved; no new stop is allowed where historical stop duration is zero, otherwise at most 50 ms extra. All case gates plus at least 10% aggregate improvement are required. These are frozen comparative tolerances, not calibrated hardware limits.

## Separate evaluation

The twelve fixtures were declared before tuning and did not drive the frozen choice. They cover fault sign/duration, reference reversal, known and unknown load, resistance/inertia mismatch, permitted timing variation, a new noise seed, opposite limiting stress and independent-reference recovery with and without reset. They are constructed numerical cases, not a blinded physical experiment or statistical sample of robot failures.

**The intended clean ±45° reversal exceeds the existing observer rate contract.** The first alarm occurs at 1.427 s under every evaluation policy. Historical true velocity is about −25.145 rad/s at that tick, beyond the configured 25 rad/s position-rate limit; its innovation is only about −0.0000506 rad. All 41 historical alarm samples and all 27 selected-policy alarm samples have reason `position_rate`. The matched-clean traces retain the same reference and benign noise. This exposes an inconsistent clean-motion assumption and rate-check envelope; it does not isolate noise as the cause. The fixture label, threshold and failed result are preserved.

| Evaluation fixture | Window RMSE, °: historical → selected | Window peak current, A: historical → selected | All comparative gates |
|---|---:|---:|---|
| eval_negative_freeze | 11.925 → 2.993 | 0.1838 → 0.2616 | Fail |
| eval_short_freeze | 3.436 → 1.939 | 0.3816 → 0.3816 | Fail |
| eval_reversed_burst | 44.039 → 29.872 | 0.3027 → 1.2732 | Fail |
| eval_known_positive_load | 0.773 → 0.329 | 0.1252 → 0.1254 | Fail |
| eval_known_negative_load | 0.773 → 0.329 | 0.1252 → 0.1254 | Fail |
| eval_unknown_load_freeze | 2.069 → 4.306 | 0.2403 → 0.2410 | Fail |
| eval_model_mismatch_burst | 25.771 → 5.283 | 0.0629 → 0.0331 | Pass |
| eval_permitted_delay_jitter | 14.475 → 14.475 | 1.9178 → 1.9178 | Pass |
| eval_benign_noise_reversal | 47.592 → 22.927 | 2.8772 → 2.8772 | Fail |
| eval_opposite_capped_reversal | 62.155 → 62.485 | 0.3350 → 0.3879 | Fail |
| eval_independent_reference_recovery | 1.761 → 1.152 | 0.0024 → 0.0021 | Pass |
| eval_independent_reference_no_reset | 2.393 → 1.680 | 0.0000 → 0.0000 | Pass |

![Separate evaluation results](phase3_tuning_evaluation.png)

| Fixture | Failed comparative checks |
|---|---|
| eval_negative_freeze | window peak current |
| eval_short_freeze | matched-clean disturbance RMSE |
| eval_reversed_burst | window peak current |
| eval_known_positive_load | matched-clean disturbance RMSE |
| eval_known_negative_load | matched-clean disturbance RMSE |
| eval_unknown_load_freeze | tracking RMSE, matched-clean disturbance RMSE, final error |
| eval_benign_noise_reversal | execution invariant |
| eval_opposite_capped_reversal | window peak current |

First alarm and recovery confirmation are whole-record indicators. Recovery confirmation finds 50 ms continuously normal after the first nonnormal response; it does not prove every subsequent fault was detected or every later episode recovered. Final mode and command/reset invariants are checked separately.

## Actual command-limit activity

The two synthetic 2 V command-budget fixtures deliberately make the constraints relevant. All four variants use identical selected gains/filter. `NO_MODE_CAP` removes only mode caps, `RELAXED_SLEW` raises nonnormal slew to 10,000 V/s, and `NO_EXTRA_LIMITS` applies both changes. The last comparator retains the bus/software bound and a finite slew rate.

| Stress fixture | Policy | Window RMSE, ° | Window peak current, A | Mode-cap clips | Coincident-cap clips | Slew clips |
|---|---|---:|---:|---:|---:|---:|
| capped_reversal | G100_F020 | 62.170 | 0.3892 | 78 | 14 | 62 |
| capped_reversal | NO_MODE_CAP | 38.386 | 1.3743 | 0 | 50 | 40 |
| capped_reversal | RELAXED_SLEW | 62.092 | 0.3899 | 78 | 14 | 0 |
| capped_reversal | NO_EXTRA_LIMITS | 37.996 | 1.3764 | 0 | 51 | 0 |
| eval_opposite_capped_reversal | G100_F020 | 62.485 | 0.3879 | 75 | 14 | 63 |
| eval_opposite_capped_reversal | NO_MODE_CAP | 38.766 | 1.3735 | 0 | 50 | 40 |
| eval_opposite_capped_reversal | RELAXED_SLEW | 62.409 | 0.3885 | 76 | 14 | 0 |
| eval_opposite_capped_reversal | NO_EXTRA_LIMITS | 38.361 | 1.3752 | 0 | 51 | 0 |

Clipping counts cover the complete record; tracking/current columns use the fixed scoring window. A coincident-cap clip means mode and available-supply limits are equal, including the ordinary 2 V command budget. Merely reaching a cap is not counted as intervention. Bus-only clipping and separate correction magnitudes are retained in [limiter metrics](limiter_metrics.csv).

Removing mode caps alone improves window tracking RMSE by 38.26% and 37.96%, while window peak current rises 3.53× and 3.54×, and integrated squared current rises 16.16× and 16.68×. Relaxing slew alone changes RMSE by only about 0.12% in each case despite actual slew clipping. These two fixtures show the mode-cap tradeoff clearly; they do not justify removing it or establish a general benefit for every constraint. Anti-windup settings were unchanged, so this study does not isolate anti-windup's benefit.

![Motion and actual clipping in limiting stress](phase3_tuning_limiter_stress.png)

Amplitude and slew interventions are reconstructed from raw command, prior applied command, effective limits and mode-transfer behavior. Anti-windup updates the following integral state and is not a separate same-tick actuator command. Squared-current and squared-voltage integrals are effort proxies; neither they nor clipping counts establish thermal or mechanical safety. Hard-stop samples are separate from clipping.

## Scope and next work

The tuning study is complete and reproducible; the controller's historical defaults remain unchanged. It provides a measured numerical tracking/current tradeoff and identifies the case gates that prevent unconditional promotion. Further tuning needs explicit motion/current priorities and wider identified model/load bounds. Reusing these evaluation cases for another choice would make them development cases, requiring new evaluation fixtures.

The newly exposed motion/rate-check mismatch should be resolved by defining the admissible reference and velocity envelope, then evaluating a compatible reference-shaping/rate-check design on new cases. The present record does not justify simply raising the detector threshold. Physical stop/hold under load also remains unresolved: zero terminal voltage permits load-driven motion, and gain/filter tuning cannot remove drift while the command is forced to zero. Independent-reference integrity and its model/error assumptions, low-motion sensor observability, calibrated thresholds and physical EMI/receiver behavior remain open. The broader Phase 3 gate is still open.

## Reproduction and source recovery

From the project's `03_MATLAB` folder, run `startup_project`, then `phase3_tuning_main`. It creates a fresh evidence directory, runs the 33 tuning tests, executes the frozen 226-run study, performs 20 Simulink comparisons and exports the figures. The full acceptance run additionally included all 315 project tests. The optional constructor `phase3_tuning_configuration(params, options)` reproduces candidate settings without modifying `phase3_configuration`.

The campaign runner deliberately raises `EMIProject:TuningExecutionFailed` after saving complete evidence when a declared invariant fails. The public entrypoint retains that failure and completes integration/figure diagnostics. In this recorded run, the first acceptance script stopped at this assertion; a separate local continuation loaded the saved study and completed those diagnostics without rerunning, changing or relabelling the cases. Passing diagnostic checks does not clear the clean-operation rejection.

The design contract is `05_Control_Algorithms/Phase3_Controller_Tuning.md`. Full local evidence is stored at `C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics\03_MATLAB\results\development\phase3_tuning_20260910_141100`. Per-pair subfolders contain response, matched-clean and actual-activity CSVs plus exact MAT configurations and profiles. The frozen selection's `evaluationStarted=false` records its pre-evaluation checkpoint; the final decision separately confirms evaluation completion.

This review package includes [test results](all_project_tests.csv), [Simulink comparisons](phase3_simulink_validation.csv), [the frozen design](frozen_design.json), [frozen selection](frozen_selection.json), [final decision](decision.json), [source inventory](source_changes.csv), [source checkpoint](source_checkpoint.zip) and [documentation rollback archive](source_rollback.zip). The checkpoint contains this extension's added files and updated documentation, not the full project. Existing simulation code, defaults, models and earlier evidence remain preserved.
