# Evidence catalogue

This catalogue connects the September 2026 progress report to the records behind its conclusions. Start with the [illustrated report](EMI_Robotics_Progress_Report.pdf) or the [current checkpoint](../../00_Project_Management/Causal_Receiver_Checkpoint.md). Use the [publication reproduction guide](Publication_Reproduction.md) for software, input restoration and the limits of the public bundle.

The current result is a verified causal simulation with a rejected development gate. Numerical agreement, usable receiver behavior and physical validation are separate questions. The planned combined-mitigation evaluation has not been opened.

## Current checkpoint

| Question | Recorded result | Evidence to inspect |
|---|---|---|
| Does the current project test suite pass? | 468 tests passed; zero failed or incomplete. | [Complete test table](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/all_project_tests.csv) and [regression summary](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/regression_summary.json) |
| Was the original controller preserved? | 116 records match exactly across all 31 channels, plant states and recorded reasons. This applies when the optional external measurement boundary is unused. | [Legacy identity record](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/legacy_equivalence.json) |
| Does the receiver engine agree with the native circuit reference? | 24 final numerical comparisons pass across eight event fixtures and three maximum steps. Largest node-voltage error is 0.0802 mV; largest threshold-event time difference is 0.0020 ns. Discrete sequences and virtual counts match exactly. | [Native comparison table](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/native_final_acceptance.csv) and [numerical summary](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/native_numerical_summary.json) |
| Do smaller native steps change the conclusion? | All 16 successive refinement checks pass. Six initial node-voltage failures were rerun with tighter tolerances; 30 executions produced the final 24-comparison set. | [Refinement table](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/native_final_refinements.csv) and [checkpoint account of retained reruns](../../00_Project_Management/Causal_Receiver_Checkpoint.md) |
| Are those native records all within the receiver model's domain? | No. Twelve of 24 records exceed the assumed 7 V absolute common-mode domain. Numerical agreement passes while strict receiver usability fails. | [Strict native usability decision](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/native_usable_acceptance.json) |
| What development work was completed? | 16 records: two fixtures, four arms and an exposed/clean companion for each. They form eight paired comparisons. | [Record index](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/record_index.csv) and [development summary](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/development_summary.json) |
| Does normal operation remain acceptable? | All eight clean companions pass the declared tracking, command, packet, sequence, delay and count guards. | [Paired metrics](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/metrics.csv) and [domain and clean decoder checks](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/domain_and_clean_decoder_summary.csv) |
| Do the exported records support the scores? | Independent Python reconstruction passes 352 checks: 280 record checks and 72 paired-metric checks. | [Independent audit record](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/independent_audit.json) and [audit implementation](../../06_Circuit_Simulations/FOUR_WAY/scripts/audit_exported_records.py) |
| Can evaluation begin at this checkpoint? | No. The rejection is preserved. The four-way campaign has 16 development records, zero evaluation records and zero production closure-diagnostic records. | [Rejected acceptance manifest](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/rejected_acceptance.json) and [acceptance-gate verification](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/final_gate_verification.json) |

The CSV clean-sequence and clean-delay fields apply to clean companions. Their placeholder values in exposed rows must not be interpreted as additional failed exposed tests. In the development summary, the combined execution/clean gate is false because exposed records exceed the receiver domain, even though all eight clean companions pass.

## The development finding

The [domain table](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/domain_and_clean_decoder_summary.csv) supplies the values in the report's receiver-domain figure. The [paired metrics](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/metrics.csv) supply the associated count and actuator outcomes.

| Fixture | Coupling Ccp / Ccn | Peak common mode with 100 pF | Peak common mode with 1000 pF | Interpretation |
|---|---|---:|---:|---|
| DEV01 | 10 / 9 pF | 3.347500502 V | 3.347507762 V | All four exposed arms pass. There is no persistent EMI count error or paired actuator disturbance to mitigate. |
| DEV02 | 200 / 5 pF | 7.557484631 V | 8.037571426 V | All four exposed arms leave the assumed 7 V domain. Their subsequent fallback trajectories are rejected diagnostics. |

