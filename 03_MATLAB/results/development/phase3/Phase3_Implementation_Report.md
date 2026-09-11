# Phase 3 implementation and local verification

**Implemented and installed:** 9 September 2026, MATLAB R2026a Update 3 / Simulink.  
**Project:** `C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics`

## Outcome

Fault detection, observer monitoring and supervised control are implemented as the **PHASE3-PROTOTYPE-V1 numerical research controller**. The original project contains the new source, generated Simulink model, tests, evidence and updated development/requirement documents. The existing actuator parameter set remains `REPRESENTATIVE-ACTUATOR-V0.3`.

**244/244 project tests pass**, including **70 new Phase 3 tests**. All **29 matched cases** completed and **58/58 MATLAB/Simulink comparisons passed**. The installed location independently passes the 70 new tests and reproduces every campaign CSV exactly.

The broad Phase 3 gate remains open. A stationary freeze, small bias and slow drift can escape detection; a low-motion freeze can prevent observer reacquisition; zero-voltage stop permits substantial motion under load. These are recorded limits, not successful recovery or physical safety validation.

## Implemented behavior

- Finite/range/rate checks, causal increasing timestamps, freshness timeout and residual hysteresis.
- Three-state observer with source-time innovation, gated correction and replay of actual applied motor voltage. Corrupt/held data never refresh trust or recovery evidence.
- Normal, suspected, degraded, recovery and latched stop states with exact elapsed-duration persistence, timeout precedence and qualified explicit reset.
- Observer feedback, lower-bandwidth PIDF scheduling, reference filtering, voltage/slew caps, tracking anti-windup and bumpless mode transfers.
- Per-sample measurements, estimates, innovations, modes, transition reasons, command limits and reset evidence; detection, false-alarm, recovery and matched-clean metrics.

The [design contract](Phase3_Design_Contract.md) gives all thresholds, timing, interfaces, assumptions and reproduction steps. Limits are provisional. The observer/supervisor receives no true plant state, scenario label or injected-fault mask. This separation is checked by tests.

## Verification

| Check | Recorded result |
|---|---|
| Active control, SC01A and SC01B R2 regression suite | **244/244 passed**, up from 174 |
| New Phase 3 coverage |70 tests: observer 15; supervisor 12; controller 10; integration 10; scenario 9; metrics 9; Simulink 5 |
| Matched numerical campaign |29 fixtures × protected/baseline and both matched-clean records = **116 runs**, 3,001 samples each |
| Phase 3 Simulink integration |**58/58 passed**, all 23 numeric channels, exact discrete fields and innovation missing masks, no simulation warnings; largest difference **5.06e-13**, below 1e-9 |
| Required detection fixtures |**11/11 detected**; this is a declared fixture gate, not universal detection |
| Finite plant/command records, voltage/bus bounds, zero command while stopped |**29/29 pairs passed** |
| Clean/permitted conditions |**0 false-alarm episodes across 9 fixtures**, 27 simulated seconds; no physical false-alarm-rate inference |
| Policy ablation |3 cases × 4 policies = 12 records; 6 additional runs plus reused baseline/full records |
| Legacy Phase 2 Simulink checks |**15/15 passed** |
| Supply/load regression |**13/13 passed** |
| Installed project verification |**70/70 tests**, 29-case campaign and 3 further Simulink comparisons passed |
| Installed numerical reproduction |**60/60 campaign CSVs byte-identical** |
| Independent export audit |**1,715 checks passed**, including 870 recomputed metric/status values; separate local Python arithmetic |

The Simulink plant evolves independently, with commands calculated online. The sensor/channel and decision helpers are shared with MATLAB; this is integration cross-validation, not a second independent detector implementation. Separate unit fixtures verify observer poles/replay and handwritten transition boundaries. Deliberate negative tests exercise rejection paths; their expected failures are not failed acceptance cases. Repeated runs check reproduction and are not new unique coverage. Frozen native/SPICE circuit campaigns were preserved; their active regression tests passed.

## Measured outcomes and tradeoffs

Among 20 injected-fault fixtures, **16 were detected, 3 were missed and 1 had insufficient observation time**. Nine clean/permitted cases are excluded from that denominator. The 3 misses are stationary freeze, 0.1-degree bias and slow bias ramp. A packet burst beginning 10 ms before record end is correctly censored because the 20 ms freshness deadline has not elapsed.

Large count jumps and out-of-range position values are rejected on their arrival tick. Missing packets trigger a response 20 ms after the first missing sample in the declared burst. The motion-freeze fixture is detected after 1 ms. Combined-case timing starts at first configured receiver exposure, which can include delay tolerated by the policy before a later corrupt value triggers it.

