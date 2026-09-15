# Project goals assessment

12 September 2026 · Current project evidence and fresh verification

**The project is still working toward the right research question, but it has not shown that combined electrical and software mitigation improves EMI tolerance.** The simulation foundation and causal receiver/control connection are implemented. The next step is to establish a usable receiver model, then run an accepted comparison. More controller features cannot resolve that receiver-model gap.

This assessment reviews the charter, roadmap, requirements, evidence status, receiver revision brief and EDMD results. Fresh verification passed **522/522 MATLAB tests**: 468 main-project tests, 22 original SC01B tests and 32 hybrid checks. The two Python suites also passed **10/10 tests**, split between six four-way tests and four SC01B R2 tests. All **16 frozen PLAN-V1 files** match their recorded hashes after exact restoration of the authoritative plan; this review also checked those hashes independently. These checks establish software and numerical consistency within their stated scopes, not physical validation.

Fresh reproduction also completed:

- **116 legacy controller records** matched all 31 channels, plant traces and reason fields exactly, including matching missing-value masks.
- **16 development records** reproduced the same outcome. The overall execution/clean guard result remains false, and the exposed DEV02 cases still leave the receiver domain.
- **24/24 native numerical comparisons** and **16/16 refinement checks** passed. Twelve of the 24 native runs remain rejected by the receiver-domain rule; numerical agreement does not make those operating points physically valid.
- The full hybrid EDMD study reran with **24 training, 12 validation and 40 test trajectories**, selecting candidates 3 and 12 from 18 candidates before test generation. The EDMD benefit screen still passed **0/4 regimes**, with no nonfinite forecasts.
- The evaluation guard rejected the blocked evaluation before creating its output folder. Evaluation remained unopened.

This was not a rerun of every historical campaign. In particular, the original SC01B native/SPICE campaign was not rerun; its 22 isolated tests cover analytic metrics, energy accounting and output preservation. The fresh native comparison above belongs to the four-way receiver study. No hardware validation was performed.

## Progress against the seven objectives

| Charter objective | What is supported | What remains open |
|---|---|---|
| 1. Establish a clean, reproducible actuator-control baseline | Implemented and supported by the fresh regression suite and 116 freshly reproduced legacy controller records. All 31 channels, plant traces and reason fields match exactly. The nominal three-state model, controller and matched no-fault runs provide a useful reference. | Identify the actual actuator and load before treating the assumed parameters as hardware behavior. Preserve the distinction between numerical reproduction and physical validation. |
| 2. Derive coupling models | Capacitive, inductive and shared-impedance models, parameter sweeps and independent circuit comparisons are recorded. The causal experiment connects a capacitive A-channel network to the decoder and controller. | The integrated comparison covers one assumed capacitive topology with ideal B timing. It does not establish measured cable, shielding, grounding or mutual-coupling behavior. |
| 3. Create repeatable fault injection | Encoder faults, timestamped packet delay/loss, ground offset and averaged motor-bus sag/interruption are implemented. Saved tests check channel isolation, timing and seeded repeatability. | Current-sensor corruption, physical controller brownout and protocol-specific physical errors remain unimplemented. Motor-bus interruption must not be counted as controller brownout. |
| 4. Detect faults using limits and model residuals | The observer and supervisor implement plausibility, residual and freshness checks. Their known misses are recorded. | Fresh stationary freeze, small bias and slow drift can evade detection. Model/load mismatch and uncalibrated limits prevent broad detection claims. EDMD does not close these gaps. |
| 5. Implement degraded operation, recovery and stop | Numerical modes, qualification/reset rules, optional reference reconstruction, motion shaping and a separate stop/hold study are implemented. | Primary-only recovery can fail. Zero-voltage stop permits motion under load. Integrated loaded restart still needs drive/brake handoff, engagement/release evidence and estimation that accounts for brake torque. Gate 3 remains open. |
| 6. Compare baseline, electrical-only, software-only and combined mitigation | The causal interface and 16 development records, including eight clean companions, were freshly reproduced with the same outcome. The evaluation guard still blocks evaluation. | The experiment has not reached accepted comparative evaluation. DEV01 has no persistent EMI count corruption; all four exposed DEV02 arms exceed the assumed 7 V receiver domain. Later fallback behavior cannot establish mitigation benefit. RES-005, A01 and Gate 4 remain open. |
| 7. Connect simulation to circuit and hardware validation | Source history, parameter provenance and reports provide a documented numerical path. Fresh four-way native comparisons passed 24/24 numerical checks and 16/16 refinements. | Twelve native operating points remain outside the receiver domain. Selected hardware, a connected schematic, calibration and independent measurements are still needed. Gate 5 remains open. The literature review is partial. |

The combined-benefit success criterion is **not demonstrated**. The passing software suites show that the tested rules behave as specified; they do not turn the rejected development cases into valid physical evidence. Formal Draft requirement approvals remain unchanged.

## What blocks the main question

The immediate blocker is receiver behavior, not a lack of simulation runs. PLAN-V1 assumes instantaneous switching at +0.20 V and −0.20 V, a 7 V common-mode domain and no short-pulse filter. Its higher exposure leaves that domain. Raising the limit or using a replacement receiver's wider headline range would not identify threshold, delay, loading or fast-transient behavior.

