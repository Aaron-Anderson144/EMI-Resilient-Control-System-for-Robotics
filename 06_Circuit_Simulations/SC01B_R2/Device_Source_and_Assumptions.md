# SC-01B R2 device sources and assumptions

SC-01B R2 uses unchanged Infineon IAUC100N04S6L014 MOSFET equations with a revised bipolar behavioral gate drive. The original sibling SC01B campaign remains immutable. Its scope is **isothermal verification of the native device-model realization against the original manufacturer SPICE equations**. Agreement between those realizations is not physical validation of a MOSFET, driver IC, motor inverter, or robot installation. No hardware component selection is claimed.

This document describes the frozen fixture in `functions/sc01b_parameters.m` and the native/SPICE builders. Generated run records and the campaign report provide actual numerical acceptance results; the operating-point matrix below is not itself a statement that those comparisons passed.

## MOSFET reference and provenance

The [Infineon datasheet, revision 1.0, 2019-04-01](https://www.infineon.com/assets/row/public/documents/10/49/infineon-iauc100n04s6l014-datasheet-en.pdf) supplies these reference anchors. Values are typical unless marked otherwise; temperature is 25 °C.

| Quantity | Value | Test condition |
|---|---:|---|
| Drain-source / gate-source ratings | 40 V / ±16 V | Device ratings |
| On resistance, typical / maximum | 1.12 / 1.40 mΩ | VGS = 10 V, ID = 50 A |
| Input / output / reverse-transfer capacitance | 3027 / 835 / 47 pF | VDS = 25 V, VGS = 0, 1 MHz |
| Qgs / Qgd / total gate charge | 9.0 / 9.4 / 49 nC | VDD = 32 V, ID = 100 A, VGS = 0–10 V |
| Body-diode forward voltage | 0.8 V typical, 1.1 V maximum | IF = 50 A, VGS = 0 |
| Body-diode recovery time / charge | 45 ns / 38 nC | VR = 20 V, IF = 50 A, 100 A/µs |

The capacitance, diode-forward and gate-charge curves appear in figures 10, 11 and 15. Dynamic and recovery figures are characterized/design-verified, not production-tested. Their 50–100 A conditions differ substantially from this fixture. In particular, 38 nC and 45 ns are not imposed as constant recovery behavior near 3 A, and 49 nC does not specify charge at 12 V drive.

The native model uses the installed Simscape Electrical **SPICE-Imported MOSFET** selection `Infineon OptiMOS6 40V / IAUC100N04S6L014`. The independent engine includes the unchanged installed file:

`<matlabroot>/toolbox/physmod/elec/supporting_files/IAUC100N04S6L014.cir`

The inspected MATLAB R2026a file has SHA-256 `EF36D4C42564ABAFD708B31FAE5D727CCB392B1079A05C599A137D2E34F6B92A`. Its generic description says “OptiMOS5 40V,” whereas its named subcircuit and the datasheet/catalog identify the selected IAUC part. No unverified revision number is inferred from that header. The precise filename, named subcircuit, installation version and hash identify the comparison source.

Both realizations retain the vendor model's nonlinear charge behavior, body diode and internal package network. Neither replaces them with the earlier SC-01A prescribed ramps or constant headline capacitances. The original vendor model remains an external installed dependency under its accompanying terms; it is not copied into this project or its public reference bundle.

## Revised behavioral driver and fixture

R2 assumes a regulated **+12 V on / −1.5 V off** drive relative to each MOSFET's external source terminal. A passive continuous directional gate impedance conducts according to `I = ΔV/Ron` for positive source-to-gate voltage difference, and `I = ΔV/Roff` otherwise. `Ron = 3 Ω + external gate resistance + additional turn-on resistance`; the selected additional turn-on resistance is zero. `Roff = 3 Ω` is the total external discharge impedance. The original internal gate resistance and package inductances remain additional.

The directional impedance is an ideal behavioral approximation, not a transistor-level driver or a literal diode bypass. The negative output rail requires a revised bipolar supply/output arrangement. **R2 is not an unchanged UCC27211A implementation.** Negative-rail generation/regulation, bootstrap charging/droop, UVLO, nonlinear source/sink limits, driver heating, clamp/diode dynamics and channel variability are not modeled. No particular hardware driver is selected by this work.

The [TI UCC27211A datasheet, SLUSBL4D](https://www.ti.com/lit/ds/symlink/ucc27211a.pdf) is the original timing reference: 20/19 ns rising/falling typical delays, and 7.2/5.5 ns 10–90% rise/fall times into 1 nF. Those timing tests do not identify a universal output resistance. The inherited 3 Ω output approximation and 20 ns internal command ramp remain assumptions, not a fit to the complete TI driver. Delays are applied to ramp onset, simplifying the datasheet measurement convention.

[TI, Fundamentals of MOSFET and IGBT Gate Driver Circuits, SLUA618A, sections 3.4–3.5](https://www.ti.com/lit/ml/slua618a/slua618a.pdf) describes stronger local gate discharge and negative turn-off voltage as ways to improve turn-off behavior and immunity to switching-node coupling. It also explains why an antiparallel diode becomes less effective near zero gate voltage. This provides the design basis for the remedy; it does not specify or guarantee R2's numerical values.

| Quantity | R2 value | Basis |
|---|---:|---|
| On / off gate-source command | +12 / −1.5 V | New regulated bipolar-drive assumption |
| Total external charge impedance | 25 Ω nominal; 13 / 50 Ω in gate cases | Inherited assumed 3 Ω output plus 22 / 10 / 47 Ω turn-on resistor |
| Total external discharge impedance | 3 Ω | New fixed split-drive assumption |
| Rising / falling delay | 20 / 19 ns | Inherited typical timing reference, simplified event convention |
| Internal command ramp | 20 ns, linear | Inherited assumption; actual device voltage follows the circuit |
| Source / feed impedance | 24 V / 0.05 Ω / 20 nH | Inherited fixture assumption |
| Local decoupling / ESR | 10 µF / 0.01 Ω | Inherited fixture assumption |
| Series load | 8 Ω / 2.5 mH | Inherited load without motor back-EMF |
| Commanded dead time | 300 ns | Inherited control assumption |
| Junction / case temperature | 25 °C | Isothermal test |

Vendor temperature nodes are held at a surrogate electrical value of 25 representing 25 °C; they are not a 25 V power rail. Self-heating is outside the experiment. A simulator's global temperature banner does not replace those explicit device inputs.

## Initial state, cases and timing

The 5 µs record begins at a consistent high-side-on DC operating point. Nominal current is approximately 2.98096418 A, determined by feed/device/load conduction, not separately forced. Each alternate case establishes its own operating point. Comparisons start at 1 µs and retain the initial/pre-edge current evidence.

| Driver-source action | Ramp starts | Ramp ends |
|---|---:|---:|
| High side falls | 2.019 µs | 2.039 µs |
| Low side rises | 2.320 µs | 2.340 µs |
| Low side falls | 3.719 µs | 3.739 µs |
| High side rises | 4.020 µs | 4.040 µs |

This is one preloaded off/on commutation pair, not periodic PWM steady state. Command separation does not prove absence of device overlap. Gate/drain transitions emerge from the nonlinear circuit and need not have the source ramp duration.

| Case | Source | Load resistance | External turn-on resistor |
|---|---:|---:|---:|
| `nominal` | 24 V | 8 Ω | 22 Ω |
| `holdout_bus18` | 18 V | 8 Ω | 22 Ω |
| `holdout_load4ohm` | 24 V | 4 Ω | 22 Ω |
| `holdout_gate47` | 24 V | 8 Ω | 47 Ω |
| `holdout_bus30_load16_gate10` | 30 V | 16 Ω | 10 Ω |

All retain the 2.5 mH inductance and other declared settings. R2 drive settings were selected through local screens including these cases. The inherited `holdout` names therefore identify regression cases, not blinded validation. No MOSFET parameters were adjusted to improve native/SPICE agreement.

## Remedy investigation and numerical representation

The immutable original campaign recorded nominal native common positive channel current of 3.19690 A and a 47 Ω native terminal peak of 186.91947 A. All five original cases had unresolved gate events. The portable [baseline extract](references/SC01B_Baseline_Summary.json) records original finest metrics and SHA-256 hashes of the source metrics/status files. It does not overwrite or backstamp that campaign.

Local screening showed that stronger discharge alone removed the 47 Ω runaway but left overlap at the 30 V / 10 Ω turn-on-resistor corner. Adding enough turn-on resistance conflicted with the existing 47 Ω gate-event window. The selected −1.5 V off bias and 3 Ω discharge path retained the full case variation and the original windows while providing more modeled overlap margin. These screens justify a revised fixture; final acceptance still depends on the complete collected R2 campaign.

The original PWL source representation showed strict-tolerance failures at command corners. The adopted remedy combines an algebraically equivalent initial value plus finite clipped-linear behavioral source with a fixed **1 ns transient TSTEP independent of the integration maximum TMAX**. Levels, delays, ramp durations and strict tolerances remain unchanged. Source conversion alone was insufficient in finer-step experiments. With `wrdata` and no `interp`, the data retain actual integration times, which the adapter checks against TMAX. This is not smoothing, a longer ramp, resampled output or an accepted partial trace.

The [solver resolution](results/verification/supplemental/solver/Solver_Resolution.md) and [portable supplement](results/verification/supplemental/solver/README.md) retain 19 complete strict checks and 132 per-signal comparisons, including all five revised cases at 0.0625 ns TMAX and nominal/combined cases at 0.03125 ns. TSTEP 10 ns repeats yielded identical arrays to TSTEP 1 ns; unchanged-original-driver strict recovery checks also completed. These observations support the numerical workaround without attributing it to a proven internal solver defect or to the physical drive revision. Full R2 acceptance still follows the collected campaign flags.

Native physical-network integration uses local trapezoidal steps, with the corresponding Simulink discrete step set explicitly. Native consistency tolerances control nonlinear initialization/reinitialization, not adaptive truncation-error estimates. SPICE uses trapezoidal integration and the recorded tolerances/source-stepping options. **The actual refinement arrays, consistency cases and frozen gates are those in `criteria.json` for the collected study.** The current workflow uses three native and two SPICE steps; altering those sequence lengths requires a new implementation and campaign. Generated reports derive their step labels from the recorded arrays rather than assuming a particular finest value.

The original portable runtime was ngspice 41 Windows x64, obtained from the [official ngspice download page](https://ngspice.sourceforge.io/download.html) and its [Fusion360/EAGLE portable package](https://ngspice.sourceforge.io/eagle-upgrade/ngspice-Fusion360-Update.7z). It needs no Fusion360/EAGLE installation. Original archive SHA-256: `3EA9BA44A8EB6C9B0791F5C093239E0BEE5DC5DDA334FA1C42F385CA6CEC599D`; executable SHA-256: `EF5CE0AE623D43810B2B528B31AC3941418EACA0F9ABA802E407ABA7DF8863AC`. Alternative runtime experiments must remain identified by their own version/provenance and cannot inherit these hashes.

All warnings, errors, incomplete runs, missing/nonfinite waveform data or failure to reach the stop time reject an attempt even if the executable returns process exit code zero. Required strict-check failures remain explicit failed/unavailable comparisons. Exploratory finer steps or alternative solver settings outside the collected criteria are supplementary and cannot replace required failed evidence. Current completion and failure statements belong in the generated report, not as permanent assumptions in this document.

## Acceptance and energy accounting

The numerical allowances retain the original values: waveform max(1% of reference peak absolute amplitude, 0.01 V or 0.01 A); event timing 1 ns; signed terminal energy max(1% of absolute reference energy, 1 nJ); external closure max(0.1% of accounted energy scale, 0.1 nJ). Actual values are recorded in `criteria.json`. Waveforms are compared on the union of recorded integration knots without fitted time shift or filtering.

Required switching events must have complete windows, correct endpoint states and finite ordered unique directed crossings. Missing, clipped, grazing or repeated required crossings cannot silently pass. Switch-voltage thresholds follow roots of `Vswitch − q·Vbus` for q = 0.1/0.5/0.9. Gate diagnostic levels remain **1.2, 6 and 10.8 V** and the original −0.1 to +0.5 µs command windows. These voltage levels remain referenced to +12 V; they are not fractions of the new 13.5 V excursion.

R2's operating-point gate also requires **zero simultaneous positive native channel conduction above max(1 mA, 0.1% of peak load current)** for every native refinement and consistency run. Channel knowledge must be present. Terminal-current coincidence includes capacitive and diode contributions; gate midpoint overlap is also a proxy and cannot satisfy this requirement. The reported peak common channel value remains visible even below the numerical floor.

`executionPassed`, `numericalCampaignPassed`, `modeledChannelOverlapPassed`, `operatingPointsPassed` and `switchingFailuresResolved` are computed by the complete-matrix acceptance helper. The overall switching flag requires both the full numerical and operating-point gates. Automated test success is separate. A voltage-rating pass is a modeled envelope check and does not qualify hardware.

External closure accounts for DC-source and both bipolar gate-source work, feed/decoupling/load/directional-gate losses, signed MOSFET terminal energy and changes in feed/load inductors and the DC-link capacitor. Capacitor energy uses the voltage behind ESR. The absolute preloaded load-inductor energy is not a permissive error normalization. Signed terminal energy includes charge transfer and is not semiconductor heat.

The local `references/Source_Manifest.json` retains the original manufacturer-PDF provenance. Independent measured commutation, negative-rail and complete-driver characterization, layout/component tolerances, temperature variation and receiver integration remain necessary before claiming the source represents robot hardware. `physicalSourceValidated` remains false.
