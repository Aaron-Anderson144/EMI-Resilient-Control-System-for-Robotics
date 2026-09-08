# EMI Modeling Plan

## Purpose

Translate physical interference mechanisms into reduced-order disturbance signals that can be injected into the robotic-actuator digital twin.

## Capacitive Coupling

Use the first-order relationship:

\[
i_{noise}=C_c\frac{dv}{dt}
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

Represent the return path with frequency-dependent resistance and inductance. Feed the resulting offset into the controller supply, sensor ground, or communication reference.

## Common-Mode and Differential-Mode Paths

Maintain separate disturbance channels for:

- Common-mode voltage and current
- Differential-mode voltage and current
- Common-mode-to-differential conversion from imbalance

## Fidelity Levels

1. **Signal injection:** prescribed noise waveform added to a measurement.
2. **Reduced-order coupling:** waveform derived from switching edge and coupling parameters.
3. **Circuit model:** parasitic components and receiver impedance represented in SPICE or Simscape.
4. **Field-informed model:** parameters imported from measurement or electromagnetic field analysis.

## Parameter Provenance

Each parameter must be labeled as measured, datasheet, literature, estimated, or assumed. Sensitivity sweeps are required for assumed parasitics.

