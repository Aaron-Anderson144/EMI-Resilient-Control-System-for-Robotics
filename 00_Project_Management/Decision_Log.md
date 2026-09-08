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

## New Decision Template

| ID | Date | Decision | Rationale | Alternatives | Consequence | Status |
|---|---|---|---|---|---|---|
| DEC-XXX | YYYY-MM-DD |  |  |  |  | Proposed |
