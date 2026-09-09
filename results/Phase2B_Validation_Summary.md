# Phase 2B Validation Summary

## Identification

- **Date:** 2026-09-08
- **Parameter set:** `REPRESENTATIVE-ACTUATOR-V0.2`
- **Parent parameter set:** `REPRESENTATIVE-ACTUATOR-V0.1`
- **Parameter provenance:** assumed reduced-order values for sensitivity analysis
- **Controller sample time:** 1 ms
- **Simulation duration:** 1.50 s
- **Samples per scenario:** 1501
- **Simulink model:** `EMI_Resilient_Actuator_Phase2B.slx`
- **Cross-validation numerical gate:** `1e-9`

## Validation Scope

This result verifies the Phase 2B software implementation against its specified reduced-order equations, deterministic scenario logic, communication scheduling semantics, and an independent Simulink realization. It does not validate the assumed physical parameters against hardware.

The electromagnetic path is a physics-based reduced-order, receiver-equivalent model. The 1 kHz controller model cannot resolve the assumed 20 kHz PWM cycles or 100–200 ns edges; finite-edge peak calculations are mapped into a 120 Hz controller-rate envelope. The volts-to-radians sensitivity is phenomenological and is not a physical encoder-decoder transfer function.

## Automated Tests

| Suite | Passed | Failed |
|---|---:|---:|
| Phase 1 baseline | 5 | 0 |
| Phase 2A encoder faults | 7 | 0 |
| Phase 2B coupling and communication | 16 | 0 |
| **Total** | **28** | **0** |

The Phase 2B tests cover no-fault regression, half-open windows, analytical peak equations, capacitive/inductive polarity and scaling, isolated channels, exact superposition, zero transfer/conversion, deterministic random scheduling, causal and monotonically increasing accepted timestamps, delay bounds, exact packet-loss endpoints, pre-onset identity, finite outputs, recovery dwell/censoring logic, and invalid-scenario rejection.

Two useful test refinements remain: explicitly force a packet-arrival collision and an out-of-order arrival in a constructed schedule, and independently scale the nonzero shared-resistance, shared-inductance, and ground-conversion terms.

## Simulink Smoke Test

All ten scenarios completed. Every run logged 1501 samples, every logged output was finite, accepted source timestamps were monotonic, and scheduled delays were nonnegative bounded integers.

| Scenario group | Scenarios passed |
|---|---:|
| No fault | 1 of 1 |
| Isolated and combined coupling | 4 of 4 |
| Ground offset | 1 of 1 |
| Communication delay, jitter, and packet loss | 3 of 3 |
| Combined Phase 2B | 1 of 1 |
| **Total** | **10 of 10** |

## MATLAB/Simulink Cross-Validation

All ten scenarios passed the numerical comparison. Discrete profiles matched exactly in every scenario.

| Quantity | Largest recorded difference |
|---|---:|
| Time | 0 s |
| Reference | 0 rad |
| Position | `1.8940e-13` rad |
| Velocity | `2.2751e-12` rad/s |
| Current | `3.9621e-13` A |
| Sensor-side measurement | `1.8940e-13` rad |
| Received measurement | `1.8940e-13` rad |
| Command | `9.1591e-13` V |
| Continuous diagnostics | 0 |
| Discrete profile comparison | Exact for all ten scenarios |

The largest continuous-signal difference was the velocity difference, approximately `2.2751e-12` rad/s. The maximum position difference was approximately `1.8940e-13` rad. Both are well below the recorded `1e-9` numerical gate.

This agreement demonstrates numerical consistency between the two implementations. Because they share the same assumed parameter definitions and reduced-order physics, agreement does not establish physical fidelity.

## Packet-Loss Statistical Study

Each probability case used 200 seeded trials and 80,000 total packet opportunities.

| Configured probability | Drops / opportunities | Observed fraction | Wilson 95% interval | Result |
|---:|---:|---:|---:|---|
| 0 | 0 / 80,000 | 0 | `[0, 0.00004802]` | Exact endpoint passed |
| 0.20 | 15,934 / 80,000 | 0.199175 | `[0.19642, 0.20196]` | Configured value inside interval |
| 1 | 80,000 / 80,000 | 1 | `[0.99995198, 1]` | Exact endpoint passed |

