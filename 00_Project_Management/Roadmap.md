# Project Roadmap

## Integrated V2 checkpoint — 15 September 2026

The causal V2 receiver/control integration and full frozen experiment are complete: 256 development records, 1,536 reserved evaluation records, and 256 separate source-return diagnostics. Electrical filtering removed the small observed sampled-count errors. The combined treatment did not meet the predefined task-benefit criterion under any of the 16 receiver hypotheses; every baseline task already passed. These are conditional numerical results; physical receiver behavior remains unmeasured.

The causal adapter, independent native acceptance, all 256 development records, separate implementation freeze, all 1,536 reserved records and 256 return-sensitivity diagnostics are complete. Full independent reconstruction/scoring audits passed. [Results and evidence](Verification/Four_Way_V2_2026-09-15/Results.md).

**Next research step:** measure the actual receiver's fast-pulse behavior and loaded circuit response, then use those measurements to constrain a new experiment. The present numerical hypotheses do not identify physical receiver behavior.

## Receiver V2 preparation checkpoint - 15 September 2026

The [receiver contract](../04_EMI_Models/Receiver_V2_Contract.md), Signal Lab characterization workflow, and conditional [PLAN-V2](../04_EMI_Models/Four_Way_EMI_Experiment_V2.md) protocol are implemented/documented. The compact electrical campaign has 40 records / 640 behavioral cases: all numerically converged and in-domain, no final count errors, and 80 cases with pulse-law-dependent edge behavior. The nine receiver-engine tests include independent KCL/matrix-exponential checks and multiple-root, grazing and event-ordering adversaries. See the [new evidence checkpoint](Verification/Receiver_V2_2026-09-15/README.md).

**Next at that preparation checkpoint:** implement the causal V2 motor/receiver adapter, verify native circuit and full event/count agreement, complete all 256 development logical records, and freeze that accepted implementation before the 1,536 reserved evaluation records. The finalized protocol is not an implementation acceptance. Six-microsecond electrical records do not establish three-second control behavior, hardware validity or combined benefit. The September 12 historical status below is retained as its dated checkpoint.

## Historical status — 12 September 2026 verification

Fresh verification passed **468/468 robotics tests** and **32/32 hybrid-estimation checks**. All **16 frozen PLAN-V1 files** match their recorded hashes after exact restoration of the authoritative plan. These checks confirm their stated implementation scopes; they do not accept the rejected development experiment or prove combined mitigation benefit. Gates 3, 4 and 5 remain open, and formal Draft approvals are unchanged. Gate definitions below state the completion conditions; they are not approval records. No completed Gate 0 approval record was found in this review.

The immediate research path is receiver/topology characterization, accepted development under a defensible model scope, then a newly frozen four-arm evaluation. Keep the historical PLAN-V1 criteria and results intact. A wider receiver voltage limit alone does not resolve threshold, loading, timing or fast-transient uncertainty.

The [EDMD hybrid experiment](../11_EDMD_Hybrid_Estimation/docs/RESULTS.md) is completed supporting work on estimation under model mismatch. Quadratic EDMD did not improve on the linear correction, both learned versions degraded nominal accuracy, and no condition passed its benefit screen. Its multistep forecasts use recorded future voltages, so they do not demonstrate improved control or EMI resilience. Keep it separate from the control/protection path and from the receiver milestone. A future estimation study should compare the small linear correction with a disturbance-estimating physics observer while preserving nominal accuracy.

## Phase 0 — Foundation

**Purpose:** Define the scope, organize the work, and decide what evidence each phase needs.

### Tasks

- Approve the research charter.
- Confirm software licensing and available MathWorks products.
- Select or identify a representative actuator.
- Establish requirements, FMEA, data conventions, and test naming.
- Start the literature and decision logs.

### Gate 0

The research question, system boundary, initial metrics, and parameter-assumption policy are approved.

## Phase 1 — Clean Baseline Digital Twin

**Purpose:** Produce a stable actuator and controller before introducing EMI.

### Tasks

- Implement a three-state electrical-mechanical motor model.
- Tune a discrete position controller.
- Simulate step, trajectory, and load-disturbance cases.
- Record poles, tracking error, overshoot, settling time, and control effort.
- Create the baseline Simulink block diagram.
- Add automated stability and reproducibility tests.

