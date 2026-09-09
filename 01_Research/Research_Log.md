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

---

## 2026-09-09 — Phase 2B Parameter Sensitivity

- **Objective:** Screen assumed coupling, receiver, source and ground inputs; preserve reproducible comparisons and identify the next physical-evidence priorities.
- **Work performed:** Added a 26-control catalog with explicit ranges/units/provenance; signed imbalance controls; seeded stratified design; one-at-a-time sweeps; paired physical-only and fixed-communication contexts; two interaction grids; generated figures/summary; and selected Simulink cross-validation.
- **Results:** The standard study completed 1,886 analytical study runs: 506 one-at-a-time runs, 1,024 combined-design runs, 264 grid runs, 78 no-fault regressions, three references and 11 exported-case runs. All 45 project tests and 11 selected Simulink comparisons pass. The largest cross-validation difference is approximately 2.28e-12. Shared analysis-window metrics are [0.70, 1.15) s.
- **Findings:** Ground offset, equivalent voltage-to-angle gain, ground conversion and envelope frequency caused the largest one-at-a-time position changes within the selected ranges. The largest combined-design active position delta was 13.56 degrees with fixed communication faults; this is a sampled model result, not a hardware limit. Recovery was censored in 48/512 physical-only and 54/512 combined cases before 1.50 s.
- **Model limits exposed:** Diagnostic margins do not trigger modeled encoder faults; receiver capacitance affects only a reported pole; PWM frequency, voltage fall time, pulse-width and count-cap settings are inactive. Balanced changes to line values preserve differential imbalance. Tests verified these implementation roles explicitly.
- **Verification refinement:** Independent review caught a MATLAB table-argument shape error before completion and prompted shared metric windows for consistent context comparisons. Both were corrected, then the final one-command workflow was executed successfully. No original plant/controller/fault equations or model files were modified.
- **Provenance:** Ranges remain exploratory assumptions. No hardware was selected or measured. Primary-source references and identification requirements are recorded in `04_EMI_Models/Parameter_Identification_and_Switching_Case.md`.
- **Next action:** Implement proposed SC-01A finite-edge circuit harness and its convergence checks. Prioritize ground/receiver transfer, decoder behavior, shared-return impedance and commutation-source evidence. Communication-severity/seed ensembles, moving trajectories, supply interruption and Phase 3 resilience remain separate future work.

---

## 2026-09-09 — SC-01A Finite-Edge Native Circuit Verification

- **Objective:** Complete the next specified circuit step and resolve finite-edge receiver disturbances locally.
- **Files changed:** Added `06_Circuit_Simulations/SC01A` with a native SLX and builder, prescribed source definitions, exact independent reference, case runner, threshold utility, tests, plots, reports and raw results. Updated project status and traceability documents.
- **Assumptions introduced:** Source resistances, shunt capacitances, bias returns, finite intended logic levels and stress imbalance are explicitly assumed. Behavioral M*dI/dt sources are not a reciprocal mutual-inductor model. Shared return current includes the circuit loading.
- **Work performed:** Ran the existing 45 tests and 22 new circuit/threshold tests. Executed 16 deterministic cases at maximum steps of 1, 0.5 and 0.25 ns, plus three tenfold-tighter-tolerance runs; checked independent circuit-reference agreement, threshold event convergence, superposition, polarity, symmetry and 10-versus-20-period PWM settling. Retained native traces and solver evidence.
- **Results:** All 67 tests and 51 final native campaign runs pass. All 32 step comparisons, three tolerance checks, five native invariant checks and three period comparisons pass. Nominal combined rising-edge differential disturbance is approximately 51.7 mV. The deliberately asymmetric 300/5 pF negative-edge stress case crosses the illustrative receiver band. Largest refined differential-reference discrepancy is approximately 17.7 microvolts.
- **Unexpected behavior and resolution:** An early zero-order-held source encoding caused minimum-step warnings. Explicit duplicate-time event values removed those warnings without smoothing the waveform. Added a diagnostic record and reject-on-warning gate; both normal and deliberately injected-warning paths were checked. Saved-model workspace defaults and per-case overrides were verified separately.
- **Interpretation:** The result verifies the deterministic assumed circuit and its numerical resolution. It does not establish a selected device source, a real receiver glitch, an encoder count error, a measured immunity limit or hardware validation.
- **Next action:** SC-01B requires traceable driver/MOSFET/diode and commutation-loop parameterization. Receiver/decoder identification, supply interruption and resilient-control work remain open.

---

## 2026-09-09 — SC-01B Selected-Device Source Experiment

- **Objective:** Replace the prescribed source at the source-model level with a documented nonlinear device half-bridge and independent numerical verification.
- **Implementation:** Added native Simscape and original-vendor-SPICE realizations using IAUC100N04S6L014, a UCC27211A-informed behavioral driver, assumed supply/decoupling/load values and consistent DC initialization. Retained native internal channel/diode currents, event data, energy accounting, complete parameters and portable independent runtime provenance.
- **Experiment:** Five frozen operating points; native trapezoidal integration at 0.5/0.25/0.125 ns; original SPICE at 0.25/0.125 ns; representative tenfold consistency/tolerance tightening. See the generated `SC01B/results/verification/SC01B_Validation_Summary.md` for exact counts, tests and individual pass/fail gates.
- **Finding:** The 47 ohm external gate-resistance case produces an approximately 187 A drain-current spike. Independent original equations reproduce it, and native internal channel currents show simultaneous conduction. Commanded 300 ns dead time and zero overlap at a 6 V gate diagnostic level do not prove that the channels are separated.
- **Integrity of the experiment:** The failing gate-resistance case remains in the frozen matrix. Neither its gate resistance/dead time nor its fixed event windows were changed to force acceptance. Exploratory failed solver pilots are excluded from the installed final evidence.
- **Numerical limitation:** The nominal all-tight original-SPICE refinement aborts at the first gate corner. Fifteen isolated diagnostic trials preserved the electrical deck: relative-only and current-absolute-only tightening fail, while voltage-only tightening completes. Iteration, integration-method and timestep changes did not resolve the strict check. Its rejection is retained and full numerical acceptance remains open; supplemental diagnostic controls/logs are included separately from accepted waveform evidence.
- **Scope:** The driver is an explicit approximation, temperatures are fixed at 25 degrees C and load/loop values are assumed. Signed terminal energy is not semiconductor heat. This work verifies model implementation and exposes an operating limitation; it does not establish a physical source, safe operating area, decoder errors or robot immunity.
- **Next action:** Characterize a gate-drive/dead-time mitigation with held-out conditions, then identify actual commutation/loop behavior before connecting the source to the checked coupling network. Receiver identification and supply interruption remain separate work.

- **Final verification record:** All 84 project tests pass. The frozen campaign contains 29 attempted records: 27 complete without warnings and 2 rejected strict-SPICE references. All five finest native/original-SPICE waveform comparisons and all ten exterior energy-balance checks pass. All five cases fail at least one conservative gate-event check; the coarsest 0.5 ns, 4 ohm load comparison also exceeds its low-current error allowance, while the 0.25 ns comparison passes. Full numerical and operating-point flags remain false. Independent CSV calculations confirm signs and closure, and the saved nominal SLX matches all 18 campaign traces exactly.
