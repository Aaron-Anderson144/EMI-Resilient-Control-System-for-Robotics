# System Requirements

## Status Legend

- **Draft:** Candidate requirement awaiting review
- **Accepted:** Approved project requirement
- **Verified:** Supported by recorded evidence

## Functional Requirements

| ID | Requirement | Verification | Status |
|---|---|---|---|
| FUN-001 | The digital twin shall model actuator position, velocity, and winding current. | Model inspection and test | Verified |
| FUN-002 | The baseline shall provide closed-loop position control. | Simulation | Verified |
| FUN-003 | Fault injection shall be disabled by default. | Automated test | Draft |
| FUN-004 | The model shall support sensor-noise, sensor-dropout, delay, jitter, packet-loss, and ground-offset scenarios. | Scenario tests | Draft |
| FUN-005 | The controller shall expose normal, degraded, recovery, and safe-stop operating modes. | State-transition tests | Draft |
| FUN-006 | Every simulation shall record the configuration and parameter set used. | Output inspection | Draft |

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
| DATA-001 | Stored signals shall include time, reference, position, velocity, current, command, fault state, and disturbance state when available. | Data inspection | Draft |
| DATA-002 | Every parameter shall include units and provenance. | Parameter review | Draft |
| DATA-003 | Raw experimental data shall be immutable; transformations shall create processed copies. | Folder and workflow review | Draft |
| DATA-004 | Figures used in the report shall be reproducible from a saved dataset and script. | Reproduction test | Draft |

## Safety Requirements for Future Hardware

| ID | Requirement | Verification | Status |
|---|---|---|---|
| SAFE-001 | The testbed shall include an accessible emergency stop or power disconnect. | Inspection | Draft |
| SAFE-002 | Moving components shall be guarded or operated within a controlled exclusion area. | Inspection | Draft |
| SAFE-003 | Initial testing shall use current-limited, bench-scale power. | Procedure review | Draft |
| SAFE-004 | EMI injection shall use controlled conducted or localized near-field methods. | Procedure review | Draft |
| SAFE-005 | Formal compliance shall not be claimed without appropriate facilities, calibration, and procedures. | Report review | Draft |
