# EMI Modeling Plan

## Purpose

Translate physical interference mechanisms into reduced-order disturbance signals that can be injected into the robotic-actuator digital twin.

The initial Phase 2B implementation is a physics-based reduced-order, assumed-parameter, receiver-equivalent model. It is intended for equation checks and sensitivity analysis. It is not a measured or physically validated representation of a specific cable, drive, receiver, encoder, or installation.

## Capacitive Coupling

Use the first-order relationship:

\[
i_{noise}=C_c\frac{dv}{dt}
\]

The implemented differential approximation uses line imbalance rather than total common-mode capacitance:

\[
\Delta C=C_{+}-C_{-},\qquad
V_{cap}=\alpha_C R_D \Delta C\frac{\Delta V}{t_r}H_{rx}
\]

Initial study variables:

- Coupling capacitance
- Switching voltage
- Voltage edge rate
- Victim impedance
- Cable separation and shield-equivalent attenuation

## Inductive Coupling

Use the first-order relationship:

\[
v_{noise}=M\frac{di}{dt}
\]

The implemented differential approximation is:

\[
\Delta M=M_{+}-M_{-},\qquad
V_{ind}=\alpha_M \Delta M\frac{\Delta I}{t_i}H_{rx}
\]

Initial study variables:

- Mutual inductance
- Aggressor current
- Current edge rate
- Victim loop area
- Cable orientation and twisting factor

## Shared-Impedance Coupling

Use:

\[
v_{shared}=Z_{return}(f)i_{return}
\]

The current Phase 2B approximation is:

\[
V_{return}=R_{return}\Delta I+L_{return}\frac{\Delta I}{t_i},\qquad
V_{shared,DM}=k_{CM\rightarrow DM}V_{return}H_{rx}
\]

The later circuit model will replace this finite-edge peak approximation with a frequency-dependent return network.

## Common-Mode and Differential-Mode Paths

Maintain separate disturbance channels for:

- Common-mode voltage and current
- Differential-mode voltage and current
- Common-mode-to-differential conversion from imbalance

Phase 2B stores capacitive, inductive, shared-impedance, ground common-mode, ground differential-mode, and total receiver differential-mode signals separately. A receiver-margin flag compares the total differential voltage with an assumed 0.20 V margin. This comparison is diagnostic only; no physical receiver threshold behavior has been validated.

## Controller-Rate Envelope

The controller model uses a 1 ms sample time. The assumed PWM frequency is 20 kHz, so individual PWM periods and 100–200 ns edges cannot be resolved at controller rate. The model therefore:

1. calculates peak differential voltage from the stated finite-edge equations;
2. applies an assumed first-order receiver gain at a 120 Hz observed baseband frequency;
3. uses windowed sinusoidal component envelopes to expose the feedback loop to an in-band disturbance.

The envelope is not the PWM waveform and shall not be used to infer conducted-emission spectra, edge timing, receiver pulse-width violations, or electromagnetic-compliance performance.

## Communication Channel

Each sensor sample is treated as a timestamped packet. The current reduced-order channel can apply an 8-sample fixed delay, seeded integer jitter from 0 to 8 samples, and seeded packet loss with probability 0.20 during the half-open interval `[0.70, 1.10)` s. Lost packets never arrive. When arrivals collide, the newest source timestamp is retained; arrivals older than the last accepted timestamp are rejected. If no newer packet is accepted, the receiver holds its previous value and records measurement age.

This is not a full CAN or other bus model. Arbitration, serialization, retransmission, bit timing, CRC behavior, bus-off states, and physical-layer thresholds are outside the Phase 2B scope.

## Fidelity Levels

1. **Signal injection:** prescribed noise waveform added to a measurement.
2. **Reduced-order coupling:** waveform derived from switching edge and coupling parameters.
3. **Circuit model:** parasitic components and receiver impedance represented in SPICE or Simscape.
4. **Field-informed model:** parameters imported from measurement or electromagnetic field analysis.

## Parameter Provenance

Each parameter must be labeled as measured, datasheet, literature, estimated, or assumed. Sensitivity sweeps are required for assumed parasitics.

The current Phase 2B values are all explicitly assumed under parameter set `REPRESENTATIVE-ACTUATOR-V0.2`. The volts-to-radians conversion is additionally labeled phenomenological because it is a system-level sensitivity bridge, not a physical law. See `Phase2B_Coupling_and_Communication_Faults.md` for the exact values, equations, scenario map, metrics, and verification limits.
