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

## Phase 2B Sensitivity Artifacts (2026-09-09)

All sensitivity files are in `03_MATLAB/results/sensitivity`. These are simulated data from exploratory assumed ranges. The `Sample` key joins `phase2b_sensitivity_global_inputs.csv` with the two context rows in `phase2b_sensitivity_global_metrics.csv`.

| Field or file | Unit / interpretation |
|---|---|
| Catalog `Low`, `Nominal`, `High`; OAT `Value`; global parameter columns | Display units specified by the catalog `Unit`; multiply by `SIConversion` for internal units. This is an explicit exception to unit suffixes on global input keys. |
| `Scale` | Linear, logarithmic or integer design coordinate; not a calibrated probability distribution. |
| `Role` | `response`, `diagnostic`, `derived_only`, or `inactive` in the current implementation. |
| `Context` | `physical_only` or `combined_phase2b`, with the same [0.70, 1.15) s metric window. |
| `ActiveRMSE_deg`, `ActivePeak_deg`, `PostPeak_deg` | Position differences from the matched no-fault case, in degrees. |
| `NominalTrajectoryChange_deg`, `NominalCommandChange_V`, `NominalReceiverChange_V` | Maximum whole-record change from the nominal **faulted** case in the same context. |
| `MaxTrajectoryChange_deg` in ranking | Largest `NominalTrajectoryChange_deg` across that parameter's one-at-a-time levels. Range-dependent influence measure. |
| `ReceiverPeak_V`, `EquivalentErrorPeak_deg` | Actual sampled receiver differential magnitude and phenomenological angle-error magnitude. |
| `MarginExceededSamples`, `CommonModeExceededSamples` | Number of diagnostic-flag samples; not counts of physical receiver/encoder failures. |
| `ActiveSaturatedSamples`, `PostSaturatedSamples` | Samples whose raw command exceeds the voltage limit in the stated window. |
| `RecoveryTime_s`, `RecoveryCensored` | Original 0.05-degree / 50-sample dwell criterion after 1.15 s; censored cases have NaN time. Tiny values near machine precision mean the first eligible sample. |
| `FirstValue`, `SecondValue` | Interaction-grid coordinates; units resolved through `FirstParameter`/`SecondParameter` and the catalog. |
| `phase2b_sensitivity_study.mat` | Complete nominal/sample parameter structures, design, metrics, options, seed, selected cases and Simulink validation. |

## Naming Rules

- Include units in exported column names.
- Use SI units internally unless a documented exception is necessary.
- Preserve raw values and create new fields for derived quantities.
- Record the random seed for every stochastic simulation.
- Treat disturbance intervals as half-open `[start, stop)` unless a file explicitly states otherwise.
- Distinguish true plant position, sensor-side measurement, and controller-received measurement.
- Prefix or describe baseline-subtracted comparison fields as deltas; do not label them as absolute tracking error.
- Record whether a value is assumed, calculated, simulated, datasheet-derived, literature-derived, or measured.

## SC-01A Circuit Artifacts (2026-09-09)

Files live in `06_Circuit_Simulations/SC01A/results`. All traces are simulations using assumed inputs. Native solver timestamps are nonuniform; exported point density is distinct from the integration maximum step.

