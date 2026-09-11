# SC-01B R2 switching-model review

This separately identified revision preserves the original SC01B campaign and MOSFET equations. Its outcome is computed from the recorded campaign, including rejected attempts.

**The declared R2 numerical and operating-point checks pass, including modeled channel overlap. Physical source validation remains open.**

The revised behavioral drive commands +12 V on and -1.5 V off, retains the original turn-on gate-resistance cases, and uses 3 Ω total discharge resistance. The 300 ns dead time, 20 ns linear ramps and 20/19 ns delays are retained. The negative rail and directional impedance are new design assumptions; this is not an unchanged UCC27211A implementation.

## Recorded acceptance

| Gate | Result |
|---|---|
| Required simulation execution | PASS |
| Full numerical campaign | PASS |
| Modeled channel overlap, all native runs | PASS |
| All operating points, including channel overlap | PASS |
| Switching-model failures resolved | PASS |
| Automated tests | 99 / 99 passed; 0 failed; 0 incomplete |
| Physical source validated | No |

29 required attempts were recorded: 29 complete, 0 rejected. 24 of 24 numerical comparisons have an accepted complete reference. Rejected references fail acceptance and are excluded from measured comparison-ratio plots.

| Case | Execution | Numerical | Channel overlap | Operating point |
|---|---|---|---|---|
| Nominal 24 V | PASS | PASS | PASS | PASS |
| Supply 18 V | PASS | PASS | PASS | PASS |
| Load 4 Ω | PASS | PASS | PASS | PASS |
| Gate 47 Ω | PASS | PASS | PASS | PASS |
| 30 V / 16 Ω / 10 Ω | PASS | PASS | PASS | PASS |

The operating-point gate requires complete finite records, resolved unclipped events, no repeated switch-voltage crossings, terminal voltage limits and zero simultaneous positive native channel conduction above max(1 mA, 0.1% of peak load current). Channel evidence is required for every native refinement and consistency run. Gate midpoint overlap and simultaneous terminal currents cannot substitute for internal channel-current evidence.

## Original campaign and R2

Original values come from the immutable campaign's finest native metrics, with source hashes retained in the baseline extract under references/SC01B_Baseline_Summary.json. R2 values come from this study's finest native records. These columns compare fixtures, not numerical convergence.

| Case | Original peak terminal (A) | R2 peak terminal (A) | Original common channel (A) | R2 common channel (A) | Native unresolved events, original → R2 |
|---|---:|---:|---:|---:|---:|
| Nominal 24 V | 8.24605 | 8.04885 | 3.1969 | 3.52572e-11 | 1 → 0 |
| Supply 18 V | 5.98654 | 5.83042 | 0.307106 | 5.7396e-13 | 1 → 0 |
| Load 4 Ω | 12.0573 | 11.8425 | 3.78337 | 1.78988e-10 | 1 → 0 |
| Gate 47 Ω | 186.919 | 6.11925 | 183.464 | 1.63592e-13 | 2 → 0 |
| 30 V / 16 Ω / 10 Ω | 11.5432 | 10.5802 | 5.10636 | 1.51518e-07 | 1 → 0 |

![Original and revised current peaks and numerical comparison ratios](Overview.png)

A common-channel value below the declared floor is not a claim of mathematically zero current. Drain-terminal peaks also contain charge and diode contributions. Neither a low terminal peak nor waveform agreement alone proves absence of channel overlap.

## Numerical evidence

Recorded native local-trapezoidal steps: 0.5, 0.25, 0.125 ns. Original-equation SPICE maximum steps: 0.25, 0.125 ns. Labels below come directly from the recorded comparisons. The declared nominal and combined-extension tolerance checks are included in the full numerical gate.
The comparison interval is 1–5 µs, without fitted delay, filtering or a moved time origin. Waveform allowances are max(0.01 V or 0.01 A, 1% of reference peak absolute amplitude); signed-energy allowance is max(1 nJ, 1% of absolute reference energy); event-time allowance is 1 ns; closure allowance is max(0.1 nJ, 0.1% of its recorded energy scale).

