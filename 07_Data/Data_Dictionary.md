# Data Dictionary

| Signal | Symbol | Unit | Description | Initial Source |
|---|---|---|---|---|
| Time | `time_s` | s | Simulation or measurement time | Simulation clock |
| Position reference | `theta_ref_rad` | rad | Commanded shaft position | Test scenario |
| Shaft position | `theta_rad` | rad | Actual or measured shaft position | Plant/encoder |
| Shaft velocity | `omega_rad_s` | rad/s | Actual or estimated shaft speed | Plant/estimator |
| Winding current | `current_A` | A | DC-equivalent or phase-current value | Plant/current sensor |
| Drive command | `voltage_cmd_V` | V | Controller output before or after saturation | Controller |
| Load torque | `load_torque_Nm` | N·m | Mechanical disturbance torque | Test scenario |
| Position error | `position_error_rad` | rad | Reference minus measured position | Analysis |
| Fault active | `fault_active` | Boolean | Whether fault injection is enabled | Fault injector |
| Fault type | `fault_type` | categorical | Identifier for active disturbance | Test configuration |
| Operating mode | `control_mode` | categorical | Normal, suspected, degraded, recovery, or safe stop | Supervisor |
| Residual | `residual` | signal-dependent | Measured minus predicted output | Observer monitor |
| Measured encoder position | `theta_measured_rad` | rad | Position presented to the controller after fault injection | Encoder model |
| Encoder Gaussian fault | `gaussian_fault_rad` | rad | Seeded additive random measurement error | Fault profile |
| Encoder sinusoidal fault | `sinusoidal_fault_rad` | rad | Windowed additive periodic interference | Fault profile |
| Encoder count-jump fault | `count_jump_fault_rad` | rad | Single-sample angular error derived from encoder counts | Fault profile |
| Dropout active | `dropout_active` | Boolean | Configured communication or measurement-loss interval | Fault profile |
| Measurement stale | `measurement_stale` | Boolean | Controller is receiving the held last accepted encoder value | Encoder interface |
| Sensor-side measurement | `sensor_side_measurement_rad` | rad | True position plus receiver-equivalent Phase 2B angular error before the communication channel | Phase 2B sensor interface |
| Received measurement | `received_measurement_rad` | rad | Timestamped sample accepted and presented to the controller after delay, jitter, loss, ordering, and hold-last behavior | Phase 2B communication receiver |
| Tracking error | `tracking_error_rad` | rad | Reference minus received measurement used by the controller | Controller |
| Unsaturated command | `unsaturated_command_V` | V | Linear controller output before voltage limiting | Controller |
| Capacitive current | `capacitive_current_A` | A | Differential current from line-capacitance imbalance and voltage edge rate | Reduced-order coupling model |
| Capacitive differential voltage | `capacitive_voltage_V` | V | Receiver-equivalent differential voltage attributed to capacitive coupling | Reduced-order coupling model |
| Inductive differential voltage | `inductive_voltage_V` | V | Receiver-equivalent differential voltage attributed to mutual-inductance imbalance | Reduced-order coupling model |
| Shared-impedance differential voltage | `shared_impedance_voltage_V` | V | Receiver-equivalent differential voltage attributed to resistive/inductive shared return and common-mode conversion | Reduced-order coupling model |
| Ground common-mode voltage | `ground_common_mode_voltage_V` | V | Applied controller/receiver reference offset before conversion | Phase 2B ground-offset model |
| Ground differential voltage | `ground_differential_voltage_V` | V | Differential contribution from ground-offset common-mode conversion | Phase 2B ground-offset model |
| Total receiver differential voltage | `receiver_differential_voltage_V` | V | Sum of enabled capacitive, inductive, shared-impedance, and ground differential components | Phase 2B receiver-equivalent model |
| Equivalent encoder error | `equivalent_encoder_error_rad` | rad | Phenomenological system-level angular error obtained from total receiver differential voltage | Assumed volts-to-radians sensitivity |
| Physical source window | `physical_source_window_active` | Boolean | True for the half-open physical-coupling interval when a physical mechanism is enabled | Scenario configuration |
| Ground window | `ground_window_active` | Boolean | True for the half-open ground-offset interval when enabled | Scenario configuration |
| Communication channel enabled | `communication_channel_enabled` | Boolean | True during the half-open communication-fault interval for an enabled communication scenario | Scenario configuration |
| Transmit delay | `transmit_delay_samples` | sample | Scheduled nonnegative integer source-to-arrival delay | Communication channel |
| Packet dropped | `packet_dropped` | Boolean | True when a transmitted source sample is discarded by the seeded loss process | Communication channel |
| Sample received | `sample_received` | Boolean | True when a newer source timestamp is accepted at this controller sample | Communication receiver |
| Accepted source index | `accepted_source_index` | index | One-based source-sample index accepted at an arrival instant; zero means none | Communication receiver |
| Accepted delay | `accepted_delay_samples` | sample | Controller index minus accepted source index | Communication receiver |
| Held last | `held_last` | Boolean | True when no new sample is accepted and the prior received value is retained | Communication receiver |
| Measurement age | `measurement_age_samples` | sample | Current index minus the most recently accepted source index | Communication receiver |
| Measurement age | `measurement_age_s` | s | Measurement age converted using controller sample time | Communication receiver |
| Collision discard count | `collision_discard_count` | count | Number of older same-instant arrivals discarded when the newest timestamp wins | Communication receiver |
| Out-of-order discard count | `out_of_order_discard_count` | count | Number of arrival instants rejected because the newest arrival is older than the last accepted timestamp | Communication receiver |

