# Receiver characterization V2

Standalone **conditional numerical characterization** of a THVD1450DR receiver hypothesis and a loaded, lumped input network. It does not modify the rejected FOUR-WAY-EMI-PLAN-V1, validate a physical IC, run the motor controller, or execute reserved four-way evaluation fixtures.

## Run

From MATLAB at the project root:

```matlab
addpath(genpath('06_Circuit_Simulations/RECEIVER_V2'));
report = run_receiver_characterization(freshOutputDirectory);
r = runtests('06_Circuit_Simulations/RECEIVER_V2/tests');
assert(all([r.Passed]));
```

Signal Lab calls the same entry point. The output directory must be absent or empty. Existing evidence is preserved. The compact campaign takes about 10 seconds of computation on the development host, plus MATLAB startup and report rendering.

## Circuit and receiver assumptions

The machine-readable parameter authority is `receiver_characterization_config.json`. The main project receiver contract documents parameter provenance. The network uses the SC01A nodal equations, independently implemented and checked against KCL and an augmented matrix exponential. States are positive pin voltage, negative pin voltage and shared-return inductor current. The IC ground, 50/70 pF pin shunts and 10/20 kohm bias paths reference the quiet node at 0 V. The encoder driver references the dynamic shared-return node `g`; it has 47/53 ohm output resistances. The model includes the 120 ohm differential termination and 100 or 1,000 pF differential capacitance. Aggressor shared-return current and inductive coupling are zero by assumption. Cable propagation, protection and internal clamps are absent. Clamp current is unknown/null, never asserted to be zero.

THVD1450DR is a candidate operated in an assumed 5 V, 25 C, 15 pF output-load setting. DE is low and active-low RE is low. At least 20 microseconds of pre-enabled settling and the circuit's own DC equilibrium are assumed before t=0. No enable transient is simulated. Each pin and the differential voltage must remain in [-15,+15] V. Separate +/-18 V stress diagnostics never authorize operation outside the recommended domain. Common-mode voltage alone is insufficient.

Four assumed rising/falling threshold pairs (V) are crossed with two assumed equal post-threshold latencies and two pulse laws:

| Pair | Rising | Falling |
|---|---:|---:|
| Typical illustration | -0.100 | -0.130 |
| Lower illustration | -0.170 | -0.200 |
| Upper illustration | -0.020 | -0.050 |
| Narrow-hysteresis assumption | -0.100 | -0.105 |

Latencies are 25/25 ns and 40/40 ns by edge direction. These are **post-threshold modeling assumptions**: the TI datasheet's propagation delays are measured at differential input zero, not at the assumed trip threshold. The finite set is not an exhaustive hardware corner or skew analysis.

- **Transport:** every accepted Schmitt input edge is delayed. Coincident due events retain the last state in original input order. Asymmetric delays that overtake an earlier event are explicitly rejected as unresolved.
- **Inertial:** the new input state must persist through its latency; a return before that time cancels the pending output event. Equality is accepted. This is an assumption, not a documented pulse-rejection width of THVD1450.

