# Control Strategy

## Baseline Controller

The starter model uses a discrete position controller designed around a three-state electrical-mechanical actuator model. The initial controller is intentionally conventional so that later resilience gains can be attributed clearly.

## Planned Estimator

Introduce a discrete state observer or Kalman filter estimating:

- Position
- Velocity
- Winding current or disturbance state

Define the measurement residual:

\[
r_k=y_k-\hat{y}_k
\]

Residual magnitude, duration, spectral content, and agreement with other signals will inform the measurement-confidence score.

## Detection Layers

1. Range limits
2. Rate-of-change limits
3. Timestamp and freshness checks
4. Cross-signal physical consistency
5. Observer-residual monitoring
6. Persistence and hysteresis logic

## Supervisory Modes

### Normal

All measurements are credible and the nominal controller is active.

### Suspected EMI

One or more checks fail briefly. Commands remain bounded while evidence accumulates.

### Degraded Control

The controller substitutes an estimated state, lowers bandwidth, and reduces command limits.

### Recovery

The controller requires a configurable sequence of credible measurements before restoring normal performance.

### Safe Stop

Confidence is insufficient to maintain controlled operation. The command transitions to a defined safe behavior.

## Comparison Policy

The resilient controller will be tested against exactly the same disturbance waveforms used for the baseline controller. Detector performance will report both missed detections and false alarms.

