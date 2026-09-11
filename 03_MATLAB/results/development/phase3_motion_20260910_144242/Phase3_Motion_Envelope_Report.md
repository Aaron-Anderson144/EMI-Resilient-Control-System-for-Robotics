# Phase 3 motion envelope and causal reference shaping

**Implemented and checked locally on 10 September 2026. The optional motion profile meets all predeclared numerical requirements.** The existing 25 rad/s observer rate threshold, controller gains, voltage/slew constraints, stop/reset rules and saved models remain unchanged.

In the exact previously failing clean reversal, raw-reference operation produces **41 alarm samples**, while the governed reference produces **0**. Peak actual speed changes from **26.048 to 7.701 rad/s**. The reference shaper is optional and explicitly limits admitted requested position and generated-reference motion; it does not establish a physical robot operating envelope.

## Local verification

| Check | Result |
|---|---|
| Full project suite | **348/348 tests passed**, including 33 new motion tests |
| Focused additions | 19 governor tests, 6 fixture tests and 8 independent envelope/metric tests |
| Numerical study | **80 runs**: 20 cases × raw/governed × fault/matched-clean |
| Independent-plant Simulink comparisons | **22/22 passed**: all 20 governed cases and both raw development controls |
| New clean evaluations | **8/8** meet declared motion, alarm and final-task requirements |
| New true-fault evaluations | **8/8** meet the declared response/stop/reset requirements |
| Historical reversal replay | Complete original numerical record reproduced exactly |
| Prior MATLAB source and saved model identity | **135 files unchanged**, checked with SHA-256 |
| Independent export audit | **9,390/9,390 checks passed**; [full audit](independent_motion_audit.json) |

All 80 fault and matched-clean records pass the common finite-command, command-bound, stopped-zero and release-evidence checks. Governed reference bounds and non-reference profile/controller identity checks are separate requirements. Unknown-load and model-mismatch diagnostics are recorded without a clean-performance acceptance claim. Overall declared acceptance is **true**; the numerical test and integration evidence does not establish hardware safety.

Every Simulink comparison covers all 34 numeric channels, with exact discrete profiles and matching missing-innovation masks. All comparisons completed without simulation warnings. The largest absolute channel difference is **1.01e-12**, below the existing 1e-9 threshold. MATLAB and Simulink share the tested decision helpers while their plants evolve independently; this verifies integration, not a second independent observer implementation. All simulations, tests and audits ran locally.

## What changed

The new profile wrapper applies the causal step helper to the current requested position. It stores the original request, the intermediate slew-limited position, the shaped command and their derivative evidence. Existing `reference_rad` continues to mean the command actually supplied to the controller; `requestedReference_rad` retains the original task. Every non-reference fault, load, supply, communication and reset profile remains exactly identical between comparisons.

The fixed nominal policy admits requested positions within **±120°**, limits generated-reference speed to **10 rad/s**, and limits its finite-difference acceleration to **200 rad/s²**. Those speed and position limits leave declared margins to the unchanged observer's 25 rad/s and ±π gates. At the 1 ms sample time, the smoothing coefficient is 0.01, equivalent to about 99.5 ms first-order time constant.

At each elapsed tick, an internal position moves toward the current request by at most `V × Ts`. The output then moves a fraction `beta = min(1, A × Ts / (2V))` toward that internal position. Both states start at the observer's declared initial position with zero reference velocity; sample zero introduces no hidden jump.

Writing the internal step speed as `w`, output speed satisfies `v_next = (1−beta) × v + beta × w`. Since `|w| ≤ V`, this convex recurrence preserves `|v| ≤ V`, and `|v_next−v| / Ts ≤ 2 × beta × V / Ts ≤ A`. Convex position updates also preserve the global range of initial and requested positions. This does not forbid temporary motion away from a newly reversed target, and the filter has an asymptotic settling tail. Independent tests check a closed-form ramp, full-speed reversal at beta=1, arbitrary retargeting, prefix causality, initial alignment and invalid saved-state rejection.

The helper sees the current request and its own state only. It does not use future knots, plant truth, fault masks or supervisor mode. The offline profile wrapper reproduces that per-tick interface for the existing MATLAB/Simulink harness. It continues shaping during a stop; it neither brakes the plant nor guarantees a gentle catch-up after a large stopped-position error. Out-of-range or malformed requests are rejected as software contract errors; that rejection is not a hardware emergency-stop implementation.

## Reproducing the original conflict

The original noisy ±45° reversal and its exact raw response remain preserved as development evidence. Its noiseless control produces **41 raw alarms versus 0 governed alarms**. This separates the motion/rate-check conflict from an assertion that small measurement noise alone caused it.

For the noisy case's unchanged fixed scoring window, tracking error against the **original request** changes from **47.592° to 50.766° RMSE**. Governed tracking error against the **shaped command** is **9.551° RMSE**; imposed shaping lag alone is **44.001° RMSE**. These quantities are reported separately so slowing the command cannot masquerade as completing the original task sooner.

![Original clean reversal and governed response](phase3_motion_reversal.png)

The observer gate uses position differences over source timestamps since the last trusted measurement. Actual instantaneous plant speed is a related diagnostic, not the literal gate input. The new metrics reconstruct finite candidate measurement rates, including rejected candidates, while preserving source-age, history and trusted-sample semantics.

## New clean evaluations

The design was frozen before campaign execution, with one analytical policy rather than a parameter search. Eight new clean cases cover large positive/negative steps and reversals, repeated moving retargets, known signed loads, a new noise seed and permitted delayed/jittered packets. The old failure is development evidence; it is not counted as new evaluation coverage.

