# Phase 2B Coupling and Communication Faults

## Purpose and Status

Phase 2B introduces repeatable electromagnetic-coupling, ground-reference, and communication-channel mechanisms into the robotic-actuator feedback loop. The MATLAB source, generated Simulink model, automated tests, analytical study, packet-loss study, smoke tests, and cross-validation evidence were completed on 2026-09-08.

This is a **physics-based reduced-order, assumed-parameter, receiver-equivalent model**. It is suitable for equation verification, controlled fault isolation, and sensitivity analysis. It is not a measured or physically validated model of a particular motor drive, cable, shield, ground network, receiver, encoder, communication bus, or installation.

## Fidelity Boundary

The controller model samples at 1 kHz (`Ts = 1 ms`), while the assumed PWM source switches at 20 kHz and has 100–200 ns edges. The controller-rate model cannot resolve those PWM cycles or edges. Phase 2B therefore uses a two-stage approximation:

1. calculate finite-edge peak current or voltage from the coupling equations;
2. expose the closed-loop controller to a receiver-equivalent 120 Hz baseband envelope with that calculated scale.

The envelope is not the PWM waveform. It must not be used to infer switching spectra, electromagnetic-compliance levels, receiver pulse-width behavior, or bit-error rate.

The final conversion from receiver differential voltage to angular feedback error uses `systemLevelEquivalentSensitivity_rad_V`. This parameter is **phenomenological**. It supports a system-level “what happens if” study but is not a physical encoder-decoder law and does not predict false counts, threshold crossings, metastability, or protocol errors.

## Parameter Identification

- **Parameter set:** `REPRESENTATIVE-ACTUATOR-V0.2`
- **Parent set:** `REPRESENTATIVE-ACTUATOR-V0.1`
- **Phase 2B provenance:** assumed reduced-order values for sensitivity analysis
- **Date introduced:** 2026-09-08

### Source and Receiver Assumptions

| Parameter | Value | Unit | Role |
|---|---:|---|---|
| Switching voltage step | 24 | V | Aggressor voltage change |
| Assumed PWM frequency | 20,000 | Hz | Source context; not directly sampled |
| Voltage rise/fall time | 100 | ns | Finite-edge `dV/dt` |
| Current step | 3 | A | Aggressor current change |
| Current rise time | 200 | ns | Finite-edge `dI/dt` |
| Observed baseband frequency | 120 | Hz | Controller-rate receiver-equivalent envelope |
| Differential termination | 120 | ohm | Converts differential capacitive current to voltage |
| Differential capacitance | 100 | pF | Receiver assumption reserved for higher-fidelity refinement |
| Receiver bandwidth | 5 | MHz | First-order baseband gain |
| Differential noise margin | 0.20 | V | Diagnostic comparison threshold |
| Common-mode limit | 7.0 | V | Receiver assumption reserved for threshold-oriented refinement |
| Minimum pulse width | 50 | ns | Receiver assumption reserved for decoder refinement |
| Maximum spurious counts per sample | 4 | count | Reserved bound for future count-event mapping |
| System-level equivalent sensitivity | 10 | degree/V | Phenomenological voltage-to-angle bridge |

### Coupling and Ground Assumptions

| Mechanism | Parameter | Value |
|---|---|---:|
| Capacitive | Positive-line capacitance | 10 pF |
| Capacitive | Negative-line capacitance | 9 pF |
| Capacitive | Path-transfer factor | 0.20 |
| Inductive | Positive-line mutual inductance | 20 nH |
| Inductive | Negative-line mutual inductance | 17 nH |
| Inductive | Path-transfer factor | 0.50 |
| Shared return | Resistance | 25 milliohm |
| Shared return | Inductance | 20 nH |
| Shared return | Common-mode-to-differential factor | 0.10 |
| Ground offset | Common-mode voltage | 0.10 V |
| Ground offset | Common-mode-to-differential factor | 0.10 |

## Reduced-Order Coupling Equations

The receiver gain at the observed envelope frequency is approximated as:

\[
H_{rx}=\frac{1}{\sqrt{1+(f_{env}/BW_{rx})^2}}
\]

For the current assumptions, `Hrx` is approximately unity because 120 Hz is far below 5 MHz.

### Capacitive Imbalance

\[
\Delta C=C_{+}-C_{-}
\]

