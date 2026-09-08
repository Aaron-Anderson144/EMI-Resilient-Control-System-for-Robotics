# System Requirements

## Status Legend

- **Draft:** Candidate requirement awaiting review
- **Partial:** Some required behavior is implemented and verified
- **Implemented:** Source behavior exists, but the complete verification evidence is not yet recorded
- **Accepted:** Approved project requirement
- **Verified:** Supported by recorded evidence

## Functional Requirements

| ID | Requirement | Verification | Status |
|---|---|---|---|
| FUN-001 | The digital twin shall model actuator position, velocity, and winding current. | Model inspection and test | Verified |
| FUN-002 | The baseline shall provide closed-loop position control. | Simulation | Verified |
| FUN-003 | Fault injection shall be disabled by default. | Automated test | Verified |
| FUN-004A | The model shall support independent Gaussian noise, sinusoidal interference, count-jump, and hold-last encoder-dropout scenarios. | Scenario tests and MATLAB/Simulink cross-validation | Verified |
| FUN-004B | The model shall support independent communication delay, jitter, packet-loss, and ground-offset scenarios. | Scenario, causality, determinism, boundary, and MATLAB/Simulink tests | Verified |
| FUN-004C | The model shall support independent reduced-order capacitive, inductive, and shared-impedance coupling scenarios. | Equation, scaling, isolation, superposition, and MATLAB/Simulink tests | Verified |
| FUN-005 | The controller shall expose normal, degraded, recovery, and safe-stop operating modes. | State-transition tests | Draft |
| FUN-006 | Every simulation shall record the configuration and parameter set used. | Scenario-manifest and output inspection | Verified for Phase 2B |
| FUN-007 | Communication reception shall accept only newer source timestamps, reject out-of-order arrivals, and hold the last accepted value when no newer packet arrives. | Packet-schedule tests and discrete-profile cross-validation | Partial |

## Baseline Performance Requirements

Initial thresholds are provisional until a physical actuator or authoritative parameter set is selected.

| ID | Requirement | Verification | Status |
|---|---|---|---|
| PERF-001 | The clean discrete closed loop shall have all poles strictly inside the unit circle. | Pole calculation | Verified |
| PERF-002 | The clean baseline shall track a 30 degree position command with a bounded response. | Simulation | Verified |
| PERF-003 | Baseline tracking error, overshoot, settling time, and control effort shall be recorded. | Results file | Verified |
| PERF-004 | The model shall enforce the nominal drive-voltage limit when saturation is enabled. | Simulation | Draft |
| PERF-005 | Identical parameters and random seed shall reproduce identical outputs within numerical tolerance. | Automated test | Verified |

## Resilience Requirements

| ID | Requirement | Verification | Status |
|---|---|---|---|
| RES-001 | A single implausible sensor sample shall not create an unbounded actuator command. | Fault test | Draft |
| RES-002 | Persistent invalid feedback shall cause degraded control or safe stop. | Fault test | Draft |
| RES-003 | Recovery shall require a configurable sequence of valid samples. | Transition test | Draft |
| RES-004 | The system shall report fault-detection delay and recovery time. | Data analysis | Draft |
| RES-005 | The combined mitigation configuration shall be compared against the unprotected baseline using identical disturbance profiles. | Experiment review | Draft |

## Data and Traceability Requirements

| ID | Requirement | Verification | Status |
|---|---|---|---|
| DATA-001 | Stored signals shall include time, reference, position, velocity, current, command, fault state, and disturbance state when available. | Data inspection | Verified for Phase 2B |
| DATA-002 | Every parameter shall include units and provenance. | Parameter review | Partial |
| DATA-003 | Raw experimental data shall be immutable; transformations shall create processed copies. | Folder and workflow review | Draft |
| DATA-004 | Figures used in the report shall be reproducible from a saved dataset and script. | Reproduction test | Draft |
| DATA-005 | Phase 2B comparisons shall use the matched no-fault run and report pre-window identity, active-window incremental response, post-window response, and recovery censoring. | Metrics inspection and automated test | Verified |
| DATA-006 | Every stochastic communication result shall record its seed, configured probability or bounds, and observed event count. | Manifest, metrics, and Monte Carlo output inspection | Verified |

## Safety Requirements for Future Hardware

| ID | Requirement | Verification | Status |
|---|---|---|---|
| SAFE-001 | The testbed shall include an accessible emergency stop or power disconnect. | Inspection | Draft |
| SAFE-002 | Moving components shall be guarded or operated within a controlled exclusion area. | Inspection | Draft |
| SAFE-003 | Initial testing shall use current-limited, bench-scale power. | Procedure review | Draft |
| SAFE-004 | EMI injection shall use controlled conducted or localized near-field methods. | Procedure review | Draft |
| SAFE-005 | Formal compliance shall not be claimed without appropriate facilities, calibration, and procedures. | Report review | Draft |
