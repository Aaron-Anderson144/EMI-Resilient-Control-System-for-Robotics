# Research Log

Maintain one entry for every meaningful research or engineering session.

## Entry Template

### YYYY-MM-DD — Session Title

- **Objective:**
- **Inputs and references:**
- **Model or files changed:**
- **Assumptions introduced:**
- **Work performed:**
- **Results:**
- **Unexpected behavior:**
- **Interpretation:**
- **Decision required:**
- **Next action:**

---

## 2026-09-08 — Workspace Initialization

- **Objective:** Establish a portable research workspace and begin Phase 1.
- **Inputs and references:** Initial project description and selected EMI-resilient robotic-control direction.
- **Model or files changed:** Workspace documents and baseline MATLAB source package created.
- **Assumptions introduced:** Representative 24 V actuator; three-state DC-equivalent motor; 1 ms initial sample time.
- **Results:** Research structure, parameter policy, baseline equations, controller workflow, and test skeleton prepared.
- **Unexpected behavior:** The locally detected MATLAB installation reported a Home license that excludes research use.
- **Interpretation:** Model source can be prepared, but research execution should use an appropriate license.
- **Decision required:** Confirm the MATLAB license under which the work will be executed.
- **Next action:** Review parameters, run the baseline, and generate the Simulink model.

---

## 2026-09-08 — Phase 1 Baseline Validation

- **Objective:** Verify the clean actuator model and generate the first Simulink artifact.
- **Inputs and references:** Representative actuator parameter set `REPRESENTATIVE-ACTUATOR-V0.1`.
- **Model or files changed:** Updated MATLAB R2026a legend compatibility; generated baseline CSV, MAT, PNG, and SLX files.
- **Assumptions introduced:** No new physical assumptions.
- **Work performed:** Executed five automated tests, ran the analytical discrete baseline, generated the Simulink model, and completed one Simulink run.
- **Results:** Five of five tests passed. Maximum closed-loop pole magnitude was 0.994325. The 30 degree command produced 10.745 percent overshoot and 0.709 s settling time. Final error was -0.000247903 rad. Peak linear control command was 1.407 V.
- **Unexpected behavior:** MATLAB R2026a rejected the original positional legend syntax; the plotting call was made release-compatible.
- **Interpretation:** The clean linear baseline is stable, finite, repeatable, and operational. The response is suitable as a starting reference but has not been identified against physical hardware.
- **Decision required:** Review whether the provisional 20 rad/s bandwidth and 1 ms sample time remain appropriate for the actuator ultimately selected.
- **Next action:** Begin Phase 2 with controlled encoder-noise and encoder-dropout injection.
