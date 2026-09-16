# Receiver V2: circuit and behavioral contract

**ID:** RECEIVER-V2-CONTRACT-2026-09-15. **Scope:** conditional numerical characterization, not hardware qualification. Executable values are in `06_Circuit_Simulations/RECEIVER_V2/receiver_characterization_config.json`; disagreement with this contract rejects acceptance.

## Receiver and installation

The modeled candidate is **Texas Instruments THVD1450DR**, SOIC-8, at assumed regulated **5.0 V**, **25 °C**, and **15 pF** output load. Tie pin 3 DE low, pin 2 active-low RE low, and unused pin 4 D low. Pin 8 is supply; pin 5 is quiet receiver ground; pin 6 A receives `vp`; pin 7 B receives `vn`; pin 1 R produces the received encoder-A bit. Bus pin names A/B are distinct from the encoder quadrature A/B channels.

Initialize enabled and settled before time zero, with the circuit at its own DC equilibrium. An assumed pre-run interval of at least 20 microseconds exceeds the published 14 microsecond maximum enable delay under the relevant disabled-driver test. This is not a simulated startup or brownout. A physical controller's input voltage compatibility remains unidentified.

| Quantity | Value or treatment | Evidence class |
|---|---|---|
| Recommended supply | 3–5.5 V | Specified operating condition |
| Each bus pin relative to receiver ground | −15 to +15 V | Specified operating condition |
| Differential input | −15 to +15 V | Separately checked operating condition |
| Each pin and differential stress | −18 to +18 V | Absolute maximum, not functional permission |
| Rising threshold | −100 mV typical; −20 mV maximum | Typical/recognition bound, not exact trip level |
| Falling threshold | −130 mV typical; −200 mV minimum | Typical/recognition bound, not exact trip level |
| Hysteresis | 30 mV typical | No guaranteed numerical minimum inferred |
| Propagation delay | 25 ns typical, 40 ns maximum at specified load | Reference waveform measurement |
| Pulse skew | 3.5 ns maximum under reference test | Not arbitrary-pulse characterization |
| Fast pulses, ringing, common-mode transients | Unidentified | Competing explicit hypotheses below |
| Internal pin loading, clamps and supply coupling | Unidentified | No calibrated nonlinear device model |

