# Baseline consolidation and experiment-design checkpoint

Completed locally on 10 September 2026. **The audited baseline is consolidated, the original numerical behavior is preserved, and the first four-way EMI experiment has a frozen, independently reviewed design.** The causal receiver/decoder implementation and integrated four-arm evaluation are the next milestone; they have not been executed in this checkpoint.

## Changes completed

**Packet metadata:** [PACKET-SUMMARY-V1](../04_EMI_Models/Packet_Summary_Contract.md) gives consistent full-record transmitted/dropped/accepted totals and separately identifies the fault-source window. Counts are recomputed after forced-gap rescheduling. A 100-sample forced outage now reports 1,501 transmitted, 100 dropped and 1,401 accepted; packet schedules, measurements and controller decisions are unchanged. Statistical consumers use the explicit window denominator. The entire historical 600-trial Monte Carlo table reproduces byte-for-byte, including 15,934 drops in 80,000 nominal opportunities.

**Evidence preservation:** The covered baseline, Phase 2, Phase 2B, sensitivity and SC01A entrypoints create fresh default folders and accept explicit new/empty folders. Populated or file destinations are rejected before execution writes. Figures, smoke tests and validation outputs follow the owning new workflow folder. The baseline `main` wrapper remains argument-free; use `run_baseline(folder)` for an explicit destination. Other covered workflow functions accept optional folder arguments. Named invocations remain supported; converted function files must be called by name rather than through `run('file.m')`. Low-level report/plot helpers still write within their owning workflow folder. This does not claim that every historical SC01B helper was changed.

**Local history:** The `audit-baseline-2026-09-10` tag retains the 293-file pre-change source baseline. The tested code commit is `d7413fe6a3c0cd7a091e8da756bce9e60b108489`. A separate local clone had all 303 tracked files byte-identical to that commit and restored 40 pinned local dependencies with no network access. [Local reproduction](Local_Reproduction.md) explains Git's scope, line-ending preservation and the hash-checking bootstrap. Large historical evidence and installed runtimes remain separate; this is not a complete data backup.

**Research records:** The [literature plan](../01_Research/Literature_Review_Plan.md) now has a 12-row local synthesis with source/claim limits; the [research log](../01_Research/Research_Log.md), [report outline](../09_Report/Report_Outline.md), [roadmap](Roadmap.md) and [evidence status](../02_Requirements/Research_Evidence_Status.md) are current. Formal Draft approvals were preserved. External full-text/novelty and current-source applicability research remains partial.

## Verification actually executed

| Check | Result | Scope |
|---|---:|---|
| Full suite from the fresh local checkout | **401/401 pass** | 371 existing tests plus 8 packet-summary and 22 output-preservation tests; zero failures/incomplete tests. |
| Original Phase 3 replay | **116/116 exact** | Time, state, loop values, complete signal/reason tables and campaign metrics match prior accepted evidence. Known misses/censoring remain. |
| Focused packet checks | **41/41 pass** | Clean, seeded, forced/overlapping gaps, source-time attribution, conservation and controller independence from metadata. Included in the broader suite. |
| Focused output checks | **22/22 pass** | Reuse rejection, unchanged sentinel files and real analytical exports. Included in the broader suite. |
| Phase 2B workflow in a scratch project | **10 smoke + 10 Simulink comparisons pass** | Complete analytical/600-trial statistical workflow, separated output paths and all checked channels. |
| Smallest legal sensitivity routing check | **313 numerical runs + 1 Simulink comparison pass** | One global sample, three levels, three grid levels, figure export; not a repeat of the full 1,886-run campaign. |
| Dependency/bootstrap checks | **40 inputs validated and restored** | Altered inputs, differing destinations and path traversal rejected; dry-run and repeat behavior checked. |
| Existing evidence/source models | **Preserved** | All 2,451 historical result/source-archive files retain size/mtime; 12 model/diagram/component hashes unchanged in original and scratch project. |

No new full native SC01A campaign was run for the routing change; its guard/helper behavior and the full regression suite were checked. Existing circuit equations, control gains, observer thresholds, saved models and physical assumptions were not retuned. No physical hardware validation occurred.

## Frozen next experiment

[FOUR-WAY-EMI-PLAN-V1](../04_EMI_Models/Four_Way_EMI_Experiment.md) prescribes a hash-pinned R2 source waveform, a capacitive victim network, an assumed Schmitt receiver and persistent quadrature decoder. The electrical intervention adds 900 pF across the receiver pair; the software intervention uses the existing protected policy. All arms share the same shaped zero-load task. The source is a disclosed external one-way replay with a synthetic continuous return, not a newly validated periodic motor-drive source.

The plan contains two development and twelve evaluation fixtures: **112 main logical records**, plus **16 separately labeled source-closure diagnostics**. These are planned counts, not completed simulations. The [freeze manifest](../04_EMI_Models/four_way_emi_freeze_manifest.json) binds the plan, configuration, matrix, factory assumptions and input provenance. Static checks verified all fixture combinations, source identity, record arithmetic and nonvacuous event-sample clocks.

Independent review corrected the aggregate-benefit statistic, per-burst recovery clocks and the decoder-error oracle. The latter uses an offline clean receiver driven by the same exposed trajectory to distinguish actual EMI corruption from ordinary receiver delay. Null results and rejected gates are valid outcomes; no evaluation exposure or filter will be selected after seeing results.

## Next accepting milestone

Implement the causal measurement-input boundary, circuit response and receiver/decoder state. Preserve the existing interface when unused. Verify clean quantized counts, both directions and interior reversals, threshold/invalid transitions, sampling coincidences, continuous circuit state and independence from offline truth. Pass the declared circuit/reference/timing checks, freeze implementation hashes after development acceptance, then execute the four-arm evaluation.

Brake handoff remains necessary for an integrated loaded stop/restart claim; it is not a prerequisite for this zero-load first comparison. Physical reference integrity, measured parameters, current-sensor/brownout/protocol mechanisms and hardware gates remain open.

The [eight-row action status](Audit_Action_Status.csv) records exactly which portions closed. Compact [test results](Verification/Consolidation_2026-09-10/all_project_tests.csv), [116-record identity](Verification/Consolidation_2026-09-10/original_116_identity.csv), [validation summary](Verification/Consolidation_2026-09-10/validation_summary.json), [output checks](Verification/Consolidation_2026-09-10/output_guard_validation.json) and [design checks](Verification/Consolidation_2026-09-10/design_validation.json) are tracked with this checkpoint. Complete fresh records remain in the local audit workspace. The final consolidation tag includes this report and frozen design; its source code matches the tested code commit, with later documentation/Git-formatting records only.
