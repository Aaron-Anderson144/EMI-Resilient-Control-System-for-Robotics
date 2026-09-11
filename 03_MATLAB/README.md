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

This runs the analytical discrete-time baseline in a unique folder under `results/development/baseline_<UTC stamp>` and prints that folder. To choose a destination explicitly, call `study = run_baseline("C:/path/to/new-baseline")`. A new or empty folder is required; previous complete or partial results are rejected before any run writes.

- `baseline_timeseries.csv`
- `baseline_metrics.mat`
- `baseline_response.png`

The filenames above are relative to the new run folder. The older files directly under `results` remain historical evidence. Use callable names for the study functions; do not invoke them through `run("scripts/run_baseline.m")`.

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

`phase2_main` and `run_phase2_fault_study` accept an optional output-folder argument and default to a unique `results/development/phase2_<UTC stamp>` folder. `smoke_test_phase2_model` and `validate_phase2_simulink` also accept an optional fresh destination and create separate defaults. Each rejects a populated folder before simulation. Bare calls shown above remain supported.

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

`workflow = phase2b_main("C:/path/to/new-phase2b")` selects a new or empty workflow folder. Without the argument, the workflow uses `results/development/phase2b_workflow_<UTC stamp>`. The analytical, packet-loss, smoke-test and cross-validation outputs stay in separate child folders:

- `models/EMI_Resilient_Actuator_Phase2B.slx`;
- `analytical/phase2b_<scenario>_timeseries.csv` for each named scenario;
- `analytical/phase2b_metrics.csv` and `analytical/phase2b_scenario_manifest.csv`;
- `analytical/phase2b_fault_study.mat` and `analytical/phase2b_receiver_faults_and_response.png`;
- `packet_loss/phase2b_packet_loss_monte_carlo.csv`;
- `smoke/phase2b_simulink_smoke_test.csv` and `validation/phase2b_simulink_validation.csv`.

The stored Simulink model stays in `models`; result paths above are relative to the new workflow folder. The individual `run_phase2b_study`, `run_phase2b_packet_loss_monte_carlo`, `smoke_test_phase2b_model` and `validate_phase2b_simulink` functions accept optional fresh output folders and have unique defaults. Simulation caches follow the selected validation folder. See the [packet summary contract](../04_EMI_Models/Packet_Summary_Contract.md) for full-record and fault-window count scopes.

The recorded run completed successfully: all ten Simulink cases produced 1501 finite samples, all MATLAB/Simulink continuous differences were below `1e-9`, the largest continuous-signal difference was approximately `2.2751e-12`, and all discrete profiles matched exactly. See `results/Phase2B_Validation_Summary.md` for the evidence and interpretation limits.

## Running the Phase 2B Sensitivity Study

```matlab
phase2b_sensitivity_main
```

This runs the current project tests, screens 26 parameter controls, executes 512 stratified combinations in physical-only and fixed-communication contexts, evaluates two interaction grids, and cross-validates 11 selected cases against the saved Simulink model. The standard study uses 1,886 analytical study simulations, plus test and validation reference runs. The historical 2026-09-09 workflow contained 45 tests.

`study = phase2b_sensitivity_main("C:/path/to/new-sensitivity")` accepts a new or empty workflow directory. The default is a unique `results/development/phase2b_sensitivity_workflow_<UTC stamp>` folder. Test results stay at its top level; the summary, figure, design tables and MAT archive go under `campaign`, with cross-validation under `campaign/validation`. Direct `run_phase2b_sensitivity_study` and `validate_phase2b_sensitivity` calls also guard their output folders. The older `results/sensitivity` directory remains historical evidence.

See `04_EMI_Models/Phase2B_Sensitivity_Method.md` for exact units, assumptions, common metric windows, reproducibility, and custom study sizes. The combined design is exploratory; it is not a calibrated uncertainty distribution or a real-world fault probability model.

