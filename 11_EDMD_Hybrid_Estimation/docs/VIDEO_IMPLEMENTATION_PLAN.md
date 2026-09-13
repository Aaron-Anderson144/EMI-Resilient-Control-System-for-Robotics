# Implementing the video lessons in the EDMD project

Historical proposal, preserved separately from the completed work. Diagnostics, optional causal correction weighting and transient scenarios were subsequently implemented. State-informed dictionaries and additional observers remain future experiments. See the [implementation details](IMPLEMENTATION_20260913.md) and [verification and validation review](VERIFICATION_AND_VALIDATION.md) for actual behavior and results.

September 13, 2026. Proposed changes to the existing EDMD Hybrid Estimation module. This document specifies implementation work; it does not report completed software changes or new experimental results.

**Objective:** Develop a useful learned correction that retains the accuracy of the nominal physics model and demonstrates any benefit from nonlinear observables on fresh evaluation trajectories.

The inspected module is `11_EDMD_Hybrid_Estimation/`. It already implements input-aware recursive lifting, training-only normalization, independent trajectory partitions, matched linear and persistent baselines, and multihorizon scoring. Build on those parts.

## 1. First milestone: diagnose the existing nominal error

Brunton identifies transients and nonstationarity as difficult cases at [14:50–15:22](https://www.youtube.com/watch?v=sQvrK8AGCAo&t=890s). Kutz emphasizes short prediction windows at [41:08–42:25](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=2468s). Implement those lessons by exposing when forecasts fail, before changing the learned model.

Extend `code/hybrid_score.m` with an optional third output containing one row for each model, trajectory, forecast origin and horizon. Retain origin time, target time, predicted position, true and measured target positions, signed errors, internal posterior-position error, and numerical-failure flags. Leave the existing summary outputs compatible.

Use the current 1, 20, 50, 100 and 250 ms horizons. Add a separate diagnostic summarizer and plots for:

- Mean signed error, RMSE, upper-tail absolute error and failure counts.
- Error growth with horizon, including predicted innovation and internal state contributions where useful.
- Comparisons around reversals and between settled and changing motion.
- Paired differences against physics, persistent innovation and the linear hybrid.

Keep event labels in evaluation data only. True velocity, hidden loads and simulated event times can support offline diagnosis, but cannot enter predictor or gate inputs. Define windows and overlapping-event treatment explicitly. Forecast origins currently begin at 200 ms, so the initial startup interval is not covered by those results.

Treat the already inspected test trajectories as exploratory evidence for this diagnosis. Aggregate and resample by trajectory; overlapping origins are not independent experimental runs.

**Completion criterion:** The new endpoint table reproduces the existing aggregate scores and reveals whether nominal degradation is primarily bias, scatter, event-specific error or accumulated rollout error. A negative finding is a valid outcome; this milestone does not require an improved predictor.

## 2. Add model diagnostics using the fitted models

Add a diagnostic function alongside `code/edmd_fit.m` and `code/hybrid_forecast.m`. Much of the required information is already stored in `model.training`: singular values, regressor rank, feature count and scaling.

Report the singular spectrum, numerical rank, retained rank and ridge filter effects separately. The selected models currently retain all 7 and 22 input-augmented regressor directions. Numerical full rank does not establish that every direction is useful for prediction. Any proposed rank truncation must preserve or restore the exact constant and history bookkeeping.

Check held-out lifted-feature evolution error and decoded position error separately. Also measure whether recursively advanced quadratic coordinates remain consistent with products of their corresponding predicted base coordinates. Do not silently re-lift to remove inconsistency; that changes the forecasting model.

Inspect finite-horizon behavior of the combined physics and innovation recursion. Its reported lifted spectral radius includes a deliberately constant coordinate, so that scalar cannot stand alone as a forecast-quality criterion.

The PyDMD tutorial provides a useful model-inspection example at [28:45](https://www.youtube.com/watch?v=v33cL3o2Yuk&t=1725s). A separate optimized/bagged DMD benchmark may be useful later, but copying its imaginary-axis constraint would impose inappropriate undamped dynamics without physical justification.

## 3. Test more informative observables in separate experiments

Kutz questions whether sensor measurements are the best descriptive coordinates at [2:16–4:31](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=136s). The dictionary is also central to the [EDMD formulation](https://arxiv.org/abs/1408.4408).

Implement small, distinguishable changes:

| Experiment | Added information or structure | Matched comparison |
|---|---|---|
| A | Causal nominal-observer velocity/current estimates | Linear model with those same estimates |
| B | A small friction-shaped function of estimated velocity | Model A without that nonlinear feature |
| C | Selected present-input interactions | Same observables with affine input only |

`code/hybrid_prepare_records.m` already returns observer traces separately. Use those traces to construct a declared feature interface, and update `code/edmd_snapshot_pairs.m`, `code/edmd_lift.m`, `code/edmd_fit.m` and `code/hybrid_forecast.m` consistently. Update the documented data contract, which currently permits only innovation and applied-voltage histories.

Future velocity/current estimates must be propagated using the declared forecast recursion. They cannot be read from observer traces that have already assimilated future measurements. At each forecast step, evaluate any state-dependent feature using information available before the next predicted correction, avoiding an implicit circular dependency.

Tune feature parameters on development data. Do not insert the simulator's hidden friction or load parameters. Keep input interactions as a separate change so their contribution can be identified. Controlled lifted predictors with affine input are legitimate approximations; extra interactions are a hypothesis, not a repair of an established bug. [Korda and Mezić](https://arxiv.org/abs/1611.03537)

## 4. Test a correction weight to protect nominal performance

After diagnosis, add an experimental weight to the innovation correction:

\[
\widetilde r_{k+1}=\alpha\widehat r_{k+1},\quad
\widehat y_{k+1}=C_p\widehat x^-_{k+1}+\widetilde r_{k+1},\quad
\widehat x^+_{k+1}=\widehat x^-_{k+1}+L\widetilde r_{k+1}.
\]

For the first experiment, choose alpha between 0 and 1 at the forecast origin and hold it fixed across that rollout. Alpha zero reproduces physics-only forecasting from the common initial posterior; alpha one reproduces the current full correction. Use the same weighted innovation in both the reported prediction and the internal observer update.

Calibrate the rule on development data using causal history, past completed one-step prediction performance and representation-domain checks. Do not use the true regime, true position error, hidden load, offline event labels or future innovations. A large residual alone cannot distinguish useful model-mismatch information from sensor corruption.

Apply the same rule and information to the linear and nonlinear candidates. Log the weight and reasons for fallback. Bypass a disabled learned branch rather than multiplying a nonfinite value by zero, while retaining the learned branch's failures in diagnostic counts.

Keep healthy observer preprocessing fixed. This experiment does not by itself add support for invalid receiver samples or ensure that the initial observer state is reliable during faults.

**Required checks:** Alpha zero matches the physics baseline; alpha one matches the existing learned forecast; weighting remains consistent through the recursion; future-data perturbations cannot change the origin's weight or features.

## 5. Evaluate on newly specified trajectories and operating conditions

Extend `run_experiment.m` to save a versioned study specification, freeze candidate and gate selection before evaluation, and retain the current run rather than overwrite its historical meaning.

Add a physics observer that estimates disturbances as a comparison. Keep nominal performance as an explicit requirement alongside mismatch improvements, with a predeclared absolute error allowance tied to project needs. The existing 10% EDMD benefit screen can remain as a separate comparison; do not loosen it after inspecting new outcomes.

The existing `code/study_generate_records.m` produces smooth multisine motion and smooth varying loads. Add explicit, separately labeled load-step scenarios and controlled reversals to study transients. A startup study requires its own initialization and eligibility rules.

Receiver faults require a separate data path: the current scorer and replay adapter reject invalid samples, and the hybrid generator contains no EMI or receiver model. Define handling of missing, stale and corrupted observations before introducing those tests. Distinguish synthetic measurement corruption from physically supported receiver-fault evidence.

First compare all methods with identical supplied input sequences. Then run a separate experiment where future voltage is generated by the actual feedback law from each candidate's evolving estimates. That second experiment assesses closed-loop behavior and requires its own control-performance and stability evaluation.

Finish with independent recordings in shadow mode, where the learned estimator logs predictions without issuing motor commands. Compare changed controllers and operating conditions before considering any connection to control or protection logic.

## Recommended first work package

Implement the optional per-origin forecast table, a nominal-error diagnostic report, and model-spectrum/rollout diagnostics. Reuse the frozen models for this exploratory pass. The deliverable should identify the most defensible next experiment and provide a reproducible comparison, while preserving the existing numerical baseline.
