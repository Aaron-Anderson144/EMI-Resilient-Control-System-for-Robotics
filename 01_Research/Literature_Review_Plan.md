# Literature Review Plan

## Purpose

Build an evidence base for the physical coupling models, fault scenarios, mitigation choices, controller architecture, and validation methods.

## Research Streams

### 1. Motor-Drive EMI Sources

- PWM edge rates and harmonic content
- Common-mode voltage in inverter-fed motors
- Bearing and chassis currents
- DC-bus and supply conducted emissions
- Cable length and termination effects

### 2. Coupling Mechanisms

- Capacitive near-field coupling
- Inductive near-field coupling
- Common-impedance coupling
- Ground loops and return paths
- Differential-to-common-mode conversion

### 3. Susceptible Robotic Subsystems

- Incremental and absolute encoders
- Hall sensors, resolvers, and current sensors
- CAN and RS-485 physical layers
- Embedded-controller reset and brownout behavior
- Mixed-signal PCB interfaces

### 4. Electromagnetic Mitigation

- Cable twisting and separation
- Shield construction and termination
- Chassis bonding and grounding topology
- Common-mode chokes, ferrites, and filters
- Galvanic isolation and differential interfaces
- PCB stackup, placement, and return-current control

### 5. Fault-Tolerant Control

- State observers and innovation residuals
- Sensor validation and analytical redundancy
- Robust and adaptive control
- Fault detection, isolation, and accommodation
- Graceful degradation and safe-state design

### 6. Test Methods and Standards

Review the current applicability and revision of:

- IEC 61000 immunity and emissions methods
- CISPR equipment emissions guidance
- MIL-STD-461 equipment-level EMC requirements
- ISO 11452 component immunity methods
- CAN and RS-485 physical-layer application guidance

The project will use relevant methods as research guidance unless formal compliance work is separately authorized and properly equipped.

## Suggested Search Strings

- `PWM inverter common-mode EMI motor encoder`
- `robot servo electromagnetic interference position control`
- `encoder signal corruption variable frequency drive`
- `CAN bus conducted immunity motor drive`
- `fault tolerant control sensor dropout actuator`
- `state observer residual EMI detection`
- `motor cable shield termination common mode current`
- `shared impedance coupling embedded controller reset`

## Source Priority

1. Standards and government technical publications
2. Peer-reviewed journal and conference papers
3. University theses with accessible methods and data
4. Semiconductor and equipment-manufacturer application notes
5. Textbooks and established reference works

## Inclusion Criteria

- Identifiable physical system or test configuration
- Defined disturbance or coupling mechanism
- Quantitative result or reproducible method
- Applicable frequency, voltage, current, or communication regime
- Sufficient information to identify limitations

## Exclusion Criteria

- Marketing claims without test details
- Untraceable parameter values
- Results from unrelated physical scales without a valid similarity argument
- Sources that conflate correlation with a verified coupling mechanism

## Evidence Table

| Ref ID | Citation | System | Disturbance | Coupling Path | Mitigation | Metric | Key Result | Limitations | Project Use |
|---|---|---|---|---|---|---|---|---|---|
| REF-001 |  |  |  |  |  |  |  |  |  |

