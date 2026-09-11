# Phase 3: predeclared causal motion-envelope study

This design is frozen before the motion campaign. It tests whether a causal reference governor allows specified clean motion to remain inside the unchanged observer rate checks. Historical controller gains, observer thresholds, derating caps, recovery dwell and the default policy remain unchanged. The earlier controller-tuning rejection remains valid evidence; this study does not relabel its failed clean fixture as a new evaluation success.

The prior benign-noise reversal produced a position-rate alarm when the actual sampled plant velocity exceeded the 25 rad/s rate threshold. The first alarm had a small innovation, consistent with motion itself exceeding that check. The exact previous fixture and a noiseless control are development data. The eight new clean and eight new fault fixtures below are evaluation data. Two further diagnostics separate unknown load and plant-model mismatch from the nominal clean-motion claim. These are finite software examples, not hardware operating limits or a physical stop validation.

## Frozen reference transformation

Let `u[k]` denote the original requested position, `q[k]` the internal slew-limited position, and `r[k]` the shaped position sent into the existing control loop. With `Ts = 0.001 s`, `V = 10 rad/s`, `A = 200 rad/s²`, and `beta = min(1, A*Ts/(2*V)) = 0.01`:

```text
q[k] = q[k-1] + clamp(u[k] - q[k-1], -V*Ts, V*Ts)
r[k] = (1-beta)*r[k-1] + beta*q[k]
```

The declared request domain is `|u[k]| <= 120 degrees`. The fixtures start at zero, with `q = r = 0` and zero initial shaped velocity. The transformation uses the current request and its own prior state; future request knots, fault labels, plant truth, observer alarms and supervisor mode are not governor inputs. The governor is an additional upstream transformation; the existing degraded/recovery reference filter retains its separate meaning.

For finite differences `v[k] = (r[k]-r[k-1])/Ts`, the recurrence is `v[k] = (1-beta)*v[k-1] + beta*(q[k]-q[k-1])/Ts`. Each slew increment is bounded by `V*Ts`, so induction gives `|v[k]| <= V`. Consequently `|v[k]-v[k-1]|/Ts <= 2*beta*V/Ts <= A`, including arbitrary reversals of a bounded request. The slew update stays between its previous state and the current request; the filter is a convex combination. Therefore q and r remain within the global range of the initial condition and requests. These statements bound the sampled reference and its finite differences, not plant velocity, current, continuous-time intersample behavior, mechanical travel, or behavior under an unknown load. Gaussian noise has the specified standard deviation, not a deterministic amplitude bound.

## Fixtures fixed before evaluation

The executable declaration is [phase3_motion_fixtures.m](../03_MATLAB/functions/phase3_motion_fixtures.m). Every record spans 0 to 3 s at 1 ms. Requests hold their last value; every request begins at 0 degrees at time zero. Ranges below are half-open for injected windows and closed for offline score windows. Reference knots are written as `time:degrees`. All unlisted plant parameters and controller settings use the historical nominal defaults. The reset protocol is a fixed operator request at 2 s, not a response to an offline fault mask. No fixture supplies an independent position reference or a true-state recovery vector.

| Partition / id | Original request after zero | Declared condition | Score window (s) |
|---|---|---|---|
| Development: `development_original_noise_reversal` | .1:+45, 1.4:-45 | Exact prior `eval_benign_noise_reversal`; .005-degree Gaussian standard deviation, seed 260921 | 1.4–1.9 |
| Development: `development_noiseless_reversal` | .1:+45, 1.4:-45 | Same declaration with noise amplitude zero | 1.4–1.9 |
| Clean: `clean_step_80` | .137:+80 | Nominal plant/channel | .137–.837 |
| Clean: `clean_reversal_75` | .159:+75, 1.117:-75 | Nominal reversal | 1.117–1.917 |
| Clean: `clean_reversal_100` | .183:-100, 1.263:+100 | Larger opposite reversal | 1.263–2.163 |
| Clean: `clean_rapid_retargets` | .143:+75, .237:-80, .331:+110, .449:-65, .587:+95, 1.401:-30 | Retargets during ongoing motion | .143–2.101 |
| Clean: `clean_known_positive_load` | .193:+70, 1.213:-50 | Actual and assumed load both +.008 Nm | 1.213–2.013 |
| Clean: `clean_known_negative_load` | .171:-85, 1.157:+60 | Actual and assumed load both -.006 Nm | 1.157–1.957 |
| Clean: `clean_new_noise_reversal` | .167:+85, 1.239:-65 | .005-degree Gaussian standard deviation; new seed 260932 | 1.239–2.039 |
| Clean: `clean_permitted_delay_jitter` | .179:+90, 1.087:-90 | 8 ms fixed delay plus 0–8 ms seeded jitter during .613–1.413; seed 260933 | 1.087–1.887 |
| Fault: `fault_count_jump_reversal` | .131:+55, .997:-65 | One 128-count primary impulse at 1.027 s | .997–1.527 |
| Fault: `fault_out_of_range` | .163:+70 | +4 rad primary error during .823–.824 | .823–1.223 |
| Fault: `fault_moving_freeze` | .151:+95 | Primary position held with fresh timestamps during .231–.381 | .231–.831 |
| Fault: `fault_short_packet_gap` | .149:+60, 1.187:-40 | Missing packets during .547–.657 (110 ms) | .547–1.057 |
| Fault: `fault_long_packet_gap` | .173:+35 | Missing packets during .611–1.001 (390 ms) | .611–2.4 |
| Fault: `fault_loaded_supply_interruption` | .181:+40 | Zero motor bus during .873–1.139; actual and assumed load +.008 Nm | .873–2.4 |
| Fault: `fault_persistent_bias` | .139:+40 | +5-degree primary bias from .687 through record end | .687–1.287 |
| Fault: `fault_excessive_delay` | .157:+65, 1.287:-45 | 35 ms fixed packet delay during .733–1.133 | .733–1.533 |
| Diagnostic: `diagnostic_unknown_load` | .197:+70, 1.173:-60 | Actual load +.001 Nm; assumed load zero | 1.173–1.973 |
| Diagnostic: `diagnostic_model_mismatch` | .211:+80, 1.293:-70 | Actual R +10%, inertia +15%; nominal observer unchanged | 1.293–2.093 |

