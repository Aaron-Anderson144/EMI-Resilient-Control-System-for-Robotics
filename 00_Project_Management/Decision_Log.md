# Decision Log

Use this file to record decisions that change the project architecture, scope, models, tools, or acceptance criteria.

| ID | Date | Decision | Rationale | Alternatives | Consequence | Status |
|---|---|---|---|---|---|---|
| DEC-001 | 2026-09-08 | Use MATLAB/Simulink as the primary system-modeling environment. | Integrates plant, controls, tests, and future code-generation workflows. | Python-only workflow | Requires an appropriate MathWorks license. | Accepted |
| DEC-002 | 2026-09-08 | Begin with a three-state DC-equivalent actuator model. | Establishes a transparent control baseline before adding switching complexity. | Full BLDC inverter model immediately | Switching and commutation effects are deferred. | Accepted |
| DEC-003 | 2026-09-08 | Use a 1 ms initial controller sample time. | Representative starting point for a servo controller; subject to revision. | Faster or slower sampling | Computational load and bandwidth studies remain future work. | Provisional |
| DEC-004 | 2026-09-08 | Treat all starter motor values as assumptions. | No physical motor has been selected or measured. | Present values as identified parameters | Prevents overstating model validity. | Accepted |
| DEC-005 | 2026-09-08 | Separate clean baseline and EMI-injection phases. | Prevents hidden disturbances from contaminating reference results. | Build one combined model immediately | Requires explicit model variants or enabled subsystems. | Accepted |
| DEC-006 | 2026-09-08 | Use explicit string-array labels for exported MATLAB legends. | MATLAB R2026a interprets the earlier positional legend syntax differently. | Retain the older syntax | Improves release compatibility without changing model behavior. | Accepted |
| DEC-007 | 2026-09-08 | Represent initial encoder dropout as hold-last behavior. | A receiving interface commonly retains the most recent accepted sample; the stale flag remains available to future detection logic. | NaN, zero substitution, or extrapolation | Prevents numerical collapse while exposing stale-data risk. | Accepted |
| DEC-008 | 2026-09-08 | Maintain independent MATLAB and Simulink Phase 2 implementations. | Numerical cross-validation reduces the chance that a block-diagram wiring error is mistaken for physical behavior. | Simulink-only implementation | Adds validation code but improves traceability. | Accepted |
| DEC-009 | 2026-09-08 | Represent Phase 2B near-field coupling with finite-edge analytical peak equations and a receiver-equivalent baseband envelope. | The 1 kHz controller model cannot resolve individual edges of the assumed 20 kHz PWM source. | Alias the PWM waveform into the controller model; immediately build a switching model | Enables controlled system-level sensitivity studies without claiming PWM-waveform fidelity. | Accepted |
| DEC-010 | 2026-09-08 | Label Phase 2B coupling, receiver, and communication values as assumed parameters under `REPRESENTATIVE-ACTUATOR-V0.2`. | No cable geometry, receiver circuit, installation, or hardware measurement has been selected. | Treat the values as identified parameters | Requires parameter sweeps and later physical identification before engineering limits are inferred. | Accepted |
| DEC-011 | 2026-09-08 | Use an explicit phenomenological volts-to-radians sensitivity for the initial system-level feedback study. | The current model needs a bounded bridge from receiver differential voltage to controller-visible error but does not include a digital encoder decoder. | Threshold/count-event decoder model; direct prescribed angular fault | Results describe equivalent feedback sensitivity, not bit errors, threshold crossings, or a physical encoder transfer law. | Provisional |
| DEC-012 | 2026-09-08 | Model communication as timestamped sample packets with seeded delay/loss, newest-timestamp acceptance, out-of-order rejection, and hold-last reception. | A causal scheduling model exposes stale data, collisions, and packet age without requiring a full protocol stack. | Variable-delay signal block only; detailed CAN bus simulation | Protocol arbitration, retransmission, and physical-layer errors remain outside the present scope. | Accepted |
| DEC-013 | 2026-09-08 | Use half-open disturbance windows and matched no-fault delta metrics for Phase 2B. | Exact sample counts and baseline subtraction prevent the commanded step transient from obscuring the incremental fault response. | Whole-run tracking metrics only | Adds pre/active/post masks, recovery dwell logic, and explicit censored recovery reporting. | Accepted |

