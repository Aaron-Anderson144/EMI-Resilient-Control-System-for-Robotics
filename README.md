# EMI Resilient Control System for Robotics

**Can electrical design and fault-tolerant control work together to make robotic actuators more resistant to electromagnetic interference?**

The goal is to understand how electrical interference affects a robotic actuator and how the controller should respond. The project uses MATLAB/Simulink to connect the motor, interference models and fault-tolerant controller. It follows a switching waveform through the receiver circuit and encoder count to the motor's motion.

The causal V2 receiver/control integration and full frozen experiment are complete: 256 development records, 1,536 reserved evaluation records, and 256 separate source-return diagnostics. Electrical filtering removed the small observed sampled-count errors. The combined treatment did not meet the predefined task-benefit criterion under any of the 16 receiver hypotheses; every baseline task already passed. These are conditional numerical results; physical receiver behavior remains unmeasured.

## Open the Workbench on Windows

1. [Download the Windows app](https://github.com/Aaron-Anderson144/EMI-Resilient-Control-System-for-Robotics/releases/latest) and extract the entire portable ZIP.
2. Double-click **Open EMI Workbench.lnk** in the extracted folder.

**The Windows shortcut is the main way to launch Signal Lab.** Keep it beside the other extracted files when moving the app. It opens a local desktop window with experiment workflows, native run history, logs, and results. Python and the browser runtime are included; viewing saved results needs no account or internet connection. New simulations and tests require separately installed, licensed MATLAB.

For source development, clone or download and extract this repository, then double-click [Open EMI Workbench.lnk](Open%20EMI%20Workbench.lnk) in the project root. The source launcher requires Python 3.10 or newer and opens the browser interface. Download the whole project, rather than only the shortcut. See the [Workbench guide](12_Workbench/README.md) and [desktop packaging guide](12_Workbench/desktop/README.md).

## Integrated PLAN-V2 results — 15 September 2026

The causal V2 receiver/control integration and full frozen experiment are complete: 256 development records, 1,536 reserved evaluation records, and 256 separate source-return diagnostics. Electrical filtering removed the small observed sampled-count errors. The combined treatment did not meet the predefined task-benefit criterion under any of the 16 receiver hypotheses; every baseline task already passed. These are conditional numerical results; physical receiver behavior remains unmeasured.

The implementation passed 155 MATLAB checks and 14 independent audit/acceptance tests. Native circuit acceptance passed 24 runs, 384 receiver comparisons and 256 refinements. A separate implementation/evidence freeze was accepted before evaluation, and all saved experiment records were independently reconstructed and scored. Signal Lab 1.5 adds receiver characterization, development, evaluation, and source-return controls with separate result tables for every receiver assumption. Imported-evidence cards and imported history entries have been removed. Evaluation and source-return controls require a configured, verified local acceptance setup; the public download leaves them disabled until that setup is supplied.

See the [results and interpretation](00_Project_Management/Verification/Four_Way_V2_2026-09-15/Results.md), [compact evidence](00_Project_Management/Verification/Four_Way_V2_2026-09-15/README.md), and [causal V2 implementation](06_Circuit_Simulations/FOUR_WAY_V2/README.md). The frozen protocol retains its original preparation status; the separate acceptance and completed-result checkpoint record subsequent execution. The historical PLAN-V1 result remains unchanged. See the [public reproduction scope](00_Project_Management/Verification/Four_Way_V2_2026-09-15/PUBLIC_REPRODUCTION.md) for the full archives needed to regenerate the reports and audits.

## Receiver characterization and protocol preparation - 15 September 2026

Signal Lab now includes **Receiver v2 characterization**. It runs a declared THVD1450DR model and loaded circuit across 40 electrical records / 640 behavioral cases, with continuous signed pin/differential-domain checks, threshold and timing sensitivity, transport/inertial pulse hypotheses, saved plots, detail records and source identities. The completed characterization has 640 numerically converged in-domain cases, no clean or final-count errors, and 80 cases with pulse-law-dependent edge behavior. This is a conditional electrical result, not hardware validation or a motor-control benefit.

The [receiver/circuit contract](04_EMI_Models/Receiver_V2_Contract.md) and [PLAN-V2](04_EMI_Models/Four_Way_EMI_Experiment_V2.md) define the completed four-way experiment. PLAN-V2 preserves all sixteen receiver variants and the development/evaluation combinations reserved before execution. Its protocol was finalized before the causal implementation, numerical/development acceptance and separately frozen evaluation reported above. The historical rejected PLAN-V1 remains unchanged. [Characterization evidence](00_Project_Management/Verification/Receiver_V2_2026-09-15/README.md).

## Historical verification — 12 September 2026

Fresh checks passed **468/468 robotics tests** and **32/32 hybrid-estimation checks**. All **16 frozen PLAN-V1 files** match their recorded hashes after the authoritative plan was restored exactly. These are separate verification scopes. They do not change PLAN-V1's rejected development result, open evaluation or formal Draft approvals.

The [EDMD hybrid study](11_EDMD_Hybrid_Estimation/README.md) supports this finding so far: **a learned correction can improve forecasts when the motor behaves differently from the physics model**. In the original three simulated mismatch conditions, learned correction reduced 50 ms position-forecast error by about **66–80% compared with nominal physics alone**. Physics alone was most accurate when its model already matched the motor. Multistep forecasts were supplied with recorded future voltages; this does not demonstrate improved closed-loop control or EMI resilience. The learned correction remains separate from motor control and protection.

The September 12 review identified [receiver and circuit-topology characterization](00_Project_Management/Reviews/2026-09-12/Receiver_Revision_Brief.md) as the next milestone; the new checkpoint above records its conditional electrical implementation. The [original frozen plan](04_EMI_Models/Four_Way_EMI_Experiment.md) controls the checks; the [readable companion](04_EMI_Models/Four_Way_EMI_Experiment_Readable.md) explains that historical design and does not replace its frozen bytes.

[Illustrated progress report (PDF)](09_Report/Publication_2026-09-11/EMI_Robotics_Progress_Report.pdf) · [Editable report (Word)](09_Report/Publication_2026-09-11/EMI_Robotics_Progress_Report.docx) · [Public project update](09_Report/Publication_2026-09-11/Public_Update.md) · [Reproduction guide](09_Report/Publication_2026-09-11/Publication_Reproduction.md)

## How the project works

![Causal actuator and interference architecture](09_Report/Publication_2026-09-11/assets/system_architecture.png)

The controller holds each voltage command for 1 ms. Motor motion determines when the encoder should change state. The circuit and receiver determine which changes get through, and the quadrature decoder keeps a running count for the next control decision. The controller gets the measured position, a source index and a receipt flag. True position and interference labels are kept out of its inputs.

The interference comes from a recorded switching waveform that has passed numerical checks. It is replayed into the receiver, with a defined synthetic return between pulses. This version models the loaded A-channel circuit and assumes ideal B-channel timing. Coupling back to the actuator's driven winding and a complete physical encoder installation still need to be modeled. See the [implementation and scope](04_EMI_Models/Four_Way_Causal_Implementation.md).

## Historical PLAN-V1 checkpoint — September 2026

| Verified evidence | Result and meaning |
|---|---|
| Full project regression suite | **468/468 tests pass**, with zero failures or incomplete tests |
| Original controller behavior | **116/116 records remain exact**, including all 31 channels, plant states and reasons |
| Native circuit numerical comparisons | **24/24 comparisons and 16/16 refinements pass**; largest node-voltage error is 0.0802 mV against a 0.1 mV allowance |
| Development experiment | **16 records / 8 matched clean-exposed pairs**; all eight clean companions pass |
| Independent record audit | **352/352 reconstruction and scoring checks pass** |
| Evaluation | **Unopened**: receiver-domain acceptance is rejected; combined benefit is not demonstrated |

These counts cover different checks, so they should not be added together. Six native cases needed tighter-tolerance reruns after their first attempts failed: 30 executions produced 24 final comparisons. Agreement between numerical models still needs to be checked against a physical circuit and a usable receiver.

The two development exposures show where the current model reaches its limit:

![Development exposures and the assumed receiver domain](00_Project_Management/Verification/Causal_Receiver_2026-09-11/receiver_domain_checkpoint.png)

- **Lower exposure (DEV01, coupling 10/9 pF):** all four arms pass, with no persistent EMI count error or paired actuator disturbance. Peak common mode is about 3.348 V.
- **Higher exposure (DEV02, coupling 200/5 pF):** all four exposed arms exceed the assumed 7 V common-mode domain. Peaks are 7.557 V with 100 pF differential capacitance and 8.038 V with 1,000 pF. These records are rejected for interpreting control effects.

The model assumes a 7 V operating boundary. That value has not been measured as a damage or immunity limit. Once it is crossed, the simulation holds A so diagnostic recording can finish. Any later count errors, tracking differences or stop commands fall outside the supported receiver model and cannot show whether mitigation worked.

Read the [checkpoint](00_Project_Management/Causal_Receiver_Checkpoint.md), [compact verification evidence](00_Project_Management/Verification/Causal_Receiver_2026-09-11), and [requirement evidence status](02_Requirements/Research_Evidence_Status.md) for the supporting records and limits.

## Historical PLAN-V1 comparison

The first plan is frozen. It compared four combinations of electrical and software treatment, each with its own clean run:

| Arm | Differential capacitance | Control policy |
|---|---:|---|
| BASELINE | 100 pF | Original baseline policy |
| EM_ONLY | 1,000 pF | Original baseline policy |
| SW_ONLY | 100 pF | Phase 3 protected policy |
| COMBINED | 1,000 pF | Phase 3 protected policy |

The larger capacitance is the electrical change being tested; its benefit has not been established. Tracking, current, command effort, count corruption, false alarms and recovery all matter when judging the result. The plan has 16 completed development records. Its 96 evaluation records and 16 separate closure diagnostics remain unopened. See [FOUR-WAY-EMI-PLAN-V1](04_EMI_Models/Four_Way_EMI_Experiment.md).

The receiver contract, causal PLAN-V2 implementation, acceptance checks, and completed comparison are documented above. The next research step is to measure the receiver's fast-pulse behavior and loaded circuit response, then constrain a new experiment with those measurements. PLAN-V1 and its rejected development result remain in the record.

## Work completed along the way

| Workstream | Contribution | Scope still open |
|---|---|---|
| Actuator and fault library | Reproducible representative actuator; encoder, communication and motor-bus fault models | Selected hardware and identified parameters |
| Reduced-order EMI models | Capacitive, inductive and shared-impedance studies; parameter sensitivity | Measured coupling and receiver transfer |
| Native electrical circuits | Finite-edge loaded network and revised switching-source verification | Physical circuit measurements and component selection |
| Fault-tolerant control | Observer, suspect/degraded/recovery/stop modes; explicit missed-fault and recovery cases | Wider model/load uncertainty and measured thresholds |
| Motion shaping | Rate-alarm samples in the preserved clean reversal reduced from 41 to zero, with a 6.67% original-request tracking RMSE cost | Calibrated operating envelope |
| Separate stop/hold study | Assumed mechanical-brake model and independent numerical audit | Integrated loaded brake handoff and physical stop/restart |
| Causal integration | Continuous circuit state, receiver events, persistent decoder and strict measurement boundary | Accepted four-arm evaluation and physical validation |

Historical campaign sizes and their original acceptance limits remain in the [research log](01_Research/Research_Log.md) and [report evidence map](09_Report/Report_Outline.md). A simulation stop command does not by itself establish safe physical holding.

## Run the project locally

For the integrated local interface, double-click **Open EMI Workbench.lnk** in the project root. The [research workbench](12_Workbench/README.md) brings together saved evidence, baseline and verification runs, live logs, and results. It uses the existing MATLAB workflows and their experiment settings. Signal Lab has seven workflows. The two acceptance-gated controls verify configured local scientific sources and evidence before starting; the other five use the local project snapshot. See the workbench guide for the acceptance configuration and required Python 3.12 launcher.

The **Signal Lab desktop edition** packages the interface, local service, compact project snapshot, and application runtimes into a portable Windows folder. Double-click **Open EMI Workbench.lnk** in the extracted release; new scientific workflows still require installed MATLAB. See the [desktop packaging guide](12_Workbench/desktop/README.md) for its contents and rebuild instructions.

For a first analytical baseline, install MATLAB and Control System Toolbox, open `03_MATLAB`, and run:

```matlab
startup_project
study = run_baseline;  % creates a fresh timestamped results folder
```

The complete checkpoint was tested with MATLAB R2026a Update 3, Simulink, Control System Toolbox, Simscape and Simscape Electrical. The causal receiver engine also requires a configured MATLAB-supported C++ compiler. Historical independent circuit comparisons use pinned local ngspice runtimes. The R2 vendor model is supplied by the tested MATLAB installation.

**Cloning the source code does not download the full experiment archive.** The regression fixtures, frozen switching waveform, historical records and runtimes are stored separately and checked by identity. Start with the [publication reproduction guide](09_Report/Publication_2026-09-11/Publication_Reproduction.md). It explains what is needed to read the evidence, run the baseline or repeat the full suite and research campaigns. The [unchanged dependency manifest](00_Project_Management/Local_Dependencies.json) and [local bootstrap instructions](00_Project_Management/Local_Reproduction.md) list the files to retain.

## Repository map

| Folder | Contents |
|---|---|
| `00_Project_Management` | Charter, roadmap, checkpoints, compact evidence and provenance |
| `01_Research` | Research log and literature-review plan |
| `02_Requirements` | Requirements, FMEA, test plan and evidence status |
| `03_MATLAB` | Actuator, fault and control implementation; tests and saved models |
| `04_EMI_Models` | Model assumptions, experiment contract and causal implementation |
| `05_Control_Algorithms` | Detection, supervision, recovery, motion and stop/hold designs |
| `06_Circuit_Simulations` | Native circuits, independent references and receiver engine |
| `07_Data` / `08_Results` | Data organization and results planning |
| `09_Report` | Progress publication and report assembly map |
| `10_Hardware_Design` | Future testbed planning |
| `11_EDMD_Hybrid_Estimation` | Separate physics-plus-learned-correction experiment, trained models, results and healthy-log replay |
| `12_Workbench` | Local research interface, workflow launcher, run records, and results viewer |

The numerical parameters are assumed values for a representative system. They have not been measured from a selected actuator, cable or receiver. Hardware immunity, universal fault detection, physical safety and compliance have not been demonstrated. Formal Draft requirement approvals remain unchanged.
