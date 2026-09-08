# MATLAB and Simulink Workspace

## Purpose

This folder contains the Phase 1 clean actuator model. It intentionally excludes EMI injection so that the reference behavior is established before faults are introduced.

## Initial Equations

The state vector is:

\[
x=\begin{bmatrix}\theta & \omega & i\end{bmatrix}^{T}
\]

with:

\[
\dot{\theta}=\omega
\]

\[
J\dot{\omega}=K_t i-b\omega-\tau_L
\]

\[
L\dot{i}=v-Ri-K_e\omega
\]

Inputs are drive voltage and load torque. Initial outputs are position, velocity, and winding current.

## Folder Map

- `parameters` — representative physical and simulation parameters
- `functions` — model, validation, and controller functions
- `scripts` — analysis and Simulink model-generation scripts
- `tests` — automated baseline tests
- `models` — generated Simulink models
- `results` — generated data and plots

## Running the Baseline

From this folder in MATLAB:

```matlab
startup_project
main
```

This runs the analytical discrete-time baseline and writes:

- `results/baseline_timeseries.csv`
- `results/baseline_metrics.mat`
- `results/baseline_response.png`

## Creating the Simulink Model

```matlab
startup_project
build_baseline_model
```

The script creates:

```text
models/EMI_Resilient_Actuator_Baseline.slx
```

If the model already exists, the builder preserves it. To replace it intentionally:

```matlab
build_baseline_model(true)
```

## Running Tests

```matlab
startup_project
results = runtests("tests");
table(results)
```

## Important Limitation

This is a linear, unsaturated analytical baseline. The generated Simulink model adds a voltage-saturation block, but it still uses a reduced-order motor model. Switching, commutation, cable parasitics, common-mode paths, sensor electronics, and EMI injection are future fidelity layers.