## Sensitivity-study decisions, 2026-09-09

| ID | Date | Decision | Rationale | Alternatives | Consequence | Status |
|---|---|---|---|---|---|---|---|
| DEC-014 | 2026-09-09 | Use declared exploratory linear/log ranges and a seeded stratified design for Phase 2B sensitivity. | No measurement-based parameter distributions exist. | Treat arbitrary ranges as physical uncertainty | Results rank modeled effects within the design; sampled fractions are not real-world failure probabilities. | Accepted |
| DEC-015 | 2026-09-09 | Use a shared [0.70, 1.15) s metric window for physical-only and combined sensitivity contexts, with fixed communication settings/seeds. | Makes RMSE denominators and paired comparisons consistent. | Different active windows by context | Physical-only metrics include 0.15 s before physical onset; time-window semantics are documented. | Accepted |
| DEC-016 | 2026-09-09 | Sweep signed line imbalance while preserving paired means, and screen inactive/diagnostic settings explicitly. | The implemented equations depend on imbalance and omit several reserved receiver mechanisms. | Independently scale each positive/negative line without distinguishing imbalance | Negligible modeled sensitivity is not interpreted as physical unimportance. | Accepted |
| DEC-017 | 2026-09-09 | Specify SC-01A as a finite-edge electrical harness before a device-parameterized half-bridge. | Source, cable and receiver hardware have not been selected or measured. | Assume transistor switching data or enforce the commutation slope on motor-winding current | Allows circuit-equation and convergence checks while retaining explicit assumed provenance. | Implemented and numerically verified, 2026-09-09 |

## New Decision Template

| ID | Date | Decision | Rationale | Alternatives | Consequence | Status |
|---|---|---|---|---|---|---|
| DEC-XXX | YYYY-MM-DD |  |  |  |  | Proposed |

## SC-01A implementation decisions, 2026-09-09

| ID | Decision | Rationale and consequence | Status |
|---|---|---|---|
| DEC-018 | Use native conserving Simscape capacitors, resistors and a shared return inductor, checked against an independent three-state exact affine solution. | Loading and line asymmetry determine common-mode conversion. Old scalar path factors and volts-to-radians gain are not applied to this network. | Implemented |
| DEC-019 | Declare 47/53 ohm source resistances, 50/70 pF shunt capacitances, 10/20 kilohm bias returns and finite intended logic stimuli as assumptions. | The receiver network needs explicit loading and reference paths; no selected component data exist. Open-circuit source levels differ from loaded receiver levels. | Implemented, physical values provisional |
| DEC-020 | Use prescribed series M*dI/dt sources for SC-01A inductive excitation. | Self-inductances and geometry are unavailable. These sources verify equation/sign response without claiming reciprocal mutual inductance. Negative cases are signed zero-to-negative perturbations. | Implemented |
| DEC-021 | Mark ideal source jumps with duplicate-time left/right input data, require warning-free completed native simulations, and refine actual integration settings. | Early zero-order-held pulses caused minimum-step warnings. Exact event encoding resolves jumps without input smoothing; returned diagnostics and a reject-on-warning gate expose numerical issues. | Implemented and tested |
| DEC-022 | Treat +/-0.20 V receiver-band residence and noise crossings as illustrative diagnostics. | The model has no identified receiver hysteresis, short-pulse response or quadrature decoder. Band exposure does not establish output glitches or count errors. | Implemented |

## SC-01B implementation decisions, 2026-09-09

