# MATLAB and Simulink Workspace

## Purpose

This folder contains the verified Phase 1 clean actuator model, the cross-validated Phase 2A encoder-fault injection layer, and the software-verified Phase 2B implementation for reduced-order electromagnetic coupling, ground offset, and communication faults. The baseline remains separate so faulted and unfaulted behavior can be compared directly.

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

## Running Phase 2A

Run the analytical fault study:

```matlab
startup_project
phase2_main
```

Generate and validate the Phase 2 Simulink model:

```matlab
build_phase2_model
smoke_test_phase2_model
validate_phase2_simulink
```

Available scenario names are `none`, `gaussian`, `sinusoidal`, `count_jump`, `dropout`, and `combined`. The `combined` scenario is available for exploration but is not part of the independent-fault comparison set.

## Running a Phase 2B Source Scenario

Run the complete Phase 2B artifact pipeline with:

```matlab
startup_project
phase2b_main
```

`phase2b_main` runs the analytical scenario study, the 200-trial packet-loss study for `p=0`, the configured probability, and `p=1`, builds the Phase 2B Simulink model, smoke-tests all ten scenarios, and runs analytical/Simulink cross-validation. Run the automated test suite separately with `runtests("tests")` so test results are visible and reviewable. The recorded 2026-09-08 run passed all 28 project tests, including all 16 Phase 2B tests.

The current Phase 2B source API can be exercised directly:

```matlab
startup_project
params = actuator_parameters();

baselineScenario = phase2b_scenario("none", params);
baseline = simulate_phase2b_actuator(params, baselineScenario);

faultScenario = phase2b_scenario("capacitive_coupling", params);
faulted = simulate_phase2b_actuator(params, faultScenario);
metrics = phase2b_metrics(faulted, baseline, params);
```

Available Phase 2B names are:

- `none`
- `capacitive_coupling`
- `inductive_coupling`
- `shared_impedance`
- `combined_coupling`
- `ground_offset`
- `communication_delay`
- `communication_jitter`
- `packet_loss`
- `combined_phase2b`

The isolated scenarios are the primary verification cases. `combined_coupling` checks superposition, while `combined_phase2b` is an exploratory stress case and does not isolate causal attribution.

`physical_coupling_profile` calculates differential receiver voltage from assumed line imbalance, edge rate, path-transfer, termination, shared-return, and ground-conversion parameters. `communication_channel_profile` schedules timestamped samples, rejects older arrivals, and exposes packet age, collisions, loss, and hold-last state. `phase2b_metrics` compares each faulted run with the matched Phase 2B `none` run and reports pre-window identity, active-window deltas, post-window response, and threshold/dwell recovery censoring.

The completed Phase 2B pipeline creates:

- `models/EMI_Resilient_Actuator_Phase2B.slx`;
- `results/phase2b_<scenario>_timeseries.csv` for each named scenario;
- `results/phase2b_metrics.csv` and `results/phase2b_scenario_manifest.csv`;
- `results/phase2b_fault_study.mat` and `results/phase2b_receiver_faults_and_response.png`;
- `results/phase2b_packet_loss_monte_carlo.csv`;
- `results/phase2b_simulink_smoke_test.csv` and `results/phase2b_simulink_validation.csv`.

The recorded run completed successfully: all ten Simulink cases produced 1501 finite samples, all MATLAB/Simulink continuous differences were below `1e-9`, the largest continuous-signal difference was approximately `2.2751e-12`, and all discrete profiles matched exactly. See `results/Phase2B_Validation_Summary.md` for the evidence and interpretation limits.

## Important Limitation

This remains a reduced-order motor and encoder-interface model. Phase 2A faults are prescribed signals. Phase 2B coupling amplitudes are calculated from assumed parameters, but the result is still a receiver-equivalent system model rather than a measured cable/receiver model.

The controller sample rate is 1 kHz, so it cannot resolve the individual edges of the assumed 20 kHz PWM source. Phase 2B calculates finite-edge peak magnitudes and maps them into a 120 Hz controller-rate envelope. The `systemLevelEquivalentSensitivity_rad_V` parameter is a phenomenological volts-to-radians bridge for closed-loop sensitivity analysis; it is not a physical encoder-decoder transfer function and does not predict bit errors, false counts, or threshold crossings. Switching, commutation, detailed parasitic networks, receiver electronics, protocol behavior, and hardware validation remain future fidelity layers.
