# Phase 3 detection, observer monitoring and supervised control

Implemented numerical prototype: `PHASE3-PROTOTYPE-V1`, 2026-09-09. The base actuator remains `REPRESENTATIVE-ACTUATOR-V0.3`. Thresholds are assumptions, not measured operating limits. See the [acceptance report](Phase3_Implementation_Report.md).

## Available information

The online detector receives position, source sample index, new-packet flag and previous actual applied motor voltage. The supervisor additionally receives monitored bus health and an explicit operator reset. Reference and assumed constant load are known inputs. True state, disturbance windows, scenario labels and fault masks are used only to construct simulated measurements or score results offline. A regression changes offline masks and requires identical control.

Timestamp integrity, powered control/sensor rails, known initial zero state and knowledge of applied voltage are assumptions. Actual load and assumed load are separate fixture fields. `scenario.assumedLoadTorque_Nm` explicitly overrides the nominal configuration and is saved in the effective run configuration. Limited model-mismatch and unknown-load cases are included.

## Timestamp-aware observer

The discrete three-state observer estimates position, velocity and winding current. Each tick predicts using the previous applied voltage and assumed load. A packet from index `s` is compared with its stored source-time prior. Only a packet passing all gates corrects that prior. Actual applied voltages are replayed from `s` to the present; past controllers are not rerun. A bounded 32 ms history supports the 20 ms measurement-age limit.

Desired posterior poles are `exp(-[80 100 120]*Ts)`. The gain is placed for `(I-K*C)*A`, matching prediction then correction. This is a model observer, not a smoothing filter: its direct position correction can be negative while the three-state error dynamics remain stable. Tests independently verify poles, convergence and delayed replay.

New timestamps must be integer, causal and strictly increasing. Seen and trusted timestamps are separate: rejected data cannot refresh confidence or be reused; future timestamps cannot poison the watermark. Gates check finite values, position within ±180 degrees, source-time rate within 25 rad/s, and innovation within 0.5 degree. Residual hysteresis clears at or below 0.25 degree. Accepted innovations between clear and trip may correct the observer but do not qualify as credible recovery evidence.

Missing/held reception is neutral for up to 20 ms since the last trusted source and never advances recovery. Age greater than 20 ms raises an alarm; more than 250 ms makes the estimate unusable. Before the first packet, age runs from the declared initial estimate. The protected controller always uses the current posterior: rejected or missing data leave prediction-only feedback.

## Supervised states

IDs are 0 normal, 1 suspected, 2 degraded, 3 recovery, 4 safe_stop. Durations mean elapsed intervals: `N` observations span `(N-1)*Ts`. At 1 ms, 5 ms persistence needs six observations and 50 ms credible dwell needs 51.

| Condition | Current-sample action |
|---|---|
| Bus below 12 V or unusable estimate | Stop immediately, before other transitions. |
| First alarm in normal | Enter suspected. |
| Five milliseconds of consecutive alarms | Enter degraded. |
| Ten milliseconds of consecutive fresh credible samples in suspected/degraded | Enter recovery. |
| Fifty further milliseconds of consecutive credible samples in recovery | Return to normal. |
| Alarm during recovery | Return to degraded immediately. |
| Missing credible evidence | Reset the good count; absence within observer grace alone is neutral. |
| Non-normal episode reaches 500 ms | Stop before a coincident recovery completion. Suspected/degraded/recovery share the clock. |
| Stop release | Require healthy bus, usable estimate, 50 ms consecutive credible samples and explicit reset, then enter recovery and complete its separate dwell. |

A reset before qualification is ignored. The campaign uses a fixed one-sample reset at 2 s, independent of fault truth. Transition reasons are logged. An invalid observer estimate cannot defeat a commanded stop: the stopped control calculation receives an ignored finite placeholder while the invalid estimate remains in diagnostics.

## Controller and drive

Normal operation implements the existing PIDF's exact Tustin recurrence and matches the unconstrained legacy clean run. Normal/suspected use its 20 rad/s tuning target; degraded/recovery use a separately tuned 10 rad/s target plus a 50 ms reference filter. A tuning target is not a guaranteed achieved bandwidth under faults or saturation.

Mode voltage caps are 100%, 50%, 25%, 25%, and 0% of nominal command limit. Available bus is always an additional hard bound. Slew is 10,000 V/s in normal and 200 V/s otherwise; a tighter hard bound or stop overrides slew. Twenty-millisecond tracking anti-windup follows applied voltage. Mode/gain changes rebase PID state to previous applied voltage, avoiding artificial transfer jumps unless a new hard cap requires one.

Stop commands exactly zero terminal voltage while plant and load continue evolving. It is not an open circuit, brake, torque hold, MCU reset or verified emergency stop. The loaded interruption case demonstrates substantial load-driven drift. Voltage bounds do not establish mechanical, current, energy or thermal safety.

## Reproduction and evidence

From `03_MATLAB`, run `startup_project` then `phase3_main`. It creates a timestamped folder, runs focused tests, 29 fixtures with protected/baseline and matched-clean records (116 numerical runs), 58 independent-plant Simulink comparisons, and six additional ablation runs. Campaign and ablation entrypoints reject populated output folders. The Simulink validator writes to its caller-selected folder; use a fresh folder as the entrypoint does. MAT stores exact profiles/configurations; JSON uses null for disabled infinite point/window times.

The new Simulink model has an independently evolving actuator plant. Its interpreted S-function shares tested sensor/channel and decision helpers with MATLAB. Cross-validation verifies plant/scheduler integration and 23 numeric channels; it is not an independent implementation of the detector. Only innovation may be missing, with an exactly matching NaN mask. Other values must be finite; discrete fields exact; complete continuous traces must agree within 1e-9 without warnings. Wrong-project and stale-schema models are rejected. This research model is not embedded or real-time code.

The ablation compares legacy control, observer plus supervisor with normal gains and no extra derating, the addition of mode caps/slew, and full lower-bandwidth/filter policy. Protected variants share anti-windup, bumpless transfers and latched stop. Inactive bounds are not credited as measured improvements.

## Scoring and retained limits

Detection delay begins at first receiver exposure; source-to-receiver latency is separate. Preexisting responses are not credited. An absent response is missed only after its observation window completes; otherwise it is right-censored. Recovery reports the start of a normal interval confirmed by a separate complete 50 ms observation window, measured from the last receiver-exposed sample rather than the half-open fault-window end; insufficient tail remains censored. False alarms use nine declared clean/permitted fixtures and are not real-world rates. Tracking, matched-clean position/command changes, current, voltage effort and variation accompany detection.

Freshly timestamped frozen values at rest are unobservable with this single measurement. Small bias and slow drift can be absorbed and missed. A freeze accepted during low motion can bias the observer so that returning measurements fail its residual gate; the default dropout remains stopped because reset qualification is unavailable. Do not silently reseed from that disputed sensor. A justified reacquisition/re-homing policy or independent sensing is needed.

Physical stop/hold behavior, threshold calibration, wider uncertainty testing, actual timestamp/protocol behavior and measured sensor/load models remain open. The broad safety/performance wording of Gate 3 is not closed by this numerical prototype. Electromagnetic mitigation and the four-way RES-005 comparison remain Phase 4 work.