### Gate 1

The baseline model is stable, reproducible, documented, and free of fault injection.

## Phase 2 — EMI and Fault Injection

**Purpose:** Create controlled, repeatable disturbances.

**Historical circuit status as of 2026-09-09:** SC-01B R2 passes all five declared operating points: 29/29 required simulations completed, 24/24 numerical comparisons passed, and 99/99 project tests passed. The 47 Ω peak terminal current falls from 186.919 A to 6.1193 A, with no native channel overlap above the existing current floor in any native run. The original SC01B remains preserved. Phase 2A/2B, sensitivity and SC01A results remain unchanged. The v0.3 averaged supply/load integration closes the software supply-interruption item. Physical source identification remains open.

### Tasks

- [x] Add encoder noise, impulses/count jumps, and hold-last dropout.
- [x] Add timestamped communication delay, bounded jitter, packet loss, and stale-sample behavior at source level.
- [x] Complete automated and MATLAB/Simulink verification of the implemented communication channel.
- [x] Add a receiver-equivalent ground-offset disturbance channel.
- [x] Derive reduced-order capacitive, inductive, and shared-impedance coupling inputs from assumed parameters.
- [x] Add SC-01A as a separate finite-edge electrical harness for source/coupling/receiver-voltage behavior, with numerical convergence evidence.
- [x] Implement the selected-device SC-01B half-bridge and its numerical verification campaign; retain failed operating points explicitly.
- [x] Resolve the SC-01B modeled gate-drive failures in the declared five-case R2 fixture. The physical operating envelope remains unvalidated.
- [x] Resolve strict SPICE failures with identical algebraic source waveforms and separate print/integration settings; retain the original rejected evidence and verify finer steps.
- [x] Implement and numerically verify the assumed causal receiver/decoder connection to control; September 11 checkpoint records the development-domain rejection.
- [ ] Identify receiver/decoder behavior and a defensible operating domain before accepting a revised comparative experiment.
- [x] Add averaged motor-supply sag/interruption, explicit controller-state hold/reset, loaded plant continuity and MATLAB/Simulink coverage. Physical controller brownout remains a separate hardware-specific task.
- [x] Complete fixed-seed Monte Carlo packet-loss execution and confidence-interval reporting.
- [x] Sweep assumed parasitics, edge rates, path-transfer factors, and receiver sensitivity; record diagnostic-only and inactive controls separately.
- [x] Define parameter-identification evidence and the next switching-level circuit specification, SC-01.

### Gate 2

Each fault has documented units, provenance, severity parameters, half-open activation logic, and a test demonstrating that it affects only its intended channel. Stochastic scenarios are reproducible, communication timing is causal, and matched no-fault comparisons are stored.

**Gate status:** Satisfied for the implemented Phase 2A/2B software mechanisms and the defined exploratory sensitivity study. The v0.3 supply/load campaign closes the modeled motor-supply mechanism. The Phase 2 completion campaign closes supplemental E-006D constructed packet and E-002B/E-003B spectrum/recovery evidence. E-004B supervisory response belongs to Phase 3; hardware-specific behavior remains open. Physical-parameter identification is still required before making hardware claims. Passing this gate does not establish physical fidelity.

## Phase 3 — Detection and Resilient Control

**Purpose:** Detect corrupted data and preserve controlled behavior.

### Tasks

- [x] Implement finite, physical range/rate, timestamp and freshness checks.
- [x] Add a source-time state observer and residual monitor with applied-input replay.
- [x] Define provisional confidence, hysteresis and elapsed-duration persistence.
- [x] Implement normal, suspected, degraded, recovery, and latched numerical safe-stop states.
- [x] Compare observer/supervisor, command-limited and lower-bandwidth policies.
- [x] Complete a frozen nine-policy tuning grid, separate evaluation and actual limiter ablations; retain the historical default because comparative requirements fail.
- [x] Add an optional causal reference envelope with unchanged observer thresholds and verify it on eight new clean and eight new fault cases; record its task-delay cost.
- [ ] Identify physical motion/current limits and wider model/load uncertainty before treating the numerical envelope as a hardware operating policy.
- [x] Add optional independent-reference observer reconstruction with propagated measurement-error bounds, stopped-only re-anchor and separate primary qualification/reset.
- [ ] Select and validate the independent reference, its error/independence assumptions and model/load uncertainty for physical reacquisition.
- [x] Compare terminal short, external resistor and finite-capacity mechanical brake in a separate local stop/hold plant harness; verify 180 runs and independent continuous dynamics.
- [ ] Implement an explicit drive/brake torque handoff, release interlocks and justified brake-aware estimation before integrating a loaded restart.
- [ ] Select and identify physical brake/terminal behavior, sensor observability and calibrated load/travel/current limits; validate physical stop/hold.

