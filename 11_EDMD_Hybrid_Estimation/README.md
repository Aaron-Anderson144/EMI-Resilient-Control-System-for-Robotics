# EDMD Hybrid Estimation

**Version 0.2.1 — verified offline research prototype for the EMI-Resilient Control System for Robotics.**

**Larry Anderson — Research collaborator and technical adviser.** Larry Anderson is recognized as a key project contributor. See the [professional contribution record](CONTRIBUTIONS.md).

The idea is simple: keep the motor's physics model and learn when its predictions tend to be wrong. This folder contains the MATLAB code, trained models, simulations, a tool for replaying controller logs, and the results.

## Original benchmark

The hybrid approach helped when the simulated motor behaved differently from the physics model. At 50 ms, its error was about 66–80% lower than nominal physics in the three mismatch conditions. But **quadratic EDMD did not beat the simpler learned linear correction**. Both learned corrections also made things worse when the physics model already matched the motor well. For now, this is an offline research prototype.

Mean error across ten unseen trajectories per condition, in degrees; lower is better:

| Condition | Nominal physics | Simple persistent correction | Linear hybrid | EDMD hybrid |
|---|---:|---:|---:|---:|
| Matching motor model | 0.0061 | 0.0260 | 0.1842 | 0.1860 |
| Parameter and load variation | 1.4938 | 0.3238 | 0.2975 | 0.2992 |
| Added nonlinear friction | 2.8697 | 1.1548 | 0.8005 | 0.8010 |
| Larger mismatch and faster motion | 7.0768 | 3.4341 | 2.3763 | 2.3787 |

For these 50 ms forecasts, every method was given the recorded future voltages. That makes this a prediction test; it does not show better closed-loop control or EMI resilience. The [results and limitations](docs/RESULTS.md) explain what the numbers mean.

## Start here

Open this folder as MATLAB's current folder. **All 74 automated checks passed** with MATLAB R2026a and Control System Toolbox. Reference motor parameters and required functions are included; the original robotics project is not needed to rerun it.

```matlab
run_checks          % Verify the prototype
run_verification    % Repeat tests, all model fits, selection and saved evidence
run_experiment      % Repeat training, validation and held-out simulation
run_diagnostics     % Inspect frozen errors, events, spectra and recursive lift
run_correction_study % Select optional correction weights, then score new scenarios
```

Each experiment creates a new results folder and updates `results/latest_run.json`. Existing runs are retained. To inspect the supplied results without retraining, open [the comparison figure](results/tp76c650cf_8abb_4d22_8d57_24d2dc9d3462/forecast_comparison.png) or [the detailed results](docs/RESULTS.md).

The diagnostic and correction runners create separate result folders and pointers. They preserve the original `latest_run.json`, trained predictors and replay defaults. The [implementation note](docs/IMPLEMENTATION_20260913.md) describes their data contracts and protocol; [the update results](docs/RESULTS_20260913.md) report the completed comparison.

The [verification and validation review](docs/VERIFICATION_AND_VALIDATION.md) records the timing/replay fixes, independent evidence audit and current acceptance limits. Software verification passed; the original incremental EDMD-benefit screen failed all four regimes. Hardware, receiver-fault and closed-loop validation have not been established.

The [three-video analysis](docs/VIDEO_ANALYSIS.md) and [historical implementation proposal](docs/VIDEO_IMPLEMENTATION_PLAN.md) preserve the reasoning behind the changes. The result and verification reports distinguish implemented work from remaining experiments.

The EDMD folder includes its simulated records and trained models, including the complete verification reproductions. On Windows, use a short checkout path if local path-length limits prevent opening deeply nested evidence folders.

To replay a compatible, healthy controller log:

```matlab
log = replay_controller("C:\path\to\controller.csv");
```

The replay uses the models identified by `results/latest_run.json`. It writes one-step predictions and prediction errors into a new replay folder. Required fields and timing assumptions are documented in [Using your data](docs/USING_YOUR_DATA.md). It consumes recorded measurements and actual applied voltage, without issuing motor commands.

## How it works

1. Run healthy motion and record encoder position and applied voltage.
2. Calculate how far each encoder reading differs from the nominal observer's prediction.
3. Learn patterns in that difference using either a linear or quadratic EDMD dictionary.
4. Forecast the difference alongside the physics model and compare the resulting position forecasts with simpler alternatives.

The correction predicts the expected encoder reading. The estimated motor state used inside the model is a separate quantity. The [design note](docs/DESIGN.md) explains the difference and the equations.

## Folder guide

| Location | Contents |
|---|---|
| `run_checks.m`, `run_experiment.m` | Verification and reproducible experiment entry points |
| `run_verification.m`, `verification/` | Full MATLAB reproduction and independent Python evidence audit |
| `run_diagnostics.m`, `run_correction_study.m` | Frozen-model diagnosis and validation-selected correction experiments |
| `replay_controller.m` | One-step replay of compatible healthy logs |
| `code/` | Physics observer, innovation preprocessing, learned predictors, scoring and figures |
| `tests/` | Timing, causality, numerical and data-boundary checks |
| `results/` | Original 76 trajectories, 52 additional evaluation trajectories, diagnostics, candidate scores and figures |
| `docs/` | Design, findings, data contract, original primer and earlier assessment |
| `reference_project/` | Snapshot of the representative motor parameters and required reference functions |
| `CONTRIBUTIONS.md` | Project contributor credit and acknowledgments |
| `PROVENANCE.md`, `package_manifest.json` | Source origins, run history and final file hashes |

## Development decision

Keep the linear hybrid as the simpler learned comparison. The new optional weighting rule uses completed prediction errors and training-domain checks to decide how much correction to apply. In the additional simulated trajectories it reduced nominal 50 ms EDMD error from 0.1842 to 0.0077 degrees, compared with 0.0061 degrees for physics. It also gave up substantial accuracy under larger mismatch; it is not a general replacement for the unweighted predictor.

Diagnostics now expose signed error, reversal behavior, singular directions, ridge filtering and recursive feature consistency. The additional scenarios include load steps, reversals and a changed acquisition controller. State-informed dictionaries, a disturbance-estimating observer, independent recordings and receiver-fault tests remain subsequent experiments.

The robot's existing controller and protection logic have not been connected to the learned correction.
