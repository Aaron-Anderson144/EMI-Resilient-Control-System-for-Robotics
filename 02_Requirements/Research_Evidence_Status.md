# Research Evidence Status

Updated 2026-09-23 to include the completed PLAN-V2 experiment. This is a scope/evidence reconciliation, not an approval record. The original [Research Charter](../00_Project_Management/Research_Charter.md) remains the goal authority; original [System Requirements](System_Requirements.md) statuses are unchanged. **Supported numerical** means recorded evidence within a declared model and fixture. **Partial** means material scope/proof remains. **Design only** means implementation/results are absent. **Physical pending** means selected/identified hardware or measurements are still needed.

The [completed PLAN-V2 results](../00_Project_Management/Verification/Four_Way_V2_2026-09-15/Results.md) supersede the September 11 checkpoint as the current numerical evidence. The frozen V2 study completed 256 development, 1,536 reserved evaluation and 256 separate source-return diagnostic records. Electrical filtering removed the small observed sampled-count errors, but the predefined combined task-benefit criterion failed under all 16 receiver hypotheses because every baseline task passed. These findings depend on an unmeasured receiver model; combined task benefit and physical validation remain open. The rejected PLAN-V1 development outcome remains historical evidence.

## Seven charter objectives

| Objective | Evidence status and local evidence | Missing proof / next action |
|---|---|---|
| 1. Clean reproducible actuator baseline | Supported numerical: `03_MATLAB/functions/baseline_closed_loop.m`, `tests/TestBaseline.m`, baseline outputs and [Local Reproduction](../00_Project_Management/Local_Reproduction.md). Current checkpoint preserves all 116 original controller records exactly. | Identify physical actuator/load; retain source and pinned dependencies, not just an output archive. |
| 2. Capacitive, inductive, common-mode/shared-impedance models | Partial: reduced-order [Phase2B model](../04_EMI_Models/Phase2B_Coupling_and_Communication_Faults.md), sensitivity report, SC01A network/reference and implemented [causal receiver](../04_EMI_Models/Four_Way_Causal_Implementation.md). | Separate assumed transfer from measured parameters; identify mutual/return/cable geometry and full receiver behavior. The present causal experiment uses the declared capacitive network and ideal B channel. |
| 3. Repeatable sensor, power and communication faults | Supported numerical for implemented library; partial charter scope: [completion report](../03_MATLAB/results/development/phase2_completion/Phase2_Completion_Report.md) and [supply integration](../03_MATLAB/results/development/v03/Development_Validation_Summary.md). | Current-sensor corruption, hardware controller brownout and protocol-specific physical errors remain unimplemented. Motor-bus sag is a distinct mechanism. |
| 4. Physical-limit/residual detection | Partial: [Phase3 prototype](../03_MATLAB/results/development/phase3/Phase3_Implementation_Report.md) and [motion envelope](../03_MATLAB/results/development/phase3_motion_20260910_144242/Phase3_Motion_Envelope_Report.md). | Thresholds remain assumed; stationary freeze/small bias/drift and model/load uncertainty limit detectability. |
| 5. Degraded operation, recovery and safe-stop | Partial: prototype, [reference recovery design](../05_Control_Algorithms/Phase3_Independent_Reference_Recovery.md), [tuning report](../03_MATLAB/results/development/phase3_tuning_20260910_141100/Phase3_Controller_Tuning_Report.md), [separate stop/hold report](../03_MATLAB/results/development/phase3_stop_hold_20260910_150537/Phase3_Stop_Hold_Report.md). | Numerical command stop is not physical holding. Integrated brake handoff/restart, reference integrity and physical bounds remain open; rejected tuning is retained. |
| 6. Baseline / electromagnetic / software / combined comparison | Partial: [PLAN-V2 results](../00_Project_Management/Verification/Four_Way_V2_2026-09-15/Results.md) include 256 development records, 1,536 evaluation records and 256 separate source-return diagnostics across 16 receiver hypotheses. Electrical filtering removed the observed sampled-count errors; the predefined combined task-benefit criterion failed in every hypothesis. Historical PLAN-V1 development was rejected outside its assumed receiver domain. | A01/RES-005 and the combined-benefit claim remain open. Measure receiver fast-pulse and loaded-circuit behavior, identify physical parameters, then design a separately reviewed experiment if new evidence supports one. |
| 7. Traceable desktop-to-circuit-to-hardware path | Partial: SC01A/R2 numerical verification, the verified causal bridge, manifests, [parameter identification plan](../04_EMI_Models/Parameter_Identification_and_Switching_Case.md), [hardware plan](../10_Hardware_Design/Hardware_Plan.md), source history and dependencies. | Selected hardware, preliminary connected schematic, calibration and held-out measurements remain physical pending. Numerical agreement does not validate physical receiver behavior. |

