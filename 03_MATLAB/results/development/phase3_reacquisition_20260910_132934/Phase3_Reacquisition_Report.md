# Phase 3 independent-reference observer recovery

**Implemented and verified locally on 10 September 2026.** The original project now includes an optional recovery path for an observer that cannot accept returning encoder data after a sensor freeze. This is `PHASE3-PROTOTYPE-V1.1`; the actuator parameters remain `REPRESENTATIVE-ACTUATOR-V0.3`.

The new path defaults off. It requires a separate position-reference stream with a declared error bound, reconstructs the current position, velocity and current from a short observation history, and permits an explicit re-anchor only while the controller is already latched stopped. The primary encoder must then qualify again, followed by a separate reset. Reference data cannot release the drive on their own.

## Local verification

| Check | Result |
|---|---|
| Full existing control and active circuit test suites, including additions | **282/282 passed** |
| New tests | **38**: 23 reconstruction tests and 15 integration tests |
| New numerical recovery fixtures | **15/15 met declared expectations**, 3,001 samples each |
| New independent-plant Simulink comparisons | **15/15 passed** |
| Original campaign replay | **116/116 records exactly reproduced** for time, all plant states, original 20 loop channels and decision reasons |
| Original protected/unprotected Simulink comparisons | **58/58 passed** under the extended log schema |
| Additional rebuilt saved-model verification | **1/1 nominal comparison passed** |
| Independent Python export audit | **129/129 checks passed** |

The 73 campaign Simulink comparisons verify all 34 numeric channels: three plant states and 31 loop channels. Discrete values and missing-innovation masks match exactly, all runs complete without simulation warnings, and the largest absolute channel difference is 5.06e-13, below the declared 1e-9 threshold. The extra saved-model check is a repeated nominal case, not new unique fault coverage.

MATLAB and Simulink share the tested observer/control helpers and sensor fixtures, while their actuator plants evolve independently. These comparisons verify integration; they are not a second independent detector implementation. The Python audit separately recalculates command/latch invariants, event times, release evidence and tracking metrics from CSVs. The recorded MATLAB, Simulink and Python checks ran locally. No hardware measurements or external publication were performed.

## Recorded behavior

In the original dropout fixture, the observer re-anchors at **1.500 s**, the fixed operator reset is accepted at **2.000 s**, and normal mode resumes at **2.050 s**. The no-reference run stays stopped through 3 seconds. Full-record tracking error changes from 3.838° RMSE to 3.640°; final position changes from 27.607° to 29.970° for the 30° target.

- Missing or coincident early reset keeps the actuator command at zero despite a successful re-anchor.
- Missing request, interrupted reference data, old timestamps, understated noise, excess declared uncertainty and the declared unknown-load fixture prevent a commit.
- A persistent primary-encoder bias blocks release even after the independent reference reconstructs the observer.
- Bounded reference error and delayed returning primary packets recover in their declared fixtures.
- The loaded moving fixture reconstructs nonzero velocity/current. Its tracking error remains approximately **54.0° RMSE**: observer recovery does not solve the zero-voltage stop/hold problem.

![Local recovery results](reacquisition_results.png)

The default window uses 51 synchronized reference samples over 50 ms. With the study's 0.005° reference-error declaration, its calculated state-error bounds are approximately **0.00729° position, 0.00218 rad/s velocity and 0.000158 A current**. Tests construct worst-sign measurement errors that attain the componentwise bounds.

## Limits retained

Those bounds assume the configured plant, applied-voltage history and constant load are exact. They cover reference-position measurement errors; they do not cover unknown model/load/input errors. The reference is synthetic, and neither its physical independence nor its declared error bound has been validated.

A deliberately undeclared 0.8° constant reference bias passes the dynamic fit and commits a biased estimate. Disagreement with the primary encoder prevents release in that fixture. This records the limit: consistency with a model does not establish sensor truth.

Stationary freezes, small bias and slow drift remain single-sensor observability limits. Derating/recovery tuning, physical stop/hold under load, selected reference hardware and broader uncertainty validation remain open. The broad Phase 3 gate remains open.

## Reproduce and recover files

In the project's `03_MATLAB` folder, run `startup_project`, then `phase3_reacquisition_main`. The entrypoint runs the 38 new tests, 15 numerical fixtures and their Simulink comparisons into a fresh evidence folder. The generated V2-31 Simulink model is installed in the project; original loop channels keep their order. The default configuration leaves independent-reference recovery disabled.

The design contract is `05_Control_Algorithms/Phase3_Independent_Reference_Recovery.md`. The README, roadmap, decision log and requirements map identify the new capability and remaining gaps.

Full local evidence: `C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics\03_MATLAB\results\development\phase3_reacquisition_20260910_132934`.

This review package includes the [scenario summary](reacquisition_summary.csv), [test results](all_project_tests.csv), [exact original-response comparison](legacy_exact_regression.csv), [independent audit](independent_export_audit.json), [source inventory](source_changes.csv), [extension source checkpoint](source_checkpoint.zip) and [pre-change rollback archive](source_rollback.zip). The source checkpoint contains the added/changed extension files; it is not a complete copy of the project. Earlier evidence is preserved in its existing folders. Initial development failures were fixture/setup errors and are retained in the task's work logs; they are not counted as passing acceptance runs.
