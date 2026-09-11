# Phase 2 evidence completion

**Completed locally:** 9 September 2026 (America/New_York), MATLAB R2026a Update 3 / Simulink.  
**Installed project:** `C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics`

## Outcome

The three remaining numerical evidence gaps are closed: **E-006D constructed packet reception**, **E-002B encoder spectrum**, and **E-003B count-jump trajectory recovery**. The additions and updated requirements/roadmap are installed in the original project. FUN-007 is now verified for the specified numerical receiver.

The active suite passes **174/174 tests**, up from 150. The 24 new tests and both new evidence workflows pass again from the installed location. Existing sensitivity and supply results remain accepted. This completes the outstanding checks for the implemented Phase 2 software mechanisms; Phase 3 detection and supervision is the next software milestone.

## What changed

The production channel now calls a separately testable deterministic packet scheduler. Seven fixtures specify expected arrival, acceptance, held-source, measurement-age and discard arrays by hand. They cover newest-wins collisions, an older-only late arrival, a collision where every candidate is stale, accepted delayed packets, dropped/out-of-record packets, startup/all-loss behavior and a single immediate packet. Discard accounting is conserved: collision losers plus a rejected newest stale candidate are counted once. Delay/loss random draws and existing seeded behavior are unchanged.

The encoder evidence workflow records the active-window spectrum of injected encoder error separately from the measurement-minus-matched-baseline diagnostic. It stores sample rate, exact selected samples, window, mean removal, FFT length, normalization, frequency resolution and peak selection. Inputs and derived spectral arithmetic fail closed on nonfinite values. Interior-band fixtures avoid interpreting ambiguous DC/Nyquist boundary peaks or physical frequencies above Nyquist.

Count-jump recovery now has saved matched-position metrics: requested and actual injection times, effective event end, threshold, consecutive-sample dwell, first qualifying start, confirmation and censor reason. This adds analysis evidence; it does not add a fault detector or change controller behavior.

## Local verification

| Check | Result |
|---|---|
| Active control + SC01A + R2 suite | **174/174 passed**: 8 new communication methods and 16 new encoder-analysis methods |
| Installed new test suites | **24/24 passed** |
| Hand-declared packet schedules | **7/7 exact**, covering 36 sample rows and nine independently specified schedule fields |
| Frozen communication profiles | **30/30 identical in every field**, with caller random state unchanged; ten historical profiles are also checked by the unit suite |
| Encoder spectra | **3/3 passed**: coherent 120 Hz, off-bin 123.4 Hz, and 2 kHz sampling |
| Count-jump recovery outcomes | **5/5 passed**: positive, reverse, loaded, off-grid request, and deliberately censored endpoint |
| New encoder MATLAB/Simulink comparisons | **8/8 passed**, complete records and zero warnings; maximum logged difference **7.28e-13**, below 1e-9 |
| Legacy Phase 2 comparisons | **15/15 passed** |
| Sensitivity regression | **1,886 runs** completed; **11/11** selected Simulink comparisons passed |
| Sensitivity reproduction | **18/18 numeric input/result CSVs match v0.3 exactly** |
| Supply regression | **13/13 passed** |
| Independent local export audit | **9/9 packet/spectrum/recovery checks passed**, including convolution-based recovery recomputation |
| Encoder export reproduction | **18/18 CSVs identical** across initial, final-figure and installed campaigns |

Repeated runs verify installation/reproducibility and are not counted as new unique test coverage. The unchanged full native/SPICE circuit campaigns were not rerun; their regression suites are included in the 174 tests, and prior circuit evidence is preserved.

## Observed encoder results

The nominal 120 Hz injection produces a **120 Hz** peak using 400 samples and **2.5 Hz** unpadded resolution. The off-bin 123.4 Hz fixture reports **122.5 Hz**, within its declared half-bin allowance; it does not claim interpolated frequency precision. Doubling the sampling rate to 2 kHz uses 800 samples over the same window and retains the 2.5 Hz resolution.