## Initial charter success criteria

| Criterion | Evidence status | Boundary / next accepting evidence |
|---|---|---|
| Clean linear internal stability | Supported numerical by baseline poles/tests. | Exact nominal linear model; not global nonlinear or physical stability. |
| Fixed-seed determinism | Supported numerical by baseline/fault/packet tests and manifests. | Seeded synthetic distributions are not measured reliability. |
| Configuration, parameters and version recorded for every experiment | Partial: named campaign manifests/source hashes; source checkpoint and dependency pinning explicit. New causal acceptance inventory binds the implementation and runtime. | Custom/ad hoc runs must follow the same discipline; source history and compact publication evidence are not a complete data/runtime backup. |
| Faults default off and baseline uncontaminated | Supported numerical in declared default/isolation/clean-companion tests. The unused external measurement boundary preserves all 116 legacy records, including all 31 channels. | Preserve this boundary in future interface revisions; do not allow plant truth or exposure/domain annotations into control. |
| Combined case outperforms baseline on predefined metrics | Not demonstrated. PLAN-V2 completed its frozen evaluation, but no receiver hypothesis met the combined task-benefit criterion; every baseline task passed. PLAN-V1's development gate remains rejected. | Physical receiver characterization and a new, prospectively defined comparison are needed before a broader benefit claim. The conditional electrical-filtering effect alone does not satisfy the task-benefit criterion. |
| Unsafe/unbounded simulation produces explicit safe-state outcome | Partial: finite/bounded voltage, supervisor latch and explicit failed/missed/censored outcomes. | Physical unsafe-state definition and independent current/energy/travel/hold limits are absent; zero voltage can backdrive. No physical safety claim. |

## Expected charter deliverables

| Deliverable | Evidence status | Remaining work |
|---|---|---|
| Version-controlled MATLAB/Simulink twin | Supported numerical source artifact with checkpoint history and [publication reproduction guide](../09_Report/Publication_2026-09-11/Publication_Reproduction.md). | Maintain verified dependencies/generated models and per-campaign source/configuration manifests. A source clone alone does not contain every required input or historical result. |
| EMI coupling and circuit models | Supported numerical in Phase2B, SC01A, SC01B_R2 and the causal receiver bridge. | Defensible receiver/topology operating domain and physical parameter identification. |
| Fault-injection library | Supported numerical for encoder/communication/motor-bus mechanisms. | Current-sensor and physical MCU/protocol mechanisms remain open. |
| Baseline and fault-tolerant controller | Supported numerical prototype and optional variants, with negative results retained. | Measured envelope, observable recovery and physical safe-state/restart policy. |
| Simulation test suite and dataset | Supported numerical: 468 passing tests at the causal checkpoint, preserved named campaigns, and selected fresh reproduction. | Never label selective reproduction as rerunning all historical data; maintain raw/configuration/source associations. |
| Experimental test plan | Partial: [Simulation Test Plan](Simulation_Test_Plan.md), hardware planning, rejected PLAN-V1 development and completed [PLAN-V2 conditional comparison](../00_Project_Management/Verification/Four_Way_V2_2026-09-15/Results.md). | Calibrated bench protocol, measured receiver behavior, operating limits, apparatus and uncertainty. |
| Hardware architecture and preliminary schematic | Partial architecture planning only in [Hardware Plan](../10_Hardware_Design/Hardware_Plan.md). | No selected/connected hardware schematic, bill of materials or inspection evidence is accepted. |
| Research report, figures and recommendations | Progress publication with integrated narrative and numerical evidence: [report](../09_Report/Publication_2026-09-11/EMI_Robotics_Progress_Report.pdf), completed [PLAN-V2 results](../00_Project_Management/Verification/Four_Way_V2_2026-09-15/Results.md) and [assembly map](../09_Report/Report_Outline.md). The full research deliverable remains partial. | Critical literature comparison and measured validation before broad conclusions. |

