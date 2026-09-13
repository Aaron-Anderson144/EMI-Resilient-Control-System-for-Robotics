# EDMD assessment for the EMI robotics project

The quadratic EDMD prototype is not ready to replace the project's observer. At the planned 50 ms horizon, its nonlinear features improved on a learned linear predictor by less than 1%, with a small regression in one condition. Both learned models helped when the motor model was wrong, but the simpler linear predictor provided nearly all of that benefit. On the existing clean project records, the physics observer was substantially more accurate than EDMD.

This finding applies to the tested prototype, dictionary and simulation. A better Koopman formulation may still be possible. For now, keep the physics observer and test a simpler learned correction or disturbance estimator before connecting a learned model to the controller.

## What was tested

The study used the project's representative three-state DC-equivalent actuator parameters and its original observer functions. A separate measured-position PD controller generated diverse, bounded motion trajectories. It is an acquisition controller for this study, not a reproduction of the historical project controller.

- 24 training trajectories: eight each for nominal dynamics, parameter/load variation and nonlinear friction.
- 12 validation trajectories: four per training condition.
- 40 test trajectories: ten per condition, including an additional stress condition outside the training ranges.
- Each trajectory lasts three seconds, sampled at 1 ms, with 4096-count/revolution position quantization and added observation noise of 0.08 count standard deviation.
- Eighteen candidates covered linear and quadratic dictionaries, 2/5/10 delays and three ridge strengths. Model settings were selected using validation data only, and saved before test generation. Normalization used training observations only.

The varied condition changes resistance and inertia by up to 20%, varies viscous damping, and introduces unknown time-varying loads bounded by 0.005 Nm. The nonlinear condition adds smooth Coulomb friction of 0.003–0.008 Nm. Stress expands parameter changes to 35%, friction to 0.012 Nm and load to 0.012 Nm. These values are hypothetical modeling assumptions. No EMI circuit, receiver exposure or hardware is simulated in these new trajectories. Commands remained unsaturated, so this study does not establish behavior under drive saturation.

The primary outcome is the mean of the ten trajectory-level position RMSEs at 50 ms. Forecasts also cover 1, 20, 100 and 250 ms. All models use the same 133 origins per test trajectory after 100 ms warmup. Each forecast begins with measurements available at its origin and advances without future measurement correction. True position is used only for scoring; error against encoder measurements is also retained.

Every forecast is conditional on the recorded future voltage sequence. That sequence would not automatically be known during an actual feedback or dropout event. This is an offline prediction comparison, not a closed-loop control experiment.

## Prediction results

Mean trajectory-level position RMSE at 50 ms, in degrees:

| Test condition | Learned linear | Quadratic EDMD | Nominal physics with gates disabled |
|---|---:|---:|---:|
| Nominal | 0.318 | 0.316 | 0.0064 |
| Parameter and load variation | 0.395 | 0.395 | 1.564 |
| Added nonlinear friction | 0.818 | 0.817 | 3.012 |
| Stress outside training ranges | 2.263 | 2.254 | 6.042 |

The last column uses the original nominal dynamics and correction gain, with every fresh measurement accepted. It helps separate model error from the effect of rejecting measurements. Disabling the gates is a diagnostic comparison, not a proposed control policy.

Relative to learned linear, EDMD changed mean error by +0.62%, −0.05%, +0.18% and +0.37% improvement, respectively. None met the predeclared 10% practical-improvement screen. The small stress improvement has a positive paired bootstrap interval, so the result is not an assertion that every difference is statistically absent. Its magnitude is too small to justify the added model size here.

The selected linear model has 22 lifted coordinates; quadratic EDMD has 253. Both selected ten delays and ridge 1e-10. Their retained regression ranks were 17 and 136, respectively. EDMD's nonlinear feature expansion therefore adds substantial size with essentially the same primary predictive accuracy.

The unchanged original observer performs well under nominal dynamics but frequently loses measurement trust under the hypothetical mismatches. Its mean fraction of unusable forecast origins was 0% nominal, 62.9% varied, 67.4% nonlinear and 74.4% stress. Numerical forecasts from those origins remain in the records, but are not treated as trusted deployed estimates. The ungated diagnostic above shows that learning helps with model mismatch even after separating this gate effect; learned linear achieves almost the same benefit as EDMD.

### Longer forecasts

At 250 ms, EDMD improved mean error relative to learned linear by about 38% nominal, 27% varied, 17% nonlinear and 5% stress. This is a secondary positive signal. Absolute EDMD errors remained approximately 4.0°, 5.8°, 7.7° and 17.0°, respectively. Across these forecasts, 20.2% exceeded 10° error. This does not support using the current learned model for extended uncorrected operation.

