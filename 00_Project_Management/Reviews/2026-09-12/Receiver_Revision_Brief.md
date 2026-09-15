# Receiver revision brief

12 September 2026 · RECEIVER-REVIEW-2026-09-12 · Design preparation; no new experiment freeze

Next, characterize the receiver and define the circuit topology. Keep the rejected FOUR-WAY-EMI-PLAN-V1 intact. Raising the voltage limit alone would leave the model's physical assumptions unresolved.

## What the development result establishes

The retained 16 development records contain eight clean companions. DEV01 stays inside the assumed common-mode domain and produces no persistent EMI count error. Every exposed DEV02 arm leaves that domain: the recorded maxima are 7.5575 V at 100 pF and 8.0376 V at 1,000 pF. These are results for the old circuit and assumed receiver. They do not establish that a replacement IC works at those exposures.

PLAN-V1 switches high at +0.20 V and low at −0.20 V. This is an explicitly assumed 400 mV hysteresis band, with instantaneous events and no short-pulse filter. It is not an identified component model. The current fallback after a domain violation remains diagnostic only.

## Manufacturer evidence and candidate direction

| Item | AM26C32I reference | THVD1450 receiver candidate |
|---|---|---|
| Supply | 4.5–5.5 V | 3–5.5 V |
| Recommended voltage conditions | Common mode −7 to +7 V | Each bus terminal −15 to +15 V; differential voltage also −15 to +15 V |
| Threshold interpretation | ±200 mV recognition bounds; 60 mV typical hysteresis | Typical rising/falling thresholds −100/−130 mV; 30 mV typical hysteresis |
| Specified receiver propagation | 9/17/27 ns min/typ/max at 50 pF | 25/40 ns typ/max at 15 pF; no minimum specified |

Sources checked 12 September 2026: [TI AM26C32, SLLS104M, October 2023, §§5.3, 5.6–5.7](https://www.ti.com/lit/ds/symlink/am26c32.pdf) and [TI THVD14xx, SLLSEY3E, May 2019, §§7.4, 7.7–7.8](https://www.ti.com/lit/ds/symlink/thvd1451.pdf). Specifications have stated test conditions; typical values are not guaranteed corners. Absolute maximum ratings do not authorize functional operation.

**Provisional design direction:** investigate THVD1450 with its driver disabled and receiver enabled (DE low, active-low RE low). Its enable controls suit receiver-only use; THVD1451 has an always-enabled driver. This receiver is a candidate for modeling. It has not been selected for purchase or qualified as a replacement. [TI functional modes, §9.4](https://www.ti.com/lit/ds/symlink/thvd1451.pdf)

If adopted, use the same receiver in all four new experiment arms. Keep the electrical intervention and software policy separate so their effects can be identified. Do not credit a receiver change as a benefit of the existing differential-capacitance treatment.

## Contract to complete before a new experiment

1. **Specify the installation.** Record exact component/grade, supply, temperature, receiver output load, enabled state and startup settling; locate the IC ground relative to the modeled shared return. Identify encoder-driver output impedance, cable assumptions, termination, bias paths and protection. The existing 120 Ω termination, 50/70 pF shunts and 10/20 kΩ returns remain network assumptions unless supported separately.
2. **Evaluate the complete operating domain continuously.** Record both signed pin voltages relative to IC ground, differential voltage and common mode. For the candidate's symmetrical pin bounds, the derived pin predicate is `abs(vcm) + abs(vd)/2 <= 15 V`; impose `abs(vd) <= 15 V` separately. For example, `vcm=14 V, vd=4 V` places one pin at 16 V and fails. A saved common-mode maximum cannot establish these predicates. Separate operating-domain failures, absolute-stress flags and unresolved dynamic behavior.
3. **Define threshold and timing uncertainty.** Use datasheet recognition bounds as constraints, not exact Schmitt thresholds. Record paired rising/falling thresholds and admissible hysteresis assumptions. Separate propagation delays by edge direction. A nominal illustration may use typical values, but an outcome dependent on that single choice is conditional. A delay value is not a guaranteed pulse rejection width.
4. **Resolve fast-transient behavior.** The reviewed specifications do not supply a general acceptance/rejection law for arbitrary narrow pulses, ringing and simultaneous fast common-mode excursions. Obtain an applicable receiver model, manufacturer characterization or measurements. Alternatively, predeclare a conditional behavioral study and report the consequences of unresolved pulse/overdrive behavior. Do not describe voltage-domain passage as physical receiver validation.
5. **Add electrical characterization records before control scoring.** Retain continuous signed voltage extrema, first violation and time outside each domain, slew rates, input pulse amplitude/width and overdrive, output pulse widths, circuit/driver currents, and any modeled clamp current. Record reference-ground displacement explicitly. Existing retained traces may help design diagnostics; they are development evidence, not new holdouts.

## Work sequence and completion checks

| Step | Deliverable | Completion condition |
|---|---|---|
| R1: receiver/topology contract | Versioned parameter table, circuit definition and assumption register | Every parameter classified as guaranteed, typical, assumed or uncharacterized; reference ground and dynamic limitations explicit |
| R2: electrical characterization harness | Separate implementation with continuous domain checks and receiver timing records | Independent equation checks; both polarities; domain boundaries; uncertain thresholds; narrow pulses; state continuity; coincident edges/samples; numerical refinement |
| R3: development assessment | New source-bound characterization results | Clean decoding and delay assessed; all failures retained; determine whether a physical or conditional numerical scope is supportable |
| R4: new four-arm experiment | Reviewed PLAN-V2 and separate development/evaluation fixtures | Receiver/topology, treatments, exposures, timing, uncertainty, scoring and rejection rules frozen before evaluation |
| R5: comparison | Matched clean/exposed records and independent scoring | Accepted entry conditions; report null, negative and nonmonotonic outcomes as readily as improvement |

Use characterization fixtures to explore failures and guide the design. Keep those fixtures separate from unseen evaluation cases. Choose the new exposure matrix from the declared operating envelope and research question; do not tune it to force baseline failure or combined benefit. If uncertain receiver behavior changes the conclusion, report that dependence instead of selecting a favorable model.

Keep the historical ideal B channel explicit if it remains in the next topology. Modeling two physical channels and their relative delays is a separate scope decision. Preserve the controller's measurement boundary: plant truth, receiver-domain flags and exposure labels remain outside its feedback inputs. Loaded brake handoff and hardware validation remain separate milestones.

## Current status

The receiver candidate has been researched. The contract and implementation still need to be completed. No PLAN-V2 is frozen, no replacement receiver has been validated, and no new comparative evaluation was run during this review.