| Field or file | Unit / interpretation |
|---|---|
| `positive_V`, `negative_V` | Receiver line voltages relative to receiver ground, V. |
| `differential_V`, `commonMode_V` | Total receiver difference and line-voltage mean, V. Includes intended signal and disturbance. |
| `ground_V` | Sender shared-ground voltage relative to receiver ground, V. Algebraic jumps can occur at ideal source corners. |
| `returnCurrent_A` | Actual current through the shared return, A, including driver/receiver loading; not the prescribed commutation-current source alone. |
| `deltaDifferential_V`, `deltaCommonMode_V` | Native voltage minus matched intended-only loaded-circuit reference, V. |
| `PeakDM_V`, `PeakCM_V`, `PeakGround_V` | Maximum absolute baseline-subtracted disturbance over the full record, V. |
| `AbsAreaDM_Vs`, `AbsAreaCM_Vs` | Integral of the absolute baseline-subtracted disturbance, V*s. |
| `NoiseExposure_s` | Time with absolute differential disturbance above the illustrative 0.20 V noise threshold. |
| `ReceiverBand_s` | Time with total receiver input inside +/-0.20 V; includes intended-transition band residence. Not a failure count. |
| Event CSV `Time_s`, `Level_V`, `Direction`, `Channel` | Linearly interpolated crossing time, threshold, rising/falling direction and noise/total-input channel. Grazing contacts are classified separately. |
| `sc01a_case_manifest.json` / `.csv` | Complete per-case parameters and compact case changes, SI units. Null/NaN transition offset means no intended logic transition. |
| `sc01a_case_metrics.csv` | Case/refinement key, actual solver settings, full-native metrics, reference errors, counts and runtime. |
| `sc01a_convergence.csv`, `sc01a_tolerance_refinement.csv` | Successive refinement errors, event matching, exposure differences, numerical acceptance gates and pass state. |
| `sc01a_period_settling.csv` | Corresponding final-period voltage/current differences after 10 versus 20 periods; gate is 0.1 mV or 0.1 mA according to quantity. |
| `sc01a_*_timeseries.csv` | Full refined short-case waveform at native timestamps. |
| `sc01a_pwm_*_last_period.csv` | Only the final complete period; full long records remain in raw MAT files. |
| `raw/sc01a_*.mat` | Full refined native result, parameters, case, exact source arrays, metrics and event records. |
| `sc01a_study.mat` | Campaign metadata, all result/check tables, short-case examples and representative refinement traces. |

Pointwise reference checks retain all short-case native samples and a declared subset for long PWM records. Exact source-corner timestamps are omitted only from the algebraic ground-voltage error comparison; continuous node voltages and return current remain checked. Neither threshold exposure nor crossing count is an encoder/communication error rate.

## SC-01B Device-Source Artifacts (2026-09-09)

Files live in `06_Circuit_Simulations/SC01B/results/verification`. All are simulated at fixed 25 degrees C. The first microsecond is an initialization preamble; aggregate comparisons cover 1–5 microseconds. Waveform CSVs preserve actual recorded integration times. Missing event times or unknown SPICE internal-channel diagnostics use NaN and never silently pass required gates.

| Field or file | Unit / interpretation |
|---|---|
| `switch_V`, `bus_V` | Switch-node and local DC-link voltages relative to electrical ground, V. |
| `highVds_V`, `lowVds_V`, `highVgs_V`, `lowVgs_V` | External MOSFET terminal differences, V. |
| `highCurrent_A`, `lowCurrent_A` | Drain current into each device, A; includes charge/displacement contributions. |
| `highGateCurrent_A`, `lowGateCurrent_A` | Current entering each gate terminal, A. |
| `highChannelCurrent_A`, `lowChannelCurrent_A` | Native vendor internal channel branch currents, drain to source, A. |
| `highDiodeCurrent_A`, `lowDiodeCurrent_A` | Native vendor body-diode branch currents, source to drain, A. |
| `loadCurrent_A`, `feedCurrent_A` | Actual series load and supply-feed branch currents, A. |
| `InitialLoadCurrent_A`, event `Ipre_A` | Consistent initial current and current at the delayed source command, A. |
| `SwitchT10_s`, `SwitchT50_s`, `SwitchT90_s` | Roots against 10/50/90 percent of instantaneous local bus, s. |
| `GateMidpointOverlap_s` | Time both external gate voltages exceed 6 V; a diagnostic, not channel-conduction proof. |
| `HighTerminalEnergy_J`, `LowTerminalEnergy_J` | Signed integral of Vds*Id + Vgs*Ig over the indicated window, J; includes internal charge transfer, not heat. |
| `Residual_J`, `EnergyScale_J` | Exterior energy-accounting residual and its nonzero-work/storage-change scale, J; no normalization by absolute preloaded inductive energy. |
| `criteria.json`, per-case `parameters.json` | Frozen numerical gates and full assumed/sourced fixture values. |
| `runs.csv`, `metrics.csv`, `events.csv`, `balance.csv` | Completion/solver records, finest-trace metrics, event status and energy closure. |
| `waveforms.csv` | Per-signal pointwise error and acceptance allowance. Units follow `Signal` suffix. Union of both traces' knots; no fitted shift/filter. |
| `comparisons.csv` | Step/tolerance/independent-engine component gates and combined status. A reproduced stress failure remains failed where required event completeness is unmet. |
| Per-case MAT and `*_finest.csv` | Raw recorded waveforms and metadata at each refinement; CSVs export finest runs. |
| `study.mat`, `status.json`, `test_results.mat` | Complete study, explicit numerical/operating/physical status and regression evidence. Physical-source validation remains false. |

