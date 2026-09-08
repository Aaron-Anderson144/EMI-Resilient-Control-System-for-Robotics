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

**Status as of 2026-09-08:** Phase 2A is complete for Gaussian encoder noise, sinusoidal encoder interference, a one-sample count jump, and bounded hold-last dropout. Phase 2B now has software-verified reduced-order capacitive, inductive, shared-impedance, ground-offset, fixed-delay, bounded-jitter, and packet-loss mechanisms. All 16 Phase 2B automated tests and all ten MATLAB/Simulink comparisons pass. Physical-parameter identification, sensitivity sweeps, and supply interruption remain open.

### Tasks

- [x] Add encoder noise, impulses/count jumps, and hold-last dropout.
- [x] Add timestamped communication delay, bounded jitter, packet loss, and stale-sample behavior at source level.
- [x] Complete automated and MATLAB/Simulink verification of the implemented communication channel.
- [x] Add a receiver-equivalent ground-offset disturbance channel.
- [x] Derive reduced-order capacitive, inductive, and shared-impedance coupling inputs from assumed parameters.
- [ ] Replace the controller-rate envelope with a switching-level model when PWM-edge behavior must be resolved.
- [ ] Add supply-interruption scenarios.
- [x] Complete fixed-seed Monte Carlo packet-loss execution and confidence-interval reporting.
- [ ] Sweep assumed parasitics, edge rates, path-transfer factors, and receiver sensitivity.

### Gate 2

Each fault has documented units, provenance, severity parameters, half-open activation logic, and a test demonstrating that it affects only its intended channel. Stochastic scenarios are reproducible, communication timing is causal, and matched no-fault comparisons are stored.

**Gate status:** Satisfied for the implemented Phase 2A and Phase 2B software mechanisms. The full Phase 2 gate remains open for supply interruption and the planned parameter-sensitivity work. Passing this gate does not establish physical fidelity.

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

Run sensitivity sweeps over the assumed coupling and receiver parameters, replace high-influence assumptions with geometry-, circuit-, literature-, or measurement-derived values, and define the next switching-level Simscape Electrical case. Supply interruption remains a separate Phase 2 task.