\[
\frac{dV}{dt}=\frac{\Delta V}{t_r}
\]

\[
I_{cap,pk}=\Delta C\frac{dV}{dt}
\]

\[
V_{cap,pk}=\alpha_C R_D I_{cap,pk}H_{rx}
\]

With `deltaC = 1 pF` and `dV/dt = 2.4e8 V/s`, the calculated current peak is approximately `0.24 mA` and the receiver differential-voltage peak is approximately `5.76 mV`.

### Inductive Imbalance

\[
\Delta M=M_{+}-M_{-}
\]

\[
\frac{dI}{dt}=\frac{\Delta I}{t_i}
\]

\[
V_{ind,pk}=\alpha_M\Delta M\frac{dI}{dt}H_{rx}
\]

With `deltaM = 3 nH` and `dI/dt = 1.5e7 A/s`, the calculated receiver differential-voltage peak is approximately `22.5 mV`.

### Shared-Return Impedance

\[
V_{return,pk}=R_{return}\Delta I+L_{return}\frac{dI}{dt}
\]

\[
V_{shared,DM,pk}=k_{CM\rightarrow DM}V_{return,pk}H_{rx}
\]

The current assumptions produce `75 mV` from the resistive term and `300 mV` from the inductive term before conversion. The calculated differential contribution after the 0.10 conversion factor is approximately `37.5 mV`.

### Ground-Reference Conversion

\[
V_{ground,DM}=k_{ground,CM\rightarrow DM}V_{ground,CM}
\]

The current assumptions produce a constant `10 mV` differential contribution while the ground-offset scenario is active.

### Receiver Sum and Equivalent Angular Error

\[
V_{receiver,DM}=V_{cap}+V_{ind}+V_{shared,DM}+V_{ground,DM}
\]

\[
\theta_{equiv}=K_{sys}V_{receiver,DM}
\]

The component waveforms use distinct sine/cosine phases, so their peaks are not assumed to occur simultaneously. `combined_coupling` uses direct sample-by-sample superposition. The margin diagnostic is true when the magnitude of the summed differential voltage exceeds the assumed 0.20 V differential noise margin.

At 10 degree/V, the individual calculated peak scales correspond to approximately 0.0576 degree capacitive, 0.225 degree inductive, 0.375 degree shared-impedance, and 0.10 degree ground-offset equivalent error. These values are model outputs from assumed inputs, not measured encoder errors.

## Activation Windows

All windows are half-open: the start sample is included and the stop sample is excluded.

| Mechanism | Interval |
|---|---|
| Capacitive, inductive, and shared-impedance source envelope | `[0.85, 1.15)` s |
| Ground offset | `[0.85, 1.10)` s |
| Delay, jitter, and packet-loss configuration | `[0.70, 1.10)` s |

Half-open intervals make expected sample counts unambiguous at the 1 ms sample time. Delayed arrivals created within the communication window can still arrive after the configuration window; post-window metrics capture any resulting persistence.

## Communication Model

Every sensor-side sample is assigned its source index as a timestamp. The configured channel can apply:

- fixed delay of 8 samples;
- independently seeded integer jitter from 0 through 8 samples;
- independently seeded packet loss with probability 0.20;
- hold-last reception when no newer sample is accepted.

For source sample `k`, a non-lost packet is scheduled at `k + delay(k)`. Packets scheduled after the end of the record do not arrive. If multiple packets arrive at the same controller sample, the newest source index wins. If the newest arrival is not newer than the last accepted source index, it is discarded as out of order. The channel records accepted delay, last accepted source index, measurement age, collision discards, out-of-order discards, and held-last state.

This scheduling model is causal but protocol-agnostic. It does not model CAN arbitration, frame serialization, bit stuffing, CRC, retransmission, bus-off behavior, clock tolerance, or physical-layer voltages.

## Named Scenarios

