# Phase 2A Encoder Fault Definitions

## Purpose

Create deterministic signal-level faults before connecting disturbance magnitude to detailed electromagnetic coupling models.

## Implemented Scenarios

| Scenario | Initial Definition | Active Interval |
|---|---|---|
| None | No additive fault and no dropout | Entire run |
| Gaussian | Zero-mean noise, 0.25 degree standard deviation, fixed seed | 0.20–1.20 s |
| Sinusoidal | 1 degree amplitude at 120 Hz | 0.35–0.75 s |
| Count jump | Positive 128-count error for one sample with a 4096-count encoder | 0.45 s |
| Dropout | Hold the last accepted encoder value | 0.50–0.65 s |

## Interpretation Limits

These amplitudes are exploratory. They do not yet correspond to a measured electric or magnetic field, cable coupling coefficient, receiver threshold, or selected encoder. Their role is to validate the injection architecture and establish observable controller responses.

## Required Next Fidelity Step

Use the capacitive, inductive, and shared-impedance models in `EMI_Modeling_Plan.md` to derive physically traceable disturbance amplitudes and frequency content. Sensitivity sweeps should replace single assumed values.