| ID | Decision | Rationale and consequence | Status |
|---|---|---|---|
| DEC-023 | Use the installed Infineon IAUC100N04S6L014 charge-based model and compare its Simscape conversion with original equations in portable ngspice 41. | Independent engines check circuit realization and numerical conversion; shared vendor equations do not provide independent physical validation. Vendor model code remains an installed dependency. | Implemented |
| DEC-024 | Use a UCC27211A-informed behavioral driver: 12 V, typical 20/19 ns delays, assumed 3 ohm drive resistance and 20 ns command ramps. | A transparent fixed approximation avoids claiming the full IC, bootstrap, UVLO or nonlinear output-stage behavior. External gate resistance is varied explicitly. | Implemented, physical values provisional |
| DEC-025 | Start from consistent high-side-on DC operation and retain one off/on commutation pair. | The load current follows the 2.5 mH series load and circuit drops; no forced winding-current slew or physical periodic steady-state claim. | Implemented |
| DEC-026 | Use explicit local trapezoidal integration with step refinement and separately recorded nonlinear consistency tolerances. | Initial global-solver pilots failed; fixed integration steps are actual network steps, not output resampling. All warnings reject production runs. | Implemented |
| DEC-027 | Retain the frozen 47 ohm gate-drive stress failure and inspect internal channel currents. | Both engines reproduce the spike, and internal channels confirm simultaneous conduction even with zero 6 V midpoint overlap. Do not tune the holdout or widen event windows to manufacture a pass. | Implemented; mitigation open |
| DEC-028 | Report signed drain-plus-gate terminal energy and exterior circuit energy closure. | Terminal energy includes stored-charge transfer and must not be labeled semiconductor heat. Source work, external resistance losses and external storage changes are accounted separately. | Implemented |
| DEC-029 | Retain rejected strict-tolerance SPICE attempts as failed checks while evaluating the rest of the matrix. | The nominal all-tight check aborts at the first gate corner despite multiple numerical-control probes. No partial trace, successful process exit code or voltage-only check can substitute for the missing required reference. | Implemented; full numerical acceptance open |

## SC-01B R2 resolution decisions, 2026-09-09

| ID | Decision | Rationale and consequence | Status |
|---|---|---|---|
| DEC-030 | Preserve SC01B and identify the driver remedy as SC01B_R2: +12/−1.5 V, unchanged charge resistance, 3 Ω discharge path and unchanged 300 ns dead time. | Fixes the declared five-case model while retaining transistor equations. Negative rail and ideal split impedance are new assumptions; the existing cases were used for design selection. | Numerically verified; physical implementation open |
| DEC-031 | Use exact clipped-linear B sources and fixed 1 ns TSTEP with independent TMAX. | Resolves the strict ngspice 41 limitation without smoothing, retiming, vendor-model edits or relaxed tolerances. Actual integration knots and finer-step/TSTEP-sensitivity evidence are retained. | Verified |
| DEC-032 | Gate all required execution, unclipped energy/event records and zero above-floor native channel overlap; bind native and SPICE results to source/runtime hashes. | Waveform agreement or successful software tests alone cannot clear switching behavior. Independent CSV and solver-evidence audits supplement the full campaign. | Verified |

## Parameter integrity and supply/load integration, 2026-09-09

| ID | Decision | Rationale and consequence | Status |
|---|---|---|---|
| DEC-033 | Apply requested plant, controller, reference, load, timing and limits through shared SimulationInput configuration and require the updated model schema. | Metadata must describe the actual simulation; stale or wrong-project models fail explicitly. | Implemented; local acceptance recorded in the v0.3 development report |
| DEC-034 | Retain both motor-voltage and signed load-torque plant inputs in analytical and Simulink models. | A configured nonzero load must affect motion and drive effort. | Implemented with an independent linear load-response comparison |
| DEC-035 | Represent supply faults as an averaged motor-bus voltage while control/sensor rails remain powered. | Zero supply forces zero terminal voltage; it does not disconnect the winding or reset mechanical/electrical plant state. | Implemented; hardware topology remains provisional |
| DEC-036 | Hold controller state by default during zero motor supply, with a separate reset-next-state scenario. | Explicit update semantics permit tests of state continuity and restart without claiming MCU brownout behavior or a physical safe stop. | Implemented and cross-validated |
| DEC-037 | Reject nonfinite or malformed active inputs and compare complete finite sampled records before calculating acceptance maxima. | NaN comparisons must not silently pass; all logged channels and exact discrete profiles are verified. | Implemented with negative regression tests |
| DEC-038 | Save development evidence in new output directories with source/model hashes; R2 requires explicit reuse for a populated output directory. | Protect frozen evidence and bind results to the code that produced them. Original SC01B remains preserved. | Implemented |