The exact old development scenario name and description are retained for replay. New evaluation reference trajectories differ from all preceding tuning/evaluation trajectories. The nominal, permitted-noise and permitted-channel claims apply only to the declared deterministic fixtures; they do not cover arbitrary noise realizations, unmodeled load or arbitrary motor parameters.

## Comparison and evidence separation

Run the unchanged historical policy with the governor disabled and enabled for each fixture. Each policy has a paired clean companion obtained by removing the declared corruption, retaining the original requested position, benign noise, plant parameters, actual/assumed load, initial state and fixed reset. The main policies use exactly the same original request and all nonreference profiles, including actual corruption values and packet schedules. Their only deliberate difference is the causal reference transformation. A diagnostic companion retains its unknown load or model mismatch; removing sensor injection cannot turn that discrepancy into a nominal model.

The planned numerical set is 20 fixtures × 2 policies × 2 paired conditions = 80 runs. The planned Simulink comparison set has all 20 governed fault/declared-condition records plus the two raw development records, for 22 comparisons. The existing 315 regression tests and the new meaningful unit/fixture checks precede acceptance. Numerical/Simulink agreement establishes agreement between these software realizations; it does not establish physical validity.

Record original requested position and shaped command separately. Report full-record and fixed-window tracking error against both, as well as the final absolute error and final 0.1 s RMSE against the original request. Report original-request-to-shaped-reference error/lag, true sampled plant speed, measurement-candidate speed where defined, peak current, actual command/cap/slew clipping, mode residence, alarms, stop entry, reset release and recovery. Any undefined candidate speed remains visibly undefined; do not convert it into a reassuring zero. Good tracking of a delayed shaped reference alone does not demonstrate good tracking of the user's original request. No gain-promotion score is defined in this study.

Offline fields `partition`, `kind`, `window_s`, `alarmDeadline_s`, `responseKind`, `requireStop` and `requireResetRelease` must not enter the observer, controller or governor. Plant truth is used for simulation and offline metrics only. Controller/observer inputs remain received primary samples with timestamps, available drive information and the declared assumed plant/load model. Reference shaping cannot make a stale, corrupted or unsupported measurement credible.

## Predeclared gates and response protocol

All governed clean evaluation fixtures must have zero observer alarms, remain in normal mode for the complete record, have sampled true peak speed at most 20 rad/s, and have each defined measurement-candidate peak speed at most 25 rad/s. The 20 rad/s empirical plant check preserves a 20% margin below the unchanged 25 rad/s observer rate threshold. Each also requires final absolute original-request error at most .5 degree and final 0.1 s original-request RMSE at most .5 degree. The two development replays receive the same reported clean checks but are identified as previously observed development data. Shaped-reference velocity/acceleration/range checks are verified independently. Finite plant and command values, actual command within the available command limit, and zero command while stopped apply to every main and paired-clean record.

| Fault id | Required response kind | Absolute deadline (s) | Require eventual stop | Require qualified reset release |
|---|---|---:|---|---|
| `fault_count_jump_reversal` | Alarm | 1.028 | No | No |
| `fault_out_of_range` | Alarm | .824 | No | No |
| `fault_moving_freeze` | Alarm | .281 | No | No |
| `fault_short_packet_gap` | Alarm | .572 | No | No |
| `fault_long_packet_gap` | Alarm | .636 | Yes | Yes |
| `fault_loaded_supply_interruption` | Stop | .874 | Yes | No |
| `fault_persistent_bias` | Alarm | .737 | Yes | No |
| `fault_excessive_delay` | Alarm | .758 | No | No |

`alarmDeadline_s` is the existing metadata name for an absolute required-response deadline; `responseKind` determines whether the response is an observer alarm or stop entry. Sensor and communication faults require alarms. Supply interruption requires stop and may have no observer alarm. Clean and diagnostic fixtures use `responseKind = "none"` and a NaN deadline. Count a response only at or after the first receiver exposure from the offline `receiverFault` record and by the declared deadline. A response already active before that exposure receives no detection credit.

The long packet gap exceeds the 250 ms prediction horizon. Its modest, settled request and exact nominal plant/assumed model are deliberately declared before results so that prediction and subsequently returned primary packets can be assessed without inventing an independent anchor. Release still requires the actual separate 2 s reset and at least 51 credible fresh primary samples spanning 50 ms, followed by the existing recovery dwell. This requirement is an empirical test expectation, not a guarantee that a single encoder can recover from arbitrary sensor freezes. The persistent-bias record retains corruption during the reset and must not gain credibility from the request alone. The loaded supply record requires stop but does not require release; zero commanded voltage still permits loaded drift and is not a validated mechanical hold.

Freeze detection is tested while the declared trajectory moves. It does not imply detection of every stationary freeze or observability of absolute sensor bias from one position channel. Unknown-load and model-mismatch diagnostics retain their discrepancy and receive reported outcomes, not the nominal clean-performance pass claim. If an evaluation gate fails, preserve the fixtures, bounds and observer thresholds, report the failure and its evidence, and retain historical defaults. Any subsequent design change needs a new named declaration and new evaluation evidence; no post-result relabeling or threshold adjustment is authorized by this design.