| Case / comparison | Waveform ratio | Energy ratio | Timing difference (ns) | Required events resolved | Result |
|---|---:|---:|---:|---|---|
| Nominal 24 V / native_0.5_to_0.125ns | 0.777023 | 0.0547147 | 0.0184488 | PASS | PASS |
| Nominal 24 V / native_0.25_to_0.125ns | 0.174843 | 0.0116588 | 0.00414513 | PASS | PASS |
| Nominal 24 V / spice_0.25_to_0.125ns | 0.132218 | 0.0101773 | 0.00147801 | PASS | PASS |
| Nominal 24 V / native_to_original_spice_0.125ns | 0.0347134 | 0.00060368 | 0.000166276 | PASS | PASS |
| Nominal 24 V / native_consistency_10x | 0 | 0 | 0 | PASS | PASS |
| Nominal 24 V / spice_tolerances_10x | 0.0378345 | 0.000968752 | 0.000369419 | PASS | PASS |
| Supply 18 V / native_0.5_to_0.125ns | 0.701814 | 0.0463787 | 0.0110788 | PASS | PASS |
| Supply 18 V / native_0.25_to_0.125ns | 0.156746 | 0.00971959 | 0.00210123 | PASS | PASS |
| Supply 18 V / spice_0.25_to_0.125ns | 0.097294 | 0.00856163 | 0.00118048 | PASS | PASS |
| Supply 18 V / native_to_original_spice_0.125ns | 0.0280281 | 0.000269669 | 0.000644865 | PASS | PASS |
| Load 4 Ω / native_0.5_to_0.125ns | 0.886038 | 0.0665973 | 0.041577 | PASS | PASS |
| Load 4 Ω / native_0.25_to_0.125ns | 0.217357 | 0.0123141 | 0.00669977 | PASS | PASS |
| Load 4 Ω / spice_0.25_to_0.125ns | 0.132952 | 0.0123928 | 0.00234793 | PASS | PASS |
| Load 4 Ω / native_to_original_spice_0.125ns | 0.0609862 | 0.000982739 | 0.00110371 | PASS | PASS |
| Gate 47 Ω / native_0.5_to_0.125ns | 0.640424 | 0.0185677 | 0.00568064 | PASS | PASS |
| Gate 47 Ω / native_0.25_to_0.125ns | 0.147263 | 0.00374576 | 0.00120009 | PASS | PASS |
| Gate 47 Ω / spice_0.25_to_0.125ns | 0.107231 | 0.00660614 | 0.00104419 | PASS | PASS |
| Gate 47 Ω / native_to_original_spice_0.125ns | 0.0470268 | 0.000668446 | 0.000120275 | PASS | PASS |
| 30 V / 16 Ω / 10 Ω / native_0.5_to_0.125ns | 0.987468 | 0.151584 | 0.0265706 | PASS | PASS |
| 30 V / 16 Ω / 10 Ω / native_0.25_to_0.125ns | 0.22926 | 0.0312204 | 0.00469465 | PASS | PASS |
| 30 V / 16 Ω / 10 Ω / spice_0.25_to_0.125ns | 0.11787 | 0.00493982 | 0.00105061 | PASS | PASS |
| 30 V / 16 Ω / 10 Ω / native_to_original_spice_0.125ns | 0.0496619 | 0.00313824 | 0.000242794 | PASS | PASS |
| 30 V / 16 Ω / 10 Ω / native_consistency_10x | 0 | 0 | 0 | PASS | PASS |
| 30 V / 16 Ω / 10 Ω / spice_tolerances_10x | 0.0509592 | 0.0048397 | 0.00122729 | PASS | PASS |

A ratio of 1 is the acceptance boundary. Unavailable means no accepted reference; it never means zero difference. Current-timing agreement and initial-state consistency remain separate components of the recorded composite comparison flag. Signed device terminal energy includes stored-charge transfer and is not semiconductor heat.

### Solver investigation and rejected evidence

