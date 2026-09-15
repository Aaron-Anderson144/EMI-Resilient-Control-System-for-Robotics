# Project verification and goal review

12 September 2026 · EMI-Resilient Control System for Robotics

**The software checks pass, and the main results are reproducible. We are still working toward the original goal, but we have not yet shown that combined electrical and software mitigation improves EMI tolerance.** The receiver model remains the immediate blocker. EDMD is useful supporting research, but the current results do not justify adding it to the control loop.

This review checked the current code, preserved inputs, result calculations, package copies and progress statements. It also reran the baseline, historical controller comparison, four-way development experiment, native circuit comparisons and full hybrid EDMD experiment. Passing these checks verifies the implemented numerical work; physical performance remains unverified.

## Fresh verification results

| Check | Result | What it establishes |
|---|---|---|
| Main MATLAB suite | 468/468 passed | Current robotics, SC01A, SC01B_R2 and four-way tests pass. |
| Original SC01B suite, isolated from R2 | 22/22 passed | The preserved original implementation passes its own metrics, energy and output-preservation tests. |
| Hybrid EDMD suite | 32/32 passed | Preparation, forecasting, data generation and causal replay checks pass. |
| Python audit tests | 10/10 passed | Four existing R2 tests and six new pair-coverage tests pass. |
| Historical controller reproduction | 116/116 exact | All 31 logged channels, plant states and decision reasons match at all 3,001 samples per record, including missing-value patterns. |
| Four-way development reproduction | 16 records, eight pairs | All 181 generated CSV exports match the saved numerical/text results, apart from run times. The development rejection is reproduced. |
| Fresh native circuit comparisons | 24/24 numerical passes; 16/16 refinement passes | Voltage, event timing, decoded counts and refinement checks meet the existing limits. Twelve runs still exceed the receiver domain. |
| Full EDMD reproduction | 24 training, 12 validation and 40 test trajectories; 18 candidates | The same models are selected and the same benefit decision is reached: zero of four conditions passes. |
| Evaluation guard | Correctly blocked | Rejected acceptance stops execution before an evaluation output folder is created. |
| File integrity | 16 frozen files, 40 retained dependencies and 106 existing package-manifest entries match | Required inputs and the four existing package scopes retain their declared identities. |

That is **522 passing MATLAB tests and 10 passing Python tests**, with no failed or incomplete tests. The original SC01B suite was run separately because its class and function names overlap with the revised circuit. A scratch-runner setup error occurred before that suite started; it was corrected and its record was retained.

The clean baseline again reports stable closed-loop poles, a maximum pole magnitude of 0.994325, tracking RMSE of 0.0830428 rad, 10.745% overshoot and 0.709 s settling time for the implemented representative case. These values describe that model and task, not selected hardware.

## What the reruns tell us

The lower four-way exposure, DEV01, still produces no persistent EMI count error or paired actuator error in any arm. It provides no demonstrated mitigation benefit. Every exposed DEV02 arm still leaves the assumed receiver operating range. The later held-receiver response remains diagnostic data and cannot establish that a treatment works. Development acceptance remains rejected; the 96 reserved evaluation records and 16 closure records remain unopened.

The fresh native runs used the final archived solver settings for each case and step size. No settings were tuned during this verification, and no acceptance limit was relaxed. The largest node-voltage difference was **0.080203 mV**, below the existing 0.1 mV limit. The largest event-time difference was **0.001968 ns**, below 1 ns. There were no solver warnings. Agreement between the two numerical implementations does not make the out-of-domain receiver cases physically valid.

The EDMD experiment was rebuilt with its original seeds. Candidate scores and selected-model numerical fields match exactly after excluding timing fields. The per-run forecasts and pooled forecast summaries are byte-identical; later aggregate tables differ only by rounding, at most about 1.03e-12 in a reported field. This is a reproducibility result using already known test cases, not additional independent evidence.

