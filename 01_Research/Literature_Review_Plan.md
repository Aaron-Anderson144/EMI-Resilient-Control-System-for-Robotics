# Literature Review Plan

## Purpose

Build an evidence base for the physical coupling models, fault scenarios, mitigation choices, controller architecture, and validation methods.

## Research Streams

### 1. Motor-Drive EMI Sources

- PWM edge rates and harmonic content
- Common-mode voltage in inverter-fed motors
- Bearing and chassis currents
- DC-bus and supply conducted emissions
- Cable length and termination effects

### 2. Coupling Mechanisms

- Capacitive near-field coupling
- Inductive near-field coupling
- Common-impedance coupling
- Ground loops and return paths
- Differential-to-common-mode conversion

### 3. Susceptible Robotic Subsystems

- Incremental and absolute encoders
- Hall sensors, resolvers, and current sensors
- CAN and RS-485 physical layers
- Embedded-controller reset and brownout behavior
- Mixed-signal PCB interfaces

### 4. Electromagnetic Mitigation

- Cable twisting and separation
- Shield construction and termination
- Chassis bonding and grounding topology
- Common-mode chokes, ferrites, and filters
- Galvanic isolation and differential interfaces
- PCB stackup, placement, and return-current control

### 5. Fault-Tolerant Control

- State observers and innovation residuals
- Sensor validation and analytical redundancy
- Robust and adaptive control
- Fault detection, isolation, and accommodation
- Graceful degradation and safe-state design

### 6. Test Methods and Standards

Review the current applicability and revision of:

- IEC 61000 immunity and emissions methods
- CISPR equipment emissions guidance
- MIL-STD-461 equipment-level EMC requirements
- ISO 11452 component immunity methods
- CAN and RS-485 physical-layer application guidance

The project will use relevant methods as research guidance unless formal compliance work is separately authorized and properly equipped.

## Suggested Search Strings

- `PWM inverter common-mode EMI motor encoder`
- `robot servo electromagnetic interference position control`
- `encoder signal corruption variable frequency drive`
- `CAN bus conducted immunity motor drive`
- `fault tolerant control sensor dropout actuator`
- `state observer residual EMI detection`
- `motor cable shield termination common mode current`
- `shared impedance coupling embedded controller reset`

## Source Priority

1. Standards and government technical publications
2. Peer-reviewed journal and conference papers
3. University theses with accessible methods and data
4. Semiconductor and equipment-manufacturer application notes
5. Textbooks and established reference works

## Inclusion Criteria

- Identifiable physical system or test configuration
- Defined disturbance or coupling mechanism
- Quantitative result or reproducible method
- Applicable frequency, voltage, current, or communication regime
- Sufficient information to identify limitations

## Exclusion Criteria

- Marketing claims without test details
- Untraceable parameter values
- Results from unrelated physical scales without a valid similarity argument
- Sources that conflate correlation with a verified coupling mechanism

## Local-source evidence synthesis, 2026-09-10

Status: **partial literature review**. The table below replaces the blank register using content already recorded in local model/source documents. It reports what those notes support; this update did not retrieve, reread or verify the current revision of the external publications. It does not establish an exhaustive search, peer-reviewed novelty, comparative effectiveness or current standards applicability. External links and original provenance remain in the cited local records.

Use [Parameter Identification and the Next Switching Circuit Case](../04_EMI_Models/Parameter_Identification_and_Switching_Case.md) as local record **PI**, and [R2 Device Sources and Assumptions](../06_Circuit_Simulations/SC01B_R2/Device_Source_and_Assumptions.md) as **R2**. Both distinguish measured, datasheet and assumed values.