## Phase 2B Comparison Fields

| Field | Unit | Description |
|---|---|---|
| `deltaPosition_rad` | rad | Faulted true position minus matched no-fault true position |
| `deltaMeasurement_rad` | rad | Faulted received measurement minus matched no-fault received measurement |
| `deltaCommand_V` | V | Faulted saturated command minus matched no-fault command |
| `preMaxAbsPositionDelta_rad` | rad | Maximum absolute position delta before the earliest enabled mechanism starts |
| `activePositionDeltaRMSE_rad` | rad | Position-delta RMSE over the scenario analysis window |
| `activeMaxAbsPositionDelta_rad` | rad | Maximum absolute position delta over the analysis window |
| `activeMaxAbsMeasurementDelta_rad` | rad | Maximum absolute received-measurement delta over the analysis window |
| `activeMaxAbsCommandDelta_V` | V | Maximum absolute command delta over the analysis window |
| `postMaxAbsPositionDelta_rad` | rad | Maximum absolute position delta after the latest enabled mechanism stops |
| `packetDropFraction` | ratio | Dropped packets divided by enabled-window transmitted packets |
| `missingUpdateFraction` | ratio | Held-last controller samples divided by enabled-window samples |
| `meanMeasurementAge_samples` | sample | Mean measurement age during the enabled communication window |
| `maxMeasurementAge_samples` | sample | Maximum measurement age during the enabled communication window |
| `recoveryTime_s` | s | First post-window time that begins the required in-threshold dwell; `NaN` if not observed |
| `recoveryCensored` | Boolean | True when recovery is not observed within the simulated post-window record |

## Naming Rules

- Include units in exported column names.
- Use SI units internally unless a documented exception is necessary.
- Preserve raw values and create new fields for derived quantities.
- Record the random seed for every stochastic simulation.
- Treat disturbance intervals as half-open `[start, stop)` unless a file explicitly states otherwise.
- Distinguish true plant position, sensor-side measurement, and controller-received measurement.
- Prefix or describe baseline-subtracted comparison fields as deltas; do not label them as absolute tracking error.
- Record whether a value is assumed, calculated, simulated, datasheet-derived, literature-derived, or measured.
