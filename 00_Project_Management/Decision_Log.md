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
