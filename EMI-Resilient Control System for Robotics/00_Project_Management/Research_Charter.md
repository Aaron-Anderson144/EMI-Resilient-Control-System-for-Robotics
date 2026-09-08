# Research Charter

## Identification

- **Project:** EMI-Resilient Control System for Robotics
- **Academic title:** Electromagnetic Interference Characterization and Fault-Tolerant Control of Robotic Actuator Systems
- **Version:** 0.1
- **Date:** 2026-09-08
- **Status:** Initial research definition

## Problem Statement

Robotic actuators combine fast-switching motor drives, sensitive feedback devices, embedded controllers, and digital communication buses in a compact electromechanical assembly. Switching currents, cable coupling, shared return paths, and grounding errors can corrupt sensor signals or communications. A controller that assumes every measurement is valid may respond incorrectly or become unstable.

The project will investigate electromagnetic design and control-system resilience as one integrated problem.

## Primary Research Question

How much can combined electromagnetic design and fault-tolerant control increase a robotic actuator system's tolerance to conducted and near-field electromagnetic interference?

## Supporting Questions

1. Which modeled coupling paths create the greatest degradation in position-control performance?
2. Which grounding, shielding, cabling, and filtering measures provide the greatest improvement?
3. Can model-based residuals identify corrupted measurements before unsafe motion occurs?
4. Can a degraded-control mode preserve bounded behavior during temporary sensor or communication faults?
5. What tradeoffs arise among resilience, bandwidth, complexity, mass, cost, and recovery time?

## Central Hypothesis

Combining electromagnetic mitigation with model-based fault detection and degraded-control modes will maintain bounded robotic-actuator behavior at interference levels that cause an unprotected baseline controller to experience unacceptable tracking errors, communication faults, resets, or loss of control.

## Initial System Boundary

The first digital twin represents:

- One nominal 24 V rotary actuator
- One motor drive
- One embedded position controller
- One incremental encoder
- One CAN-like communication channel
- One mechanical inertia and load torque
- Conducted and near-field coupling represented by reduced-order models

## Objectives

1. Establish a clean, reproducible actuator-control baseline.
2. Derive reduced-order capacitive, inductive, common-mode, and shared-impedance coupling models.
3. Create repeatable sensor, power, and communication fault injection.
4. Implement fault detection using physical limits and model residuals.
5. Implement degraded operation, recovery, and safe-stop logic.
6. Compare baseline, electromagnetic-only, software-only, and combined mitigation configurations.
7. Produce a traceable path from desktop simulation to circuit simulation and hardware validation.

## Scope

### Included

- System-level motor and control modeling
- Conducted and near-field coupling approximations
- Position and velocity control
- Encoder and current-sensor disturbances
- Packet loss, delay, jitter, and stale data
- Filter and grounding equivalent circuits
- Statistical simulation campaigns
- Future bench-scale validation planning

### Excluded from the Initial Phase

- Formal EMC certification
- Classified or platform-specific information
- High-power radiated testing
- Full three-dimensional enclosure or cable-harness field simulation
- Production-qualified hardware
- Claims of defense-system compliance

## Independent Variables

- Interference amplitude, frequency, duration, and repetition rate
- Coupling capacitance and mutual inductance
- Shared ground and supply impedance
- Shield and filter configuration
- Communication delay and packet-loss probability
- Controller and observer configuration

## Dependent Variables

- Position and velocity tracking error
- Overshoot and settling time
- Control effort and peak current
- Encoder error rate
- Communication error rate
- Fault-detection delay and false-alarm rate
- Recovery time
- Probability of entering degraded mode or safe stop

## Initial Success Criteria

The numerical thresholds below are provisional and must be reviewed after the clean baseline is identified.

- The clean linear baseline is internally stable.
- The simulation is deterministic when the random seed is fixed.
- Every experiment records configuration, parameter set, and software version.
- Fault injection is disabled by default and cannot contaminate baseline runs.
- The combined mitigation case outperforms the unprotected baseline across predefined resilience metrics.
- Unsafe or unbounded simulated behavior results in an explicit safe-state outcome rather than being silently discarded.

## Expected Deliverables

- Version-controlled MATLAB/Simulink digital twin
- EMI coupling and circuit models
- Fault-injection library
- Baseline and fault-tolerant controller
- Simulation test suite and dataset
- Experimental test plan
- Hardware architecture and preliminary schematic
- Research report, figures, and design recommendations

## Safety and Responsible Use

Hardware experiments will use bench-scale voltages and currents, current limiting, mechanical guarding, emergency shutdown, and controlled conducted or near-field disturbance methods. No uncontrolled high-power radiation will be generated. Applicable laboratory and software licensing requirements must be confirmed before execution.

