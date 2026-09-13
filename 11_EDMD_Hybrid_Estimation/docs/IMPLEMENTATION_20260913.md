# Implementation note — 13 September 2026

This update adds diagnostics for the existing frozen predictors and a separate experiment that selects when to apply a learned innovation correction. It preserves the nominal observer, learned dictionaries, fitted operators, and original four-way comparison. The weighted variants are optional experiments, not promoted default predictors. The additional correction rule acts inside offline forecasts; it is not connected to the robot controller or protection logic.

This document describes implemented behavior and the evaluation protocol. The completed evaluation and its accuracy tradeoffs are recorded in [the update results](RESULTS_20260913.md), with generated reports and execution records in the cited result folders.

## 1. What is being predicted

The nominal reference observer uses measured encoder position and applied voltage to estimate position, velocity, and current. At sample k, its innovation is the measured encoder position minus the nominal prior position. The learned linear and quadratic EDMD models predict this innovation from its causal history and past applied inputs.

Every forecast starts from the nominal observer posterior at its origin. It receives the same recorded future voltage sequence as the other methods. At each future step, the implementation computes:

```text
physics prior       = nominal A * previous posterior + nominal B * supplied voltage
raw innovation      = outputMean + learned C * propagated lifted state
applied correction  = origin weight * raw innovation
predicted encoder   = nominal C * physics prior + applied correction
next posterior      = physics prior + observer L * applied correction
```

The predicted encoder reading is the primary output. The posterior position is a separate internal estimate and is scored separately. Future measured position, simulation truth, reference motion, and hidden load do not enter the recursive forecast.

The original learned models use weight one. The physics baseline uses zero future innovation. The persistent baseline applies the mean of the 20 most recent innovations. The weighted variants add a causal rule for choosing a weight at the origin, as described below.

## 2. Frozen-model diagnostics

`run_diagnostics.m` loads `selected_models.mat`, `test_records.mat`, and `study_plan.json` from an existing experiment. It does not refit or select models. Its intended source is the original four-way experiment. Reusing its previously inspected test records is exploratory diagnosis, not a fresh generalization test of a revised model.

The runner recomputes the benchmark and checks identical model/regime/run/horizon pairing, truth RMSE within 1e-12 radians, and identical nonfinite forecast counts against the stored per-run results. Matching infinities remain failures. It then writes endpoint records, event comparisons, model diagnostics, figures, and `Diagnostic_Report.md` into a new folder.

### Endpoint and event evidence

`forecast_endpoints.csv` retains each paired forecast origin and target, predicted position, truth and measured errors, posterior position error, failure status, correction weight and reason, and learned-candidate failure status. Truth is used only for offline scoring and event labeling.

`hybrid_endpoint_summary.m` produces trajectory-level bias, population standard deviation of signed errors, RMSE, nearest-rank 95th-percentile absolute error, and maximum absolute error. Summary RMSE, bias, spread, and percentiles are arithmetic means of the trajectory metrics; maximum error is the worst endpoint. Paired comparisons require the same origins. Overlapping origins are not independent experimental trials.

The event groups are all targets, targets within 50 ms before or after a true-velocity sign reversal, and targets away from those reversals. An initial departure from zero velocity is not a reversal. Across an exact zero-velocity plateau, the reversal time is the first subsequent nonzero sample with the opposite sign. Records without usable truth velocity remain in the all-target group and are excluded from both reversal groups.

Default forecast origins begin at or after 200 ms. Consequently, the initial startup interval is outside the evaluation coverage. The new scenario generator retains commanded-reversal and load-transition times as offline metadata, but the current event-summary function does **not** add load-step-specific groups or use commanded reversals instead of actual velocity reversals.

If a forecast fails, it stays in the counts and makes the affected trajectory's magnitude metrics infinite. Signed bias is undefined for failed groups. Two failed methods do not produce a valid finite paired improvement.

### Fit and recursive-lift evidence

`hybrid_model_diagnostics.m` skips the empty physics and persistent models and returns three tables:

| Table / saved file | Meaning |
|---|---|
| `modelSummary` / `model_diagnostics.csv` | Stored rank, rank reconstructed from the original truncation threshold, singular-value conditions, constant-coordinate checks, and full and affine-block spectral radii. |
| `singularSpectrum` / `singular_spectrum.csv` | Every stored training regressor singular value, retained/dropped status, effective ridge filter factor, and inverse gain. |
| `rolloutSummary` / `lifted_rollout_diagnostics.csv` | Held-out one-step errors, recursive quadratic consistency, constant-coordinate drift, and failure counts, with separate `run` and `trajectory_equal_weight` rows. |