Source: [TI THVD14xx, SLLSEY3E Rev E](https://www.ti.com/lit/ds/symlink/thvd1451.pdf), pin functions, recommended conditions, receiver electrical/switching characteristics and Figures 25/27, checked 15 September 2026. Test conditions remain part of each specification. **The published propagation delay is measured from `vd=0` in its reference waveform. Adding that number after a Schmitt threshold crossing is an assumed behavioral latency, not a literal datasheet timing corner.**

## Explicit loaded circuit

Retain the SC01A three-state topology `[vp, vn, ir]`. Receiver ground is the quiet zero reference. Encoder-driver sources use a separate shared-return node `g`, connected to zero through 25 milliohm and 20 nH. Record `g` displacement; do not subtract it again from `vp/vn` when checking receiver pins.

| Element | Declared value | Classification |
|---|---|---|
| Encoder source levels | `Vsp=2.5+s`, `Vsn=2.5−s`, `s=±1 V` | Representative driver assumption |
| Driver edges | Linear, 100 ns | Assumed |
| Source resistance | 47/53 ohm | Assumed |
| Pair termination | 120 ohm | External assumed resistor, not internal receiver resistance |
| Shunts to quiet ground | 50/70 pF | External lumped assumptions, not identified pin capacitance |
| Returns to quiet ground | 10/20 kohm | External loading, not a calibrated leakage model |
| Differential capacitance | 100/1,000 pF | Electrical treatment; no superiority presumed |
| Aggressor coupling | Fixture `Ccp/Ccn` | Assumed susceptibility axis |
| Inductive source / aggressor return-current injection | Zero | Excluded mechanisms |
| Nonlinear input protection | Unmodeled | Clamp current is unknown, not measured zero |
| Encoder B | Ideal timing | Two physical channels remain future work |

The mass matrix and return relation are:

```text
C = [50pF + Ccp + Cd, -Cd; -Cd, 70pF + Ccn + Cd]
gp=1/47; gn=1/53
g=(gp*vp + gn*vn - ir - gp*Vsp - gn*Vsn)/(gp+gn)
L*dir/dt=g-R*ir
```

Driver currents are `(g+Vsp−vp)/47` and `(g+Vsn−vn)/53`. Actual coupling-branch currents are `Ccp*(dVa/dt−dvp/dt)` and `Ccn*(dVa/dt−dvn/dt)`, distinct from the Norton forcing terms `C*dVa/dt`. Independent node KCL/return-law checks must verify the implementation. Preserve state across every source knot and finite driver transition.

## Characterization sources and fixtures

Read the original `SC01B_R2/results/verification/nominal/native_finest.csv`, SHA-256 `1ecdd83ee4f4846b70e2d40ba04f4b3188e737c94f08300a5bbbfcc36acb9cd5`, retaining every original time/voltage knot. A 100 ns linear return to its initial voltage precedes DC hold through **6 microseconds**. This is a compact synthetic construction, not a periodic or measured installation waveform.

Eight replay-derived exposed fixtures cross coupling 30/5 or 300/5 pF, differential capacitance 100/1,000 pF, and source polarity +/−. The implementation subtracts the original constant DC offset and applies the declared polarity: `Va=polarity*(Vraw−Vraw(0))`. This is algebraically equivalent for this derivative-driven linear coupling network, which has no absolute-aggressor clamp/ground dependence. Positive retains the original voltage differences at every knot; negative is an explicitly mirrored synthetic diagnostic. The raw source hash remains independently checked. Each has a matched constant-aggressor clean companion. Initial encoder A is low; two full intended Gray cycles from 0.8 to 4.9 microseconds exercise rising/falling A and ideal B. Initial-high behavior is checked separately.

Separate constructed 24 V pulse diagnostics use 5 ns ramps and declared 10/40/200 ns widths, 30/5 pF coupling, both capacitances and both source polarities, with clean companions. Width is the flat plateau duration between the 5 ns rising and falling ramps; total nonzero-pulse support is width plus 10 ns. These are not native-source or physical records. The compact electrical fixtures are development evidence, not the reserved integrated PLAN-V2 evaluation.

## Finite receiver sensitivity set

Cross four threshold pairs, two assumed equal-edge post-threshold latencies (25/25 or 40/40 ns), and two pulse laws: **16 variants** per circuit.

| Threshold pair | Rising / falling, V | Meaning |
|---|---|---|
| Nominal | −0.100 / −0.130 | Typical values used illustratively |
| Lower | −0.170 / −0.200 | Assumed pair within recognition constraints |
| Upper | −0.020 / −0.050 | Assumed pair within recognition constraints |
| Narrow | −0.100 / −0.105 | Assumed 5 mV hysteresis sensitivity |

**Transport:** retain threshold-generated logical edges and apply the declared latency. **Inertial:** cancel a pending output change if the requested state fails to persist through its latency. The latter equates an illustrative rejection interval with latency by assumption; it is not a datasheet pulse-rejection guarantee.

This finite set is not a complete device-corner envelope. Unequal edge delays are omitted from the campaign; an asymmetric-delay unit fixture checks event handling but cannot establish skew robustness. Preserve every variant, identify pulse-law-dependent conclusions, and never select the most favorable model. Applicable device characterization or measured traces are required to promote the scope to physical receiver behavior.

## Domain and numerical acceptance

Check signed `vp`, signed `vn`, and `vd=vp−vn` across the continuous trajectory. Pin-domain membership is equivalently `abs(vcm)+abs(vd)/2<=15 V`; separately impose `abs(vd)<=15 V`. Common-mode extrema alone are insufficient. Keep ±18 V stress diagnostics separate from operating acceptance.

Retain continuous extrema or conservative enclosures, first exit and duration, refinement checks, threshold/output transitions, pulse widths, currents and ground displacement. Exact affine propagation plus between-knot bounds avoids labeling coarse samples as continuous coverage. Unresolved grazing, threshold roots, incompatible delayed-event order, or failed refinement must be rejected/unresolved, not accepted. A later valid voltage does not restore interpretation of behavior following an invalid excursion.

Fresh workflow outputs include configuration and source/code identity, cases and variants, event/detail records, numerical checks, plots and a readable report. Passing checks verifies these declared equations and hypotheses, not hardware validity or combined mitigation benefit.

## Next four-way experiment

Use the same receiver/topology/behavioral variant in all four arms. Only differential capacitance and the historical protection-enabled control choice differ. The common receiver replacement cannot be credited as the capacitance treatment's benefit.

This electrical harness requires a separately accepted causal motor/controller integration under [PLAN-V2](Four_Way_EMI_Experiment_V2.md). It does not unlock the historical evaluation, and PLAN-V1 inputs, results and rejected gates remain preserved.