## Phase 3 numerical prototype

Run `startup_project` then `phase3_main` to reproduce focused tests, 29 matched fixtures, 58 Simulink comparisons and three-case policy ablations. Outputs use a new timestamped directory. The model shares online decision helpers with MATLAB while running an independent plant. See [the design contract](../05_Control_Algorithms/Phase3_Detection_and_Supervision.md) and [accepted evidence](results/development/phase3/Phase3_Implementation_Report.md). Zero-voltage stop is a numerical policy, not a physical brake; observer reacquisition and unobservable sensor faults remain explicit limits.

The optional V1.1 [independent-reference recovery extension](../05_Control_Algorithms/Phase3_Independent_Reference_Recovery.md) adds reconstruction while latched stopped, with declared measurement-error bounds and a separate primary qualification/reset. Run `phase3_reacquisition_main` for its 38 tests, 15 numerical fixtures and 15 Simulink comparisons. The capability defaults off; it requires a separate reference stream and does not resolve physical reference integrity, unknown model/load errors or stop/hold. The current model schema has 31 loop channels, retaining the original 20 in their original order.

## Frozen controller tuning and separate evaluation

Run `phase3_tuning_main` after startup to reproduce 33 focused tests, 226 numerical executions (113 fault/matched-clean pairs), 20 independent-plant Simulink comparisons and three PNG/PDF figures in a new directory. The [design contract](../05_Control_Algorithms/Phase3_Controller_Tuning.md) freezes nine gain/filter settings and eight tuning plus twelve evaluation fixtures before selection. The optional `phase3_tuning_configuration(params, options)` constructor changes only declared tuning fields; calling it without options equals the existing default configuration.

The [recorded report](results/development/phase3_tuning_20260910_141100/Phase3_Controller_Tuning_Report.md) retains historical defaults: `G100_F020` is diagnostic only, improves normalized tracking by 17.35%/29.37%, but passes all comparative case gates in only 5/8 tuning and 4/12 evaluation cases. Current and disturbance tradeoffs remain. The intended clean reversal exceeds the existing rate-check envelope and fails under all three evaluated policies. `run_phase3_tuning_study` saves the entire campaign then raises `EMIProject:TuningExecutionFailed`; the public main catches only that known requirement failure, retains it, and completes independent integration and plotting diagnostics. Successful tests/integration do not clear the rejected clean-operation requirement.

The 2026-09-10 tuning acceptance suite passed its then-current 315 tests and all 20 Simulink comparisons; a 7,336-check independent CSV audit reproduced the rejected outcome. That checkpoint preserved every prior MATLAB source/model hash. The tuning extension preserved the observer, supervisor, reset, 31-channel loop schema and disabled-by-default recovery behavior.

## Optional causal motion envelope

Run `phase3_motion_main` after startup to reproduce 33 focused tests, 80 numerical runs and 22 independent-plant Simulink comparisons in a fresh directory. The [design contract](../05_Control_Algorithms/Phase3_Motion_Envelope.md) freezes one analytical shaper and 20 cases before execution. `phase3_motion_profiles(params, scenario, configuration)` preserves the original task as `requestedReference_rad`, replaces `reference_rad` with the shaped controller command, and retains its causal trace. Every other exogenous profile and the 31-channel loop schema remain unchanged.

The nominal request envelope is ±120°, generated-reference speed 10 rad/s and sampled acceleration 200 rad/s². A slew-limited intermediate position followed by a derived first-order coefficient proves those reference bounds; actual plant and received measurement rates are evaluated separately. The helper uses current requests only, starts from the declared observer initial position, and does not alter supervision or stop behavior.