The nominal 128-count impulse occurs at **0.450 s**, with effective end **0.451 s**. The position delta enters the first qualifying 50-sample, ±0.05° dwell at **0.541 s** and confirms it at **0.590 s**. Recovery delay is therefore **90 ms after the affected sample ends**; the 50-sample dwell spans 49 ms at 1 kHz. Reverse, loaded and off-grid cases give the same delay in these fixtures. The endpoint jump at 3 s has no post-fault record and correctly remains **censored**.

The exported [encoder spectrum/recovery figure](encoder_evidence_final/phase2a_evidence_overview.png) and [sensitivity figure](sensitivity/phase2b_sensitivity_overview.png) were visually checked for legible labels, units and scope. A figure-only light-theme correction followed the full regression; all eight encoder cases were rerun, then the installed tests and workflows passed. Each run retains its own actual source/model manifest.

## Preservation and traceability

Installed **9 modified** and **8 new** source/document files. All **1337 other pre-existing files** remain byte-for-byte unchanged, including v0.3 and frozen circuit/control evidence. The three model files and physical parameter defaults remain unchanged; `REPRESENTATIVE-ACTUATOR-V0.3` still identifies those defaults.

New evidence is stored under `03_MATLAB/results/development/phase2_completion`. The [source-change inventory](source_changes.csv), [readable diff](source_changes.patch), [installation manifest](installation_manifest.json), [rollback files](changed_source_rollback.zip), [pre-change checkpoint](pre_phase2_completion_source_checkpoint.zip) and [completed source checkpoint](phase2_completion_source_checkpoint.zip) retain a recoverable record. The requirements, test plan, FMEA traceability map, decision log and roadmap link to this campaign without rewriting historical counts.

## Evidence index

- [Full 174-test table](all_project_tests.csv), [execution log](acceptance_log.txt), [source identity](run_manifest.json)
- [Installed 24-test table](installed_project/installed_tests.csv), [installed source identity](installed_project/run_manifest.json), [changed-file code analysis](installed_project/changed_matlab_code_analysis.csv)
- [Constructed packet acceptance](communication_edges/communication_edge_validation.csv), [expected/actual schedules](communication_edges/communication_edge_schedules.csv), [30-profile regression](communication_frozen_regression.csv)
- [Encoder summary](encoder_evidence_final/Phase2A_Evidence_Summary.md), [spectral checks](encoder_evidence_final/phase2a_spectral_validation.csv), [recovery outcomes](encoder_evidence_final/phase2a_recovery_validation.csv), [Simulink checks](encoder_evidence_final/phase2a_simulink_validation.csv), [exact case/analysis parameters](encoder_evidence_final/phase2a_case_manifest.json)
- [Sensitivity summary](sensitivity/Phase2B_Sensitivity_Summary.md), [supply regression](supply_regression/supply_validation.csv)
- [Independent export audit](independent_export_audit.json), [encoder reproduction check](encoder_reproduction_check.json)

## Next software milestone

Begin Phase 3 with physical range/rate checks and a state observer/residual monitor. Define persistence and normal/suspected/degraded/recovery/safe-stop transitions, then compare detection delay, false alarms, command bounds and recovery under these frozen disturbances. E-004B supervisory dropout response remains part of that work.

Physical source/receiver/decoder identification, CAN-specific behavior, MCU brownout, realizable gate drive and hardware validation remain outside this numerical closure. Trajectory recovery and zero-voltage commands are not physical safety validation.

From `03_MATLAB`, run `startup_project`, `runtests("tests")`, `run_communication_edge_study`, and `run_phase2a_evidence_study`. Both new workflows create fresh timestamped output folders by default and reject populated explicit destinations. Preserve the existing `results/phase2b_fault_study.mat`: the communication regression test intentionally uses that frozen historical profile evidence.
