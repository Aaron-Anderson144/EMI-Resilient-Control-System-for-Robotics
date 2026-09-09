# Phase 2A Validation Summary

## Identification

- **Date:** 2026-09-08
- **Parameter set:** `REPRESENTATIVE-ACTUATOR-V0.1`
- **Sample time:** 1 ms
- **Samples per scenario:** 1501
- **Simulink model:** `EMI_Resilient_Actuator_Phase2.slx`

## Test Results

- Phase 1 tests: 5 passed
- Phase 2A tests: 7 passed
- Total: 12 passed, 0 failed
- Simulink smoke tests: 5 scenarios completed
- Analytical/Simulink tolerance: `1e-9` rad
- Largest observed analytical/Simulink position difference: approximately `2.53e-13` rad

## Scenario Metrics

| Scenario | Tracking RMSE (rad) | Measurement RMSE (rad) | Maximum measurement error (rad) | Faulted samples |
|---|---:|---:|---:|---:|
| None | 0.083043 | 0 | 0 | 0 |
| Gaussian | 0.083054 | 0.0034548 | 0.012873 | 1000 |
| Sinusoidal | 0.083034 | 0.0063709 | 0.017419 | 400 |
| Count jump | 0.082970 | 0.0050680 | 0.19635 | 1 |
| Dropout | 0.082729 | 0.0071876 | 0.046105 | 150 |

The tracking metric includes the full step transient, which dominates these relatively small disturbances. Phase 2B should add disturbance-window metrics so fault effects are not obscured by the commanded transient.

## Evidence Files

- `phase2_metrics.csv`
- `phase2_fault_study.mat`
- `phase2_encoder_faults.png`
- `phase2_simulink_validation.csv`
- `phase2_simulink_smoke_test.csv`
- One time-series CSV for each scenario

## Next Step

Add physically parameterized capacitive and inductive coupling profiles, communication delay and packet loss, ground-offset bias, and disturbance-window performance metrics.
