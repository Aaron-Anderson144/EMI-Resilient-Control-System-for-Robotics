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

---

## 2026-09-10 — Reconcile completed numerical work with the research record

- **Objective:** Restore the central log after the earlier SC01B entry; distinguish numerical verification, comparative outcomes and physical evidence.
- **Method:** This is a retrospective synthesis of the preserved local reports below. Their test/campaign counts describe those historical checkpoints; they are not additional executions in this documentation session. No external publication was reread or revision-validated in this update.

| Completed work and local record | Result and interpretation | Remaining proof |
|---|---|---|
| [SC01B R2 source revision](../06_Circuit_Simulations/SC01B_R2/results/verification/SC01B_Validation_Summary.md) | Revised bipolar behavioral drive resolves the declared modeled channel-overlap failures; native/vendor-equation comparison and strict-solver evidence pass. Original failed SC01B remains preserved. | Physical source/driver/negative-rail/temperature and parasitic identification; vendor-equation agreement is not measurement validation. |
| [Supply/load integration](../03_MATLAB/results/development/v03/Development_Validation_Summary.md) and [Phase 2 completion](../03_MATLAB/results/development/phase2_completion/Phase2_Completion_Report.md) | Averaged motor-bus interruption and loaded continuity, constructed packet schedules, spectrum/recovery and censoring are recorded. | Physical MCU brownout, protocol-specific errors and instrument evidence are separate. |
| [Phase 3 prototype](../03_MATLAB/results/development/phase3/Phase3_Implementation_Report.md) | Source-time observer, plausibility checks and supervised bounded-voltage behavior work in the declared cases. Missed/censored faults, primary-only non-recovery and loaded zero-voltage drift remain explicit results. | Single-sensor observability, identified limits and broad safe-stop/restart requirements. |
| [Independent-reference recovery](../03_MATLAB/results/development/phase3_reacquisition_20260910_132934/Phase3_Reacquisition_Report.md) | Optional stopped-only reconstruction permits a separately requested reset after primary qualification in the exact-model synthetic fixture. | Selected independent sensor, uncertainty/independence evidence and load/model mismatch; no automatic truth-based reinitialization. |
| [Controller tuning](../03_MATLAB/results/development/phase3_tuning_20260910_141100/Phase3_Controller_Tuning_Report.md) | Frozen nine-policy grid completed; diagnostic candidate G100_F020 fails comparative current/disturbance gates. Clean reversal exposes a motion/rate-check mismatch. Defaults are retained. | A faster response alone does not justify promotion; inactive caps are not evidence of protection. |
| [Motion envelope](../03_MATLAB/results/development/phase3_motion_20260910_144242/Phase3_Motion_Envelope_Report.md) | Common causal reference shaping resolves the declared clean-motion/rate-check conflict without raising observer thresholds; original-request delay cost remains scored. | Reference derivative bounds are not guaranteed physical plant speed/current bounds. |
| [Separate stop/hold](../03_MATLAB/results/development/phase3_stop_hold_20260910_150537/Phase3_Stop_Hold_Report.md) | Finite-capacity assumed mechanical holding, terminal short and external resistor are compared with continuous-reference checks. Expected overload, failed engagement and failed release remain visible. | No controller brake integration, hardware brake qualification, holding/restart safety or measured torque envelope. |

- **Decision:** Treat these results as numerical evidence in their stated model domains. No hardware safety requirement or Draft research requirement is approved by this log update.
- **Next action:** Align the evidence matrix with the charter and implement a causal electrical-receiver-decoder bridge before claiming a four-way actuator mitigation comparison.

---

## 2026-09-10 — Whole-project audit and reproducibility baseline

