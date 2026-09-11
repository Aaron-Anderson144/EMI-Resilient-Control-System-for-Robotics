# Future Hardware Plan

## Initial Bench Architecture

- Nominal 24 V low-power BLDC or servo motor
- Compatible motor drive with accessible command and diagnostic signals
- Incremental encoder
- Embedded controller with CAN or RS-485
- Current-limited DC supply
- Mechanical load or inertia fixture
- Emergency power disconnect
- Oscilloscope and differential probes appropriate to the circuit
- Current probe or shunt measurement
- Near-field magnetic and electric probes

## Design Work That Can Be Completed Before Purchasing

- System block diagram
- Power and signal budget
- Preliminary wiring diagram
- Grounding and chassis-bonding plan
- Cable and connector specification
- Shield-termination options
- Test-point plan
- Measurement uncertainty budget
- Preliminary schematic and PCB partitioning
- Bill of materials with alternatives
- Mechanical guard and fixture concept

## Selection Criteria

- Published motor and drive parameters
- Accessible encoder and communication signals
- Controllable switching frequency if possible
- Bench-safe voltage and current
- Replaceable cabling and shield configurations
- Controller data logging
- Available protection and fault reporting

## Safety Gate Before Energizing

Do not energize the future testbed until current limits, emergency shutdown, guarding, grounding, probe ratings, and a written test procedure have been reviewed.

## Stop and hold identification requirements — 10 September 2026

The separate [numerical stop/hold study](../05_Control_Algorithms/Phase3_Stop_Hold.md) compares a terminal short, a passive external resistor and an assumed mechanical brake. It selects no hardware and changes no operating controller. The .030 Nm equal static/sliding capacity, 30 ms engagement delay and 20 ms capacity ramp are explicit model assumptions. The 3.75 capacity/load ratio for .008 Nm is not a qualified safety margin.

Before choosing a brake or defining a physical stop policy, establish:

- **Load and torque reference:** Identify actual shaft load, inertia, gearing, efficiency and load direction. Refer motor, brake and load torque to the same shaft. Specify capacity against combined load and residual motor torque, including overload cases.
- **Static and sliding capacity:** Identify holding and sliding torque separately over the intended wear, temperature and operating conditions. Equal values in the numerical inclusion are a simplification. Characterize breakaway, overload slip and recapture rather than treating the shaft as an unlimited position lock.
- **Engagement and release latency:** Measure the complete command/power-loss-to-torque profile. The assumed brake has no capacity for 30 ms and reaches full capacity only at 50 ms. Include release ramp, delayed engagement and interrupted or repeated requests in the timing budget.
- **Energy and heat:** Establish energy per stop, repeated-stop duty, permissible continuous slip and temperature limits. Include continuing load work, winding heat, external-resistor heat and friction heat separately. The solver's numerical dissipation is not physical heat or a brake rating.
- **Drive-terminal topology:** Identify actual terminals during inhibit, bus interruption, control-power loss and emergency disconnect. The existing zero-terminal-voltage model is an ideal dynamic-braking short, not an open circuit or static hold. Preserve inductive-current commutation and characterize switching voltages/current.
- **Resistor purpose and rating:** A resistor may relocate dissipation but reduces low-speed electrical damping. Identify the resistor loop and its switching/current path; the modeled terminal voltage is -Rext*i. Do not substitute a resistor for static holding capacity.
- **Mechanical behavior:** Identify mounting strength, backlash, compliance, travel limits and consequences of overload. A model with exact stiction does not establish positional accuracy or mechanical locking.
- **Status and failure diagnostics:** Define evidence for engagement, release, failure to engage, failure to release and partial capacity. A requested brake state alone does not confirm holding torque. Specify how slip or a blocked release is detected and recorded.

The next local integration design must specify a **drive/brake handoff and interlock**. Releasing under load at zero applied drive allows renewed backdrive. A powered handoff needs an explicit authority/state sequence for establishing supporting torque, releasing the brake, confirming release and handling failure. Controller integrator/anti-windup behavior, command limits and interrupted handoff must be included. Do not add a silent nonzero-voltage exception to the existing latched-stop contract.

The observer also needs a justified model or independently supported evidence for brake reaction and constrained motion. Its present dynamics contain motor input and assumed external load but no brake torque. Simulated true reaction torque cannot be supplied as though it were a measured signal. Primary-sensor recovery or independent-reference qualification alone does not validate this new mechanical state or authorize restart.

Emergency disconnect and mechanical load support remain distinct requirements. The separate numerical mechanism comparison does not close Gate 3, hardware safety requirements, physical restart validation or the Phase 4 electromagnetic mitigation comparison. Component selection, measurements and a reviewed bench procedure remain future work; no purchase or energization is part of this study.
