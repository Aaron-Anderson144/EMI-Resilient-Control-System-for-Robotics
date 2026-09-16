# Receiver characterization V2

Conditional numerical characterization only; no physical receiver validation or control scoring.

Generated 2026-09-15T22:03:49Z. 40 circuit records / 640 behavioral cases.

- 640 of 640 variant cases are continuously inside the modeled voltage domain with converged numerics.
- 0 variant cases leave the operating domain; 0 remain numerically unresolved.
- 0 clean cases have count/edge errors; 0 valid-domain exposed cases have final count error (0 additional diagnostic rejected cases).
- 80 valid-domain variant cases change final count or edge count between assumed pulse laws (80 total including rejected diagnostics).

## Scope and interpretation

- Voltage-domain passage establishes only a conditional model-domain result, never physical validation.
- Threshold pairs and post-threshold latencies are a finite assumed sensitivity grid, not guaranteed component corners.
- Transport and inertial behavior are competing assumptions; propagation delay is not a pulse-rejection specification.
- Ideal B, lumped cable, assumed network impedances, no protection/clamp model, and no driver/MCU hardware qualification.
- Negative native polarity is a mirrored diagnostic. Synthetic pulses use plateau widths plus two 5 ns ramps.
- Domain violations retain diagnostic events and counts but cannot enter control scoring.
- This development characterization does not execute or validate the new four-way control experiment.

## Continuous numerical method

Exact affine-segment modal propagation; continuous linear-interpolation error bounds M2*h^2/8; adaptive root isolation and coarse/fine verification. All source and driver knots retain persistent state. On each interval the stable exponential modes bound the second derivative, giving a continuous interpolation error envelope M2 h^2 / 8. Nonmonotone candidate root cells are subdivided; remaining unresolved cells reject acceptance. Threshold roots are bisected to 1e-13 s. Extrema are observed values with retained enclosing bounds, not certified exact extrema. Coarse/fine event sequences and count results must agree. Per-record bounds and current/slew bounds are in summary.json and details.

## Topology and timing

IC ground, pin shunts and bias returns are the quiet reference 0 V; the encoder driver reference is the dynamic shared-return node g. No receiver ground displacement is silently added. Input driver has 47/53 ohm output resistance, 120 ohm termination and assumed shunts/bias paths. THVD1450DR is pre-enabled for at least20us before t=0 with a DC-equilibrium network; supply5V, ambient25C and output load15pF are assumptions. There is no enable transient. Post-threshold latency is an explicit modeling assumption: TI times are referenced to input vd=0. Inertial events at exactly the required duration are accepted; simultaneous A/B changes are grouped before decoding.

## Reproduction

Run `addpath(genpath('06_Circuit_Simulations/RECEIVER_V2')); run_receiver_characterization(freshOutputDirectory)` from the project. Source SHA-256: `1ecdd83ee4f4846b70e2d40ba04f4b3188e737c94f08300a5bbbfcc36acb9cd5`. Parameters are copied into parameters.json. Original native timestamps are retained; 100ns synthetic return is separately declared. Synthetic pulse widths mean plateau duration. All synthetic cases are development diagnostics.

The `suitableForFourWay` flag is only the clean numerical prerequisite; every exposed control case still requires its own domain and behavior checks. No benefit claim follows from this flag.

`extraEdges` and `missedEdges` are net excess/deficit of A-edge count versus the intended sequence, not matched-event classifications. Pulse-law dependence counts paired variants whose total output-edge count or final count differs; it does not compare every waveform timestamp. Input/output pulses and complete decoder events are retained per record in MAT and logic CSV files. Decoder events within1ps are grouped at the latest time in the group before a same-time sample.