The [recorded 2026-09-10 motion report](results/development/phase3_motion_20260910_144242/Phase3_Motion_Envelope_Report.md) passed all 18 required governed behavior cases, its then-current 348 project tests and all 22 Simulink comparisons. The exact historical noisy reversal and its noiseless control both had 41 raw alarms and zero governed alarms. Original-request window RMSE worsened 6.67% in that development case; shaped-command error was reported separately. All eight new clean cases remained normal, and all eight fault cases met their specified deadlines/stop/reset requirements. A 9,390-check local Python audit independently verified the exported evidence. That checkpoint preserved all 135 previously verified MATLAB source/model hashes.

This optional profile does not bound physical motion under arbitrary loads, bypass a stop or justify a higher observer threshold. It continues through stops, so large restart catch-up errors and physical loaded stop/hold remain separate work.

## Separate passive stop/hold harness

Run `startup_project` then `phase3_stop_hold_main` for a new local 20-fixture, three-mechanism, three-grid campaign (180 runs). The driver rejects a populated output folder and freezes assumptions/source identity before execution. The [design](../05_Control_Algorithms/Phase3_Stop_Hold.md) specifies terminal short, a 1.2 ohm resistor loop and an assumed finite-capacity mechanical brake. This is a separate plant harness with no controller/observer or Simulink brake integration.

The [recorded 2026-09-10 report](results/development/phase3_stop_hold_20260910_150537/Phase3_Stop_Hold_Report.md) passed the then-current 371 project tests, all 20 expected mechanical outcomes and 3,949 independent checks across 180 traces and 60 continuous references. Fine-grid maxima were 0.004172 degree position, 0.002785 rad/s velocity and 0.002627 A current error; numerical energy loss was at most 0.598 percent of the declared scale. That study preserved all 148 prior MATLAB source/model files. Later consolidation changes have their own local Git history and verification scope; see [local reproduction](../00_Project_Management/Local_Reproduction.md).

Outputs contain `frozen_design.json`, 1 ms state/cumulative-energy traces, full-step travel/current/energy extrema in `stop_hold_metrics.csv`, and a MAT archive. The saved `audit_stop_hold.py` in the campaign uses the existing local SciPy environment and takes a campaign path; run it separately before treating a new run as accepted. The public MATLAB main explicitly reports that the independent audit remains required. The saved acceptance driver also runs the full project tests. Brake torque is the preceding substep's solved value, with a time-zero placeholder; load columns are right-continuous at knots.

At the previous loaded stop, modeled motion falls from 92.797 degrees of backdrive to 1.692 degrees before holding at 46.875 ms. Hardware capacity/delay/heat are not identified. Release under load still requires torque handoff and a distinct interlock; the observer needs justified brake-aware dynamics.

## Important Limitation

This remains a reduced-order motor and encoder-interface model. Phase 2A faults are prescribed signals. Phase 2B coupling amplitudes are calculated from assumed parameters, but the result is still a receiver-equivalent system model rather than a measured cable/receiver model.

The controller sample rate is 1 kHz, so it cannot resolve the individual edges of the assumed 20 kHz PWM source. Phase 2B calculates finite-edge peak magnitudes and maps them into a 120 Hz controller-rate envelope. The `systemLevelEquivalentSensitivity_rad_V` parameter is a phenomenological volts-to-radians bridge for closed-loop sensitivity analysis; it is not a physical encoder-decoder transfer function and does not predict bit errors, false counts, or threshold crossings. Switching, commutation, detailed parasitic networks, receiver electronics, protocol behavior, and hardware validation remain future fidelity layers.

## v0.3 parameter and supply extension

All three Simulink models now accept actual run parameters through the `create_baseline_simulation_input`, `create_phase2_simulation_input` and `create_phase2b_simulation_input` helpers. Nonzero nominal load is applied to the second plant input. Invalid inputs and stale/wrong-project models are rejected. `run_supply_integration_study` creates a new 13-case evidence package for averaged motor-bus faults, controller-state policies and loaded motion; read `04_EMI_Models/Phase2C_Supply_and_Load.md` from the project root for the physical scope. Current results are under `results/development/v03`; older top-level results remain frozen history.
