# Hybrid experiment results

The hybrid predictor improved short-horizon forecasts when the simulated motor differed from its model. **Quadratic EDMD did not beat the simpler linear correction**, and both learned versions made the nominal case less accurate. No condition passed the EDMD benefit screen.

These results come from the hybrid experiment in run `tp76c650cf_8abb_4d22_8d57_24d2dc9d3462`. The [earlier assessment](PREVIOUS_ASSESSMENT.md) tested direct position prediction. It is a separate experiment.

## Protocol

The experiment used 24 training, 12 validation and 40 held-out test trajectories, each three seconds at 1 ms. Whole trajectories and random seeds were separated by partition. The test set contained ten runs in each of four conditions. All trajectories were newly simulated for this experiment, with seed ranges recorded in [study_plan.json](../results/tp76c650cf_8abb_4d22_8d57_24d2dc9d3462/study_plan.json).

The representative model has position, velocity and current states, a 24 V drive and 4096-count/revolution encoder. Generated measurements include encoder quantization and 0.08-count standard-deviation noise. The acquisition controller uses measured position and a filtered measurement difference. The initial position, velocity and current are assumed known to be zero.

The nominal condition matches the reference motor. Variation changes resistance and inertia by up to 20%, changes viscous damping, and adds unknown time-varying load bounded by 0.005 Nm. The nonlinear condition adds smooth Coulomb friction of 0.003–0.008 Nm. Stress increases parameter variation to 35%, friction to 0.012 Nm, load to 0.012 Nm and reference speed. These are hypothetical test assumptions. The acquisition controller differs from the historical project's controller, and the experiments do not simulate an EMI circuit or receiver.

A healthy, ungated nominal observer produces the innovations used for training. The fit gets those innovations and the applied-voltage history. Simulated truth, hidden load, parameter labels and reference trajectories are kept out of the features and fitting targets. Truth is used only to select models on validation data and score the results offline.

Eighteen candidates combine degree 1/2 dictionaries, delays 2/5/10 and ridge strengths 1e-10/1e-6/1e-3. Training normalization is reused unchanged. The lowest equal-trajectory mean validation error at 50 ms selects one candidate for each degree. Both models were saved before test generation. Models were not retuned on test results.

Both selected models use **delay 2 and ridge 0.001**. The linear model has 6 lifted features; EDMD has 21. Their input-augmented regressor ranks are 7 and 22 respectively. Their reported spectral radii are 1, including the exact constant coordinate. This is not a stability or bounded-error guarantee. Six lightly regularized candidates produced enormous but finite validation errors, retained in [candidate scores](../results/tp76c650cf_8abb_4d22_8d57_24d2dc9d3462/validation_candidates.csv).

## Primary result: 50 ms

All four methods start from the same nominal observer posterior. They receive the same recorded future voltages and no future measurements. The persistent baseline holds the mean of the previous 20 innovations. Learned hybrids predict future innovations and use the documented physics-plus-innovation recursion.

Test origins begin at 200 ms and advance by 20 ms. A common 250 ms endpoint limit leaves **128 origins per test trajectory at every reported horizon**. Validation selection at 50 ms uses 138 origins per trajectory, identical for all candidates. Each table entry below is the mean of ten trajectory RMSEs against continuous simulated position, in degrees.

| Condition | Physics | Persistent | Linear hybrid | EDMD hybrid | EDMD improvement vs physics |
|---|---:|---:|---:|---:|---:|
| Nominal | 0.00605 | 0.02602 | 0.18424 | 0.18596 | 30.7 times the error |
| Varied | 1.49376 | 0.32377 | 0.29746 | 0.29925 | 79.97% |
| Nonlinear | 2.86969 | 1.15482 | 0.80048 | 0.80101 | 72.09% |
| Stress | 7.07682 | 3.43414 | 2.37634 | 2.37867 | 66.39% |

EDMD was slightly worse than the linear hybrid in every condition: mean error increased by 0.93%, 0.60%, 0.066% and 0.098%, respectively. EDMD won only 4/10, 4/10, 5/10 and 5/10 paired trajectories. Paired trajectory bootstrap intervals for its relative improvement over the linear model span zero in all four conditions. These intervals are descriptive, based on ten trajectories per condition and 10,000 paired resamples; they are not adjusted for multiple comparisons.

Compared with holding the recent innovation constant, EDMD reduced error by 30.64% under nonlinear friction and 30.74% under stress. The varied case improved by 7.58%, with only 6/10 paired wins and an interval spanning zero. The linear hybrid achieved the same gains, so these results do not show a benefit from the extra nonlinear features.

The declared screen requires at least 10% improvement over **each** of physics, persistence and the linear hybrid, at least 7/10 paired wins against each, and no nonfinite EDMD forecasts within the regime. No regime passes. Full comparisons and intervals are in [paired_comparisons_50ms.csv](../results/tp76c650cf_8abb_4d22_8d57_24d2dc9d3462/paired_comparisons_50ms.csv).

## Longer horizons and numerical behavior

The selected predictors stayed finite at every tested horizon, but their errors still grew substantially at 250 ms. EDMD mean trajectory RMSE reached **2.67°, 4.49°, 8.26° and 22.87°** for nominal, varied, nonlinear and stress conditions. The linear hybrid was slightly better in every condition at that horizon too.

In stress, 70.47% of EDMD's 250 ms endpoint forecasts exceeded the study's 10° large-error screen. This threshold is an analysis choice, not a robot safety requirement. No EDMD 50 ms endpoint exceeded 10° in this particular test set. Finite arithmetic therefore does not establish usable long-horizon behavior.

The reported forecast is `C*xprior + predictedInnovation`: the expected encoder position. The internal posterior position uses a different expression and has its own `posteriorTruthRMSE` column in the per-run table. Innovations include noise and observer behavior as well as model error. They do not directly measure a physical disturbance.

## Verification and conclusion

The original version 0.1 release passed **32 automated checks**, including the log-replay adapter. They covered known-input timing, independent observer recursion, simulation integration accuracy, history bookkeeping, future-data causality, exclusion of hidden truth from prediction, invalid-data rejection, and retention of divergent forecasts. The [preserved verification summary](../provenance/verification_summary_v0_1.json) records that historical check. The current expanded suite and reproducibility review are described in [Verification and validation](VERIFICATION_AND_VALIDATION.md).

An independent audit verified all 76 seeds and measured/truth trajectories are distinct, the selected candidates are the validation minima, all 800 test-result rows have the expected coverage, and all twelve paired comparisons reproduce from the per-run table. A compatibility check also replayed the previously inspected `DEV01_BASELINE_clean` controller log: 3,001 rows and 2,800 eligible finite EDMD one-step forecasts. That check establishes file compatibility, not hardware performance or successful EMI detection.

The implementation shows how a learned innovation forecast can work alongside nominal physics. The results support further testing of the simpler linear correction. They do not justify putting EDMD in the protection or motor-control path. The remaining work includes preserving nominal accuracy, handling uncertainty, comparing disturbance observers, testing faults, collecting independent physical data and checking behavior with another controller.
