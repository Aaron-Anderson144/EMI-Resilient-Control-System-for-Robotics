# EMI-Resilient Control System for Robotics

MATLAB/Simulink workspace for electromagnetic-interference characterization and fault-tolerant control of robotic actuators.

## Current Status

- Phase 0 workspace and research documents: prepared
- Phase 1 baseline actuator model: executed and verified on 2026-09-08
- Simulink model: generated and successfully simulated on 2026-09-08
- Phase 2A encoder fault injection: implemented and cross-validated
- Phase 2B reduced-order coupling, ground-offset, and communication implementation: software-verified on 2026-09-08
- Phase 2B parameter sensitivity: completed on 2026-09-09; 26 controls, 1,886 study simulations, 512 combined-parameter sets in two contexts, and 11 selected Simulink comparisons
- SC-01A finite-edge native Simscape circuit: completed and numerically verified on 2026-09-09; 16 cases, 51 native simulations, three step sizes and tighter-tolerance checks
- SC-01B device-parameterized half-bridge: implementation and 29-attempt campaign complete (27 completed, 2 strict-tolerance attempts rejected); 84 tests pass, but gate-event failures and solver limits leave full numerical/source acceptance open
- Supply-interruption faults, measured source identification and receiver/decoder integration: remaining Phase 2/Phase 4 work
- Resilient-control implementation: planned for Phase 3
- Hardware validation: future work

All 84 automated tests pass: 45 control/sensitivity tests, 22 SC-01A circuit/threshold checks and 17 SC-01B energy, event and comparison checks. The Phase 2A MATLAB and Simulink implementations agree within a `1e-9` rad validation tolerance for all scenarios. All ten original Phase 2B Simulink scenarios completed with 1501 finite samples, exact discrete-profile agreement, and a largest continuous-signal MATLAB/Simulink difference of approximately `2.2751e-12`. The configured `p=0.20` packet-loss study observed 15,934 drops in 80,000 opportunities (`0.199175`) with a Wilson 95% interval of `[0.19642, 0.20196]`; the `p=0` and `p=1` edge cases were exact.

The sensitivity study found the largest one-at-a-time position changes from ground offset, the assumed voltage-to-angle mapping, ground conversion, and envelope frequency within its declared ranges. The largest sampled active position delta was 13.56 degrees with the fixed communication faults. These exploratory results are not hardware limits or failure probabilities. See `03_MATLAB/results/sensitivity/Phase2B_Sensitivity_Summary.md` and `04_EMI_Models/Phase2B_Sensitivity_Method.md`.

These results verify software behavior against the stated reduced-order equations and an independent Simulink realization. They do not physically validate the assumed coupling, receiver, cable, encoder, or communication parameters. Parameter identification and measurement-based comparison remain necessary for hardware validation.

The numerical parameters in this package are representative starting values, not measurements from a selected motor, cable, receiver, or installation. Results must not be presented as experimental findings until the model is parameterized and validated.

## Workspace Map

| Folder | Purpose |
|---|---|
| `00_Project_Management` | Charter, roadmap, decisions, risks, and milestones |
| `01_Research` | Literature-review plan and research log |
| `02_Requirements` | System requirements, FMEA, and simulation test plan |
| `03_MATLAB` | MATLAB and Simulink source files for the digital twin |
| `04_EMI_Models` | Electromagnetic coupling models and assumptions |
| `05_Control_Algorithms` | Baseline and resilient-control design notes |
| `06_Circuit_Simulations` | Native Simscape finite-edge circuit, independent reference, tests and transient results |
| `07_Data` | Raw, synthetic, and processed datasets |
| `08_Results` | Approved figures, tables, and result summaries |
| `09_Report` | Research-report structure and drafts |
| `10_Hardware_Design` | Future testbed architecture and hardware planning |

## Initial Virtual Platform