## Phase 2 evidence completion, 2026-09-09

| ID | Decision | Rationale and consequence | Status |
|---|---|---|---|
| DEC-039 | Extract timestamp acceptance from seeded delay/loss generation and verify handwritten arrival schedules. | Explicit collision/stale-arrival expectations supplement shared-profile MATLAB/Simulink comparisons; existing seeded fields stay exact. | Verified by E-006D campaign and frozen regressions |
| DEC-040 | Record mean-removed, periodic-Hann, unpadded one-sided encoder spectra with sample rate, resolution and normalization. | Peak frequency comes from sampled data; interior-band fixtures avoid aliasing and edge-bin amplitude ambiguity. Closed-loop measurement differences remain a separately labeled diagnostic. | Verified by E-002B campaign |
| DEC-041 | Measure count-jump recovery from the end of its actual affected sample using matched-position error and a complete threshold dwell. | Nearest-sample injection, first dwell start, confirmation and censoring are explicit; trajectory recovery does not implement supervisory recovery. | Verified by E-003B campaign |

## Phase 3 prototype decisions, 2026-09-09

| ID | Decision | Rationale and consequence | Status |
|---|---|---|---|
| DEC-042 | Use a timestamp-aware three-state observer with gated source-time corrections and replay of actual applied voltage. | Rejecting a value never refreshes confidence; no truth masks enter decisions. | Implemented; assumed model and thresholds |
| DEC-043 | Require elapsed-duration credible evidence, latched zero-voltage stop and explicit qualified reset. | Holds cannot advance recovery; a loaded plant continues moving under its dynamics. | Numerically verified; physical stop/hold open |
| DEC-044 | Preserve missed detections, censoring, worsened tracking and unresolved observer reacquisition. | Single-sensor consistency cannot prove truth; bounded commands alone do not prove resilience improvement. | Recorded in matched Phase 3 campaign |
| DEC-045 | Use an independent Simulink plant with shared decision helpers, plus independent unit fixtures. | Validates integration without claiming independent detector implementations or hardware validation. | Numerically verified |

## Independently referenced observer recovery, 2026-09-10

| ID | Decision | Rationale and consequence | Status |
|---|---|---|---|
| DEC-046 | Keep reference-assisted reacquisition disabled by default; require a separate position-reference stream with declared error bounds. | The disputed primary encoder cannot establish its own truth. Synthetic reference measurements demonstrate the interface; hardware reference selection and independence remain open. | Implemented as an optional numerical extension |
| DEC-047 | Reconstruct the current three-state estimate from a contiguous reference window and actual applied-voltage history, with scaled observability, fit and propagated measurement-error checks. | Avoids assuming zero velocity/current during zero-voltage stop. Unknown model/input/load errors remain outside the calculated bounds; a constant reference bias can fit. | Focused reconstruction and integration checks recorded |
| DEC-048 | Permit an explicit re-anchor only while already latched stopped; discard earlier replay history and preserve primary trust/watermarks. | Reference data never satisfy primary credible dwell, queue a reset or release on the commit tick. Subsequent primary qualification and a separate reset remain mandatory. | Verified with exact release-boundary and still-corrupt-primary fixtures |

## Frozen controller tuning, 2026-09-10

