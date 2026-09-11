# Phase 3 controller tuning: frozen comparative study

Design declared on 10 September 2026, before running this study's policy grid. The study ID is `PHASE3-TUNING-STUDY-V1`; the comparison criteria ID is `PHASE3-TUNING-COMPARISON-V1`. This document specifies the experiment, not an acceptance result.

The historical degraded/recovery policy performed worse than the normal-gain observer/supervisor comparison in the recorded motion-freeze fixture, and its additional command limits were inactive in the three original ablation cases. This study separates gain/filter selection from evidence about actual command clipping. **No default configuration is changed by the study, even if a candidate meets its comparative gates.**

## Candidate scope and frozen order

The nine grid policies use degraded controller tuning-target ratios `0.5`, `0.75` and `1.0`, each with degraded/recovery reference-filter time constants `0`, `0.020` and `0.050` seconds. Ratios are visited in that order, with filter times in that order within each ratio. Names encode the settings: `G075_F020` means a 75% tuning target and a 20 ms filter. `G050_F050` is the historical comparison. A tuning target is not a demonstrated closed-loop bandwidth under faults or saturation.

Grid candidates retain the normal controller, observer thresholds, freshness and prediction deadlines, mode persistence, recovery/release dwell, explicit reset, anti-windup and zero-voltage stop. They retain historical mode voltage scales (normal 1, suspected 0.5, degraded/recovery 0.25) and slew rates (normal 10,000 V/s, otherwise 200 V/s). Actual and nominal model parameters remain separate. The optional independent-reference feature is enabled only in its two explicitly declared evaluation fixtures.

## Declared fixtures and target windows

Every record lasts 3 seconds at a 1 ms sample interval. Target windows are fixed calendar intervals `[start, stop)`, shared by every policy; they are not shortened when a policy enters stop or recovery. Each faulted run has its own matched-clean run with the same plant, load, reference, benign noise, reset protocol and controller configuration, with the injected faults removed.

The eight tuning fixtures are:

| Fixture ID | Target window, s | Purpose |
|---|---:|---|
| `freeze_during_motion` | 0.13–0.70 | Historical 30-degree motion freeze, 0.13–0.45 s |
| `encoder_count_jump` | 0.45–0.85 | Historical 128-count impulse |
| `out_of_range_measurement` | 0.45–0.85 | One-sample 4-radian additive error |
| `short_packet_burst` | 0.25–0.75 | Missing packets, 0.25–0.34 s |
| `reversal_during_recovery` | 0.45–0.90 | Count jump followed by a reference reversal at 0.48 s |
| `capped_reversal` | 0.24–0.85 | Synthetic 2 V software limit and +60 to −60 degree reversal during a packet burst |
| `loaded_supply_interruption` | 2.00–2.40 | Historical known-load interruption; post-reset scoring, with full-record drift reported separately |
| `clean_reference_reversal` | 1.60–2.10 | Clean ordinary-tracking/nuisance-alarm guard |

The twelve evaluation fixtures are declared before selection. They cover negative 30-degree motion freeze; a shorter positive 45-degree freeze; a later ±45-degree reversal with missing packets; known ±0.01 Nm loads; an unmodelled +0.001 Nm load; actual resistance +5% and inertia +10%; permitted delay/jitter during reversal; a new 0.005-degree noise fixture using seed 260921; opposite-direction synthetic 2 V limiting stress; and independent-reference dropout reconstruction with and without the separate reset. Exact windows, reference knots, parameter overrides and descriptions are stored in [the fixture function](../03_MATLAB/functions/phase3_tuning_fixtures.m) and copied into the frozen design manifest.

The clean guards are the tuning clean reversal and evaluation permitted-delay/jitter and benign-noise cases. Mismatched-model/load cases are not labelled clean or assumed to recover. The independent reference is a synthetic, synchronized position stream with an assumed error bound; no physical sensor independence is established. The two 2 V cases deliberately stress software limits and are not proposed hardware operating points.

## Metrics and comparative gates

The primary ranking metric is tracking RMSE against the commanded physical reference within each fixed target window. Also report matched-clean position-disturbance RMSE, peak tracking error/current, integrated current squared and voltage squared, command variation including the change entering the window, full-record tracking/current, final error, alarms, stop duration, mode changes and recovery evidence. Squared-current and squared-voltage integrals are effort proxies, not heat or physical safety measures. Full-record RMSE is supplementary because long clean or stopped intervals can obscure the transient being tuned.

