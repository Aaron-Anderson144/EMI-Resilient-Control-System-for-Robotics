# Research Report Outline

The [September 2026 progress report](Publication_2026-09-11/EMI_Robotics_Progress_Report.pdf) presents the current simulation and integration milestone. An [editable Word version](Publication_2026-09-11/EMI_Robotics_Progress_Report.docx), [public project explanation](Publication_2026-09-11/Public_Update.md) and [reproduction guide](Publication_2026-09-11/Publication_Reproduction.md) accompany it. This outline remains the assembly plan for the broader research report.

The implemented causal bridge and its rejected development gate can now be reported together. The combined-mitigation hypothesis, hardware immunity, physical safety and broad engineering recommendations remain unproven. [Research Evidence Status](../02_Requirements/Research_Evidence_Status.md) controls the supported scope; the [local literature synthesis](../01_Research/Literature_Review_Plan.md) remains partial and does not establish novelty or current external-source applicability.

## 1 Abstract

Research question, implemented causal method, principal development finding and scope. State numerical verification and receiver-domain rejection directly. Do not present the planned combined benefit as an achieved result.

## 2 Introduction

- Robotic actuator EMI problem and motivation
- Need to connect electrical disturbance to decoded feedback and motion
- Research questions, hypothesis and intended contributions
- Present progress and evidence needed for the full research claim

## 3 Background

- Motor-drive interference sources and coupling mechanisms
- Feedback and communication susceptibility
- Fault detection, observability and supervised control
- Critical comparison with primary literature and applicable standards

## 4 System Definition

- Representative actuator, controller and timestamped measurement boundary
- External one-way source replay and synthetic closure
- Loaded A-channel circuit, ideal B timing and persistent quadrature decoder
- Offline shadow attribution and separation of scoring from control
- Assumed operating domain and physical validation boundary

## 5 Electromagnetic Models

- Reduced-order capacitive, inductive and shared-impedance studies
- Finite-edge network and independent numerical reference
- Original switching-source failure and revised driver verification
- Common-mode and differential-mode behavior
- Parameter provenance, sensitivity and receiver-domain limits

## 6 Control Design

- Baseline controller, observer and residual generation
- Normal, suspected, degraded, recovery and latched-stop behavior
- Optional motion shaping and independent-reference recovery
- Missed faults, rejected tuning and reference-integrity limits
- Separate stop/hold study and open integrated loaded brake handoff

## 7 Experimental Method

- Frozen configurations, fixtures, hashes and four-arm treatment definitions
- Same-arm clean pairing and original-request versus shaped-command scoring
- Native numerical agreement, refinement and independent reconstruction
- Development acceptance before evaluation
- Predeclared model-domain rejection and treatment of fallback diagnostics
- Future calibrated hardware method, uncertainty and held-out measurements

## 8 Results

- Clean baseline and verified fault-library behavior
- Reduced-order sensitivity and native circuit verification
- Control detection/recovery limits, tuning rejection and motion delay cost
- Separate assumed-brake numerical study
- Causal bridge verification and exact legacy-controller preservation
- Lower-exposure null result and higher-exposure domain rejection
- Explicit unopened evaluation and closure-production records

## 9 Discussion

- What numerical agreement establishes and what it leaves open
- Electrical filtering, common mode and control tradeoffs
- Receiver-domain failure as an experiment-design finding
- Model fidelity, observability and physical holding limitations
- Reproducibility limits and critical literature comparison
- Generalizability only where supported by evidence

## 10 Conclusions and Future Work

- Supported integration and numerical findings
- Justified receiver/topology decision and new reviewed experiment version
- Accepted development followed by four-arm evaluation
- Hardware identification, measurement and physical validation priorities
- Integrated loaded brake handoff and restart validation

## Appendices

- Parameters and assumption register
- Equations, circuit definitions and test fixtures
- Metric and event conventions
- Supplementary evidence and retained failures
- Software, dataset, runtime and figure provenance
- Reproduction commands and unavailable inputs

## Evidence assembly map for 2026-09-11

| Section | Material available locally | Material still required before a broad claim |
|---|---|---|
| Abstract / introduction | Charter question, original objectives, implemented causal bridge and explicit rejected development outcome. | Accepted four-way benefit evaluation and critical comparison with published work. |
| Background | Local source/model notes, source manifest and literature evidence table. | Full-text synthesis, conflicting results, standards applicability and exact revision/section records. |
| System definition | Representative actuator, historical controller, strict measurement packet, causal circuit/decoder, optional observer/governor/reference contracts. | Selected hardware and measured parameter/limit uncertainty. Separate true current from a modeled current sensor and motor-bus loss from MCU brownout. |
| Electromagnetic models | Phase2B sensitivity, SC01A explicit network, SC01B/R2 preserved source/solver reports and verified receiver integration. | Defensible receiver/topology domain and measured coupling/receiver behavior. Out-of-domain decoder diagnostics are not physical encoder predictions. |
| Control design | Phase3 detection/supervisor, rejected tuning, optional motion shaping and independent-reference recovery reports. | Broader load/model sensitivity and physical restart/limit identification. Include missed stationary freeze and non-recovery outcomes. |
| Experimental method | [Frozen first four-way contract](../04_EMI_Models/Four_Way_EMI_Experiment.md), configuration/fixtures, implementation inventory, same-arm clean pairing and predeclared gates. | Reviewed new plan after the domain finding; accepting implementation and development evidence before evaluation; calibrated bench procedures later. |
| Results | 468 passing tests, 116 exact legacy records, 24 final native comparisons, 16 refinements, 16 development records and 352 independent reconstruction/scoring checks. Earlier baseline/control/circuit studies remain supporting evidence. | Accepted four-arm evaluation and measured validation. DEV01 is a null result; all DEV02 exposed arms are rejected. Keep historical campaign sizes separate from new execution counts. |
| Discussion / conclusion | Model-specific findings, explicit null/rejected outcomes and identified observability/stop/domain limitations. | Evidence for hardware generalization, combined benefit, novelty and physical immunity. |

For each final figure/table record its raw or processed dataset, configuration, source revision, producing script, units, scoring interval and reproduction command. Label numerical verification separately from physical validation. Report original-request tracking beside shaped-command tracking; current/energy costs beside tracking improvements; and censored recovery beside successful recovery. Keep the external one-way source replay and its synthetic closure visible in the four-way method and captions. The separate assumed-brake study is supporting physics, not an integrated controller safety result.

The compact publication evidence does not include every historical result tree. Use the reproduction guide to identify source-only, baseline and full-campaign requirements. Earlier reports retain their original dates and acceptance statements; this map replaces the September 10 assembly map's description of the causal bridge as absent.