| Case | Baseline | Protected | Interpretation |
|---|---|---|---|
| Out-of-range measurement: peak command change from matched clean |10.751 V |0.00382 V |The corrupt measurement is rejected; full-record tracking RMSE is slightly worse, not uniformly improved. |
| Freeze during motion: tracking RMSE |36.27° |18.33° |Improvement for this fixture; peak current falls from 6.48 A to 0.96 A. |
| Ordinary 128-count jump: peak position change from matched clean |0.185° |0.253° |Command rejection reduces the impulse in voltage, while mode transfer/lower-bandwidth response worsens this position metric. |
| Loaded supply interruption: tracking RMSE |5.93° |54.00° |Latched zero-voltage stop allows load-driven drift; it is unsuitable as a claimed physical stop/hold solution. |

The default low-motion encoder dropout is detected only when data returns, 150 ms after first exposure. Earlier accepted frozen values bias the observer, so returning measurements remain outside its gate; it stays stopped through the 3 s record and the 2 s reset is rejected. The implementation deliberately does not silently reseed from a disputed sensor. A separate justified re-homing/reacquisition policy or independent sensing is needed.

Fourteen of the 16 detected fixtures regain normal mode with a complete 50 ms confirming tail. The default dropout and late bias remain recovery-censored. Reported recovery delay is measured from the last receiver-exposed sample, not the half-open event end; for the impulse, normal resumes at 0.511 s, 61 ms after its affected sample. Stop release also depends on the fixed operator reset at 2 s, so its waiting time is included rather than hidden.

The [ablation table](final_acceptance/ablation/phase3_ablation_metrics.csv) separates observer/supervisor behavior, additional command limits, and full lower-bandwidth/filter policy. All protected variants retain common anti-windup, bumpless transfers and stop logic. **The additional mode caps/slew never activate in these three cases**, so their benefit is not demonstrated here. In the motion-freeze case, observer/supervisor with normal gains achieves **4.86° RMSE**, compared with **18.33° for the full lower-bandwidth/filter policy**. That policy therefore needs further evaluation and tuning; the full feature bundle is not claimed to be optimal. Both figures below were visually checked for labels, units and legibility.

![Protected and baseline responses](final_acceptance/figures/phase3_response_examples.png)

![Retained observer and loaded-stop limitations](final_acceptance/figures/phase3_retained_limitations.png)

## Installation and preservation

Installed **38 new** and **9 modified** source/document files. All **1468 other pre-existing files** remain byte-for-byte unchanged, including previous numerical and circuit evidence. New evidence is under `03_MATLAB/results/development/phase3`.

The [source inventory](source_changes.csv), [readable diff](source_changes.patch), [installation manifest](installation_manifest.json), [rollback archive](changed_source_rollback.zip), [pre-change checkpoint](pre_phase3_source_checkpoint.zip) and [complete Phase 3 checkpoint](phase3_source_checkpoint.zip) preserve a recoverable record. The complete checkpoint contains **277 source files**; SHA-256: `c4fe40f44439c24699e2f88dca9d1e3e92b8d6aa0acb6e1a8036da7063886770`.

## Evidence and next development step

- [Full test table](final_acceptance/all_project_tests.csv), [execution log](final_acceptance/acceptance_log.txt), [source/model identities](final_acceptance/run_manifest.json), [static analysis](final_acceptance/static_analysis.csv)
- [Campaign metrics](final_acceptance/campaign/phase3_metrics.csv), [state transitions](final_acceptance/campaign/phase3_transitions.csv), [exact MAT archive](final_acceptance/campaign/phase3_study.mat), [configuration/scenario manifest](final_acceptance/campaign/phase3_configuration_and_scenarios.json)
- [Simulink checks](final_acceptance/simulink/phase3_simulink_validation.csv), [per-channel checks](final_acceptance/simulink/phase3_simulink_validation_channels.csv), [supply regression](final_acceptance/supply_regression/supply_validation.csv)
- [Installed tests](installed_project/installed_tests.csv), [installed source identities](installed_project/run_manifest.json), [exact export reproduction](installed_reproduction_check.json), [independent audit](independent_export_audit.json), [audit reproduction script](audit_phase3_exports.py)

Next, resolve observer reacquisition after accepted low-motion freeze, revisit derating/recovery gains using the ablation findings, and define physical stop/hold behavior under load; then expand uncertainty coverage and calibrate thresholds. Stationary/small/slow fault observability needs independent evidence or sensing. Electromagnetic mitigation/four-way RES-005 comparisons and hardware validation remain separate work. This milestone supplies tested numerical foundations; it does not establish a safe robot operating envelope.

To reproduce, open `03_MATLAB` and run `startup_project` then `phase3_main`; it creates a fresh timestamped evidence directory. The interpreted model requires MATLAB, Control System Toolbox and Simulink and is not real-time embedded code.