The single `packet_loss` closed-loop scenario used the configured seed and dropped 91 of 400 in-window packet opportunities (`0.2275`). That single-run fraction is not the estimate used for generator validation; the 200-trial aggregate above is.

## Calculated Coupling Scale

The following are calculated from the assumed parameter set, not measured values:

| Component | Analytical peak scale | Largest sampled magnitude in manifest | Assumed receiver margin exceeded? |
|---|---:|---:|---|
| Capacitive differential voltage | approximately 5.76 mV | 5.7486 mV | No |
| Inductive differential voltage | approximately 22.5 mV | 22.5000 mV | No |
| Shared-impedance differential voltage | approximately 37.5 mV | 37.4815 mV | No |
| Ground differential voltage | 10 mV | 10.0000 mV | No |
| Combined coupling | phase-dependent sum | 58.6268 mV | No |
| Combined Phase 2B physical contribution | phase-dependent sum plus ground | 68.5028 mV | No |

The analytical peak scale and sampled magnitude differ slightly for sinusoidal components because the 1 ms sample grid does not necessarily land on the continuous-time waveform peak. “Margin not exceeded” applies only to the assumed 0.20 V diagnostic margin in this model; it does not prove receiver immunity.

## Matched-Baseline Closed-Loop Results

Primary metrics subtract the matched Phase 2B `none` run so the commanded step transient does not mask the incremental fault response.

| Scenario | Active position-delta RMSE (rad) | Active max position delta (rad) | Active max received-measurement delta (rad) | Active max command delta (V) | Max measurement age (samples) |
|---|---:|---:|---:|---:|---:|
| `capacitive_coupling` | `8.3170e-06` | `2.2034e-05` | `1.0228e-03` | `2.7729e-03` | 0 |
| `inductive_coupling` | `1.3257e-05` | `3.6944e-05` | `3.9290e-03` | `1.0644e-02` | 0 |
| `shared_impedance` | `5.3456e-05` | `1.4170e-04` | `6.6414e-03` | `1.7995e-02` | 0 |
| `combined_coupling` | `7.4754e-05` | `1.9893e-04` | `1.0423e-02` | `2.8168e-02` | 0 |
| `ground_offset` | `1.6336e-03` | `1.9326e-03` | `1.7453e-03` | `4.6910e-03` | 0 |
| `communication_delay` | `3.6665e-04` | `6.0636e-04` | `6.6197e-04` | `1.7040e-03` | 8 |
| `communication_jitter` | `9.5000e-05` | `1.4297e-04` | `4.0951e-04` | `1.0636e-03` | 6 |
| `packet_loss` | `1.3083e-05` | `2.0413e-05` | `3.0070e-04` | `7.9150e-04` | 4 |
| `combined_phase2b` | `1.0537e-03` | `2.2346e-03` | `1.4134e-02` | `3.6247e-02` | 17 |

The recorded pre-window maximum position delta was zero for every faulted scenario. Recovery was not censored in any recorded scenario. The ground-offset case required approximately 0.049 s to satisfy the configured 0.05 degree, 50-sample recovery criterion; the other recorded scenarios satisfied the criterion at the first eligible post-window sample.

These values describe this one assumed parameter set. They are not acceptance limits for a physical robot or controller.

## Evidence Files

- `phase2b_scenario_manifest.csv`
- `phase2b_metrics.csv`
- `phase2b_fault_study.mat`
- `phase2b_receiver_faults_and_response.png`
- `phase2b_packet_loss_monte_carlo.csv`
- `phase2b_simulink_smoke_test.csv`
- `phase2b_simulink_validation.csv`
- one `phase2b_<scenario>_timeseries.csv` file for each of the ten named scenarios
- `models/EMI_Resilient_Actuator_Phase2B.slx`

## Claim Boundary and Next Work

It is accurate to say that Phase 2B is **software-verified for the implemented reduced-order scenarios**. It is not accurate to say that Phase 2B is experimentally validated, that the assumed receiver margin guarantees immunity, that communication behavior reproduces a specific protocol, or that the controller is fault-resilient.

Next work should sweep the assumed parameters, add the remaining constructed communication/scaling edge cases, identify critical parameters from geometry/circuit data or measurements, introduce a threshold/count-event receiver model where appropriate, and move switching-edge questions into a switching-level circuit or Simscape Electrical simulation.
