# Development validation: v0.3 parameter, load and supply integration

**Completed locally:** 9 September 2026, MATLAB R2026a Update 3 and Simulink.  
**Installed project:** `C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics`

## Outcome

All four confirmed software defects from the verification report are corrected. Supply sag/interruption integration is complete for the declared averaged motor-terminal model. The updated source, three rebuilt Simulink models, regression tests and live documentation are installed in the original project.

The final active suite passed **150/150 tests**. A separate original SC01B suite passed **22/22 tests**, including five new archive-protection tests. The model-parameter tests and all 13 supply cases also passed again from the original project location. Repeated runs are confirmations, not additional unique coverage.

## Corrections and evidence

| Issue | Implemented result | Evidence |
|---|---|---|
| Parameter metadata could disagree with Simulink constants | Each run applies reference, plant/controller matrices, load, timing and voltage limits. Stale schemas and wrong-project models are rejected. | `TestSimulinkParameters`: changed reference, plant, controller, sample time, load, low bus and nonmutation/path checks. |
| Nominal mechanical load was ignored | Both analytical and block-diagram models now drive the second plant input. Signed load remains active during supply faults. The linear baseline includes its load response. | Independent linear oracle, positive/negative load and all-three-model integration checks. |
| NaN/Inf and malformed inputs were accepted | Finite real scalar, range, integer, timing-grid, scenario and profile checks reject invalid input before simulation. Historical no-supply parameter sets remain supported. | `TestInputValidation`, 12 test methods with multiple mutations. |
| Comparison gates could pass invalid differences or omit channels | A shared gate checks raw dimensions, finite values, ordered/matching time, every channel and exact discrete profiles; tracking-error/raw-command channels are included. | `TestValidationGates`, 10 methods including corruption of every original Phase 2B channel; all 15 legacy cases passed. |
| Command could exceed the nominal bus in older models | All nonlinear realizations and builders cap voltage at the lesser of configured limit and available bus. | Low-bus regression across all three models; the linear baseline remains explicitly unsaturated. |
| Circuit records and output folders were insufficiently guarded | R2 collector validates complete native settings and actual integration grid. Both SC01B runners select fresh default folders and require explicit reuse of populated outputs. | Nine native-record tests, all 17 frozen native records rechecked, five original-runner preservation tests and an R2 sentinel probe. |
| Live plans and evidence links were stale | Updated requirements, roadmap, generator text and quick starts; central traceability map covers all 31 requirement IDs and 10 FMEA IDs. | `02_Requirements/Verification_Traceability.md` records covered, partial and planned claims. |

## Fresh execution

| Check | Result |
|---|---|
| Active control + SC01A + R2 tests | **150/150 passed** |
| Original SC01B tests, isolated MATLAB path | **22/22 passed**: 17 existing and 5 preservation tests |
| Rebuilt-model integration tests | **10/10 passed**, then **10/10** again at the installed location |
| Legacy analytical/Simulink comparisons | **15/15 passed**: 5 Phase 2A and 10 Phase 2B |
| Supply integration | **13/13 passed** in both the development copy and installed project; 3,001 samples per case, zero simulation warnings |
| Sensitivity regression | **1,886 simulations** completed and **11/11** selected Simulink comparisons passed |
| Sensitivity reproduction | All 18 comparable numeric input/result CSVs match the earlier audit exactly; only comparison-error fields improved, within the same 1e-9 gate |
| Frozen R2 native records under stronger collection checks | **17/17 accepted**; no circuit equations or stored results changed |
| MATLAB static analysis | **138 source files checked**; 113 advisory messages, predominantly dynamic array growth; no parser errors reported |

The sensitivity campaign preceded the final low-bus and archive/provenance follow-through. Those changes do not alter its nominal Phase 2B physics; final targeted tests cover the changed paths. The existing 51-run SC01A and 29-run R2 circuit campaigns were freshly reproduced during the preceding audit; this development pass did not repeat those unchanged circuit simulations.

## Supply scope and results

