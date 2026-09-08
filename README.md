# EMI-Resilient Control System for Robotics

Portable starter workspace for a research project on electromagnetic-interference characterization and fault-tolerant control of robotic actuators.

## Current Status

- Phase 0 workspace and research documents: prepared
- Phase 1 baseline actuator model: executed and verified on 2026-09-08
- Simulink model: generated and successfully simulated on 2026-09-08
- Phase 2A encoder fault injection: implemented and cross-validated
- Communication, supply, and physically derived coupling faults: remaining Phase 2 work
- Resilient-control implementation: planned for Phase 3
- Hardware validation: future work

All 12 automated Phase 1 and Phase 2A tests pass. The Phase 2 MATLAB and Simulink implementations agree within a `1e-9` rad validation tolerance for all scenarios. Models, metrics, datasets, and validation summaries are recorded under `03_MATLAB/models` and `03_MATLAB/results`.

The numerical parameters in this package are representative starting values, not measurements from a selected motor. Results must not be presented as experimental findings until the model is parameterized and validated.

## Workspace Map

| Folder | Purpose |
|---|---|
| `00_Project_Management` | Charter, roadmap, decisions, risks, and milestones |
| `01_Research` | Literature-review plan and research log |
| `02_Requirements` | System requirements, FMEA, and simulation test plan |
| `03_MATLAB` | MATLAB and Simulink source files for the digital twin |
| `04_EMI_Models` | Electromagnetic coupling models and assumptions |
| `05_Control_Algorithms` | Baseline and resilient-control design notes |
| `06_Circuit_Simulations` | Future LTspice or equivalent circuit models |
| `07_Data` | Raw, synthetic, and processed datasets |
| `08_Results` | Approved figures, tables, and result summaries |
| `09_Report` | Research-report structure and drafts |
| `10_Hardware_Design` | Future testbed architecture and hardware planning |

## Initial Virtual Platform

- Nominal 24 V robotic actuator
- BLDC or servo motor represented initially by a three-state DC-equivalent model
- Position feedback from an incremental encoder
- Discrete position controller with a 1 ms initial sample time
- CAN-like communication behavior introduced in a later phase
- PWM motor drive treated as the main anticipated EMI source

## MATLAB Quick Start

1. Copy this entire folder to the desired project location.
2. Open MATLAB using a license appropriate for the intended use.
3. Set the MATLAB current folder to `03_MATLAB`.
4. Run `startup_project`.
5. Run `main` to execute the analytical baseline simulation.
6. Run `build_baseline_model` to create `models/EMI_Resilient_Actuator_Baseline.slx`.
7. Run the tests with `runtests("tests")`.

## Required MathWorks Products

- MATLAB
- Simulink
- Control System Toolbox

Simscape and Simscape Electrical will be used when the baseline model advances to a switching inverter, motor-drive, and parasitic-network representation.

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
