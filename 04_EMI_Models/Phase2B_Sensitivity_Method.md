# Phase 2B Parameter-Sensitivity Method

Date: 2026-09-09. Parameter set: `REPRESENTATIVE-ACTUATOR-V0.2`.

This study screens the existing reduced-order model. All parameter ranges are exploratory assumptions, not measured tolerances, confidence intervals or calibrated probability distributions. The study does not identify real hardware parameters or establish an immunity or stability limit.

## Experimental design

- **26 parameter controls:** 17 affect the receiver waveform or voltage-to-angle mapping; two affect diagnostic thresholds; one changes a reported pole only; six have no differential-response effect in this implementation.
- **One-at-a-time sweeps:** nine evenly spaced linear/logarithmic levels as declared in the catalog, plus the exact nominal value if absent. Integer count-cap levels are rounded and deduplicated. Every other input stays nominal.
- **Combined-parameter exploration:** 512 stratified samples over the 17 response parameters, with seed `260909`. Each coordinate occupies each of 512 strata exactly once. Log-coordinate sampling is used where declared. No Statistics and Machine Learning Toolbox or Parallel Computing Toolbox is required.
- **Two contexts:** every physical channel with immediate loss-free reception, and the same physical channels plus the original fixed-delay/jitter/loss configuration. The same communication seeds and schedules are used throughout. This is one controlled communication realization, not a reliability estimate across schedules.
- **Two interaction grids:** ground conversion versus equivalent voltage-to-angle gain, and shared-return inductance versus current rise time. Each uses 11 levels per input plus exact nominal values if absent. Other physical paths remain enabled at nominal values, so these are full-system response surfaces.

The exact values, units, linear/log coordinate and implementation role are saved in `phase2b_sensitivity_catalog.csv`. `phase2b_sensitivity_global_inputs.csv` contains every combined-design input; the MAT archive preserves the complete parameter structures and selected validation cases. Sample numbers join the input and metric tables.

## Controlled comparisons

Both contexts use the same half-open analysis window, **[0.70, 1.15) s**, so their RMSE denominators agree. Physical-source disturbances begin at 0.85 s; ground offset stops at 1.10 s; source coupling stops at 1.15 s. The extra 0.70–0.85 s portion is retained in physical-only metrics to make the two contexts directly comparable. The total record is 1.50 s at 1 ms/sample.

Every run is compared with the all-faults-disabled Phase 2B trajectory. Only `params.phase2b` is varied; plant, controller, voltage limits, commanded 30-degree step, time grid and initial state stay fixed. Low/nominal/high no-fault regressions for every catalog row check that reuse of one clean baseline is valid. Tests also verify reconstruction of the nominal physical profile.

Recorded measures include position-delta RMSE and peak in the analysis window, post-window peak, measurement error, command change, actual sampled receiver-voltage peak, diagnostic exceedance counts, saturation counts, measurement age, and recovery/censoring. Ranking uses the maximum whole-record position change from the nominal **faulted** case in the same context. It measures the effect of changing an assumption, while matched-clean metrics measure the modeled disturbance response.

Recovery retains the original 0.05-degree threshold and 50-sample dwell. A zero recovery time means the trajectory already meets that tolerance at the first post-window sample. It does not mean zero error. Censoring means the required dwell was not observed before the record ended; it does not by itself prove instability.

## Parameter semantics

Capacitance and mutual-inductance imbalance are signed controls that preserve the mean of the two nonnegative line values. Separate mean controls preserve imbalance. This avoids confusing common changes to both conductors with differential imbalance.

The catalog deliberately includes inactive and diagnostic inputs. Receiver capacitance changes the reported `1/(2*pi*R*C)` pole without filtering the waveform. Noise margin and common-mode limit change diagnostic flags without triggering a modeled receiver/count fault. PWM frequency, voltage fall time, minimum pulse width and spurious-count cap are reserved inputs. Equal changes to paired capacitances or mutual inductances have no modeled differential effect.

The 30 Hz–10 MHz bandwidth range explores the model's first-order gain **at the baseband envelope frequency**. Its low end is a hypothetical effective baseband filter, not an identified digital receiver. The 5–400 Hz envelope range remains below Nyquist but is not a resolved PWM signal. Finite-edge slopes are source assumptions; the current step describes a commutation branch, not a forced nanosecond motor-winding current change.

## Verification and interpretation

The workflow runs the complete project test suite before the study, checks finite values and pre-window identity on every study case, and cross-validates nominal and selected extreme cases against the saved Simulink model. The comparison checks all 29 logged columns plus time, exact discrete diagnostics/sample counts and an absolute `1e-9` numerical tolerance. These checks establish numerical consistency, not physical accuracy.

One-at-a-time rankings depend on the chosen ranges, nominal point, waveform phases and trajectory. The combined design is finite exploration; its maximum is the largest observed sample, not a guaranteed worst case. Percentages of exploratory cases that exceed a diagnostic margin are not real-world failure probabilities. Fixed phases permit cancellation, and the largely settled step does not cover moving trajectories. A physical hardware priority must also consider quantities that this model omits.

## Run locally

From `03_MATLAB`, run:

```matlab
phase2b_sensitivity_main
```

The entry point runs tests, the full study, figure generation and selected Simulink comparisons. It writes only the dedicated `results/sensitivity` directory. Existing baseline and Phase 2A/2B study artifacts remain separate.

For a custom exploratory size after `startup_project`:

```matlab
study = run_phase2b_sensitivity_study("results/sensitivity_custom", ...
    GlobalSamples=1024, Levels=13, GridLevels=15, Seed=260909);
validation = validate_phase2b_sensitivity(study,"results/sensitivity_custom");
```

Consult `Parameter_Identification_and_Switching_Case.md` for the evidence required to replace assumptions and the proposed SC-01 circuit specification. That circuit is the next fidelity step; it is not implemented by this sensitivity workflow.
