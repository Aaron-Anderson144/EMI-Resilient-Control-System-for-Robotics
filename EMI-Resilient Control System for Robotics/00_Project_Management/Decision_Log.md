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

## New Decision Template

| ID | Date | Decision | Rationale | Alternatives | Consequence | Status |
|---|---|---|---|---|---|---|
| DEC-XXX | YYYY-MM-DD |  |  |  |  | Proposed |
