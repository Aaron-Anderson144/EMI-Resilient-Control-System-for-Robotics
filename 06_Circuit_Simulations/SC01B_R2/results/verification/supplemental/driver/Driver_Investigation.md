# SC-01B independent local driver investigation

Selected screening candidate: +12 V on / −1.5 V off, original charge resistance (13 / 25 / 50 Ω, including the assumed 3 Ω output resistance), fixed 3 Ω discharge resistance, unchanged 300 ns commanded dead time and 20 ns driver-source ramps.

The two-terminal drive element is passive and continuous: I = ΔV/Ron for ΔV > 0, otherwise I = ΔV/Roff. It is an ideal behavioral split-impedance driver. The −1.5 V off supply is a new fixture assumption; this is not an unchanged UCC27211A implementation. Actual output-stage, diode, negative-rail generation, bootstrap and hardware tolerances remain outside this screen.

Original Infineon MOSFET equations and package parasitics were preserved by including the installed original file. No device fit, capacitance change, snubber, output alignment, resampling or threshold relaxation was used.

## Fine local confirmation

All five cases completed to 5 μs at 0.125 ns maximum step and 1e−6 relative tolerance with no ngspice diagnostics. Each of the four gate transitions had exactly one crossing at each original diagnostic level (1.2, 6 and 10.8 V) and no opposite crossing within its original −0.1 to +0.5 μs command window. The terminal voltage diagnostic thresholds remain fractions of the original +12 V drive, not fractions of the bipolar excursion.

| Case | Peak terminal current, A | Peak common positive channel current, A | Channel floor, A | High-on 10.8 V margin, ns |
|---|---:|---:|---:|---:|
| nominal | 8.04895 | 4.00178e-11 | 0.00298096 | 242.015 |
| bus18 | 5.83041 | 2.91038e-11 | 0.00223572 | 243.093 |
| load4 | 11.8421 | 1.81899e-10 | 0.00592434 | 241.927 |
| bus30load16gate10 | 10.5821 | 1.51216e-07 | 0.00186903 | 354.863 |
| gate47 | 6.11863 | 2.91038e-11 | 0.00298096 | 6.44362 |

The reproduced original 47 Ω external-gate case reached 186.915 A terminal current and 183.459 A common positive channel current. The selected fine screen reduced its terminal current to 6.11863 A; its common-channel value was at numerical noise. The largest selected-case common channel current is approximately 151 nA at the 30 V / 16 Ω / 10 Ω gate corner, below the existing current floor by more than four orders of magnitude. Terminal currents include capacitance current and cannot themselves classify channel overlap.

## Causal screens and rejected choices

- Stronger discharge alone eliminated the 47 Ω runaway, but did not suppress the fast 30 V / 10 Ω gate corner. With 13 Ω charge / 3 Ω discharge, that case still reached 2.129 A common channel current. At its shared peak, terminal low Vgs was only 1.197 V while internal Vgs was 2.277 V. Terminal gate threshold checks alone would miss this.
- Adding charge resistance reduced the coupling, but enough resistance would slow the 47 Ω case beyond the unchanged gate-event window. This was not selected.
- A −1 V off bias with 3 Ω discharge already reduced the fast corner common peak to 71.3 μA. The −1.5 V selection provides more modeled overlap margin while retaining about 6 ns gate-window margin in the 47 Ω corner. −2 V provided still more channel margin but only a few millivolts of gate-window margin, so it was not selected.
- All five selected-candidate 0.125 ns runs with the original PWL source representation aborted at the first 2.019 μs breakpoint. Replacing the source representation with the mathematically identical initial value plus clipped linear ramps resolved all five. This did not change ramp duration or control timing. Original rejected logs are preserved under trials/*_fine; partial raw data remain in the original work archive and are identified by hashes in attempt_ledger.json.

## Scope and evidence

These driver screens used the original TSTEP=TMAX convention. The production R2 solver remedy additionally separates a fixed 1 ns TSTEP from TMAX; see the sibling solver supplement. This is a local driver-remedy screen, not full SC-01B source acceptance. The root campaign must still establish native/independent-engine agreement, numerical and long-record acceptance, and source readiness using the project checks. No physical hardware validity or complete reverse-recovery/thermal fidelity is established.

Primary design basis: [TI, Fundamentals of MOSFET and IGBT Gate Driver Circuits, SLUA618A](https://www.ti.com/lit/ml/slua618a/slua618a.pdf), sections 3.4–3.5. These sections describe lower discharge impedance and negative turn-off voltage, while identifying the limited near-zero effectiveness of a simple antiparallel turn-off diode. The chosen numeric values remain declared simulation assumptions.

Reproduction: use the parameterized screen.py command in README.md. The seven input configuration files and all 48 decks/control files/logs are included under trials. Six rejected/incomplete attempts remain explicit in attempt_ledger.json, including the five screen6 aborts for which the original exporter did not produce summary JSON. Compressed, unfiltered selected-candidate waveforms are included for all five screen7 fine cases; other raw trial data remain in the original work archive and their hashes are retained. selected_candidate_audit.json adds internal-gate, driver-current and timing margins.
