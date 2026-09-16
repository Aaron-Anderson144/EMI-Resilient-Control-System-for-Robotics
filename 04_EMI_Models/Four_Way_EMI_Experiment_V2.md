# Four-way EMI experiment — PLAN-V2

**Design ID:** FOUR-WAY-EMI-PLAN-V2. **Scope:** a conditional numerical comparison with an explicitly defined THVD1450 behavioral receiver. This is a new protocol; PLAN-V1 and its rejected development outcome remain intact. Final protocol identity is recorded in `four_way_emi_v2_freeze_manifest.json`. Freezing the protocol does not certify the still-pending causal V2 implementation or open evaluation.

## Research question

For the declared external switching replay, loaded encoder-A circuit and motor task, does added differential capacitance, historical fault-tolerant control, or their combination reduce encoder-count and actuator disturbance? Which conclusions depend on the finite threshold, latency and short-pulse hypotheses?

The required result is a complete, reproducible comparison, including null, negative and nonmonotonic outcomes. A result with no persistent corruption is valid. A modeled receiver-domain failure is retained as a rejected case, not credited to control performance or replaced with a milder fixture.

## Receiver decision and characterization evidence

The [receiver contract](Receiver_V2_Contract.md) defines THVD1450DR, its reference ground and external loaded network, signed pin/differential limits, and 16 explicit behavioral variants. The characterization report and its source/configuration hashes are pinned in the final design manifest. The experiment uses a conditional scope because arbitrary short-pulse and fast common-mode response have not been physically identified. Voltage-domain passage alone cannot remove that uncertainty.

### Findings used to finalize this protocol

The completed compact characterization contains 40 electrical records and 640 behavioral cases. All 640 have converged numerical checks and remain inside the declared continuous voltage domain; all 320 clean variants meet the clean guards. None of these six-microsecond records ends with a count error. However, 80 behavioral cases (40 matched pulse-law pairs) change their output edge count between transport and inertial assumptions. This is a timing-model dependence, not demonstrated actuator disturbance or improved immunity.

These findings justify retaining **all sixteen** behavioral variants and variant-specific scoring. They do not justify increasing exposure to force corruption, changing the reserved matrix, or promoting one pulse law to physical truth. The absence of final count error in the characterization is retained as a null result. The much longer causal motor experiment must independently resolve whether transient events affect sampled feedback and control.

The common receiver change is not an electrical mitigation arm. Every arm within a model variant uses the same receiver, startup, threshold pair, latency and pulse hypothesis. Internal clamps, nonlinear pin loading, a physical cable and physical encoder-B channel remain outside this bounded model.

## Treatments

| Arm | Differential capacitance | Control |
|---|---:|---|
| BASELINE | 100 pF | Historical unprotected policy |
| EM_ONLY | 1,000 pF | Same unprotected policy |
| SW_ONLY | 100 pF | Historical protected policy |
| COMBINED | 1,000 pF | Same protected policy |

No controller thresholds, recovery logic, capacitance values or model variants may be retuned after evaluation. Larger capacitance is a treatment to assess, not a declared improvement. Preserve the historical measurement interface and independent-reference-disabled setting.

## Source, task and continuous circuit

The new JSON configuration explicitly copies the source, task, victim, arms and scoring definitions from the hash-preserved PLAN-V1 configuration. The frozen V1 prose remains the reference for those unchanged semantics; the changes in this document concern receiver behavior, sensitivity conditions, fixture matrix and expanded acceptance. Inconsistency between prose and JSON rejects the design.

The unchanged positive-polarity R2 replay retains every original knot and the same SHA-256. After the approximately 5 microsecond record, return linearly over 100 ns and hold through the remainder of the 50 microsecond period. Use 100 complete periods at each of the 0.250 and 1.700 second anchors, with the same 2.019 microsecond commanded-edge alignment convention. Do not mirror or scale the source in the integrated primary comparison. Mirrored and constructed-pulse characterization diagnostics are not primary evaluation fixtures.

Run the same 3 second, 1 ms control task, representative motor, zero load, 24 V bus, signed 0/30/−15 degree requests at 0/0.1/1.6 seconds, common velocity/acceleration governor and fixed 2.0 second reset. Perfect packet delivery remains intentional. Circuit and receiver states, pending delayed events and decoder count persist through driver, replay, return, period, burst and control-sample boundaries.

## Reserved fixtures

The axes below were written before the new characterization campaign results. They define newly reserved integrated combinations within a previously explored parameter region, not unseen physical ranges or random samples. They are not selected to produce baseline failure or combined benefit.

| Stage | Ccp / Ccn, pF | Task sign | Phase | Fixture count |
|---|---|---|---|---:|
| Development | 20/8; 160/8 | +1 | 0 ns | 2 |
| Evaluation | Ccp = 40, 120, 240; Ccn = 7 | +1, −1 | −75, +75 ns | 12 |

The authoritative row identities are in `four_way_emi_v2_fixtures.csv`. Development may resolve implementation and numerical defects. It cannot be used to tune treatments or scoring for a favorable result. Redesign requires a new version and preserved rejected data.

Each fixture crosses all **16 receiver variants** from the contract, all four arms, and exposed/own-arm-clean companions:

- Development: 2 × 16 × 4 × 2 = **256 logical records**.
- Evaluation: 12 × 16 × 4 × 2 = **1,536 logical records**.
- Main total: **1,792 logical records**.
- Separate closure diagnostics: Ccp 40/240 pF, Ccn 7 pF, positive task, zero phase, all 16 variants and four arms, with 100 ns versus 45 microsecond return: **256 exposed logical records**, excluded from the primary evaluation.

