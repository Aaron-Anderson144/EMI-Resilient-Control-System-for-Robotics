# Causal correction weighting study

The original learned models are frozen. A rule selected on development trajectories chooses a fixed rollout weight using completed one-step prediction errors and training-domain checks. Evaluation uses 52 fresh trajectories generated only after selection.

- Linear hybrid: window 250 samples, minimum past relative improvement 0.25, available weights [0 0.25 0.5 1].
- EDMD hybrid: window 250 samples, minimum past relative improvement 0.25, available weights [0 0.25 0.5 1].

Selection requires nominal validation RMSE within 0.10 encoder count of physics, an explicit research allowance rather than an established robot requirement. This is not a guarantee on new cases.

## Fresh 50 ms results

| Condition | Model | Mean trajectory RMSE (degrees) | Failed endpoints |
|---|---|---:|---:|
| nominal | Nominal physics | 0.00609297 | 0 |
| varied | Nominal physics | 1.48397 | 0 |
| nonlinear | Nominal physics | 2.80089 | 0 |
| stress | Nominal physics | 6.14634 | 0 |
| nonlinear_transient | Nominal physics | 3.58565 | 0 |
| stress_changed_controller | Nominal physics | 8.73343 | 0 |
| nominal | Persistent innovation | 0.0260564 | 0 |
| varied | Persistent innovation | 0.310066 | 0 |
| nonlinear | Persistent innovation | 1.14199 | 0 |
| stress | Persistent innovation | 3.49325 | 0 |
| nonlinear_transient | Persistent innovation | 0.80891 | 0 |
| stress_changed_controller | Persistent innovation | 2.00102 | 0 |
| nominal | Linear hybrid | 0.180612 | 0 |
| varied | Linear hybrid | 0.278457 | 0 |
| nonlinear | Linear hybrid | 0.782172 | 0 |
| stress | Linear hybrid | 2.43068 | 0 |
| nonlinear_transient | Linear hybrid | 0.629621 | 0 |
| stress_changed_controller | Linear hybrid | 1.50469 | 0 |
| nominal | EDMD hybrid | 0.184216 | 0 |
| varied | EDMD hybrid | 0.280764 | 0 |
| nonlinear | EDMD hybrid | 0.782338 | 0 |
| stress | EDMD hybrid | 2.43238 | 0 |
| nonlinear_transient | EDMD hybrid | 0.62608 | 0 |
| stress_changed_controller | EDMD hybrid | 1.50688 | 0 |
| nominal | Weighted linear hybrid | 0.00795799 | 0 |
| varied | Weighted linear hybrid | 0.394354 | 0 |
| nonlinear | Weighted linear hybrid | 0.964463 | 0 |
| stress | Weighted linear hybrid | 5.00811 | 0 |
| nonlinear_transient | Weighted linear hybrid | 0.948826 | 0 |
| stress_changed_controller | Weighted linear hybrid | 8.15666 | 0 |
| nominal | Weighted EDMD hybrid | 0.00774069 | 0 |
| varied | Weighted EDMD hybrid | 0.396483 | 0 |
| nonlinear | Weighted EDMD hybrid | 0.964688 | 0 |
| stress | Weighted EDMD hybrid | 5.00968 | 0 |
| nonlinear_transient | Weighted EDMD hybrid | 0.94638 | 0 |
| stress_changed_controller | Weighted EDMD hybrid | 8.15677 | 0 |

## Correction use

| Condition | Model | Physics-only origins (%) | Mean correction weight |
|---|---|---:|---:|
| nominal | Weighted linear hybrid | 98.67 | 0.0086 |
| varied | Weighted linear hybrid | 6.25 | 0.9375 |
| nonlinear | Weighted linear hybrid | 6.25 | 0.9375 |
| stress | Weighted linear hybrid | 28.36 | 0.7164 |
| nonlinear_transient | Weighted linear hybrid | 6.25 | 0.9375 |
| stress_changed_controller | Weighted linear hybrid | 44.53 | 0.5469 |
| nominal | Weighted EDMD hybrid | 98.67 | 0.0086 |
| varied | Weighted EDMD hybrid | 6.25 | 0.9375 |
| nonlinear | Weighted EDMD hybrid | 6.25 | 0.9375 |
| stress | Weighted EDMD hybrid | 28.36 | 0.7164 |
| nonlinear_transient | Weighted EDMD hybrid | 6.25 | 0.9375 |
| stress_changed_controller | Weighted EDMD hybrid | 44.66 | 0.5462 |

All methods receive the same recorded future voltages and use healthy synchronous observations. Explicit load steps and reversals test transients; the changed-controller arm scales both acquisition-controller gains to 75%. The original protection/controller implementation is not connected to this correction. No EMI receiver, missing-sample recovery, hardware or improved closed-loop-control result is established.

Use trajectory-level paired comparisons, not independent-sample claims from overlapping origins. Any subsequent tuning makes these test cases development evidence and requires new evaluation data.