The receiver brief provides a practical next route. THVD1450 is a provisional modeling candidate, not a validated replacement. Define the complete installation and signed pin/differential voltage limits, distinguish recognition bounds from assumed switching thresholds, and establish what the model can say about short pulses and ringing. If those dynamics cannot be supported physically yet, declare a conditional numerical study and show how uncertainty affects the result.

The second blocker is experimental evidence that isolates the treatments. Use the same receiver and topology across the four arms so a receiver change is not mistaken for a filter benefit. Characterization cases can guide design, but they cannot later count as unseen evaluation. Preserve PLAN-V1's failed result and freeze a new experiment before evaluating it. The original 96 evaluation and 16 closure records remain unopened in the reviewed evidence.

## Where EDMD fits

The hybrid study is useful work on objective 4's model-mismatch problem. It uses healthy simulated observations, a separate acquisition controller and recorded future voltage sequences for multistep forecasts. It neither tests an EMI receiver nor demonstrates improved closed-loop control.

At 50 ms, quadratic EDMD reduced mismatch error relative to nominal physics, but the simpler linear hybrid achieved essentially the same benefit. Quadratic EDMD was slightly worse than linear in every condition. In the nominal condition, EDMD error was 0.18596° against 0.00605° for physics. No condition passed the EDMD benefit screen, and longer forecasts developed substantial error. The fresh full study reproduced the same selection and conclusion; this result is complete supporting work, not a pending experiment or evidence of EMI mitigation.

Keep this as a separate estimation workstream. The next useful estimation comparison is a small learned linear correction against a disturbance-estimating physics observer, with nominal accuracy protected and independent test runs. That work should not replace receiver characterization on the main project path. The existing control/protection path should retain its current separation from the learned correction.

## Next priorities

1. **Preserve the verified evidence.** Fresh software checks, the scoped reproductions above and all frozen-file hashes now pass their numerical checks. Keep the receiver-domain rejections visible and distinguish the rerun campaigns from historical campaigns that were not rerun. The authoritative plan was restored after a prose edit broke its hash guard. Keep the readable companion separate and the frozen file authoritative; retain the correction and fresh checks in the project record.
2. **Complete the receiver/topology contract and characterization harness.** Produce the assumption table, signed voltage/domain records, timing and pulse-response evidence, and independent numerical checks described in the receiver brief. This is the immediate research milestone.
3. **Freeze a new comparison only when its model scope is defensible.** Separate development from evaluation, retain the historical control policy, use matched clean/exposed cases and predeclare scoring and rejection rules. Report null or negative results if that is what the experiment shows.
4. **Keep the other work tied to a specific claim.** Drive/brake integration is required for loaded restart, not for the deliberately zero-load first EMI comparison. Current-sensor, brownout and full-protocol work remain charter gaps, but need not all precede that bounded comparison. Continue the literature review alongside the receiver work.
5. **Keep EDMD in its supporting role.** The active roadmap and research log now record its completed experiment and negative comparison with linear. Preserve its separate conditional-forecast scope and leave Draft approvals unchanged.

## Progress statements reconciled

- `02_Requirements/Verification_Traceability.md` retains its dated historical statements and now has a current-status addendum. It explains that integration is implemented, development acceptance remains rejected and evaluation is unopened.
- `00_Project_Management/Roadmap.md`, `01_Research/Research_Log.md` and the root README now include completed EDMD work, its limitations and its supporting role. This does not advance the receiver milestone.
- Gate 0 describes what approval requires but has no explicit completed approval record in the reviewed documents. The roadmap now distinguishes gate criteria from approval records. Gate 1 has numerical support; Gate 2 remains explicitly limited to implemented software mechanisms.
- The root README now identifies the readable plan as explanatory and the restored frozen source as authoritative. The readable copy retains its historical design-only heading.

No calendar schedule or phase-duration commitment was found in the reviewed roadmap and progress review. The project can be assessed against milestones, but these records do not establish that it is on schedule or a particular percentage complete.

## Source records

Reviewed under `C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics`:

- `00_Project_Management/Research_Charter.md`, `Roadmap.md` and `Audit_Action_Status.csv`
- `00_Project_Management/Reviews/2026-09-12/Project_Progress_Review.md` and `Receiver_Revision_Brief.md`
- `01_Research/Literature_Review_Plan.md` and `Research_Log.md`
- `02_Requirements/System_Requirements.md`, `Research_Evidence_Status.md` and `Verification_Traceability.md`
- `11_EDMD_Hybrid_Estimation/docs/RESULTS.md`
- The authoritative and readable versions of `04_EMI_Models/Four_Way_EMI_Experiment.md`

Fresh evidence is saved beside this assessment: `test_summary.json`, `verification/original_sc01b_tests/original_sc01b_summary.json`, the two Python logs under `evidence_audits`, `legacy_equivalence.json`, `fresh_development/stage_summary.json`, `fresh_native_summary.json`, `evaluation_guard.json` and the study results under `fresh_edmd/tpfb26ae18_1c11_4b5c_9ebd_7e2068e23b1f`. The coordinator confirmed the main, Python and reproduction outcomes; this reviewer ran the original SC01B tests independently.

The approved status reconciliation updated `README.md`, `00_Project_Management/Roadmap.md`, `01_Research/Research_Log.md` and `02_Requirements/Verification_Traceability.md`. No executable code, frozen artifact, historical result or approval status was changed by these edits. No new external receiver research was performed.
