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

---

## 2026-09-08 — Phase 2A Encoder Fault Injection

- **Objective:** Introduce repeatable encoder faults inside the feedback loop while preserving the clean baseline.
- **Inputs and references:** `REPRESENTATIVE-ACTUATOR-V0.1`, 4096-count encoder assumption, 1 ms sample time.
- **Model or files changed:** Added encoder scenario and profile functions, sample-by-sample closed-loop simulation, Phase 2 runner, Phase 2 Simulink builder, smoke test, cross-validation, and fault-specific tests.
- **Assumptions introduced:** Gaussian noise standard deviation 0.25 degree; sinusoid amplitude 1 degree at 120 Hz; count jump of 128 counts; dropout from 0.50 to 0.65 s using hold-last behavior.
- **Work performed:** Executed five scenarios independently in MATLAB and Simulink and compared reference, true position, measured position, additive fault, and dropout mask.
- **Results:** All 12 automated tests passed. All five Simulink scenarios completed with 1501 samples. Maximum analytical-to-Simulink position difference was approximately 2.53e-13 rad, below the 1e-9 rad acceptance tolerance.
- **Unexpected behavior:** MATLAB table inference assigned a generic name to a nested expression; the export schema was made explicit. A structure preallocation pattern was also made release-compatible.
- **Interpretation:** The Phase 2A injection layer is deterministic, disabled by default, isolated by scenario, and independently cross-validated.
- **Decision required:** Confirm whether the initial disturbance magnitudes represent exploratory levels or should be tied to a particular encoder and cable configuration.
- **Next action:** Derive fault magnitude from capacitive and inductive coupling parameters, then add communication delay, jitter, packet loss, and ground-offset scenarios.

---

## 2026-09-08 — Phase 2B Reduced-Order Coupling and Communication Layer

- **Objective:** Connect assumed electromagnetic source and path parameters to controller-visible receiver disturbance, then add causal communication delay, jitter, packet loss, and stale-data behavior.
- **Inputs and references:** Parameter set `REPRESENTATIVE-ACTUATOR-V0.2`; 24 V switching step; 20 kHz assumed PWM frequency; 100 ns voltage edge; 3 A current step; 200 ns current edge; 120 ohm differential termination; 5 MHz receiver bandwidth; 1 kHz controller sample rate.
- **Model or files changed:** Added Phase 2B named-scenario selection, physical-coupling profile, timestamped communication profile, sample-by-sample actuator simulation, and matched-baseline metrics. Added the focused model definition in `04_EMI_Models/Phase2B_Coupling_and_Communication_Faults.md`.
- **Assumptions introduced:** Differential imbalance of 1 pF and 3 nH; capacitive and inductive path-transfer factors of 0.20 and 0.50; 25 milliohm plus 20 nH shared return; 0.10 common-mode-to-differential conversion; 0.10 V ground offset; 8-sample fixed delay; 0–8 sample seeded jitter; 0.20 seeded packet-loss probability; hold-last reception.
- **Work performed:** Implemented finite-edge peak equations, controller-rate baseband envelopes, separate coupling components, receiver-margin flags, timestamped packet arrival scheduling, collision and out-of-order accounting, packet age, and pre/active/post incremental metrics.
- **Results:** All 28 project tests passed, including all 16 Phase 2B tests. All ten Phase 2B Simulink smoke cases completed with 1501 finite samples and monotonic accepted timestamps. MATLAB/Simulink cross-validation passed for all ten scenarios; discrete profiles were exact and the largest continuous-signal difference was approximately `2.2751e-12` (velocity), with maximum position difference approximately `1.8940e-13` rad. The configured packet-loss study observed 15,934 drops in 80,000 opportunities (`0.199175`), with Wilson 95% interval `[0.19642, 0.20196]`; `p=0` and `p=1` were exact. With the current assumed values, the analytical component peak magnitudes are approximately 5.76 mV capacitive, 22.5 mV inductive, 37.5 mV shared-impedance differential voltage, and 10 mV differential ground-offset contribution. These are model calculations, not measurements.
- **Unexpected behavior:** The 1 ms sample interval is fifty times longer than the 20 kHz PWM period, so a controller-rate simulation cannot represent the individual switching edges without aliasing or loss of fidelity.
- **Interpretation:** The implemented disturbance is a software-verified, physics-based reduced-order, receiver-equivalent sensitivity model. The tests and independent Simulink realization verify internal equations, deterministic channel behavior, and numerical consistency—not physical accuracy. The 120 Hz envelope preserves a controllable in-band disturbance for closed-loop study but is not the PWM waveform. The explicit volts-to-radians sensitivity is phenomenological and does not predict receiver threshold crossings or encoder bit errors.
- **Decision required:** Select cable geometry, receiver topology, actual edge measurements, and an encoder error mechanism before treating the model as hardware representative.
- **Next action:** Sweep the assumed parasitics, path-transfer factors, edge rates, receiver margin/bandwidth, communication severity, and phenomenological sensitivity. Then replace high-influence assumptions with sourced or measured values and advance critical cases to a switching-level circuit or Simscape Electrical model.