Both selected models have fitted eigenvalues outside the unit circle: spectral radii are approximately 1.021 for linear and 1.016 for EDMD. These describe the learned predictors, not the stability of the physical robot. Some rejected short-delay candidates also produced extremely large finite validation errors; they were retained in the candidate table rather than hidden.

### Transfer to existing project records

After model selection, the study scored the two distinct saved clean trajectories from the existing four-way development campaign. These were additional transfer checks, not newly opened project evaluation cases.

| Saved trajectory | Existing physics observer | Learned linear | Quadratic EDMD |
|---|---:|---:|---:|
| DEV01 BASELINE clean | 0.0132° | 0.498° | 0.570° |
| DEV01 SW ONLY clean | 0.0123° | 0.556° | 0.642° |

EDMD was about 14–16% worse than learned linear on these records, and much worse than the existing observer. These checks give a direct reason to keep the present observer.

## Encoder anomaly sensitivity

Each learned model received a threshold fixed from healthy validation residuals: the larger of the empirical 99.9th percentile absolute one-step prior residual and one encoder count. Linear and EDMD thresholds were approximately 1.054 and 1.049 counts.

The test independently perturbed observations at 0.8 and 1.8 seconds by ±1, ±4 and ±16 counts. Each prediction used only the preceding clean history, and no fault entered the controller or later observations. A clean threshold crossing at the same instant received no detection credit.

Both learned models detected every isolated 4- and 16-count probe. Across 160 one-count probes, EDMD detected 73 and learned linear 70. EDMD also produced more healthy residual crossings in every condition, with a slightly lower threshold. These results do not demonstrate a monitoring advantage from the quadratic features.

| Condition | Healthy crossing fraction, linear | Healthy crossing fraction, EDMD |
|---|---:|---:|
| Nominal | 0.048% | 0.055% |
| Parameter and load variation | 0.093% | 0.103% |
| Nonlinear friction | 0.121% | 0.134% |
| Stress | 3.547% | 3.657% |

These are raw crossings without persistence or hysteresis, not controller alarm rates. The fixed probe times do not capture the full stress-condition crossing burden. The saved comparison also includes a recalibrated screen on the original observer's residual; model mismatch and expired trust inflated that threshold to about 38.3°. That screen is not the original controller's alarm logic, and its poor jump sensitivity is not evidence of superiority over the project's full detector and supervisor.

## Verification and interpretation

All 26 prototype, generator, scorer and residual-probe tests passed. The generator was checked against exact linear zero-order-hold propagation and finer nonlinear integration; tested position discrepancies were below 4e-10 rad. An independent audit verified 800 forecast-result rows, 40 test trajectories, common forecast origins, retained numerical failures and all 1,440 jump-probe rows. No selected model produced nonfinite forecasts; finite forecasts with large errors are still failures of useful prediction.

Bootstrap intervals resample whole trajectories. Overlapping prediction windows are not independent experiments. The ten test trajectories per condition support a bounded screening result, not a hardware reliability estimate. Only quadratic observables and 2–10 ms measurement/input histories were explored. The fit is affine in the current input, uses noisy regressors, and does not explicitly estimate unknown load. Better dictionaries, longer or differently spaced histories, constrained fits and noise-aware identification remain possible research directions.

The current physical receiver-domain limitation remains unresolved. No out-of-domain receiver traces were used as training evidence or to claim EMI resilience. Source project files and frozen experiments were unchanged.

## Recommended next implementation

Retain the existing observer for nominal operation. The next useful comparison is a disturbance-augmented physics observer versus a small learned residual correction, with learned linear kept as the baseline. A future EDMD revision should first demonstrate a material advantage over that baseline using fresh held-out trajectories and stable multi-step behavior. Any candidate should initially run alongside the controller without influencing commands, with source-time replay, missing-measurement handling and supervisory integration verified separately.

Learning may still help estimation when the model is wrong. These results do not yet justify full EDMD controller integration.

## Saved evidence

The earlier study and prototype are separate archives; their full outputs are not included in this hybrid package.

The reproducible study, models, development/test trajectories and detailed CSV results are in `edmd_robot_study/runs/tp6d389707_9044_47c6_890d_f70abc06312e`. The companion `edmd_prototype` folder contains the original fitter and predictor. `README.md` in the study folder gives reproduction commands. The figures `forecast_comparison.png` and `forecast_horizons.png` summarize all four predictors.
