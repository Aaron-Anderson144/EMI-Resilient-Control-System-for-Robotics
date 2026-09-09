# SC-01B device sources and assumptions

SC-01B uses Infineon IAUC100N04S6L014 MOSFET models and a UCC27211A-informed behavioral gate drive to produce a circuit-derived switching source. Its scope is **isothermal verification of the native device-model realization against the original manufacturer SPICE equations**. Agreement between those realizations is not physical validation of a MOSFET, driver IC, motor inverter, or robot installation. No hardware component selection is claimed.

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

## Behavioral driver and fixture

The [TI UCC27211A datasheet, SLUSBL4D, July 2024](https://www.ti.com/lit/ds/symlink/ucc27211a.pdf) gives typical rising/falling propagation delays of 20/19 ns with 12 V supplies and no output load. The measurements run from the input threshold to output 10%/falling 90%. With 1 nF, typical 10–90% rise/fall times are 7.2/5.5 ns. At 100 mA, typical high/low output drops are 0.11/0.07 V. The revision removes the former 0.9 Ω output-resistance claim because it was not specified.

Inferring a single RC resistance from the 1 nF timings gives approximately 3.277/2.503 Ω; the small-current DC drops instead imply 1.1/0.7 Ω. These deductions do not identify a universal output resistance. **The implemented symmetric 3 Ω is an assumed compromise**, and the 20 ns internal source ramp is a separate assumption. Together they are not a fit or reproduction of TI's loaded-output tests. Applying the 20/19 ns delays to ramp onset also simplifies the datasheet measurement convention.

| Implemented quantity | Nominal value | Basis |
|---|---:|---|
| Gate-drive high level | 12 V | TI characterization supply used as the fixture reference |
| Driver output resistance | 3 Ω per channel | Fixed, symmetric approximation |
| External gate resistance | 22 Ω per channel | Assumed bench value |
| Rising / falling delay | 20 / 19 ns | TI typical values, simplified event convention above |
| Internal drive-command ramp | 20 ns, linear | Assumed; actual VGS follows the circuit |
| DC source | 24 V | Assumed nominal experiment |
| Supply-feed resistance / inductance | 0.05 Ω / 20 nH | Assumed supply interconnection |
| Local DC-link capacitance / series ESR | 10 µF / 0.01 Ω | Assumed decoupling |
| Series inductive load | 2.5 mH and 8 Ω | Assumed load, without motor back-EMF |
| Commanded dead time | 300 ns | Assumed before channel delays |
| Device junction and case temperature | 25 °C | Isothermal test condition |

The nominal drive resistance is 25 Ω outside each MOSFET model; the vendor model's internal gate resistance and package inductances remain additional. Controlled drive sources reference each MOSFET's external source terminal. The high-side drive is a regulated floating supply. Bootstrap charging/droop, UVLO, input hysteresis, nonlinear source/sink limits, level shifting, driver thermal effects and channel variability are omitted. This is not the full UCC27211A IC model. The optional legacy TI `UCC27211.LIB` found during research is not used or included in `references`.

The vendor SPICE temperature nodes are held at a surrogate electrical value of 25, representing 25 °C. They do not represent a 25 V power rail. A simulator banner's global nominal temperature must not be confused with these explicit device temperature inputs. Self-heating is outside this experiment.

## Initial state and commutation record

The record lasts 5 µs. A consistent DC operating point starts with the high-side device on and the low side off. In the nominal original-SPICE pilot, the resulting load current is **2.98096418 A**. The approximately 3 A value is a reference, not a separately forced initial current: the DC feed drop and device conduction determine the state. Each alternate fixture must establish its own consistent operating point.

High-side turn-off is commanded at 2 µs and turn-on at 4 µs, with complementary low-side operation. After the specified propagation delays, the finite internal drive ramps are:

| Channel action | Ramp begins | Ramp ends |
|---|---:|---:|
| High side falls | 2.019 µs | 2.039 µs |
| Low side rises | 2.320 µs | 2.340 µs |
| Low side falls | 3.719 µs | 3.739 µs |
| High side rises | 4.020 µs | 4.040 µs |

This is one preloaded off/on commutation pair, not a periodic PWM steady state. Device gate and drain transitions emerge from the nonlinear circuit and are not equal to command ramps. Command separation alone does not establish absence of simultaneous device conduction; measured terminal traces and currents must be examined. Edge comparisons start at 1 µs to exclude the initialization preamble, while initial and pre-edge currents are reported separately.

## Frozen original-equation comparisons

The five cases use the same unchanged vendor equations and declared behavioral driver. They are predeclared conversion-verification points with no fitting or subsequent parameter tuning to improve native/SPICE agreement.

| Case | Source voltage | Load resistance | External gate resistance |
|---|---:|---:|---:|
| Nominal | 24 V | 8 Ω | 22 Ω |
| Lower supply | 18 V | 8 Ω | 22 Ω |
| Higher load current | 24 V | 4 Ω | 22 Ω |
| Slower gate drive | 24 V | 8 Ω | 47 Ω |
| Combined extension | 30 V | 16 Ω | 10 Ω |

All retain the 2.5 mH load inductance and other frozen fixture values. Load current follows the circuit, so the alternate cases are not all 3 A tests. Agreement must include the relevant voltage/current traces, edge timing, terminal peaks and numerical refinement. A 24 V nominal source alone does not establish the 40 V VDS or ±16 V VGS envelope during ringing. Device-rating checks are simulation-envelope checks and do not qualify physical hardware.

The declared native refinement sequence uses the Simscape local trapezoidal solver at physical-network steps of 0.5, 0.25 and 0.125 ns. The matching Simulink discrete step is also set explicitly. Original-SPICE comparisons use trapezoidal integration with maximum steps of 0.25 and 0.125 ns. Output interpolation is for comparisons only; it is not a substitute for refining either integration. Actual settings remain recorded with each run. The initial global implicit-solver attempt did not complete successfully and is not accepted evidence.

The local solver's consistency tolerances govern nonlinear initialization/reinitialization, not adaptive truncation-error control. The nominal configuration declares local absolute/relative consistency tolerances of 1e-12/1e-8 and factor 1, with fixed-cost iterations disabled. A separate tenfold consistency-tolerance tightening is declared for the nominal and combined-extension fixtures. Step refinement and consistency tightening answer different numerical questions and must both retain their results.

The independent implementation uses **ngspice 41, Windows x64**, acquired as a portable archive directly from the [ngspice project's official download page](https://ngspice.sourceforge.io/download.html), which links the [Fusion360/EAGLE update package](https://ngspice.sourceforge.io/eagle-upgrade/ngspice-Fusion360-Update.7z). It runs as a separate executable; no Fusion360/EAGLE installation is needed or modified. Archive SHA-256: `3EA9BA44A8EB6C9B0791F5C093239E0BEE5DC5DDA334FA1C42F385CA6CEC599D`. Executable SHA-256: `EF5CE0AE623D43810B2B528B31AC3941418EACA0F9ABA802E407ABA7DF8863AC`. This source identifies the tested runtime, not a claim that version 41 is the newest release.

The current SPICE deck selects `.options gminsteps=0 srcsteps=1`: gmin stepping is disabled and direct source stepping is used for the DC operating point. All five initial screen cases explicitly logged successful source-stepping completion, reached the 5 µs stop time and produced zero warnings. That clean completion establishes usable records; it does not establish acceptable waveforms. In particular, the initial 47 Ω screen reports a 186.9197 A terminal-current peak and two unresolved events. Its behavior requires investigation and must retain a failed or limited status if the campaign criteria remain unmet.

An earlier pilot used gmin continuation and emitted intermediate warnings. The production helper no longer accepts any such warning: all warnings/errors, aborted or incomplete runs, missing/nonfinite waveform data and failure to reach the requested stop time reject the result. Native warnings also reject acceptance. Exploratory pilots remain outside the accepted campaign.

## Predeclared numerical acceptance criteria

The campaign distinguishes within-engine refinement, native-versus-original-equation comparison and external circuit energy closure. The numerical thresholds are declared before acceptance is assessed. A failed stress point remains part of the five-case matrix; it is not removed or relabeled as passing because the engines agree with each other.

| Comparison | Criterion |
|---|---|
| Maximum waveform difference | At most max(1% of the maximum absolute reference amplitude, 0.01 V or 0.01 A) |
| Matched event timing | At most 1 ns absolute difference, with finite matched events and compatible crossing interpretation |
| Signed terminal-energy difference | At most max(1% of the absolute reference energy, 1 nJ) |
| External circuit energy closure | At most max(0.1% of the accounted energy scale, 0.1 nJ) |
| Record and diagnostics | Finite complete records; no transient warnings; native diagnostics accepted only when warning-free |

Absolute allowances prevent nearly zero signals from imposing vanishing error limits. For example, an energy comparison is `abs(Etest-Eref) <= max(0.01*abs(Eref),1 nJ)`. Waveforms are compared on the union of their recorded integration times over 1–5 µs, without a fitted time shift or filtering. The reference direction, closure normalization and individual pass flags remain explicit in the implementation and report. Signed event energy includes stored-charge transfer through drain and gate terminals and is not identified as semiconductor heat. A near-zero signed energy may result from cancellation, so branch contributions and trace differences remain useful diagnostics even when the scalar criterion passes.

Switching events use roots of `Vswitch - q*Vbus` for q = 0.1, 0.5 and 0.9, preserving the moving local bus. Gate midpoint timing and simultaneous positive terminal currents are diagnostics; they do not independently prove channel conduction or shoot-through. Missing, clipped or grazing required events cannot silently pass a timing comparison. Ringing and repeated crossings must retain their counts and interpretation; first-crossing agreement does not establish that a heavily oscillating event is an acceptable source. The declared windows must not be silently widened after inspecting a failing case.

External energy closure accounts for DC-source and both gate-source work, feed/decoupling/load/gate resistance losses, signed MOSFET terminal energies, and changes in feed-inductor, load-inductor and DC-link-capacitor stored energy. The capacitor voltage is the voltage behind its ESR, rather than the bus voltage. The large preloaded inductor's absolute stored energy must not serve as a permissive normalization for small commutation errors. Numerical agreement, record completion, device terminal-voltage limits and event suitability are separate conditions.

The local `references/Source_Manifest.json` records the official URLs, revisions, retrieval date, sizes and SHA-256 hashes for the two included manufacturer PDFs. Simulator agreement verifies the conversion and circuit realization under these assumptions. Independent measured commutation waveforms, driver characterization, component/layout tolerances, temperature variation and the final victim/receiver integration remain separate work.

## Strict-tolerance limitation found during execution

The nominal original-SPICE attempt with all three tolerances tightened tenfold stopped at 2.019 µs, the first gate-command corner. Increasing iteration budgets, changing integration method, reducing the maximum step and varying pivot/source-stepping controls did not resolve that failure. Relative-only and current-absolute-only tightening also failed at the corner; voltage-only tightening completed and closely matched the baseline. This isolates sensitivity to particular numerical criteria, not the internal root cause. The voltage-only result is supplementary and does not replace the failed frozen all-tight check.

The production adapter rejects incomplete transients even when the external executable returns a successful process exit code. The campaign preserves a rejected-attempt row and failed comparison for this stricter check. Only complete traces contribute to waveform/energy measurements. Accordingly, implementation and execution completion are distinct from full numerical acceptance, which remains false when a required reference is unavailable. Supplemental diagnosis files accompany the final verification results.