Cases cover a loaded reference, severe sag, interruption with state hold, interruption with next-state reset, combined EMI/communication/supply faults, one-sample/startup/end/off-grid fault windows, reverse and zero loads, mild sag and command saturation. Every case compares the original 29 channels, four separate supply channels and controller-state history. Supply and discrete profiles match exactly. The largest continuous logged-channel difference was **2.88e-13**, below the **1e-9** numerical comparison gate. Command bounds, zero drive during interruption, pre-fault agreement, finite records and completed execution all passed.

Each case runs for 3 s. The usual loaded fixture uses +0.01 N m; reverse and zero-load cases override it. Severe sag uses 0.05 V, mild sag 12 V and interruption 0 V on a nominal 24 V bus. The saturation fixture sets a 0.1 V command limit. Exact parameters and windows are exported in the case manifest.

Recovery is measured separately from implementation acceptance. The end-of-record interruption and severe command-limit fixture correctly report **censored recovery**; this report does not claim recovery in those two cases. The loaded reference has no fault-recovery time.

The controller, sensor and communication electronics remain powered. Zero supply means zero applied motor-terminal voltage with winding/back-EMF/load dynamics continuing; it is not an open-circuit disconnect, physical safe stop or MCU brownout model. This completes the specified numerical supply integration, not hardware supply validation.

## Preservation and source identity

Installed **36 modified** and **24 new** source/model/document files. All **1192 other original files** remain byte-for-byte unchanged against the original 1,228-file inventory, including frozen control and circuit results. New evidence is stored only under the new `03_MATLAB/results/development/v03` directory.

Recoverable before/after source checkpoints include unchanged source and vendor dependencies; generated caches/results are excluded and remain identified by the full original inventory. Run manifests retain their actual execution-time source/model hashes and MATLAB/product versions. The installation manifest identifies the final installed files. No Git repository or remote publication was created.

- [Complete pre-change source checkpoint](pre_v03_complete_source_checkpoint.zip)
- [Complete v0.3 source checkpoint](v03_complete_source_checkpoint.zip)
- [Rollback files for changed source](pre_v03_source_backup.zip)
- [Change inventory](source_changes.csv), [readable source diff](source_changes.patch), [installation and hash manifest](installation_manifest.json)

## Evidence index

- [150-test acceptance](final_acceptance/all_project_tests.csv), [execution log](final_acceptance/acceptance_log.txt), [acceptance source identity](final_acceptance/acceptance_run_manifest.json)
- [Rebuilt models](final_acceptance/rebuilt_model_tests.csv), [installed-model tests](installed_project/installed_model_tests.csv)
- [Phase 2A checks](final_acceptance/phase2_simulink_validation.csv), [Phase 2B checks](final_acceptance/phase2b_simulink_validation.csv)
- [Installed supply validation](installed_project/supply_study/supply_validation.csv), [metrics](installed_project/supply_study/supply_metrics.csv), [all-channel comparisons](installed_project/supply_study/supply_channel_comparisons.csv), [exact case parameters](installed_project/supply_study/supply_case_manifest.json), [source identity](installed_project/supply_study/run_manifest.json)
- [Sensitivity summary](sensitivity/Phase2B_Sensitivity_Summary.md), [selected comparisons](sensitivity/phase2b_sensitivity_simulink_validation.csv), [regression log](full_regression_log.txt)
- [Frozen native-record checks](frozen_native_records_rechecked.csv), [original SC01B tests](preservation_checks/original_sc01b_tests.csv), [R2 overwrite guard](preservation_checks/r2_output_guard.csv), [MATLAB code-analysis record](preservation_checks/matlab_code_analysis.csv)

## Next development boundary

The four blocking software defects and declared supply integration are closed. Before treating the whole Phase 2 fault library as complete, finish constructed communication collision/out-of-order tests (E-006D), the remaining encoder spectral evidence (E-002B) and recovery evidence (E-003B). Phase 3 observer/residual detection, persistence and supervised state transitions remain planned. Hardware identification, realizable driver/negative rail, source-to-receiver/decoder integration and physical validation remain separate work.

From `03_MATLAB`, use `startup_project`, `runtests("tests")`, and `run_supply_integration_study` to reproduce the control checks and create a fresh supply evidence folder. Use each circuit package's own startup in a separate MATLAB path context; original SC01B and R2 share function names. Interactive Phase 2A/2B model runs require their documented profile-configuration helpers.
