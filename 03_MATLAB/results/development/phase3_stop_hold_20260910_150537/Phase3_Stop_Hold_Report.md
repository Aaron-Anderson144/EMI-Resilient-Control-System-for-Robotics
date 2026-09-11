# Phase 3: stopping and holding under load

Local numerical study completed 10 September 2026. The separate passive-brake harness passes its frozen numerical acceptance: **371 project tests, 180 simulation runs and 3,949 independent audit checks**. Sixty independent continuous solutions are compared against the 180 MATLAB traces integrated at 100, 50 and 25 microsecond steps.

For the previously recorded loaded stop, the assumed mechanical brake reduces motion from **92.797 degrees of backdrive to 1.692 degrees before holding**, with sustained capture about **46.875 ms** after the stop command. This supports continuing with a mechanical holding mechanism in the local integration design. It does not select hardware, establish an allowable stop distance or change the operating controller.

## Direct comparison with the recorded stop

All three mechanisms start from exactly the same saved state at earlier campaign time 0.873 s: position 0.723546877967973 rad, velocity -0.0870857854099103 rad/s and winding current 0.100005708034876 A. The load is +0.008 Nm; the comparison ends 1.126 s later, corresponding to prior time 1.999 s before the explicit controller reset. The independent exact linear replay verifies the earlier short-circuit trajectory.

| Mechanism | Travel over 1.126 s | Sustained capture | Final speed |
|---|---:|---:|---:|
| Existing terminal short | -92.796979 deg | No hold | -1.472393 rad/s |
| 1.2 ohm external resistor | -177.831456 deg | No hold | -2.891566 rad/s |
| Assumed mechanical brake + short | -1.691761 deg | 46.875 ms | -0.000000 rad/s |

Negative travel is load-driven backmotion. Holding preserves the reached position; the brake does not restore the target position. The ideal terminal short is already electrical dynamic braking. Its steady backdrive is -84.3619 deg/s under this load. The resistor moves part of the dissipation out of the winding but reduces low-speed electrical damping: it cannot supply static holding torque. In that circuit the motor-terminal voltage is -Rext*i, while the external source remains disconnected.

![Loaded-stop comparison](phase3_stop_hold_comparison.png)

## Frozen physical assumptions

The original representative DC-equivalent parameters remain R=1.2 ohm, L=2.5 mH, Kt=Ke=0.08 in reciprocal SI units, J=0.00015 kg m² and b=0.0001 Nm s/rad. The mechanical candidate has equal static and sliding torque capacity of **0.030 Nm**, zero capacity for the first **30 ms**, then a **20 ms linear ramp**. Full capacity is available at 50 ms. The equal static/sliding capacity and its 3.75 ratio to nominal load are assumptions, not a qualified margin.

The plant includes winding current throughout each transition. A bounded friction inclusion permits sticking only within finite torque capacity; an overload causes slip. The integration method limits brake impulse to capacity times the step duration and reports its extra numerical dissipation separately. There is no unconstrained velocity/current reset or target-position snap. Open-circuit switching is omitted because an inductive-current commutation path has not been specified.

## Capacity, delay, overload and release outcomes

All **20/20 expected mechanical outcomes** match. Seventeen end held; that count includes the intentional failure-to-release fixture. The other three deliberately continue moving: above-capacity load, release under load, and failure to engage. A correctly reproduced failure is not a successful operating action. Both load signs, both motion signs, load reversal while held, the exact capacity boundary and stored-current breakaway are covered.

| Mechanical case | Net / absolute travel (deg) | Last capture (s) | Interpretation |
|---|---:|---:|---|
| +8 rad/s; load assists motion | 12.664062 / 12.664062 | 0.054675 | Expected hold |
| +8 rad/s; load opposes motion | 8.263923 / 8.263923 | 0.041075 | Expected hold |
| +8 rad/s; capacity already applied | 4.422074 / 4.422074 | 0.020750 | Expected hold |
| +8 rad/s; 50 ms delay + 20 ms ramp | 8.436048 / 8.588142 | 0.060750 | Expected hold |
| 0.0303 Nm load exceeds 0.0300 Nm capacity | -1.817274 / 1.817274 | None | Expected continued motion |
| 0.039 Nm overload from 0.3 to 0.6 s | -26.448042 / 26.448042 | 0.608925 | Expected hold |
| 0.6 A initial current; brake already applied | 0.000562 / 0.000562 | 0.001000 | Expected hold |
| Release begins 0.3 s with zero drive | -30.127047 / 30.127047 | None | Expected continued motion |
| Brake never develops torque | -48.460640 / 48.460640 | None | Expected continued motion |
| Brake remains applied despite release request | 0.000000 / 0.000000 | 0.000000 | Expected release failure; still held |