At 50 ms, quadratic EDMD helps when nominal physics is mismatched, but the linear correction performs slightly better in every tested condition. In the nominal case, physics has about **0.00605°** error while EDMD has **0.18596°**. Keep learned estimation separate from the control path until it protects nominal accuracy and demonstrates a useful advantage over simpler alternatives.

## Issues corrected

1. **The wording pass had changed a frozen input.** The authoritative experiment document was restored to its exact original bytes. The clearer wording is retained in a labeled reading copy. The original freeze manifest and all its hashes remain unchanged.
2. **The standalone CSV audit could accept duplicate metric pairs.** A new version adds complete indexed-pair coverage checks and rejects duplicate, missing and unexpected pairs. It retains the original numerical auditor and has six focused tests. Both the saved and fresh campaigns pass it. The main acceptance guard already checks exact development identities, so this was a false-positive gap in the standalone audit, not evidence of an evaluation bypass.
3. **The publication ZIP was stale.** Its 23 entries now match the current package folder. The previous ZIP was preserved. The EDMD archive scope was clarified, and its project folder, standalone folder and ZIP still match across all 57 files.
4. **Some progress statements were stale.** The README, roadmap, research log and requirements traceability now distinguish implemented integration from rejected comparative acceptance and record EDMD's supporting role. Historical statements and Draft approvals were preserved. Larry Anderson's contribution remains recorded as **Research collaborator and technical adviser**.

The first development comparison also found one saved-only auxiliary table, `domain_and_clean_decoder_summary.csv`. The campaign generator does not produce that table. The initial inventory failure was retained, followed by a separate comparison of all 181 actual generator exports: 6,205,957 numeric and 144,292 text fields match exactly, excluding 16 run-time fields. No old table was copied into the fresh evidence to make the inventory appear identical.

## Are we still on track?

**Yes in direction; the central comparison milestone is still blocked.** The baseline, coupling models, repeatable fault injection and numerical verification support the charter. Fault detection, recovery and stopping remain partial: stationary freeze, small bias and slow drift can escape detection; recovery after dropout can fail; and zero-voltage stop can permit loaded motion. Loaded brake/restart integration and physical validation remain open.

The next work should follow this order:

1. **Characterize the receiver and complete topology.** Establish defensible voltage limits, loading, threshold assumptions, timing and response to short pulses. Record the uncertainty that remains.
2. **Obtain usable development evidence, then freeze a new comparison.** Keep the receiver and topology consistent across the four treatments. Preserve PLAN-V1's rejected result and keep characterization data separate from later evaluation.
3. **Advance supporting work against specific gaps.** Continue loaded drive/brake recovery, literature coverage and estimation comparisons where they support a stated claim. EDMD should not delay the receiver work.

There is no approved calendar baseline in the reviewed records, so this review cannot establish that the project is on schedule or assign a defensible percentage complete. The seven charter objectives and remaining gate conditions are detailed in [Goals_Assessment.md](Goals_Assessment.md).

## Evidence and limits

The [evidence audit](evidence_audits/Evidence_Audit.md) separates fresh reruns from recalculations of saved circuit and EDMD records. The original SC01B circuit retains its known rejected channel-overlap result; all five saved R2 cases pass their existing audit. These circuit audits did not rerun those historical native campaigns. Other historical motion, recovery, stop/hold and tuning campaigns were covered through their tests and retained evidence, not all regenerated in full.

The [artifact audit](Artifact_Audit.md) records package hashes, source identity and local-link checks. Its inventory covers the project before this verification report was added. Seventy-five machine-specific links remain in four archived audit documents; their intended local files are present. Remote links were not fetched. The existing Word/PDF reports were unchanged in this verification and retain their earlier visual review.

No hardware was tested, no requirement approval was inferred, and no new comparative acceptance or publication was issued. The [structured summary](verification_summary.json), [evidence index](evidence_index.json), test records and fresh experiment folders preserve the results needed to review this conclusion.
