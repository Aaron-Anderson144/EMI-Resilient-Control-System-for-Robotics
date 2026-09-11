# Project Roadmap

## Phase 0 — Foundation

**Purpose:** Establish scope, organization, traceability, and acceptance logic.

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
- [ ] Identify receiver/decoder behavior and connect circuit events to the controller model when supported by evidence.
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

The controller responds predictably to every defined fault and avoids unsafe or unbounded simulated commands.

**Gate status:** The declared numerical implementation and bounded-command checks are verified in [Phase 3 evidence](../03_MATLAB/results/development/phase3/Phase3_Implementation_Report.md). The broader gate remains open: stationary freeze, small bias and slow drift can be missed; the default dropout can prevent observer reacquisition; zero-voltage stop permits loaded motion. These outcomes are retained, not treated as successful detection/recovery or physical safety.

## Phase 4 — Electromagnetic Mitigation Models

**Purpose:** Compare physical and electrical protection strategies.

### Tasks

- Model cable parasitics and shared impedances.
- Model RC/LC filters, common-mode chokes, and isolation.
- Compare shield and grounding equivalent circuits.
- Create switching-level drive cases in Simscape Electrical.
- [x] Freeze the first bounded four-way experiment design, including an actual differential-capacitance intervention, historical software policy, matched clean companions and separate development/evaluation fixtures.
- [ ] Implement and accept the causal source/coupling/receiver/decoder-to-control interface (A02).
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

## Immediate Next Milestone

The [causal receiver checkpoint](Causal_Receiver_Checkpoint.md) now implements and verifies A02's numerical source/circuit/receiver/decoder boundary while preserving the historical controller. All 468 tests and 116 exact legacy records pass. Native comparison passes 24/24 numerical records and 16/16 refinements.

The unchanged [PLAN-V1](../04_EMI_Models/Four_Way_EMI_Experiment.md) stops at its development gate: all eight clean companions pass, DEV01 has no persistent EMI count error, and every exposed DEV02 arm exceeds the assumed 7 V common-mode domain. Its fallback diagnostics cannot support mitigation claims. The 96 evaluation and 16 closure records remain unopened; A01 / RES-005 and Gate 4 remain open.

Next review the receiver/topology assumptions against a defensible operating domain, then freeze a new versioned plan and separate development/evaluation fixtures before further comparative evaluation. Preserve all PLAN-V1 data and criteria; do not retune that failed design. Physical source/cable/receiver identification and the partial literature review remain open.

Drive/brake handoff, release interlocks and brake-aware estimation remain necessary for an integrated loaded restart claim. The existing zero-load comparison does not establish physical holding, safety, immunity or requirement approval. Formal Draft approvals and physical Gate 5 remain unchanged.