Capture time is the last fine-step motion followed by a sustained zero-speed tail, measured from fixture start. All held cases have zero exported drift in their final 100 ms. The overload case still accumulates substantial travel before recapture; eventual holding does not undo that motion. Net and absolute travel are separate because a delayed stop can reverse direction.

![Delay, overload, release and energy behavior](phase3_stop_hold_boundaries.png)

## Independent verification and numerical error

The 371 passing tests comprise the previous 348 plus 17 bounded-friction/energy tests and six fixture/timing checks. The 180 traces span 20 cases, three mechanisms and three grids. All existing 148 MATLAB source/model files remain byte-identical; the optional harness introduces nine MATLAB files. No Simulink brake model or new integrated-supervisor validation is claimed.

The independent Python reference uses exact affine matrix exponentials for unbraked circuits, and event-separated continuous differential equations plus analytical stationary-current decay for mechanical sticking/slipping. It checks exact overload/stationary anchors, symmetry, prior-record replay, timing, finite capacity, passive dissipation and refinement. It does not reuse the MATLAB backward-Euler update. Both continuous-reference errors and successive-grid differences shrink within declared tolerances; numerical dissipation also decreases.

| Fine-grid numerical gate | Observed maximum | Declared limit |
|---|---:|---:|
| Position error at 1 ms export times | 0.00417104 deg | 0.05 deg |
| Velocity error at 1 ms export times | 0.00278491 rad/s | 0.02 rad/s |
| Current error at 1 ms export times | 0.00262649 A | 0.005 A |
| Numerical loss / declared energy scale | 0.597303% | 2% |
| Energy-balance residual, all internal steps and runs | 3.506e-14 J | 1e-10 J |

The discrete identity is change in stored kinetic/magnetic energy = signed load work minus winding, resistor, viscous, brake and numerical losses. Backdrive can receive energy from the load, so stored energy need not decrease monotonically. Numerical loss is not physical brake heat. Its scale is max(1e-8 J, initial stored energy + absolute net load work).

CSV traces export at 1 ms; internal integration steps are finer. The independent audit verifies exported states, cumulative ledgers and event behavior, while MATLAB accumulates travel, peak current and energy/capacity extrema at every integration step. BrakeTorque_Nm is the preceding substep's solved torque; its time-zero value is a placeholder. At a load knot, LoadTorque_Nm shows the new right-continuous load while the torque still describes the interval just completed. These columns must not be interpreted as simultaneous static reaction at those exact knots.

## Power and sensing implications

A powered electrical hold against +0.008 Nm would require **0.1 A**, **0.12 V** and **12 mW of winding heat** at zero speed in this model. Those are motor steady-state quantities; drive/controller consumption is additional. Such a hold needs continuous electrical power, trustworthy position/motion or load information, current regulation and thermal limits. It cannot silently replace the current strict zero-voltage stopped mode, particularly during a supply or sensing fault.

A normally-applied mechanical brake can support a load without motor power under the assumed capacity model, but actual engagement/release behavior, torque over temperature/wear, stop energy, duty cycle, electrical terminal state and diagnostic feedback still need identification. A command bit does not prove engagement. The existing observer also omits brake reaction torque; simulated truth cannot be passed off as measured feedback.

The next local implementation step is an explicit drive/brake handoff: establish and verify load-supporting torque before releasing the brake, define failed engagement/release behavior, and incorporate a justified brake-aware estimate. Gate 3 and physical stop/restart validation remain open. Independent-reference integrity, calibrated motion/current/load limits and wider model uncertainty also remain open.

## Saved evidence and reproduction

- [Frozen design](frozen_design.json), [all 180 run metrics](stop_hold_metrics.csv) and [acceptance decision](decision.json).
- [371 test results](all_project_tests.csv), [independent audit](independent_stop_hold_audit.json) and [solver errors](independent_solver_errors.csv).
- [Preserved-source verification](previous_source_identity_check.json), [frozen-source verification](frozen_source_check.json), [source changes](source_changes.csv), [source checkpoint](source_checkpoint.zip) and [rollback package](source_rollback.zip).
- [Independent audit program](audit_stop_hold.py), [local acceptance driver](acceptance.m), and [complete trace archive](stop_hold_traces.zip).

Project evidence is retained at `C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics\03_MATLAB\results\development\phase3_stop_hold_20260910_150537`. To verify the supplied package independently, extract `stop_hold_traces.zip` into a new folder, then run `python audit_stop_hold.py NEW_FOLDER` using Python with NumPy and SciPy. The archive includes an unchanged historical replay copy, so this verification does not depend on the original project location.

Run `startup_project` and `phase3_stop_hold_main` from the project's `03_MATLAB` folder for a new local campaign. Run the saved independent audit against that new campaign with the existing local SciPy environment. The main workflow labels its result provisional until the independent audit passes. The supplied acceptance driver additionally runs the full project test suite. Source checkpoint paths are project-relative; the rollback package preserves the eight changed prior documents and lists added files.