Clean gates require no alarms or nonnormal modes, full-record actual speed at most 20 rad/s, candidate received rate at most 25 rad/s, and final original-request error plus last-0.1-second RMSE at most 0.5°. The observed governed maxima across these cases are **10.471 rad/s actual speed** and **10.471 rad/s candidate measurement rate**.

| New clean fixture | Alarm samples: raw → governed | Peak actual speed, rad/s: raw → governed | Original-request window RMSE, °: raw → governed | Governed final-tail RMSE, ° | Result |
|---|---:|---:|---:|---:|---|
| clean_step_80 | 0 → 0 | 22.925 → 7.153 | 17.939 → 37.324 | 0.0000 | Pass |
| clean_reversal_75 | 1871 → 0 | 53.047 → 9.803 | 204.677 → 75.356 | 0.0325 | Pass |
| clean_reversal_100 | 2787 → 0 | 30.864 → 10.471 | 300.017 → 101.677 | 0.1324 | Pass |
| clean_rapid_retargets | 2750 → 0 | 53.881 → 9.200 | 217.930 → 63.124 | 0.1121 | Pass |
| clean_known_positive_load | 1772 → 0 | 40.235 → 8.980 | 164.400 → 57.200 | 0.0372 | Pass |
| clean_known_negative_load | 1831 → 0 | 51.278 → 9.694 | 209.291 → 72.275 | 0.0381 | Pass |
| clean_new_noise_reversal | 1749 → 0 | 53.037 → 9.795 | 204.726 → 75.229 | 0.0645 | Pass |
| clean_permitted_delay_jitter | 1927 → 0 | 52.646 → 10.299 | 144.258 → 94.765 | 0.0396 | Pass |

![New clean evaluations and original-task cost](phase3_motion_clean_evaluation.png)

These are deterministic assumed-model fixtures. The Gaussian noise case has a fixed seed and specified standard deviation; it is not a guarantee for every possible noise realization. Reference speed bounds alone cannot guarantee plant speed under arbitrary loads, tracking errors or model mismatch.

## Fault detection and stop/restart checks

Eight new corrupted-sensor, communication and supply cases retain the original detector and supervisor. Fault credit requires the specified new alarm or stop after exposure and by its fixed deadline; a preexisting unrelated response cannot satisfy the gate. Supply interruption requires a stop response, because it need not produce an observer alarm. Stop/reset requirements are explicit per case, and original requested-task error remains recorded even while stopped.

| Fault fixture | Required response | First qualifying response / deadline, s | Stop duration, s | Final mode | Result |
|---|---|---:|---:|---:|---|
| fault_count_jump_reversal | alarm | 1.027 / 1.028 | 0.000 | 0 | Pass |
| fault_out_of_range | alarm | 0.823 / 0.824 | 0.000 | 0 | Pass |
| fault_moving_freeze | alarm | 0.233 / 0.281 | 0.000 | 0 | Pass |
| fault_short_packet_gap | alarm | 0.567 / 0.572 | 0.000 | 0 | Pass |
| fault_long_packet_gap | alarm | 0.631 / 0.636 | 1.139 | 0 | Pass |
| fault_loaded_supply_interruption | stop | 0.873 / 0.874 | 1.127 | 0 | Pass |
| fault_persistent_bias | alarm | 0.687 / 0.737 | 2.063 | 4 | Pass |
| fault_excessive_delay | alarm | 0.753 / 0.758 | 1.017 | 0 | Pass |

Mode numbers are 0 normal, 1 suspected, 2 degraded, 3 recovery and 4 stop. The long-packet-gap case requires both a latched stop and qualified release using returned primary samples plus the fixed separate 2 s reset. The loaded supply case requires stop and preserves any subsequent drift/recovery limitations. Fresh frozen values at rest remain unobservable with the single primary sensor; this moving-freeze result does not remove that limit.

| Separate governed diagnostic | Alarm samples | Peak actual speed, rad/s | Original-request window RMSE, ° | Final mode |
|---|---:|---:|---:|---:|
| diagnostic_unknown_load | 0 | 9.300 | 63.023 | 0 |
| diagnostic_model_mismatch | 0 | 9.964 | 75.634 | 0 |

These diagnostics do not certify a model/load uncertainty range. Physical stop/hold under load, calibrated sensor/error bounds, unknown dynamics and independent reference integrity remain open. The previously rejected gain/filter candidate remains unpromoted; this study changes only the optional command profile.

## Reproduce and recover source

From the project's `03_MATLAB` folder, run `startup_project`, then `phase3_motion_main`. It runs the 33 focused motion tests, 80 numerical runs, 22 Simulink comparisons and figures in a fresh evidence folder. The recorded full regression also ran all 348 project tests. Direct use is through `phase3_motion_profiles(params, scenario, configuration)`; the lower-level initialization and step helpers expose the causal interface.

The design contract is `05_Control_Algorithms/Phase3_Motion_Envelope.md`. Full local evidence: `C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics\03_MATLAB\results\development\phase3_motion_20260910_144242`. Pair folders retain requested/command responses, matched-clean responses, governor traces and exact MAT profiles/configurations. Saved manifests bind the case declarations and outputs to source identity.

The review package includes [metrics](motion_metrics.csv), [matched-clean checks](matched_clean_metrics.csv), [profile/configuration identity](profile_and_configuration_identity.csv), [historical replay](historical_reversal_regression.json), [tests](all_project_tests.csv), [Simulink checks](phase3_simulink_validation.csv), [the frozen design](frozen_design.json), [decision](decision.json), [source inventory](source_changes.csv), [source checkpoint](source_checkpoint.zip) and [documentation rollback](source_rollback.zip). The checkpoint contains this extension's additions and updated documentation, not a full copy of the project. Existing code, default workflows, saved models and earlier evidence remain preserved.
