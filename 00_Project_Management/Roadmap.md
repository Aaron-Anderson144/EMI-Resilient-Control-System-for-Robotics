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

**Status as of 2026-09-09:** Phase 2A/2B and the 1,886-run parameter-sensitivity study are software-verified. SC-01A resolves finite edges in a checked native Simscape network. SC-01B adds a selected Infineon device source and an independent original-SPICE comparison, with a retained 47 ohm gate-resistance stress failure. See its generated verification report for final run counts and individual gates. Physical source identification and supply interruption remain open.

### Tasks

- [x] Add encoder noise, impulses/count jumps, and hold-last dropout.
- [x] Add timestamped communication delay, bounded jitter, packet loss, and stale-sample behavior at source level.
- [x] Complete automated and MATLAB/Simulink verification of the implemented communication channel.
- [x] Add a receiver-equivalent ground-offset disturbance channel.
- [x] Derive reduced-order capacitive, inductive, and shared-impedance coupling inputs from assumed parameters.
- [x] Add SC-01A as a separate finite-edge electrical harness for source/coupling/receiver-voltage behavior, with numerical convergence evidence.
- [x] Implement the selected-device SC-01B half-bridge and its numerical verification campaign; retain failed operating points explicitly.
- [ ] Resolve the SC-01B slow-gate simultaneous-conduction stress case and establish a supported operating envelope.
- [ ] Resolve or independently bound the original-SPICE strict relative/current-tolerance failure before closing full SC-01B numerical acceptance.
- [ ] Identify receiver/decoder behavior and connect circuit events to the controller model when supported by evidence.
- [ ] Add supply-interruption scenarios.
- [x] Complete fixed-seed Monte Carlo packet-loss execution and confidence-interval reporting.
- [x] Sweep assumed parasitics, edge rates, path-transfer factors, and receiver sensitivity; record diagnostic-only and inactive controls separately.
- [x] Define parameter-identification evidence and the next switching-level circuit specification, SC-01.

### Gate 2

Each fault has documented units, provenance, severity parameters, half-open activation logic, and a test demonstrating that it affects only its intended channel. Stochastic scenarios are reproducible, communication timing is causal, and matched no-fault comparisons are stored.

**Gate status:** Satisfied for the implemented Phase 2A/2B software mechanisms and the defined exploratory sensitivity study. The full Phase 2 gate remains open for supply interruption. Physical-parameter identification is still required before making hardware claims. Passing this gate does not establish physical fidelity.

## Phase 3 — Detection and Resilient Control

**Purpose:** Detect corrupted data and preserve controlled behavior.

### Tasks

- Implement physical range and rate checks.
- Add a state observer and residual monitor.
- Define confidence and persistence thresholds.
- Implement normal, suspected, degraded, recovery, and safe-stop states.
- Compare state substitution, command limiting, and bandwidth reduction.

### Gate 3

The controller responds predictably to every defined fault and avoids unsafe or unbounded simulated commands.

## Phase 4 — Electromagnetic Mitigation Models

**Purpose:** Compare physical and electrical protection strategies.

### Tasks

- Model cable parasitics and shared impedances.
- Model RC/LC filters, common-mode chokes, and isolation.
- Compare shield and grounding equivalent circuits.
- Create switching-level drive cases in Simscape Electrical.
- Compare four experiment configurations: baseline, hardware mitigation, software resilience, and combined protection.

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

**SC-01B implementation and the frozen verification experiment are complete.** The source uses the shipped IAUC100N04S6L014 nonlinear charge/body-diode model, a UCC27211A-informed behavioral driver and declared supply/load assumptions. The 47 ohm gate-resistance case exposes simultaneous channel conduction and remains a failed stress point. The next circuit step is to characterize and address this gate-drive/dead-time limitation, then identify actual source and loop parameters before connecting the source to the checked SC-01A coupling network. Receiver/decoder identification and measured ground/coupling transfer remain priorities. Supply interruption remains separate; Phase 3 resilient control is not implemented yet.