| ID | Decision | Rationale and consequence | Status |
|---|---|---|---|
| DEC-049 | Declare a nine-policy gain/filter grid, eight tuning windows, twelve separate evaluation fixtures and comparative gates before running; freeze the choice before evaluation. | Prevents evaluation-driven tuning and stop-dependent scoring. The lowest-score policy is diagnostic only when no candidate is eligible. | Implemented; 226 numerical runs recorded |
| DEC-050 | Retain historical defaults after G100_F020 improves tracking but fails current/disturbance requirements. | Aggregate gains of 17.35%/29.37% do not override 5/8 and 4/12 case-level outcomes. Tolerances are comparative assumptions, not hardware limits. | Default unchanged |
| DEC-051 | Reconstruct actual clipping and compare single-limit removals with identical gains/filter. | Mode-cap removal improves the two stress-case RMSE values about 38% while peak current rises about 3.5 times. Active slew has little net tracking effect there; anti-windup benefit is not isolated. | Diagnostic evidence recorded |
| DEC-052 | Retain the predeclared clean-reversal failure and complete diagnostic verification without clearing the rejection. | All three evaluation policies trigger position-rate alarms when the ±45° reference reversal exceeds the existing 25 rad/s envelope. This does not isolate noise as a cause or justify raising the threshold. | Study clean-operation acceptance false; motion-envelope alignment open |

## Optional causal motion envelope, 2026-09-10

| ID | Decision | Rationale and consequence | Status |
|---|---|---|---|
| DEC-053 | Keep the observer's 25 rad/s gate and historical controller unchanged; add an optional ±120° admitted request envelope and causal V10/A200 reference shaper. | Slew-limited internal position followed by beta=min(1,A*Ts/(2V)) smoothing bounds sampled reference speed/acceleration and global position range. It cannot guarantee actual plant speed or physical stopping. | Implemented without changing prior sources/models |
| DEC-054 | Score original request, shaped command and shaping lag separately; freeze 2 development, 8 new clean, 8 new fault and 2 diagnostic cases before execution. | Removing false alarms can cost task response: original-reversal request-window RMSE rises 6.67%. Unknown load/model diagnostics do not establish an uncertainty envelope. | All 18 required governed behavior cases pass; 80 numerical runs recorded |
| DEC-055 | Require new sensor alarms or supply stop by explicit deadlines, no preexisting-response credit, and genuine primary evidence plus separate reset after a long outage. | Reference shaping must not hide corruption, make stale packets credible or weaken the latch. | 348 project tests, 22 Simulink comparisons and 9,390 export-audit checks pass |

## Separate passive stop/hold study, 2026-09-10

| ID | Decision | Rationale and consequence | Status |
|---|---|---|---|
| DEC-056 | Keep the existing strict zero-voltage stop unchanged and compare passive mechanisms in a separate plant harness. | Terminal short already provides dynamic electrical braking but permits loaded drift. A 1.2 ohm external resistor reduces low-speed damping and has terminal voltage -Rext*i; it cannot statically hold. | Implemented; all 148 prior source/model hashes unchanged |
| DEC-057 | Freeze an assumed 0.030 Nm equal static/sliding mechanical capacity with 30 ms delay and 20 ms ramp. | A bounded implicit friction inclusion permits finite-impulse capture, overload slip and recapture without clearing current/velocity. Capacity and the 3.75 nominal load ratio are unqualified assumptions. | 20 fixtures, three mechanisms, three steps; 180 runs complete |
| DEC-058 | Require continuous independent dynamics, refinement and physical/numerical energy separation. | Exact affine propagation and event-separated continuous slip plus analytical sticking verify a different algorithm; load work can add energy during backdrive. Numerical dissipation is not brake heat. | 371 tests and 3,949 independent checks pass; frozen numerical acceptance true |
| DEC-059 | Keep drive/brake handoff and physical validation open after successful numerical holding. | Zero-drive release under load causes renewed motion. Brake reaction is absent from the operating observer; a command bit or simulated torque is not trustworthy engagement feedback. | Next local integration task; broad Gate 3 remains open |