| Ref ID / source cited in local record | Local synthesis | Project use | Limit that prevents a broader claim |
|---|---|---|---|
| REF-001 — TI SLLA070D, RS-422/RS-485 overview (PI) | Differential sensitivity and common-mode operation are distinct; cable delay and termination matter. | Define total intended-plus-disturbance receiver voltage, common-mode domain and eventual cable fidelity. | Does not make 0.20 V of noise a universal count error or qualify a particular encoder/receiver. |
| REF-002 — Tektronix voltage-probing techniques (PI) | Loading, bandwidth, connection inductance and edge-time convention affect recorded transients. | Specify simultaneous source/return measurements, probe configuration and deskew. | No physical waveform/probe calibration is present in this project. |
| REF-003 — ADI Capacitive Coupling lab (PI) | Inter-wire capacitance measurement includes fixture-offset considerations. | Identify each aggressor-to-line capacitance and covariance of a small imbalance. | The present pF values remain assumptions; numerical sweeps are not measured uncertainty. |
| REF-004 — MathWorks Mutual Inductor documentation (PI) | Mutual terms must agree with self-inductances, coupling magnitude and polarity. | Require a consistent passive inductance matrix before reciprocal multi-loop modeling. | Behavioral M*dI/dt checks do not identify actual geometry or a physical mutual network. |
| REF-005 — ADI Grounding and Decoupling, Part 1 (PI) | Real return paths have both resistance and inductance. | Retain shared-current topology and separate common-mode movement from differential conversion. | Assumed R+sL and generic conversion factors do not validate a grounding/shield redesign. |
| REF-006 — TI DS34C86T illustrative receiver (PI) | Receiver sensitivity, hysteresis and common-mode range are device-dependent. | Define parameters that must be identified and distinguish delay from guaranteed pulse rejection. | The component is not selected; the new +/-0.20 V Schmitt behavior is explicitly assumed. |
| REF-007 — MathWorks semiconductor/cable model-fidelity guidance (PI) | Charge dynamics and propagation/reflection fidelity require more parameters than ideal switches/lumped paths. | Stage SC01A prescribed sources, R2 nonlinear source and later cable refinement. | Selecting a model family does not validate its physical parameters. |
| REF-008 — MathWorks physical-simulation solver guidance (PI) | Variable-step/reference and refinement evidence precede a speed-optimized implementation. | Preserve tolerances, warnings, complete traces, threshold timing and independent comparisons. | Solver agreement is numerical verification, not experimental validation. |
| REF-009 — Infineon IAUC100N04S6L014 datasheet rev1.0 and installed model (R2) | The local source record ties model equations to a named subcircuit, installation and hash; typical datasheet anchors have stated operating conditions. | Isothermal native-versus-original-vendor-equation verification. | Current source revision is not newly checked; 50-100 A headline conditions cannot be transferred silently to the roughly3 A fixture. No hardware component was selected. |
| REF-010 — TI UCC27211A SLUSBL4D timing reference (R2) | Typical propagation delays are used with a simplified ramp-onset convention. | Explain the inherited timing assumptions. | The3 ohm output approximation and bipolar R2 drive are not a complete or unchanged UCC27211A implementation. |
| REF-011 — TI SLUA618A, sections3.4-3.5 (R2) | Stronger discharge and negative turn-off voltage provide a qualitative remedy rationale. | Motivate the R2 behavioral-drive investigation. | Does not identify or guarantee the selected -1.5 V/3 ohm values, thermal behavior or physical driver. |
| REF-012 — Preserved local Phase3 observer/recovery/tuning/motion/stop studies | Fixed-model tests expose observability, clean-motion, current-cost and loaded-stop limitations while recording negative outcomes. | Supply reproducible project findings and research questions for a control-literature comparison. | These are project-generated numerical results, not external literature evidence or a novelty/robustness proof. |

## Synthesis and remaining research work

The local evidence supports separating switching source, coupling network, receiver voltage, decoded data and control response. It also exposes structural confounding in the earlier volts-to-radians bridge: one closed-loop amplitude cannot uniquely identify capacitance, edge slope, path factors and encoder sensitivity. The [frozen first four-way design](../04_EMI_Models/Four_Way_EMI_Experiment.md) therefore specifies an explicit, assumed causal receiver/decoder boundary and a single actual network intervention. Its result will remain conditional on those assumptions.

Prioritize the following literature work before claiming a research contribution or physical applicability:

1. Record accessible full texts and exact sections for encoder receiver/decoder immunity and short-pulse behavior, with physical topology and measurement conditions. Compare the proposed ideal-B/Schmitt simplification against those mechanisms.
2. Build a critical peer-reviewed comparison of observer residual gating, timestamp replay, analytical redundancy and recovery under sensor faults and model/load uncertainty. Identify how fault availability, independent references and false-alarm calibration differ from this project.
3. Compare filtering, cable/shield and grounding experiments with actual source/path/receiver measurements and uncertainty. Do not infer filter effectiveness from the R2 gate-drive remedy or assume a capacitor-only result generalizes to all electromagnetic mitigation.
4. Review the applicability and current revision of the standards listed above for the eventual selected apparatus, then identify calibrated bench procedures. The present list is a research queue, not a standards review or compliance evidence.
5. For each source, record retrieval date, full citation/revision, page/section, setup, independent variables, metrics, main claim, uncertainty, limitations and project decision. Keep assumed/fitted/measured provenance separate and retain negative or conflicting results.

This update closes the empty local evidence-table and stale-log maintenance issues. A07 remains partial; the literature review and source-identification gates remain open.
