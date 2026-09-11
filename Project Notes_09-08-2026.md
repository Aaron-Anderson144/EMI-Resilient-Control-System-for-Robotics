# EMI-Resilient Control System for Robotics

## Project Overview

Design and experimentally validate a robotic control system that remains stable and operational when exposed to electromagnetic interference (EMI) from motors, power electronics, cables, and nearby electrical equipment.

This project combines electricity and magnetism, embedded hardware, feedback control, mechanical integration, communications, and software development. It is applicable to industrial robotics, autonomous vehicles, aerospace systems, and other reliability-critical robotic platforms.

## Research Question

How can shielding, grounding, filtering, cable design, and fault-tolerant communications improve the stability of a robotic controller exposed to electromagnetic interference from motors and power electronics?

## Central Hypothesis

Combining deliberate electromagnetic design with model-based fault-tolerant control will maintain robotic stability at interference levels that cause conventional controllers to experience sensor corruption, communication faults, or shutdown.

## Proposed Experimental Platform

Build a small robotic actuator system containing:

- A brushless DC motor, servo motor, or comparable actuator
- A motor inverter or variable-frequency drive
- A microcontroller-based feedback controller
- Encoder, current, temperature, and position sensors
- CAN, RS-485, or industrial Ethernet communication
- Adjustable wiring, grounding, shielding, and filtering configurations

Controlled electromagnetic disturbances can be introduced while observing their effects on sensor readings, communication reliability, and closed-loop control performance.

## Electricity and Magnetism Topics

- Capacitive and inductive near-field coupling
- Common-mode and differential-mode interference
- Ground loops and return-current paths
- Transmission-line effects and impedance mismatch
- Cable shielding and shield termination
- Conducted and radiated emissions
- Motor switching harmonics and back-EMF
- Ferrites, common-mode chokes, and LC filters
- Electromagnetic susceptibility of sensors and communication buses

## Measurements and Evaluation Criteria

Compare protection and mitigation strategies using:

- Position and velocity tracking error
- Encoder corruption or missed counts
- Communication packet-error rate
- Controller resets and fault events
- Common-mode and differential-mode noise
- Frequency spectrum of conducted emissions
- Recovery time following an interference event
- Maximum disturbance level before unstable behavior occurs

## Primary Research Contribution

The strongest research direction is **EMI-aware fault-tolerant control**. Instead of treating shielding as the only defense, the controller will identify unreliable measurements or communication failures and reconfigure its behavior.

Possible responses include:

- Switching temporarily to observer-estimated states
- Using redundant sensors
- Applying filtered or confidence-weighted feedback
- Entering a reduced-performance safe mode
- Recovering communications automatically
- Derating the actuator when disturbance levels become excessive

This treats electromagnetic compatibility as a combined physics-and-controls problem.

## Optional Quantum-Mechanics Extension

Tunneling magnetoresistance sensors could be added to monitor magnetic fields near motor drives and cables. These sensors operate through spin-dependent quantum tunneling and could be used to:

- Detect abnormal current signatures
- Identify electromagnetic interference sources
- Monitor motor condition
- Trigger adaptive filtering or controller reconfiguration

## Expected Deliverables

- A functioning robotic actuator demonstrator
- Wiring, grounding, shielding, and filter designs
- Control electronics or a custom printed circuit board
- Electromagnetic and control-system models
- Embedded fault-detection and recovery software
- An EMI test procedure and experimental dataset
- Quantitative comparisons of mitigation techniques
- Practical design guidelines for EMI-resilient robotic systems

## Alternative Academic Title

**Electromagnetic Interference Characterization and Fault-Tolerant Control of Robotic Actuator Systems**
