# Preliminary Failure Modes and Effects Analysis

Scores use an initial 1–5 scale: severity (S), occurrence (O), and detectability difficulty (D). The risk-priority number is `S × O × D`. These are planning estimates and must be revised with evidence.

| ID | Failure Mode | Physical Cause | Local Effect | System Effect | Detection | Proposed Mitigation | S | O | D | RPN |
|---|---|---|---|---|---|---|---:|---:|---:|---:|
| FM-001 | Encoder count jump | Capacitive or inductive transient | Incorrect position increment | Sudden corrective torque | Rate and consistency check | Reject sample; observer substitution | 4 | 3 | 2 | 24 |
| FM-002 | Encoder dropout | Link interruption or receiver upset | Stale position | Tracking degradation | Timestamp and freshness monitor | Degraded observer-based control | 4 | 3 | 2 | 24 |
| FM-003 | Sensor bias | Ground offset or common-mode conversion | Persistent measurement error | Position offset or drift | Observer residual and cross-check | Recalibration, isolation, safe stop | 4 | 2 | 3 | 24 |
| FM-004 | CAN packet loss | Common-mode disturbance or termination problem | Missing command or feedback | Delay or discontinuity | Error counters and sequence IDs | Hold, retry, derate, timeout | 4 | 3 | 2 | 24 |
| FM-005 | Excessive bus latency | Retransmission or processing overload | Late feedback | Reduced phase margin | Timestamp and deadline monitor | Lower bandwidth; safe transition | 4 | 2 | 3 | 24 |
| FM-006 | Controller brownout/reset | Conducted supply transient | State loss | Uncontrolled interruption | Reset-cause and voltage monitor | Hold-up, filtering, safe boot | 5 | 2 | 2 | 20 |
| FM-007 | Current-sensor spike | Switching-field coupling | False overcurrent or torque estimate | Nuisance shutdown or bad control | Plausibility and persistence check | Filtering and redundant limit logic | 3 | 4 | 2 | 24 |
| FM-008 | PWM command corruption | Logic upset or software fault | Incorrect duty cycle | Excess torque or current | Command bounds and independent limits | Saturation and shutdown interlock | 5 | 2 | 2 | 20 |
| FM-009 | Ground-loop current | Multiple return paths | Common-mode and offset voltage | Multiple sensor errors | Ground-current or differential measurement | Bonding and topology redesign | 4 | 3 | 4 | 48 |
| FM-010 | Shield current coupled into signal ground | Incorrect termination | Increased common-mode noise | Intermittent data corruption | Configuration comparison | Chassis termination redesign | 3 | 3 | 4 | 36 |

## Review Actions

1. Replace assumed occurrence scores with simulation and bench-test evidence.
2. Define severity in terms of a specific mechanical load and operating envelope.
3. Add hardware-specific failures after components are selected.
4. Link every high-priority failure to a requirement and test case.