`runs.csv` distinguishes `Completed`, `Reused` and `Diagnostic`. A rejected strict-tolerance attempt has zero accepted samples, NaN accepted stop time and its error/log reference; it is not a zero-error trace. `comparisons.csv.ExecutionComplete=false` marks an unavailable required reference, with false pass flags and infinite limit ratios. Waveform-only summaries exclude unavailable comparisons and state their count separately. Full numerical acceptance includes those rejected checks and remains false.

## Phase 3 prototype artifacts

Accepted evidence lives under `03_MATLAB/results/development/phase3`; reproduction creates a new timestamped directory. `phase3_study.mat` stores protected/baseline and both matched-clean records, exact profiles, configurations and metrics. Each effective run records the declared assumed load actually used. JSON null means an infinite disabled point/window time in these fixtures; MAT preserves exact values.

| Field or file | Meaning / unit |
|---|---|
| `position_rad`, `velocity_rad_s`, `current_A` | True simulated plant state; offline scoring only. |
| `sensorMeasurement_rad`, `receivedMeasurement_rad` | Corrupted source-side value and held/received channel value, rad. |
| `estimatedPosition_rad`, `estimatedVelocity_rad_s`, `estimatedCurrent_A` | Current observer posterior. |
| `innovation_rad` | Source-time measurement minus stored prior; NaN when no finite innovation is available. Only this numeric channel permits paired missing values in the campaign Simulink gate. |
| `mode` | 0normal,1suspected,2degraded,3recovery,4latched stop. |
| `alarm`, `measurementAccepted`, `credibleFresh`, `estimateUsable` | Detector alarm, gated correction, new clear-residual evidence and prediction confidence flags. Held data never count as credibleFresh. |
| `predictionAge_s` | Age of last trusted source, or elapsed time since declared initial estimate before first trust. |
| `command_V`, `commandLimit_V`, `unsaturatedCommand_V` | Actual applied, current hard bound and controller raw command, V. |
| `sourceIndex`, `sampleReceived` | Accepted arrival's source sample index (zero if no new packet) and reception flag. Held measurement retains its previous value. |
| `resetRequest`, `supplyHealthy` | Explicit fixed operator input and bus threshold result; not fault-truth inputs. |
| `gateReason`, `transitionReason` | Text detector and supervisor diagnostics. |
| `phase3_metrics.csv` | Detection status/delay, source/receiver onset, separate recovery/censoring, clean false alarms, tracking, matched-clean changes, current and effort. NaN timing means unavailable/not-applicable, interpreted with status. |
| `phase3_transitions.csv` | Every mode transition with evidence flags and reason. |
| `phase3_simulink_validation*.csv` | Complete finite23-channel integration checks; exact discrete fields and innovation missing masks. |
| `phase3_ablation*.csv/.mat` | Three-case policy comparisons with recorded effective configurations; inactive limits do not imply measured improvement. |

Stop/alarm duration sums held intervals and excludes the final zero-duration endpoint. Reported recovery starts a50ms confirmed normal interval and is distinct from supervisor qualification time. Censored/missed outcomes must not be replaced with zero delay or counted as recovered.