### Gate 3

The controller responds predictably to every defined fault and keeps simulated commands within safe, finite bounds.

**Gate status:** [Phase 3 evidence](../03_MATLAB/results/development/phase3/Phase3_Implementation_Report.md) verifies the implemented numerical behavior and command limits. The broader gate remains open: stationary freeze, small bias and slow drift can be missed; the default dropout can prevent observer reacquisition; zero-voltage stop permits loaded motion. These remain recorded limitations. They do not count as successful detection, recovery or physical safety.

## Phase 4 — Electromagnetic Mitigation Models

**Purpose:** Compare physical and electrical protection strategies.

### Tasks

- Model cable parasitics and shared impedances.
- Model RC/LC filters, common-mode chokes, and isolation.
- Compare shield and grounding equivalent circuits.
- Create switching-level drive cases in Simscape Electrical.
- [x] Freeze the first bounded four-way experiment design, including an actual differential-capacitance intervention, historical software policy, matched clean companions and separate development/evaluation fixtures.
- [x] Implement and numerically verify the causal source/coupling/receiver/decoder-to-control interface (A02 numerical scope).
- [ ] Resolve receiver/topology characterization and accept the revised model domain; numerical integration alone does not close A02.
- [ ] Execute and report all four experiment configurations: baseline, electromagnetic-only, software-only and combined protection (A01). A frozen design alone does not complete the comparison.

### Gate 4

All comparison cases use identical disturbances and report uncertainty, limitations, and parameter sources.

## Phase 5 — Hardware Preparation and Validation

**Purpose:** Connect simulation claims to physical measurements.

### Tasks

- Select the actuator, drive, sensors, controller, and communication interface.
- Complete schematics, wiring, grounding, shielding, and safety design.
- Create a bench test procedure and calibration plan.
- Measure clean and disturbed operation.
- Identify model parameters and compare measured versus simulated behavior.

### Gate 5

The validated model reproduces specified measured behaviors within documented error bounds.

## Historical next milestone recorded 12 September 2026

The [12 September progress review](Reviews/2026-09-12/Project_Progress_Review.md) recorded 468/468 passing local tests and unchanged checkpoint files at that review. The [receiver revision brief](Reviews/2026-09-12/Receiver_Revision_Brief.md) sets out the characterization work needed before a new plan. THVD1450 is a provisional modeling candidate; no replacement receiver is validated and no PLAN-V2 is frozen.

The [causal receiver checkpoint](Causal_Receiver_Checkpoint.md) now implements and verifies A02's numerical source/circuit/receiver/decoder boundary while preserving the historical controller. All 468 tests and 116 exact legacy records pass. Native comparison passes 24/24 numerical records and 16/16 refinements.

The unchanged [PLAN-V1](../04_EMI_Models/Four_Way_EMI_Experiment.md) stops at its development gate: all eight clean companions pass, DEV01 has no persistent EMI count error, and every exposed DEV02 arm exceeds the assumed 7 V common-mode domain. Its fallback diagnostics cannot support mitigation claims. The 96 evaluation and 16 closure records remain unopened; A01 / RES-005 and Gate 4 remain open.

Next, review the receiver and circuit-topology assumptions and establish a defensible operating domain. Then freeze a new versioned plan with separate development and evaluation fixtures before comparing mitigation results. Preserve all PLAN-V1 data and criteria; do not retune that failed design. Physical source, cable and receiver identification and the partial literature review remain open.

An integrated loaded restart still needs drive/brake handoff, release interlocks and an estimator that accounts for brake torque. The existing zero-load comparison does not establish physical holding, safety, immunity or requirement approval. Formal Draft approvals and physical Gate 5 remain unchanged.
