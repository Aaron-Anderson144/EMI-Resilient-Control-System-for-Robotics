# Phase 3: separate numerical stop and hold study

Design `PHASE3-STOP-HOLD-V1.0`, declared 10 September 2026. This study compares three passive mechanisms after drive isolation: the existing ideal terminal short, a motor circuit with an external resistor, and an assumed mechanical brake combined with the short. It is a separate plant harness. It adds no operating-mode integration or Simulink brake model and changes no existing controller, observer, reset rule or default workflow. Preservation of the 148 previously verified MATLAB source/model files is checked separately.

The study requires 20 fixtures, three mechanisms and three integration steps: **180 planned numerical runs**. Local execution checks alone do not complete acceptance; an independent continuous hybrid audit is also required. Recorded outcomes and completed verification belong in the [study report](../03_MATLAB/results/development/phase3_stop_hold_20260910_150537/Phase3_Stop_Hold_Report.md). No motor or brake component has been selected, and these assumptions do not qualify physical stop/hold behavior or close Gate 3.

## Physical boundary and assumptions

The state is position theta, velocity omega and winding current i. The nominal SI constants remain R = 1.2 ohm, L = .0025 H, Kt = Ke = .08, J = .00015 kg m² and b = .0001 Nm s/rad. These are the existing representative actuator assumptions. Positive load torque opposes positive motion. With no external voltage source:

```text
theta_dot = omega
J*omega_dot = Kt*i - b*omega - loadTorque - brakeTorque
L*i_dot = -(R + Rext)*i - Ke*omega
motorTerminalVoltage = -Rext*i
```

| Mechanism | Rext | Brake capacity | Meaning |
|---|---:|---:|---|
| `terminal_short` | 0 ohm | 0 Nm | Zero motor-terminal voltage already provides electrical dynamic braking through winding resistance. |
| `resistor` | 1.2 ohm | 0 Nm | Passive resistor loop; motor-terminal voltage is **-Rext*i**, not zero. Copper and external-resistor heat are separate. |
| `mechanical` | 0 ohm | Up to .030 Nm | Terminal short plus symmetric bounded friction, with equal static and sliding capacity. |

At zero terminal voltage under constant load, omega tends to `-loadTorque/(b + Kt*Ke/R)`. For +.008 Nm this is -1.472393 rad/s, or -84.3619 degrees/s, with +.098160 A winding current. Thus a short brakes motion but cannot statically support this load. Adding 1.2 ohm external resistance reduces low-speed electromagnetic damping and increases the asymptotic drift magnitude to 2.891566 rad/s. Neither passive electrical circuit creates sustained holding torque at zero speed. This harness does not model an open circuit or delete inductive current at isolation.

The mechanical capacity is an assumed .030 Nm for both static support and sliding friction. Equality is a model simplification, not a measured property. Its 3.75 ratio to the nominal .008 Nm load is not a qualified design margin: motor torque, larger loads, gearing, wear and temperature remain relevant. The brake is represented by timed capacity as a candidate normally-applied mechanism, without a coil, power rail, switching device, backlash, compliance or hardware diagnostics.

## Capacity, failure and release timing

For a normally timed engagement, capacity remains zero for **30 ms**, then rises linearly to .030 Nm over **20 ms**. Full capacity therefore appears at 50 ms. The delayed-engagement fixture uses 50 ms delay plus the same 20 ms ramp. A pre-engaged fixture starts with full capacity; it does not erase initial velocity or current. Release starts at the declared release time and ramps capacity down to zero over 20 ms. Load steps and capacity knots align to all three integration grids.

`failedEngagement` sets capacity to zero. `failedRelease` suppresses the release ramp, leaving the brake applied. These are explicit injected mechanical conditions, not inferred from plant truth. Remaining held in the failed-release fixture is evidence of the intended failure behavior, not a successful restart. Releasing at zero source voltage under nonzero load should permit renewed motion. This study implements no torque handoff or supervisory permission to release.

## Exact discrete friction inclusion

[phase3_stop_hold_step.m](../03_MATLAB/functions/phase3_stop_hold_step.m) uses backward Euler for the coupled current/velocity equations. For interval h, old states omega0/i0, interval load T and right-end capacity C, define:

```text
ibar = i0 / (1 + h*(R + Rext)/L)
g = h*Ke / (L + h*(R + Rext))
D = J/h + b + Kt*g
F = J*omega0/h + Kt*ibar - T
omega1 = sign(F)*max(abs(F)-C, 0)/D
brakeTorque = clamp(F, -C, C)
i1 = ibar - g*omega1
theta1 = theta0 + h*omega1
```

This solves `brakeTorque in C*Sign(omega1)`, where Sign(0) is the interval [-1,1]. When the required discrete reaction fits inside capacity, the new velocity is zero and the reaction balances the step. Otherwise the brake saturates and slip remains. The torque bound limits the brake impulse to **C*h** per interval. A large initial speed or stored magnetic energy cannot be removed by an unconstrained state reset. Position advances through the integration rule; there is no command to snap it to a target. Holding current still decays according to the electrical equation.

The finite integration step adds dissipation and affects capture timing. Zero velocity at an implicit endpoint is not proof of an exact continuous-time capture event. Three grids and the independent continuous hybrid reference assess this approximation. The simulator uses the midpoint/left interval load for aligned load steps, samples capacity at the right endpoint and exports at 1 ms. Full-rate integration accumulates energy, peak current, absolute travel and capacity excess.