The singular values come from the fit's normalized regressor matrix, including the current-input row. A direction is retained when its singular value s exceeds `svdTolerance * s(1)` and is positive. Its ridge filter factor is `s^2/(s^2 + ridge)` and inverse gain is `s/(s^2 + ridge)`; both reported effective weights are zero for dropped directions. These describe the regression before the fitter overwrites known constant and delay-bookkeeping rows. The positive-spectrum condition excludes exact zeros; the retained-spectrum condition also excludes truncated directions. Missing or empty cases remain undefined rather than being reported as well conditioned.

The exact constant coordinate creates a known unit eigenvalue. `affineSpectralRadius` examines `A(2:end,2:end)` and removes only that coordinate, not every eigenvalue near one. Its interpretation as the nonconstant affine block is flagged valid only if the constant row and its input coefficient are exact. Neither spectral radius certifies physical stability, bounded driven response, or closed-loop stability. The code deliberately does not report a raw induced norm of a coupled physics/lift matrix: position, velocity, current, and normalized polynomial features use different units. A properly scaled finite-horizon sensitivity analysis remains unimplemented.

The one-step lifted relative error is the Frobenius norm of predicted-minus-observed next features, divided by the norm of observed next features, excluding the constant coordinate. Features use the frozen training normalization. The decoded innovation RMSE is in radians; its normalized counterpart divides by the training output scale. These one-step quantities use the common forecast origins and are repeated across horizon rows; they are not multi-step prediction errors.

For recursive consistency, the learned state is advanced normally with the supplied inputs. Its predicted base-history coordinates are decoded with the training means and scales, then re-lifted only for comparison with its propagated quadratic coordinates. The comparison measures algebraic consistency of the redundant quadratic representation. It does not measure whether those predicted histories match the real future. The re-lifted state is never fed back into prediction, and a low consistency error is not evidence of forecast accuracy. Linear dictionaries have no quadratic constraint and report zero consistency error unless the forecast fails.

These diagnostics examine the raw, full-weight learned recurrence. They do not apply an attached `correctionPolicy`; weighted performance belongs to the correction study's scoring outputs. Failed origins and failed trajectories are retained in all relevant aggregations.

## 3. Fixed-at-origin causal correction

`hybrid_correction_weight.m` chooses a weight independently for each forecast origin using only information already observed at that origin. Its inputs are the frozen model, observed nominal-observer innovations, historical applied voltages, and origin indices. It does not inspect truth, regime labels, future innovations, or future voltages.

For each origin, the rule:

1. Requires a complete lookback window of completed one-step predictions. Each historical prediction is initialized from the observed history at its own previous sample, rather than from a recursively predicted history. The earliest eligible target index is `102 + delay`, preserving the fitting warmup convention.
2. Checks the current innovation/input history against the stored training minimum and maximum of each coordinate. The margin is 10% of the larger of that coordinate's training range and training scale. This rectangular range check is a heuristic support check, not a calibrated probability or a validated receiver-domain test.
3. Compares past innovation MSE for each allowed weight with zero innovation. The physics reference MSE here is `mean(observedInnovation.^2)`; it is not a multi-step position forecast loss.
4. Uses the weight with smallest historical MSE only when its relative improvement strictly exceeds the selected threshold. Weights are sorted with zero first, so equal minima favor the smaller weight. Missing lookback coverage, a history outside the training ranges, or a nonfinite historical learned prediction returns zero.

The selected weight stays fixed for the entire rollout. The same weighted correction changes both the predicted encoder output and the internal posterior update. The raw lifted recurrence continues independently; weighting does not clip eigenvalues, replace the dictionary, re-lift predicted histories, or retrain the model.

At zero weight, physics can continue even if the separately propagated learned candidate fails numerically. The implementation avoids evaluating zero times an infinite or undefined prediction, and still records the raw candidate failure. At a positive weight, a learned numerical failure remains a forecast failure through subsequent steps. The rule does not switch weights after observing a failure later in a rollout.

## 4. Selection and fresh-scenario protocol

`run_correction_study.m` loads the original four frozen methods and the original development validation records. It does not train new EDMD operators. It selects a policy separately for the learned linear and quadratic models.

Each model has ten candidate policies: an always-off policy, plus all nine combinations of lookback windows `[20, 100, 250]` samples and minimum relative improvements `[0, 0.1, 0.25]`. The nine adaptive policies allow weights `[0, 0.25, 0.5, 1]`. A long lookback can force an initial physics-only period even after the forecast warmup.

Selection minimizes mean trajectory-level 50 ms validation truth RMSE, subject to nominal validation mean RMSE being no more than physics plus 0.1 encoder count. One encoder count is `2*pi/4096` radians. This allowance is a declared research screen, not an established robot requirement or a guarantee on fresh cases. Absolute nominal errors must accompany any relative comparison. A policy can reduce nominal error while sacrificing accuracy under mismatch; passing this screen does not establish a winner across conditions. Offline truth enters this policy-selection score; it never enters the online weight decision. Strict score improvement is required to replace the current best candidate, so exact candidate ties preserve the earlier candidate, including the always-off fallback.