Each candidate is compared with the historical policy on the same ordered fixtures. The following allowances are provisional study tolerances, not hardware limits or statistical confidence intervals. A relative/absolute pair allows the **larger** of the two increases above the historical value.

| Comparative check | Allowed increase or condition |
|---|---|
| Window tracking and matched-clean disturbance RMSE | 10% or 0.25 degree |
| Window peak tracking error | 5% or 0.5 degree |
| Window and full-record peak current | 10% or 0.05 A |
| Final absolute tracking error | 10% or 0.5 degree |
| First alarm, when the historical run has one | At most 1 ms later; an absent candidate alarm fails |
| Recorded recovery confirmation | Must remain present if historical confirmation exists |
| Final mode | Must remain normal if the historical final mode is normal |
| Stop duration | No newly introduced stop when historical duration is zero; otherwise at most 50 ms longer |

Recovery confirmation means the first 50 ms continuously normal interval following the first non-normal response; final mode is checked separately. The first-alarm comparison is a whole-record timing check, not proof of detecting every injected fault. These comparisons do not replace the existing observer/supervisor tests.

Execution invariants require finite plant/command records, command and available-supply bounds, exactly zero commanded voltage while stopped, no alarms in declared clean guards, stopped/zero-command/noncredible re-anchor commits, and a current explicit reset after the required credible-primary release evidence. A failed invariant remains a failed recorded run.

For ranking, divide each window tracking RMSE by `max(historical RMSE, 0.25 degree)`, then average those normalized values across the partition. The aggregate improvement is `1 − candidate score / historical score`. Eligibility requires every comparative case gate **and** at least 10% aggregate improvement. These weights and thresholds are fixed before the grid runs.

## Selection, evaluation and command-limit attribution

The runner writes `frozen_design.json`, its MAT counterpart and source identities before candidate simulations. After the tuning grid, select the eligible policy with the lowest tracking score, using declaration order for ties. If none is eligible, select the lowest-score nonhistorical policy for **diagnostic evaluation only**. This does not make it eligible. Write `frozen_selection.json` before evaluation, and do not retune using evaluation outcomes.

The twelve evaluation cases compare the frozen candidate, historical policy, and an identical-gain/filter diagnostic comparator with extra mode caps removed and nonnormal slew relaxed to 10,000 V/s. The same comparative gates and 10% aggregate-improvement requirement apply to the candidate in evaluation. A diagnostic-only tuning choice cannot become an eligible recommendation merely by performing well in evaluation. Defaults remain unchanged in every outcome; passing both stages supports further evaluation of a named candidate, not automatic promotion.

On the two limiting-stress fixtures, additional identical-gain/filter comparisons remove mode caps alone, relax slew alone, and do both. Reuse existing records where applicable. These comparators cannot affect the frozen selection.

Activity reconstruction distinguishes actual slew clipping, amplitude clipping caused by a stricter mode cap, a stricter available-supply cap, or coincident caps. Equality with a limit alone is not counted as clipping. Hard-stop and bumpless-rebase samples are separate; zero raw command while stopped is not a counterfactual estimate of demanded actuation. Anti-windup correction changes the following integral state and is not an additional same-tick motor command. An inactive limit earns no measured benefit; active clipping must be considered alongside response changes from its paired diagnostic comparator.

The implementation is [the study runner](../03_MATLAB/scripts/run_phase3_tuning_study.m), [metric calculation](../03_MATLAB/functions/phase3_tuning_metrics.m), [comparative assessment](../03_MATLAB/functions/phase3_tuning_assess.m) and [criteria](../03_MATLAB/functions/phase3_tuning_criteria.m). Each pair preserves response and matched-clean CSVs, activity CSV and a complete MAT record. All work and evidence are local.

## Retained scope limits

The actuator, loads, disturbances and uncertainty ranges are assumed numerical fixtures. Zero terminal voltage permits loaded motion; this study does not redesign physical stop/hold behavior. It does not select hardware, prove a safe operating envelope, validate the independent reference, resolve single-sensor observability or establish EMI immunity. A better comparative controller score cannot close those gaps or the broader Phase 3 gate.