The software counterparts share these electrical peaks. DEV02 first leaves the domain at approximately 0.250002044 s; the first flagged packet is at 0.251 s. The contract holds channel A only to finish recording. No domain flag reaches the controller. Later count errors, stops or tracking differences cannot establish physical receiver behavior or a mitigation benefit.

The 7 V boundary is a declared model assumption, not a measured damage threshold, a component selection or an EMC qualification. Additional saved detail includes [burst recovery](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/recovery.csv), [corruption attribution](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/burst_attribution.csv) and [detection episodes](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/detection_episodes.csv). DEV02 performance fields retain the same rejected status in every table.

## Design and source identity

The [research charter](../../00_Project_Management/Research_Charter.md) defines the overall question and seven objectives. The [frozen experiment](../../04_EMI_Models/Four_Way_EMI_Experiment.md) defines the current four arms, motion task, exposure construction, fixtures and acceptance rules. The [causal implementation](../../04_EMI_Models/Four_Way_Causal_Implementation.md) explains event handling and the strict measurement boundary.

The experiment uses an external one-way replay of a saved switching-cell simulation. It includes the original source knots, a declared synthetic return and DC hold. Its source is not generated by the actuator's own control command. Channel B remains ideal, and the current causal aggressor path is capacitive. These boundaries are part of the design, not omissions to infer away from the diagrams.

The [public source manifest](Publication_Source_Manifest.json) identifies the publication source and its numerical checkpoint. The unchanged [local dependency manifest](../../00_Project_Management/Local_Dependencies.json) pins inputs and runtimes. The [reproduction guide](Publication_Reproduction.md) explains the six project-generated input files provided for restoration and which historical traces or tools are outside the compact package.

## Earlier studies in their own context

Each historical study used its own fixtures and acceptance rules. Historical controller-tuning and motion studies included evaluation stages; those stages are separate from the unopened evaluation of the current four-way experiment. Historical test-suite sizes and campaign counts overlap and should not be summed into a count of unique tests or experiments.

| Study | What it supports | Original report and compact supporting record |
|---|---|---|
| Parameter and supply integration | Development checks for parameter overrides, nonzero load, motor-bus sag and supply interruption. These remain distinct from physical controller brownout or a hardware reset. | [Version 0.3 development validation](../../03_MATLAB/results/development/v03/Development_Validation_Summary.md) |
| Reduced-order sensitivity | 26 controls, 1,886 study simulations and 512 stratified parameter sets in two contexts. These explore assumed ranges and a voltage-to-angle mapping; they are not measured error probabilities or guaranteed worst cases. | [Sensitivity summary](../../03_MATLAB/results/development/phase2_completion/sensitivity/Phase2B_Sensitivity_Summary.md) |
| Fault and packet evidence | Independently declared packet schedules, encoder spectrum and trajectory-recovery checks for the implemented Phase 2 mechanisms. | [Phase 2 completion report](../../03_MATLAB/results/development/phase2_completion/Phase2_Completion_Report.md) |
| Observer and supervised control | Detection, degraded operation and recovery in declared simulated fixtures, including retained misses and loaded-stop limitations. | [Phase 3 implementation report](../../03_MATLAB/results/development/phase3/Phase3_Implementation_Report.md) |
| Controller tuning | G100_F020 improved mean normalized tracking by 29.37% on 12 diagnostic evaluation fixtures, but passed all comparative gates in only four. It was not promoted. | [Tuning report](../../03_MATLAB/results/development/phase3_tuning_20260910_141100/Phase3_Controller_Tuning_Report.md), [decision](../../03_MATLAB/results/development/phase3_tuning_20260910_141100/decision.json) and [evaluation metrics](../../03_MATLAB/results/development/phase3_tuning_20260910_141100/campaign/evaluation_metrics.csv) |
| Motion shaping | In the preserved clean reversal, 41 alarm samples become zero. In its noisy case, original-request-window RMSE rises from 47.591849 to 50.765953 degrees, approximately 6.67%. These are samples and a specific tracking tradeoff, not a measured false-alarm rate. | [Motion report](../../03_MATLAB/results/development/phase3_motion_20260910_144242/Phase3_Motion_Envelope_Report.md) and [motion metrics](../../03_MATLAB/results/development/phase3_motion_20260910_144242/motion_metrics.csv) |
| Separate passive brake study | In the recorded loaded-stop fixture, an assumed 0.030 Nm brake reduces backtravel magnitude from 92.797 to 1.692 degrees. It does not establish an allowable stop distance or integrated loaded release/restart. | [Stop and hold report](../../03_MATLAB/results/development/phase3_stop_hold_20260910_150537/Phase3_Stop_Hold_Report.md) and [metrics](../../03_MATLAB/results/development/phase3_stop_hold_20260910_150537/stop_hold_metrics.csv) |