## Energy bookkeeping and gates

With E = J*omega²/2 + L*i²/2 and reciprocal SI constants Kt = Ke, each step satisfies:

```text
E1 - E0 = loadWork - copperLoss - resistorLoss - viscousLoss - brakeLoss - numericalLoss
loadWork = -T*omega1*h
copperLoss = R*i1²*h; resistorLoss = Rext*i1²*h
viscousLoss = b*omega1²*h; brakeLoss = brakeTorque*omega1*h
numericalLoss = J*(omega1-omega0)²/2 + L*(i1-i0)²/2
```

Positive load work means the external load adds energy, as during backdrive. The first four loss terms represent dissipation in the assumed physical elements. **Numerical loss is solver dissipation, not brake heat or winding heat**, and is reported separately. The exact discrete energy identity is a correctness check, not evidence that time-discretization error is negligible. The model rejects unequal Kt/Ke because this ledger relies on cancellation of reciprocal electromechanical power.

Integration steps are 100, 50 and 25 microseconds. Declared gates are energy closure at most 1e-10 J, brake capacity excess below 1e-12 Nm, and fine-grid numerical loss fraction at most .02 using `max(1e-8 J, initialEnergy + abs(totalLoadWork))` as denominator. Fine-grid comparison limits are .05 degree position, .02 rad/s velocity and .005 A current. Holding uses the final .1 s, velocity at most 1e-10 rad/s and declared drift tolerance 1e-10 rad. Independent auditing must check the continuous reference, refinement, energy exports, event/failure semantics and holding claims; successful MATLAB checks do not substitute for that audit.

## Frozen fixtures

All mechanisms use identical initial state, load and duration within each fixture. The source declaration is [phase3_stop_hold_fixtures.m](../03_MATLAB/functions/phase3_stop_hold_fixtures.m). Most records last .6 s; explicit exceptions are listed.

| Fixtures | Initial condition and event |
|---|---|
| `record_stop`, `record_stop_mirror` | Actual saved state at the earlier governed supply-stop entry, .873 s; load +.008 Nm and mirrored state/load; duration 1.126 s. The first short case replays through prior time 1.999 s. |
| `moving_positive_aiding`, `moving_positive_opposing`, `moving_negative_aiding`, `moving_negative_opposing` | Initial speed +/-8 rad/s, zero current; load +/- .008 Nm covers both motion and load signs. |
| `engaged_positive_load`, `engaged_negative_load` | Pre-engaged at rest, zero current, load +/- .008 Nm. |
| `engaged_load_reversal` | Pre-engaged; load +.008 to -.008 Nm at .3 s; duration .7 s. |
| `below_capacity`, `at_capacity`, `above_capacity` | Pre-engaged at rest; loads .0297, .0300 and .0303 Nm. Above-capacity slip is required behavior. |
| `overload_recapture` | Pre-engaged; .008, .039, .008 Nm at times 0, .3, .6 s; duration 1 s. |
| `current_breakaway` | Pre-engaged, zero speed and .6 A initial current; stored magnetic energy can initiate slip before eventual capture. |
| `delayed_engagement`, `instant_capacity` | Initial +8 rad/s; delayed full-capacity time 70 ms versus pre-engaged bounded capacity. |
| `release_under_load` | Pre-engaged at rest with +.008 Nm; release ramp starts .3 s; duration .7 s; renewed backdrive expected. |
| `failed_engagement`, `failed_release` | Missing capacity versus pre-engaged capacity retained despite a .3 s release request. |
| `no_load_moving` | Initial +8 rad/s, zero current/load; duration .8 s. |

Mechanical tail hold is expected except for `above_capacity`, `release_under_load` and `failed_engagement`. The successful representation of those exceptions must not be reported as successful load holding. Finite-capacity breakaway and recapture are separate from sensor fault detection and qualified controller reset.

## Reproduction and next work

From `03_MATLAB`, run `startup_project`, then `phase3_stop_hold_main`; the driver is `run_phase3_stop_hold_study`. It writes a frozen design, source manifest, 180 trace exports, metrics and a MAT archive in a new evidence location. Run the independent Python audit separately against that campaign; the study main intentionally reports that this audit is required. For the recorded package, the audit is saved with `results/development/phase3_stop_hold_20260910_150537/campaign` and accepts that campaign directory as its argument: `C:\Users\adand\anaconda3\python.exe audit_stop_hold.py <campaign_path>`. See the report for completed checks and exact reproduction paths.

The next local design step is a drive/brake handoff and interlock, together with a justified observable brake/reaction-torque model. At +.008 Nm, steady electrical holding alone needs .1 A and .12 V; establishing that torque is incompatible with silently retaining the present strict zero-voltage stopped contract. Brake reaction is also absent from the existing observer dynamics. Neither simulated true reaction torque nor a brake command bit may be relabeled as independent measured evidence. [Hardware identification requirements](../10_Hardware_Design/Hardware_Plan.md) remain open, alongside reference integrity, calibrated load/motion limits and physical stop validation. Gate 3 remains open; this comparison does not satisfy the electromagnetic four-way comparison RES-005.