- **Objective:** Check alignment with the original charter before adding another control feature.
- **Inputs:** Charter, all requirement/traceability/FMEA records, current source, preserved reports and local evidence. The audit reproduced 371 project tests and 327 fresh campaign executions: 223 control, 60 stop/hold, 26 closed-loop Simulink and 18 circuit runs. This is selected fresh reproduction, not a rerun of every historical campaign.
- **Findings:** The missing integrated four-way experiment and causal receiver/decoder bridge are the primary research-path gaps. Physical validation, current-sensor corruption, hardware brownout and full protocol behavior remain open. The source snapshot contains 293 selected files, including 157 MATLAB source files; it excludes results, tools and caches and is not a full project/data/runtime backup. A packet summary-count inconsistency was identified for separate correction; saved channel arrays and historical statistical windows must remain distinguishable.
- **Baseline:** Local Git commit `7b55eb55ff04b6f3908115e26b092a84025a1d44`, tag `audit-baseline-2026-09-10`, preserves the audited source snapshot before consolidation edits. See [Local Reproduction](../00_Project_Management/Local_Reproduction.md) for the dependency and evidence boundary. No remote publication is implied.
- **Licensing clarification:** The early 2026-09-08 log interpreted the runtime banner too broadly. The observed Home-license banner and the charter's licensing-completion check are distinct from a determination of this user's intended use or applicable authorization. Completion remains unconfirmed; this record makes no legal conclusion or claim that a license has been approved.
- **Decision:** Consolidate source/evidence ownership and records first. Brake handoff is needed before a loaded integrated restart claim, but is not a prerequisite for a deliberately zero-load first EMI comparison.

---

## 2026-09-10 — Freeze the first integrated four-way experiment

- **Objective:** Make charter objective 6 implementation-ready without changing historical defaults or treating a filter assumption as hardware identification.
- **Files changed:** [Evidence status](../02_Requirements/Research_Evidence_Status.md), requirement/traceability clarification, this log, local literature synthesis, report assembly map, roadmap, and [FOUR-WAY-EMI-PLAN-V1](../04_EMI_Models/Four_Way_EMI_Experiment.md) with configuration/fixture records.
- **Assumptions introduced:** External one-way R2 voltage replay with a disclosed synthetic return edge; one capacitively disturbed A pair and ideal clean B bit; assumed Schmitt receiver and explicit quadrature decoder; 900 pF added differential capacitance; common shaped zero-load task; unchanged historical software policy; two development and twelve evaluation fixtures with separate closure diagnostics.
- **Work performed:** Declared causal event/sample order, persistent count semantics, matched clean companions, measurement/truth separation, numerical rejection gates, original-request and shaped-reference scoring, and a predeclared null-result path. Local source notes were synthesized; no new external full-text or standards review was performed.
- **Results/status:** Design frozen before integrated development/evaluation. A01 / RES-005 remain open; A02 implementation and acceptance are the next milestone. A03 scope/status reconciliation is recorded without approving Draft requirements. A07 remains partial because the literature search, critical paper synthesis and current applicability checks remain incomplete.
- **Next action:** Implement and independently validate the causal measurement/receiver/decoder interface. Freeze implementation hashes after development acceptance, then execute the declared four arms and retain negative or null outcomes. Do not automatically switch the critical path to brake handoff.

---

## 2026-09-10 — Consolidated baseline verified in a fresh checkout

The [consolidation checkpoint](../00_Project_Management/Consolidation_Checkpoint.md) records 401/401 passing tests in a separate local checkout of code commit `d7413fe6a3c0cd7a091e8da756bce9e60b108489`. All 116 original controller time/state/loop/signal records and their metrics reproduce exactly; known misses and censoring remain. The 600-trial packet-loss table is byte-identical to its historical result. Covered output workflows pass preservation tests and scratch execution checks. Forty hash-pinned local dependencies restore without downloading. The first four-way design is frozen; zero integrated four-way records have been executed. A02 implementation remains next, and A07's external research remains partial.


## 2026-09-11 — Causal receiver implementation and rejected development gate

Implemented the strict measurement boundary, exact continuous plant transitions, state-preserving circuit replay, Schmitt receiver, persistent quadrature decoder and offline own-trajectory shadow. The [checkpoint](../00_Project_Management/Causal_Receiver_Checkpoint.md) records 468/468 tests, 116 exact legacy records, 24 native numerical comparisons and 16 refinements. All 16 development records and 8 clean companions completed; the independent CSV audit reconstructs counts and scoring.

DEV01 produces no persistent EMI count error or paired task disturbance. All four exposed DEV02 arms exceed the frozen 7 V receiver domain (7.557 V with 100 pF differential capacitance;8.038 V with 1000 pF). Hold-A continuation is rejected diagnostic evidence, not mitigation benefit. Native domain usability also rejects 12/24 records despite numerical agreement. PLAN-V1 and its input hashes remain unchanged; no evaluation or closure-production cases ran. Next review receiver/topology assumptions and freeze a new plan before evaluating. No hardware or Draft approval claim is made.