The solver remedy combines two controls: algebraically equivalent clipped-linear behavioral command sources, and a fixed 1 ns TSTEP independent of the actual integration maximum TMAX. Source levels, timing, ramp durations and strict tolerances are unchanged. With wrdata and no interp command, exported times are the actual integration times; each completed SPICE record is checked against TMAX. Changing source representation alone was insufficient at finer steps. Actual completion and comparison flags above determine this campaign's result; supplemental trials cannot replace failed required checks.
The [solver resolution](supplemental/solver/Solver_Resolution.md) and [portable solver supplement](supplemental/solver/README.md) retain 19 accepted strict checks and 132 per-signal comparisons, including all five cases at 0.0625 ns TMAX and the nominal/combined cases at 0.03125 ns. TSTEP sensitivity repeats and unchanged-original-driver recovery checks separate the numerical remedy from the drive revision. This supplements the declared campaign and does not prove the underlying simulator defect or hardware validity.
No required simulation attempt in this collected campaign is recorded as rejected.

## Switching and gate evidence

![Stored native and SPICE switching and gate samples](Switching_Overlay.png)

Plots use stored integration samples. Gate diagnostic levels remain 1.2, 6 and 10.8 V, referenced to the original +12 V level; they are not fractions of the bipolar excursion. The original −0.1 to +0.5 µs command windows and strict crossing rules remain. Full flags distinguish switch-voltage resolution, high-side gate resolution and counterpart low-side gate resolution.

| Case | Native / SPICE unresolved events | Native above-floor channel overlap (ns) | Native / SPICE peak terminal current (A) |
|---|---:|---:|---:|
| Nominal 24 V | 0 / 0 | 0 | 8.04885 / 8.05023 |
| Supply 18 V | 0 / 0 | 0 | 5.83042 / 5.8303 |
| Load 4 Ω | 0 / 0 | 0 | 11.8425 / 11.842 |
| Gate 47 Ω | 0 / 0 | 0 | 6.11925 / 6.11921 |
| 30 V / 16 Ω / 10 Ω | 0 / 0 | 0 | 10.5802 / 10.5828 |

## Scope and next evidence

MOSFET equations, nonlinear charge, body diode and package parasitics remain unchanged. The model is isothermal and uses an assumed supply/load fixture. The new regulated negative rail and split drive have not been tied to selected hardware. Bootstrap/negative-rail generation, UVLO, nonlinear driver limits, clamp/diode dynamics, temperature variation, layout tolerance, motor back-EMF and measured robot commutation remain outside the model.

[TI SLUA618A, sections 3.4–3.5](https://www.ti.com/lit/ml/slua618a/slua618a.pdf) provides the design basis for lower discharge impedance and negative turn-off voltage. Numeric values are declared R2 assumptions selected during local remedy screens, not manufacturer guarantees or blinded validation. See Device_Source_and_Assumptions.md in the R2 source folder.

After the declared switching gates pass, identify a realizable bipolar drive and characterize its commutation, parasitics and tolerances before treating this source as representative of robot hardware or integrating it with a validated EMI receiver model.

## Reproducible records

[Status](status.json), [criteria](criteria.json), [runs](runs.csv), [comparisons](comparisons.csv), [waveform differences](waveforms.csv), [metrics](metrics.csv), [events](events.csv), and [energy balance](balance.csv) preserve the machine-readable evidence. study.mat retains the finest traces and tables; per-case folders retain parameters, refinements and solver logs. test_results.mat retains individual test outcomes.
The [portable driver investigation](supplemental/driver/README.md) retains the fixed-drive selection, all 48 screen attempts, six rejected/incomplete attempts and selected fine raw samples. Its screening completion flags are separate from full campaign acceptance.
The [independent exported-data audit](supplemental/independent_csv_audit.json) checks exported waveform and energy identities with input hashes. It complements the complete MATLAB acceptance gate.
MATLAB: `26.1.0.3276743 (R2026a) Update 3`. Started: 09-Sep-2026 16:43:25. Completed: 09-Sep-2026 16:46:39.