Earlier circuit work is described by the [SC01A circuit and verification notes](../../06_Circuit_Simulations/SC01A/Circuit_Physics_and_Verification.md) and the [SC01B_R2 switching-source overview](../../06_Circuit_Simulations/SC01B_R2/README.md). The [device-source record](../../06_Circuit_Simulations/SC01B_R2/Device_Source_and_Assumptions.md) distinguishes inherited vendor equations, datasheet references and new driver assumptions. Circuit agreement is not hardware correlation.

Historical reports remain records of their own dates and test counts. Some of their detailed trace links refer to a larger campaign archive; the public reproduction guide defines what is supplied in this publication.

## Background reading

These four primary sources were checked at their publishers on 11 September 2026. They explain concepts and verification practices used by the project. They are a focused reading list, not an exhaustive literature review, a novelty claim or a determination of current standards applicability.

1. **Texas Instruments, RS-422 and RS-485 Standards Overview and System Configurations**, SLLA070D, June 2002, revised May 2010. Receiver differential sensitivity and common-mode operation are separate conditions; the report also discusses cable termination and propagation. This supports explaining the two voltage quantities. It does not validate the project's assumed Schmitt thresholds or select a physical receiver. [Publisher application report](https://www.ti.com/lit/an/slla070d/slla070d.pdf)

2. **Walt Kester, Grounding and Decoupling Part 1 Grounding**, Analog Devices, March 2017. A real return path has resistance and inductance, so signal or external current can create an error between reference points. This supports the shared-return concept without validating the project's numerical impedance or prescribing a universal layout. [Publisher article](https://www.analog.com/en/resources/analog-dialogue/studentzone/studentzone-march-2017.html)

3. **MathWorks, Making Optimal Solver Choices for Physical Simulation**. Variable-step results provide a baseline against which other numerical choices can be checked; step size and tolerance matter around rapid changes. This supports preserved solver settings and refinements. It does not replace physical validation. [Publisher documentation](https://www.mathworks.com/help/simscape/ug/making-optimal-solver-choices-for-physical-simulation.html)

4. **Tektronix, Probing Techniques for Accurate Voltage Measurements on Power Supplies with Oscilloscopes**. Probe loading, bandwidth, connection inductance and common-mode rejection can affect a fast-edge measurement. This informs future bench methods. No project waveform has yet been validated by a calibrated physical measurement. [Publisher application note](https://www.tek.com/en/documents/application-note/probing-techniques-accurate-voltage-measurements-power-converters-oscillos)

## What remains open

The central combined-mitigation hypothesis, selected receiver behavior, measured source/cable parameters, integrated loaded stop/restart and physical validation remain open. The next experiment needs a justified receiver/topology domain and a new versioned development/evaluation plan. The current rejected records stay attached to PLAN-V1. See the [roadmap](../../00_Project_Management/Roadmap.md) and [evidence status](../../02_Requirements/Research_Evidence_Status.md) for the broader scope.
