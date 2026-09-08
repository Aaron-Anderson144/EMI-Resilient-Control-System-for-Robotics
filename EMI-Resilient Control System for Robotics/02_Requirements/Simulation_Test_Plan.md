# Simulation Test Plan

## Test Philosophy

The clean baseline is established first. Fault tests reuse the same plant, command, sample time, and initial conditions so that only the intended independent variable changes.

## Initial Baseline Tests

| Test ID | Purpose | Input | Pass Condition | Outputs |
|---|---|---|---|---|
| B-001 | Verify discrete stability | Linear closed-loop model | All poles have magnitude below 1 | Pole list and maximum magnitude |
| B-002 | Verify position tracking | 30 degree step at 0.1 s | Response is finite and bounded | Position, error, overshoot, settling time |
| B-003 | Verify repeatability | Repeat identical run | Signals match within numerical tolerance | Difference summary |
| B-004 | Verify parameter sanity | Parameter validation | Positive physical constants and valid limits | Validation report |

## Planned Fault-Injection Tests

| Test ID | Disturbance | Primary Variable | Primary Metric |
|---|---|---|---|
| E-001 | Gaussian encoder noise | Standard deviation | Tracking RMSE |
| E-002 | Sinusoidal encoder interference | Amplitude and frequency | Error spectrum and RMSE |
| E-003 | Encoder impulse/count jump | Jump magnitude | Peak command and recovery time |
| E-004 | Encoder dropout | Duration | Maximum error and state transition |
| E-005 | Communication packet loss | Loss probability | Failure probability |
| E-006 | Communication delay and jitter | Delay distribution | Stability margin and tracking error |
| E-007 | Ground-offset bias | Bias amplitude | Steady-state error and detection delay |
| E-008 | Supply interruption | Sag magnitude and duration | Reset or safe-state outcome |

## Comparison Configurations

1. Baseline: no mitigation and no resilient-control feature
2. Electromagnetic mitigation only
3. Fault-tolerant control only
4. Combined electromagnetic and control mitigation

## Required Metadata

- Test ID and timestamp
- Model version
- Parameter-set identifier
- Random seed
- Solver and sample time
- Enabled mitigation configuration
- Disturbance definition
- Pass/fail outcome

## Analysis Outputs

- Time histories
- Error spectra
- RMSE and peak error
- Overshoot and settling time
- Fault-detection delay
- Recovery time
- Failure probability and confidence interval
- Stable/unstable operating-region map

