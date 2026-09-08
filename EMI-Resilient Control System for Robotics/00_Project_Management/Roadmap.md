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

### Tasks

- Add encoder noise, impulses, count jumps, dropout, and bias.
- Add communication delay, jitter, packet loss, and stale samples.
- Add supply and ground-offset disturbance channels.
- Derive capacitive and inductive coupling inputs.
- Add PWM-synchronous disturbance scenarios.
- Implement fixed-seed Monte Carlo execution.

### Gate 2

Each fault has documented units, severity parameters, activation logic, and a test demonstrating that it affects only its intended channel.

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

Review the representative motor parameters, run the analytical baseline, generate the Simulink model, and approve or revise the Phase 1 acceptance criteria.

