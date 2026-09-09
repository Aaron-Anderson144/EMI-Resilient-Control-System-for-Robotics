# Generated Models

Run `build_baseline_model` from the initialized MATLAB workspace to create:

```text
EMI_Resilient_Actuator_Baseline.slx
```

The generated model contains the clean position-control loop, voltage limit, discrete actuator plant, result logging, and a unity-gain placeholder for the Phase 2 EMI subsystem.

Run `build_phase2_model` to create:

```text
EMI_Resilient_Actuator_Phase2.slx
```

The Phase 2 model adds workspace-configurable additive encoder faults and a dropout path that holds the last accepted measurement. Run `configure_phase2_simulink_fault` before simulation to choose a scenario.

Run `build_phase2b_model` to create:

```text
EMI_Resilient_Actuator_Phase2B.slx
```

The Phase 2B model adds a workspace-driven receiver-equivalent angular disturbance, timestamp-derived accepted-delay signal, accepted-sample update logic, hold-last reception, and diagnostic logging around the same discrete controller and actuator plant. Use `configure_phase2b_simulink_scenario` for an interactive run. Batch smoke and cross-validation runs use `create_phase2b_simulation_input` so each case owns its parameter and signal workspace and cannot inherit a stale scenario.

The generated model was exercised on 2026-09-08 for `none`, three isolated coupling cases, combined coupling, ground offset, fixed delay, jitter, packet loss, and the combined Phase 2B case. All ten runs completed with 1501 finite samples. MATLAB/Simulink continuous differences were below `1e-9`, with largest observed difference approximately `2.2751e-12`, and discrete profiles matched exactly.

This agreement verifies the generated block-diagram implementation against the MATLAB reference implementation. It does not establish physical accuracy of the assumed coupling or receiver parameters. The model runs at the 1 kHz controller rate and does not resolve the assumed 20 kHz PWM waveform or its 100–200 ns edges.