The runner writes `study_plan.json` before selection, saves every candidate's score in `validation_candidates.csv`, and saves the chosen policies and `selection_frozen.json` before generating the test data. Evaluation includes the original four methods plus `Weighted linear hybrid` and `Weighted EDMD hybrid`.

| Fresh test arm | Seeds | Count | Scenario |
|---|---|---:|---|
| Nominal, varied, nonlinear, stress | 230101–230110; 230201–230210; 230301–230310; 230401–230410 | 40 | Original multisine motion and smooth-load generator settings. |
| `nonlinear_transient` | 231101–231106 | 6 | Nonlinear parameters, explicit smooth reversals, and mechanical load steps. |
| `stress_changed_controller` | 231201–231206 | 6 | Stress parameters, the same scenario types, and both acquisition-controller gains at 75% of their defaults. |

All 52 specified trajectories last three seconds at 1 ms sampling. The explicit motion alternates 40-degree position waypoints with quintic rest-to-rest segments lasting 0.75 s. Load levels change at 1 s and 2 s from zero to the regime's positive load bound and then its negative bound. The altered acquisition controller keeps the derivative filter and voltage saturation while changing proportional and derivative gains.

The changed-controller and nonlinear-transient arms have different parameter regimes and seeds. Their difference cannot isolate the effect of controller gain alone. The new seed sets are disjoint from the original experiment, but repeated executions of this protocol reuse these same seeds; rerunning is reproducibility, not another untouched test set. Further tuning after inspecting them requires new evaluation data.

Scoring uses common origins every 20 samples after the 200 ms warmup and horizons `[1, 20, 50, 100, 250]` samples. `forecast_summary.csv`, `forecast_per_run.csv`, and `forecast_endpoints.csv` preserve output and failure comparisons. The event tables and `paired_comparisons.csv` provide trajectory-level comparisons with common origins. `weight_usage.csv` summarizes weights at the 50 ms endpoints, including the physics-fallback fraction and raw learned failures. The generated report must be read alongside per-trajectory errors and failure counts, not only mean weights or a favorable aggregate RMSE.

## 5. Reproduction

Use MATLAB with Control System Toolbox and the bundled reference files. From this bundle's directory, resolve and retain the source experiment path before running either new entry point:

```matlab
bundleRoot = pwd;
latest = jsondecode(fileread(fullfile(bundleRoot, 'results', 'latest_run.json')));
sourceRun = fullfile(bundleRoot, 'results', latest.folder);
disp(sourceRun)  % Retain this exact source path with the reproduction record.

checks = run_checks();
diagnostics = run_diagnostics(sourceRun);
correction = run_correction_study(sourceRun);
```

An explicit `sourceRun` keeps a later change to `results/latest_run.json` from silently selecting a different source. The source must contain the original four-way models, development validation records, test records, stored forecast scores, and study plan. `run_experiment` can regenerate that original training/selection experiment when needed; it is not necessary to inspect an existing one.

Both new runners create separate output folders and retain previous runs. Defaults use `results/diagnostics` and `results/correction_studies`; the optional second argument supplies another output root. Their latest pointers are `latest_diagnostics.json` and `latest_correction_study.json` inside those roots. Tests write `results/test_results.csv` and assert that all checks passed. A partial output folder or study plan alone is not proof of completion: check the runner's completion message, matching latest pointer, generated report, and `execution.json`.

## 6. Relation to the lectures and remaining experiments

Kutz's theory lecture emphasizes that the measured variable need not be the best state description at [3:57](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=237s), defines the learned operator as a least-squares compromise across transitions at [19:39](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=1179s), discusses selecting the retained singular subspace at [26:41](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=1601s), and explains short-horizon forecast limits and fitted exponential growth at [41:08](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=2468s). Those points motivate the separate fit, representation, and horizon diagnostics here. The causal weighting rule is this project's experimental design, not a rule demonstrated in the lecture.

At [21:05](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=1265s), Kutz allows nonconsecutive snapshot-pair starting times provided every pair has the same time advance. This implementation deliberately has a narrower data contract: contiguous, synchronous, fully valid 1 ms records. The lecture's more general sampling observation does not make this code a missing-packet or irregular-sampling observer.

State-informed dictionaries using additional causal observer estimates, a disturbance-augmented physics observer, alternative nonlinear observers, different delays, and further model families remain deferred experiments. None is implemented or validated by this correction study. Such additions need explicit information boundaries, matched validation, and new evaluation records after any selection decisions.

The present work uses hypothetical healthy actuator simulations and forecasts conditional on recorded future voltage. Synthetic `domainValid` means study eligibility only. It establishes no EMI receiver validity, fault classification, asynchronous-packet recovery, hardware performance, control intervention benefit, or closed-loop stability guarantee.