Physical pulse acceptance, common-mode slew response, overdrive dependence and clamp behavior remain uncharacterized. [TI THVD14xx datasheet](https://www.ti.com/lit/ds/symlink/thvd1451.pdf).

## Fixed development campaign

The campaign has **40 circuit records and 640 behavioral cases** (16 variants per record), with clean/exposed pairs and no case deletion.

- Native: original 40,001 timestamps of the SHA-256-pinned SC01B_R2 finest source; Cp=30/300 pF, Cn=5 pF; Cd=100/1,000 pF; positive and negative polarity; clean/exposed. Positive polarity preserves the original source derivative. Negative polarity mirrors the waveform around its initial value and is explicitly a synthetic diagnostic. A 100 ns synthetic return closes the source, followed by settling to 6 microseconds. No repeated bursts are simulated here.
- Synthetic pulse diagnostics: 24 V trapezoids with 5 ns rise and fall, and **10/40/200 ns plateau widths**; both polarities; Cp=30 pF, Cn=5 pF; both Cd values; clean/exposed. These are separate development fixtures, not native source measurements.
- Every default record starts at A/B=00 and uses two complete forward Gray cycles over 0.8–4.9 microseconds. A uses a 100 ns driver transition; B is ideal. Initially high A and reverse motion are separately tested. Simultaneous A/B events within 1 ps are grouped at the latest time in the group; events precede a sample at that time. Initial and intended states are never receiver feedback inputs.

## Numerical acceptance

Each source/driver segment has affine input and an exact modal state solution; state is continuous across all knots. On each adaptive cell, the stable exponential modes bound the second derivative. The continuous deviation from endpoint linear interpolation is enclosed by `M2 * h^2 / 8`.

Any cell whose bound intersects a threshold and whose derivative bound does not establish monotonicity is subdivided. This includes cells with opposite-sign endpoints: one such cell can contain three crossings. Threshold roots are bisected to 0.1 ps. Unresolved tangencies or roots closer than the resolution reject acceptance. Same-direction duplicates at shared endpoints are removed; opposite-direction roots are not silently erased.

The 1 ns and 0.5 ns maximum-cell runs retain original finer source knots. Acceptance requires matching threshold state sequences, output/decoder event sequences and counts, event timing within 0.1 ns, and voltage extrema/enclosing bounds within 1 mV. The voltage tolerance covers vp, vn, vd, vcm and driver-ground displacement; return current has separate diagnostic bounds with ampere units. This is floating-point numerical evidence with analytical interpolation envelopes, not a hardware certificate.

Tests independently cover circuit equations, affine propagation, hidden multiple roots and domain occupation, unresolved grazing, signed pin/differential boundaries, transport/inertial short pulses, exact duration equality, asymmetric event collision/overtaking, coincident decoder edges, both Cd values, initially high state and reverse motion.

## Evidence files and field meanings

- `summary.json`: aggregate results, all 640 cases, continuous enclosing bounds and current/slew bounds per record, explicit `physicalValidation:false` and `evaluationReady:false`.
- `cases.csv`: one row per behavioral variant, including signed observed extrema, numerical bounds/refinement errors, voltage-domain status, first violation/duration, count error, edge counts, latency, overdrive and minimum pulse widths.
- `parameters.json` and `source_identity.json`: copied configuration and SHA-256 identities of engine, runner, tests, configuration and original source. A source edit requires a new run.
- `report.md` and `characterization.png`: human-readable assessment and signed voltage/edge-count plots.
- `details/*_trace.csv`: plot samples of signed voltages, shared ground, actual driver/coupling/termination currents and pin slew. These samples do not establish domain continuity.
- `details/*_crossings.csv`: columns time, signal index (1=vp,2=vn,3=vd), threshold and direction.
- `details/*_logic.csv`: complete Schmitt-input, delayed-output and decoder events, indexed by the fixed threshold/latency/law loop order.
- `details/*.mat`: full fixture, enclosing bounds, domain intervals, currents, pulse widths and every behavioral event sequence.

`extraEdges`/`missedEdges` mean **net A-edge-count excess/deficit**, not a matched-event classification. Extra and missing edges can cancel. `finalCountError` is against the independently intended Gray trajectory's final count; a zero final error does not imply an undisturbed waveform. Pulse-law-dependent case counts compare final counts or total output-edge counts, not every waveform timestamp.

`validCases` means inside the modeled voltage domain with converged numerics. Diagnostic cases outside that domain remain retained but cannot support control scoring. `validExposedErrorCases` and `validPulseLawDependentCases` exclude rejected cases. `suitableForFourWay` is only the clean decoding/domain/numerical/delay prerequisite. It does not declare integration or evaluation ready; each future exposed trajectory needs its own checks.