## Requirement approval is separate

| Requirement group | Approval/status retained | Current narrower evidence |
|---|---|---|
| FUN-005 | Draft | Modes and transition rules verified numerically in the declared Phase3 fixture. |
| RES-001/002/003/004 | Draft | Numerical gates/observer/supervisor/metrics exist; missed faults, censored recovery, load drift and physical limits remain explicit. |
| RES-005 | Draft | PLAN-V2 development and evaluation completed under 16 receiver hypotheses; the predefined combined-benefit screen failed all 16. PLAN-V1 development remains rejected. Physical applicability is unvalidated. |
| DATA-002 | Partial | Units and assumed/sourced provenance present for model parameters; measured values/current external applicability incomplete. |
| DATA-003/004 | Draft | Synthetic evidence preservation and reproducible named figures exist; experimental raw-data workflow and every future report figure remain review work. |
| SAFE-001/002/003/004/005 | Draft | Planning/documented claim boundaries only; no physical apparatus inspection or compliance evidence. |
| Existing Verified rows | Unchanged, including any explicit Phase2B/v0.3 scope | Read [traceability](Verification_Traceability.md) for tested fixture limits; Verified does not silently mean physical or universal. |

The bounded critical path now runs from the completed conditional PLAN-V2 comparison to measured receiver/topology behavior and a prospectively reviewed follow-up experiment. A01/RES-005 and Gate4 remain open because the combined task-benefit criterion was not met and physical validation is absent. Formal requirement approval remains pending. Brake handoff stays a separate necessary gate for integrated **loaded restart**, rather than an automatic blocker for the zero-load EMI experiment.

## 2026-09-15 completed PLAN-V2 checkpoint

The [results and interpretation](../00_Project_Management/Verification/Four_Way_V2_2026-09-15/Results.md) retain all 16 receiver hypotheses, 768 reserved evaluation comparisons and 128 separate source-return comparisons. Numerical and clean guards passed for the primary evaluation. Sampled EMI count errors appeared in 32/192 baseline and 32/192 software-only comparisons, and in none of the electrical-only or combined comparisons. No baseline task failed, so no combined arm could satisfy the required rescue criterion. These are conditional numerical results, not measured receiver immunity or a physical safety claim.

## 2026-09-11 causal-interface checkpoint

A02 now has a verified numerical circuit/receiver/decoder connection: 468 passing tests, 116 unchanged legacy records and 24 native numerical comparisons. A01/RES-005 and Gate4 remain open because PLAN-V1's development gate rejects the higher exposure outside its 7 V receiver domain. All 16 development records are retained; no evaluation or closure-production cases were opened. See the [checkpoint](../00_Project_Management/Causal_Receiver_Checkpoint.md). Physical validation and formal Draft approvals are unchanged.

Historical reports retain their original dates, test counts and acceptance statements. Some full reports and result trees require the retained project archive described in the reproduction guide. The current tables above supersede September 10 descriptions of the causal bridge as absent or design only.