| Name | Enabled mechanisms | Intended use |
|---|---|---|
| `none` | None | Matched Phase 2B reference; all new fault mechanisms disabled |
| `capacitive_coupling` | Capacitive only | Equation, polarity, scaling, and isolated response |
| `inductive_coupling` | Inductive only | Equation, polarity, scaling, and isolated response |
| `shared_impedance` | Shared return only | Resistive/inductive return-path response |
| `combined_coupling` | Capacitive, inductive, and shared return | Superposition check |
| `ground_offset` | Ground common-mode-to-differential conversion | Isolated reference-offset response |
| `communication_delay` | Fixed delay | Causality and stale-data response |
| `communication_jitter` | Seeded bounded jitter | Repeatability and ordering response |
| `packet_loss` | Seeded loss and hold-last | Loss fraction and missing-update response |
| `combined_phase2b` | Every Phase 2B mechanism | Exploratory stress case; not an isolation case |

## Feedback-Loop Placement

The physical profile is added to true plant position to form the sensor-side measurement. The communication model then determines which timestamped sensor-side sample reaches the controller. The controller acts on reference minus received measurement. This ordering represents physical corruption before transport and permits delay/loss to act on already-corrupted samples.

## Comparison Metrics

Each faulted run is compared with a matched `none` run from the same Phase 2B simulator and parameter set. The following are primary:

- maximum pre-onset absolute position delta;
- active-window position-delta RMSE and maximum absolute delta;
- active-window received-measurement and command deltas;
- maximum post-window position delta;
- packet-drop and missing-update fractions;
- mean and maximum measurement age;
- recovery time after the latest enabled stop time, using a 0.05 degree threshold and 50-sample dwell;
- an explicit censoring flag when recovery is not observed before the record ends.

Whole-run tracking error is not sufficient for Phase 2B attribution because the commanded step transient is much larger than the initial assumed disturbances.

## Recorded Software Verification

The 2026-09-08 evidence verifies the implementation against its specified reduced-order equations and scheduling logic:

- 28 of 28 project tests passed, including 16 of 16 Phase 2B tests;
- `none` regressed to the Phase 2A no-fault implementation within `1e-12`;
- half-open windows, peak equations, polarity, linear scaling, mechanism isolation, superposition, and zero transfer/conversion were exercised;
- the communication scheduler was deterministic, preserved the caller random-number state, maintained causal and monotonically increasing accepted timestamps, bounded fixed/jitter delays, and passed exact `p=0` and `p=1` loss tests;
- the combined case matched the no-fault case before onset within `1e-12` and all required outputs were finite;
- threshold/dwell recovery and explicit censoring behavior were exercised with a synthetic metric test;
- all ten Simulink smoke cases completed with 1501 finite samples;
- all ten MATLAB/Simulink comparisons passed the `1e-9` numerical gate, with largest continuous-signal difference approximately `2.2751e-12` and exact discrete profiles;
- the 200-trial configured packet-loss study observed 15,934 drops in 80,000 opportunities (`0.199175`) with Wilson 95% interval `[0.19642, 0.20196]`; the configured `0.20` lies inside the interval.

The original suite verifies causal/monotonic packet acceptance and hold-last behavior. A separately constructed forced-collision and forced-out-of-order edge-case test remains advisable. The 2026-09-09 sensitivity extension adds independent nonzero scaling tests for the shared resistance, shared inductance, and ground-conversion terms, plus inactive/diagnostic parameter checks. All 45 current project tests pass.

This is **software verification**, not physical validation. It does not demonstrate that the assumed coupling parameters match a real installation, that a receiver will make a bit/count error at the calculated voltages, that the controller detects a fault, or that any mitigation satisfies a safety or electromagnetic-compliance requirement. Exact results and evidence filenames are recorded in `03_MATLAB/results/Phase2B_Validation_Summary.md`.

## Required Next Fidelity Steps

- Completed on 2026-09-09: sweep assumed parasitics, transfer factors, edge rates, receiver bandwidth/margin, and phenomenological sensitivity. See `Phase2B_Sensitivity_Method.md` and `03_MATLAB/results/sensitivity/Phase2B_Sensitivity_Summary.md` for ranges, results and interpretation.
- Replace assumed imbalance with geometry-, circuit-, literature-, or measurement-derived values and record uncertainty.
- Add a threshold/count-event encoder receiver when false-count behavior is the research question.
- Move switching-edge, cable-network, common-mode, conducted-noise, or pulse-width questions to SPICE or Simscape Electrical with an appropriate solver step.
- Measure source edges, return impedance, coupled receiver voltage, communication errors, and plant response on a controlled hardware testbed.
- Compare measured and simulated quantities with documented error bounds before making hardware, safety, or compliance claims.