There are 2,048 logical records including diagnostics. Exact duplicate clean executions may be cached only with full input/state identity and an explicit mapping from every logical record. Report logical comparisons and unique executions separately. A failed domain or numerical gate remains in the complete matrix; it is not silently dropped from aggregates.

## Receiver-to-control implementation requirements

1. Generate intended quadrature events causally from each held-command continuous motor interval, including reversals. Retain 4,096 decoded counts/revolution and the historical Gray order.
2. Use the V2 loaded circuit, thresholds and explicit pulse law. Preserve pending delayed receiver events between API calls. A control sample may use only events whose output time is at or before the sample.
3. Process simultaneous receiver-A and ideal-B changes jointly using the 1 ps convention. Preserve the illegal-two-bit hold-count/update-previous-state rule. Reject cross-packet ambiguities that would need future information to repair a sampled count.
4. At a simultaneous sample, process due receiver/decoder events first. Pass only decoded position, causal source index and receipt metadata to control. Circuit validity, intended count, exposure and plant truth remain offline.
5. Keep ideal count, exposed decoded count and the unexposed receiver shadow on the **same exposed trajectory** distinct. The shadow is offline and never supplies feedback. Matched clean actuator runs remain the task comparator.
6. A continuous pin/differential domain violation rejects interpretation for that entire logical record. Any continuation convention is diagnostic only and is not a physical fallback. Unresolved root/event/refinement behavior also rejects the record.

The electrical characterization harness alone does not implement this motor/control path. PLAN-V1's hard-coded receiver must not be used with only a raised voltage boundary and renamed V2 output.

## Required acceptance before evaluation

**Gate A — design identity.** Verify the V2 protocol/configuration/matrix, receiver configuration, characterization evidence and referenced source identities, together with all 16 original frozen files. No missing dependency, mismatched hash or inconsistent logical count is allowed.

**Gate B — causal V2 implementation.** Independently review and freeze the new motor/circuit/delayed-receiver adapter. Test both motion directions, clean counting, reversal, zero coupling, ringing and narrow pulses, pulse cancellation, asymmetric event latency, coincident events/samples, ambiguous cross-packet alignments and state continuity. Test annotations cannot influence control. Preserve historical outputs when the old path is used.

**Gate C — numerical/electrical agreement.** Independent KCL and an independent time-domain circuit implementation must agree. Retain PLAN-V1's 0.1 mV pointwise voltage and 1 ns event-time tolerances, exact threshold/output/decoder order and integer sampled-count agreement. Use native steps 0.5/0.25/0.125 ns for Ccp 40/240 pF, Ccn 7 pF, both differential capacitances and initial A polarities, with virtual sampling around the declared source edge at −75/0/+75 ns. Apply all sixteen receiver variants to every native/reference waveform and each refinement, including output-event and sampled-integer agreement. Resolve or reject grazing; never call changed integer counts equivalent. Evaluate both signed pins and differential voltage continuously, with separate ±18 V stress diagnostics and explicit unmodeled clamp current. A numerical pass is not a physical-validity pass.

**Gate D — development acceptance.** Complete all 256 development logical records under the frozen treatments. All clean companions must pass the unchanged delay/count guards, finite output/current checks, clean protected normal-mode/no-alarm condition and final tracking guards. Require accepted continuous operating domains for all exposed records used for control interpretation. If any required development guard fails, retain the result and keep evaluation closed. Unidentified fast-pulse behavior remains a declared conditional scope even if these gates pass.

**Gate E — implementation freeze.** Save a separate implementation/source manifest plus full accepted Gates A–D reports before opening any reserved evaluation result. The protocol manifest is insufficient. Run all twelve evaluation cells and all sixteen variants as specified, retain failures, then independently reconstruct and score complete pair coverage. Do not reuse the PLAN-V1 acceptance file to unlock V2.

## Scoring and claims

Use the unchanged V1 metrics and numerical success thresholds copied into the V2 JSON: own-arm clean paired tracking errors over `[0.24,0.40)` and `[1.69,1.85)` seconds, original-request versus shaped-reference tracking, current/speed peaks, integral current squared, command effort, persistent count corruption, missed/false alarms, and separate recovery after each burst. No-corruption cases have no fault-detection opportunity; pre-existing alarms receive no credit.

Apply the inherited combined-benefit screen **separately within each receiver variant** over its twelve evaluation cells. Its shared denominator is `d_i=max(baseline_window_RMSE_i,0.25 degree)`; the combined normalized mean must be no more than 0.90 times the baseline normalized mean. Preserve the per-fixture position/current noninferiority guards and require at least one baseline task failure to become a combined success. Equality with EM_ONLY does not establish a software contribution or synergy.

Report all sixteen per-variant screens and all individual fixtures. Do not average model variants into a fabricated probability or report only the most favorable one. A claim of consistency across this **finite sensitivity set** requires all sixteen screens to agree and all required records to be accepted. Otherwise state which thresholds, latency or pulse hypothesis changes the conclusion. Even unanimous agreement is not robustness over all physical receiver behavior.

Domain-rejected or numerically unresolved evaluation records prevent a complete affirmative twelve-cell benefit claim for that variant. Do not impute their performance or remove them from the denominator. Valid remaining records may be described individually with their missing/rejected coverage explicit.

Closure diagnostics determine dependence on the complete synthetic replay construction. Hardware immunity, physical safe stopping, loaded brake handoff, formal requirement approval and wider plant uncertainty remain separate milestones.

## Current execution status

This protocol defines the next comparison. Its electrical characterization is provided through Signal Lab. The V2 causal motor integration, native acceptance, development acceptance and separate implementation freeze must be completed before evaluation. The reserved integrated evaluation and closure comparison have not been executed as part of protocol preparation.