- Nominal 24 V robotic actuator
- BLDC or servo motor represented initially by a three-state DC-equivalent model
- Position feedback from an incremental encoder
- Discrete position controller with a 1 ms initial sample time
- Protocol-agnostic timestamped sensor channel; protocol-specific CAN behavior remains future work
- PWM motor drive treated as the main anticipated EMI source

The controller-rate model runs at 1 kHz and therefore cannot resolve the individual edges of the assumed 20 kHz PWM source. Phase 2B uses analytically derived edge peaks and a 120 Hz receiver-equivalent baseband envelope for system sensitivity studies. Its volts-to-radians mapping is phenomenological, not a physical encoder-decoder law.

## MATLAB Quick Start

1. Copy this entire folder to the desired project location.
2. Open MATLAB using a license appropriate for the intended use.
3. Set the MATLAB current folder to `03_MATLAB`.
4. Run `startup_project`.
5. Run `main` to execute the analytical baseline simulation.
6. Run `build_baseline_model` to create `models/EMI_Resilient_Actuator_Baseline.slx`.
7. Run the tests with `runtests("tests")`.
8. Run `phase2b_main` to generate the Phase 2B analytical study, packet-loss statistical study, Simulink model, smoke-test table, and MATLAB/Simulink comparison after reviewing the assumed parameters.
9. Run `phase2b_sensitivity_main` to reproduce the sensitivity tests, 1,886-run study, figures, selected Simulink checks, and generated summary in `results/sensitivity`.

Phase 2B definitions, equations, scenario semantics, and limitations are recorded in `04_EMI_Models/Phase2B_Coupling_and_Communication_Faults.md`.

## Required MathWorks Products

- MATLAB
- Simulink
- Control System Toolbox

Simscape is required for SC-01A. SC-01B also requires Simscape Electrical and the IAUC100N04S6L014 vendor model shipped in the tested MATLAB R2026a installation. A portable ngspice 41 runtime is included for the independent original-equation comparison; it does not change any installed application.

## Optional Products for Later Phases

- Stateflow
- Motor Control Blockset
- Simulink Test
- Simulink Fault Analyzer
- Embedded Coder

## Model Fidelity Rules

1. Every parameter must have a source, measured value, or explicit assumption label.
2. Every result must identify the model fidelity level used.
3. Averaged models are for controller design; switching models are for conducted-noise studies.
4. Circuit and system simulations do not replace radiated-emissions or immunity testing.
5. Simulation conclusions must be checked against hardware before being treated as validated engineering guidance.

## Licensing Note

Use the package only with software licenses that permit the intended personal, academic, research, government, or commercial activity. License suitability is the user's responsibility.

## Native Circuit Quick Start

Set the MATLAB current folder to `06_Circuit_Simulations/SC01A` and run `sc01a_main`. This reproduces the 67-test regression suite and the 51-run circuit campaign, including exact-reference comparisons, solver refinement, threshold-event analysis and PWM settling. The saved `models/EMI_SC01A_Finite_Edge.slx` also runs directly with embedded nominal inputs.

The nominal combined rising edge produces approximately 51.7 mV peak differential disturbance; a deliberately exaggerated 300/5 pF imbalance case crosses the illustrative receiver band. These are circuit calculations with assumed bench inputs, not measured immunity limits or decoded encoder failures. See `06_Circuit_Simulations/SC01A/results/SC01A_Validation_Summary.md` for the evidence and `06_Circuit_Simulations/SC01A/Circuit_Physics_and_Verification.md` for the equations and sources.

For the selected-device source, set the current folder to `06_Circuit_Simulations/SC01B`, run `sc01b_startup`, then `study=sc01b_main`. The frozen five-case study compares three native integration steps, two SPICE steps and representative tolerance refinements, with terminal-energy and external energy-balance checks. See `SC01B/results/verification/SC01B_Validation_Summary.md` for exact results and failed gates. The saved `SC01B/models/EMI_SC01B_Device_Halfbridge.slx` includes runnable nominal defaults. This is isothermal numerical source verification, not physical validation or decoded encoder-error prediction.
