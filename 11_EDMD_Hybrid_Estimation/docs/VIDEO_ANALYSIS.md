# DMD videos in relation to our EDMD work

Historical source analysis, preserved from before the implementation. For completed changes and current evidence, read the [implementation results](RESULTS_20260913.md) and [verification and validation review](VERIFICATION_AND_VALIDATION.md).

Analysis date: September 13, 2026. Project: EMI-Resilient Control System for Robotics.

**Assessment:** The material supports our use of lifted, input-aware dynamics, but our results still support a learned innovation correction rather than a demonstrated advantage from quadratic EDMD. The next useful experiment should test a more informative representation while preserving nominal accuracy and the matched linear comparison.

**Source coverage:** All three full English auto-generated transcripts were retrieved from the user's existing Chrome tabs and reviewed. The earlier access limitation is resolved. Time links below refer to those transcripts; automatic captions can misrender technical names and equations, so the official companion MATLAB example, the exact PyDMD notebook and primary research papers support the mathematical details. This is a complete transcript review, rather than an end-to-end audiovisual viewing. Project code and saved results were inspected; no simulations were rerun or project files modified for this analysis.

## What the three sources contribute

**1. Steve Brunton — Dynamic Mode Decomposition (Overview).** The [video](https://www.youtube.com/watch?v=sQvrK8AGCAo) introduces extracting coherent structures that evolve in space and time from high-dimensional data. Its value for our project is the distinction between describing a signal's amplitude and describing how its patterns evolve. Our signals are motor measurements and observer innovations, so an identified mode would describe a pattern in those measurements and histories. It would not automatically identify a physical EMI mechanism. The author's [chapter resource page](https://databookuw.com/page-3/page-10/) places DMD alongside Koopman methods and delay-based modeling.

Our application changes the data representation substantially: the physics observer already handles the nominal motor, while the learned model predicts the remaining innovation. Any modes therefore combine motor mismatch, measurement effects, controller excitation and observer dynamics. Establishing a physical interpretation would require experiments that vary those contributors independently.

The most relevant passage is [14:50–15:22](https://www.youtube.com/watch?v=sQvrK8AGCAo&t=890s): Brunton describes favorable behavior for periodic or quasiperiodic systems, then flags strong transients, intermittency and nonstationarity as more difficult. For our project, this suggests testing prediction around reversals, load changes and fault onset separately from settled motion. It does not establish that nonstationarity caused our existing EDMD result. At [15:24–15:58](https://www.youtube.com/watch?v=sQvrK8AGCAo&t=924s), he identifies regression choices, including noise-robust and sparsity-promoting variants, as extensions of the basic fitting problem.

**2. Nathan Kutz — Dynamic Mode Decomposition (Theory).** The [official lecture page](https://faculty.washington.edu/kutz/KutzBook/page26.html) links the user's [second video](https://www.youtube.com/watch?v=bYfGVQ1Sg98) and its MATLAB example. The companion code constructs successive snapshot matrices, uses a truncated SVD, calculates the reduced evolution operator and reconstructs two known oscillations. This is a clean numerical example, with a prescribed rank that should not become a default for motor data.

In a column-snapshot convention, the central fit is

\[
X_+\approx AX_-,\qquad A=X_+X_-^\dagger.
\]

The EDMD connection is to apply the fit to chosen functions of the measurements. The [original EDMD paper](https://arxiv.org/abs/1408.4408) establishes the dictionary-based approximation. Its discussion of missing and erroneous eigenfunctions shows why more data cannot compensate for every limitation of a fixed dictionary. For our project, adding every quadratic product is a candidate representation, not proof that the relevant nonlinear dynamics have become linear.

The full transcript adds four direct connections:

- [2:16–4:31](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=136s): Kutz distinguishes underlying state from sensor observations and questions whether measured variables are the best descriptive coordinates.
- [18:45–20:02](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=1125s): the fitted operator is a least-squares compromise across sampled transitions.
- [35:31–36:14](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=2131s): he discusses rebuilding the model as conditions change.
- [41:08–42:25](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=2468s): he emphasizes short forecast windows and explains how a small fitted growth rate can eventually produce divergence for a bounded system.

These passages strengthen the case for testing operating-condition dependence and useful prediction horizons. They do not prove that a larger dictionary, a rolling fit or forced stability would improve our motor forecasts. The two-frequency example above is companion-code material; it is not demonstrated in the theory video itself.

A timing distinction also matters: [21:05–22:20](https://www.youtube.com/watch?v=bYfGVQ1Sg98&t=1265s) permits irregular starting times for snapshot pairs provided each pair has the same time advance. Our current delay-history builder and replay adapter still require their documented uniform 1 ms timing. The lecture does not make those implementations compatible with irregular or missing samples.

**3. PyDMD: A Python Package for Dynamic Mode Decomposition (DMD).** The [third video](https://www.youtube.com/watch?v=v33cL3o2Yuk) has an exact [official companion notebook](https://github.com/PyDMD/PyDMD/blob/master/tutorials/video-tutorial-code/dmd-basic-tutorial.ipynb). It demonstrates noisy synthetic oscillations, optimized DMD, model attributes, reconstruction and a later bagged fit. That fit uses 100 trials, 80% of snapshots per trial and an imaginary-axis eigenvalue constraint. The transferable idea is to inspect sensitivity and the model's dynamical content, alongside prediction error. Its undamped synthetic signal does not justify imposing imaginary-axis eigenvalues on our motor. The exact notebook does not demonstrate delay embedding.

The presenter is Sara M. Ichinaga, speaking on Steve Brunton's channel; her name is confirmed by the video-linked [PyDMD paper](https://www.jmlr.org/papers/v25/24-0739.html). The transcript makes several limits explicit: rank 2 is supplied from the known construction at [26:48–27:37](https://www.youtube.com/watch?v=v33cL3o2Yuk&t=1608s), the reconstruction error against clean synthetic data is approximately 5% at [43:19–43:59](https://www.youtube.com/watch?v=v33cL3o2Yuk&t=2599s), and the more complex fit provides no major improvement in this example at [53:09–53:19](https://www.youtube.com/watch?v=v33cL3o2Yuk&t=3189s). The demonstrated reconstruction covers the sampled interval; the video does not demonstrate forecasting unseen trajectories. Its own result reinforces the need to measure whether added complexity earns a practical gain.

Useful chapter starts, verified from the video description:

| Time | Topic |
|---|---|
| [24:13](https://www.youtube.com/watch?v=v33cL3o2Yuk&t=1453s) | Building and fitting models |
| [28:45](https://www.youtube.com/watch?v=v33cL3o2Yuk&t=1725s) | Interpreting model attributes |
| [40:38](https://www.youtube.com/watch?v=v33cL3o2Yuk&t=2438s) | Reconstruction |
| [44:25](https://www.youtube.com/watch?v=v33cL3o2Yuk&t=2665s) | Summary plots |
| [50:28](https://www.youtube.com/watch?v=v33cL3o2Yuk&t=3028s) | More complex models |

## Connection to our actual implementation

The latest work is the hybrid innovation experiment in `11_EDMD_Hybrid_Estimation`, separate from the earlier direct-position EDMD study.

The nominal observer produces an innovation, meaning the difference between an encoder reading and its predicted reading:

\[
r_k=y_k-C_p x_k^-.
\]

The selected learned predictors use

\[
h_k=[r_k,r_{k-1},r_{k-2},u_{k-1},u_{k-2}]^T,
\qquad z_k=\psi(h_k),
\]
\[
z_{k+1}\approx Kz_k+G\widetilde u_k.
\]

The code fits adjacent lifted histories with SVD and ridge regularization, enforces the constant and history shifts, lifts once at each forecast origin, and advances the lifted state recursively. It then predicts the next innovation and combines it with the nominal physics forecast. This is an input-aware lifted predictor, not independent regression at each forecast horizon. Explicit input treatment follows the motivation of [DMD with control](https://arxiv.org/abs/1409.6358) and the controlled lifting framework of [Korda and Mezić](https://arxiv.org/abs/1611.03537).

Several safeguards are already present: normalization is learned from training data only; whole trajectories and seeds are partitioned; the model consumes measured innovations and applied voltage rather than hidden true states or actual loads; validation selects the models before test generation; prediction excludes future measurements; divergent outcomes remain in the results. These should be preserved.

## What our results establish

The experiment used 24 training, 12 validation and 40 held-out test trajectories, each three seconds at a 1 ms sample interval. Eighteen candidates tested degrees 1/2, delays 2/5/10 and three ridge strengths. Both selected predictors use delay 2 and ridge 0.001. The linear dictionary has 6 features; the quadratic dictionary has 21.

The table reports the mean of ten trajectory RMSEs against continuous simulated position at the 50 ms endpoint, in degrees. Every method receives the same recorded future applied voltages.

| Condition | Physics | Persistent innovation | Linear hybrid | Quadratic EDMD hybrid |
|---|---:|---:|---:|---:|
| Nominal motor | 0.00605 | 0.02602 | 0.18424 | 0.18596 |
| Parameter/load variation | 1.49376 | 0.32377 | 0.29746 | 0.29925 |
| Nonlinear friction | 2.86969 | 1.15482 | 0.80048 | 0.80101 |
| Stress | 7.07682 | 3.43414 | 2.37634 | 2.37867 |

The EDMD hybrid reduces error relative to physics by about 80%, 72% and 66% in the three mismatch regimes. The linear hybrid achieves essentially the same gains and is slightly better in every regime. All four paired bootstrap intervals for EDMD's improvement over the linear hybrid span zero. That supports **no demonstrated incremental EDMD benefit**; it does not establish a statistically meaningful universal superiority of linear models.

The nominal deterioration is the larger practical problem: EDMD's error is about 30.7 times the physics error. No regime passes the declared EDMD benefit screen, which requires at least 10% improvement over each comparison method, at least 7/10 paired wins against each, and no nonfinite predictions.

At 250 ms, EDMD mean trajectory RMSE grows to 2.67°, 4.49°, 8.26° and 22.87° across the four conditions. Finite arithmetic and a reported spectral radius of 1 therefore do not establish a useful forecasting horizon. The model includes an exact constant coordinate with eigenvalue 1 by construction. Interpreting its other eigenvalues still requires attention to forcing, transient amplification, model mismatch and the coupled physics/innovation recursion.

These are conditional simulated forecasts. Recorded future voltages would not automatically be available during live feedback operation. The hybrid experiment contains no EMI circuit or receiver, and healthy innovations are not direct measurements of physical disturbances. Consequently the results do not establish fault rejection, EMI immunity or improved closed-loop control.

## What to test next

**First, preserve nominal accuracy.** Compare physics, persistent innovation, the linear hybrid, quadratic EDMD and a physics observer that estimates disturbances. Test a causal rule that attenuates or disables learned corrections when validation evidence does not support them. Apply the same rule to both learned models so any improvement is not incorrectly attributed to the nonlinear dictionary. Keep healthy observer preparation fixed so a change in preprocessing does not confound the comparison. Freeze the rule using training/validation data and assess it on new held-out trajectories, with a declared nominal-performance requirement.

The transcripts add a focused diagnostic before expanding the model: compare the present global fit with a small operating-condition-specific alternative, and score settled motion separately from transitions. Any deployed condition selection must use information available at the forecast origin. Measure endpoint error, signed bias, large-error frequency and recovery across declared horizons. This would help distinguish a poor global compromise from inadequate observables; neither explanation has yet been isolated. A rolling model should remain an offline experiment until handling of corrupted training samples is established.

**Second, test information content before dictionary size.** Our selected history spans only 2 ms. Longer delays of 5 and 10 samples were already candidates, so simply adding delays repeats an explored direction. A more focused experiment would add the nominal observer's causal velocity and current estimates, then compare a matched linear representation against a small dictionary containing a smooth friction-shaped velocity function and selected interactions. Use estimates available at prediction time, never simulated true velocity, current or load. Each additional observable needs a defined multistep evolution; it cannot be refreshed from future measurements.

**Third, examine how input enters the lift.** Present input enters only as an affine term. Products among past inputs and innovations are included, but explicit current-input interactions such as a lifted state times current voltage are not. These may be worth testing for controlled nonlinear dynamics. Their absence is not an implementation bug and has not been established as the cause of the current result. Such terms change the predictor class and, for a future controller, may change the optimization problem.

**Fourth, add diagnostic evidence.** Inspect singular values, effective rank and conditioning; normalized held-out feature-evolution error; decoded position error; finite-horizon amplification; and sensitivity to regularization and training trajectories. Check whether recursively predicted quadratic features remain reasonably consistent with products of their predicted underlying coordinates. A discrepancy is a diagnostic of approximation error, not automatic grounds for re-lifting, which would change the model.

For repeated noisy fits, resample whole training trajectories or appropriate blocks while preserving sequence and input alignment. Optimized or bagged DMD can provide a separate diagnostic benchmark where its exponential model and forcing assumptions are appropriate; it is not a direct replacement for our controlled EDMD. Sensor noise can bias ordinary DMD, motivating careful estimator comparisons. [Dawson et al.](https://arxiv.org/abs/1507.02264)

When comparing spectra with PyDMD, distinguish discrete eigenvalues from continuous-time rates: \(\mu=\log(\lambda)/\Delta t\), with frequency \(\operatorname{Im}(\mu)/(2\pi)\), subject to sampling ambiguity. Ensemble spread requires calibration before it can be treated as reliable forecast uncertainty. PyDMD's `BOPDMD` performs bagging only when a positive trial count is supplied. [BOPDMD documentation](https://pydmd.github.io/PyDMD/bopdmd.html)

**Finally, test the actual operating conditions.** After healthy-data prediction improves, evaluate independent controller recordings, changed control laws, missing and corrupted samples, and receiver faults within a valid physical receiver model. The present replay adapter is a healthy-data interface. Its successful replay does not establish fault-handling capability.

Missing state information, noisy innovations, excitation, mixed operating regimes, regularization and the training objective are all possible explanations for the present result. None has yet been isolated. The most useful research question is: **Can a small, causally available, physically informed representation improve on the linear correction while retaining nominal accuracy on unseen trajectories?**

## Project evidence inspected

Project root: `C:/Users/adand/OneDrive/Desktop/Projects/EMI-Resilient Control System for Robotics/`.

The principal records are under `11_EDMD_Hybrid_Estimation/`:

- `README.md`, `docs/RESULTS.md`, `docs/DESIGN.md` and `docs/USING_YOUR_DATA.md`.
- `code/edmd_fit.m`, `code/edmd_lift.m`, `code/edmd_snapshot_pairs.m`, `code/hybrid_prepare_records.m` and `code/hybrid_forecast.m`.
- Run `results/tp76c650cf_8abb_4d22_8d57_24d2dc9d3462/`, particularly `selected_models.csv`, `paired_comparisons_50ms.csv` and the documented forecast summaries.
- The September 12 project verification record in `00_Project_Management/Reviews/2026-09-12/Complete_Verification/Verification_Report.md` reports reproduction of the same selection and benefit result. These are previously completed checks, not new tests performed for this analysis.
