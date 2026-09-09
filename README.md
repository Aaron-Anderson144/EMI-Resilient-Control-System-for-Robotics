# EMI-Resilient Control System for Robotics

MATLAB and Simulink models for robotic actuator control, electromagnetic-interference characterization, and fault-injection studies.

All MATLAB entry points, functions, models, parameters, scripts, tests, results, and Simulink cache files are consolidated in [`03_MATLAB`](03_MATLAB/). See the [MATLAB workspace guide](03_MATLAB/README.md) for the baseline, Phase 2A/2B, and sensitivity workflows.

## Run the MATLAB workspace

Set MATLAB's current folder to `03_MATLAB`, then run:

```matlab
startup_project
main
```

Run its automated tests with:

```matlab
testResults = runtests("tests");
assertSuccess(testResults)
```

## Project folders

| Folder | Contents |
|---|---|
| [00_Project_Management](00_Project_Management/) | Charter, roadmap, and decisions |
| [01_Research](01_Research/) | Research plan and log |
| [02_Requirements](02_Requirements/) | Requirements, failure analysis, and test plan |
| [03_MATLAB](03_MATLAB/) | MATLAB/Simulink code, models, tests, and simulation results |
| [04_EMI_Models](04_EMI_Models/) | EMI model definitions and assumptions |
| [05_Control_Algorithms](05_Control_Algorithms/) | Control strategy |
| [06_Circuit_Simulations](06_Circuit_Simulations/) | Circuit-simulation planning |
| [07_Data](07_Data/) | Data conventions and dictionary |
| [08_Results](08_Results/) | Result organization |
| [09_Report](09_Report/) | Report outline |
| [10_Hardware_Design](10_Hardware_Design/) | Hardware planning |

Simulation results use the documented model assumptions. They are not physical hardware-validation results.
