# Circuit Simulations

## Completed: SC-01A finite-edge electrical harness

`SC01A` contains the native Simscape source/coupling/receiver circuit and its independent numerical verification. Run `sc01a_main` from that folder to reproduce the 67-test, 51-simulation workflow. Open `SC01A/models/EMI_SC01A_Finite_Edge.slx` to inspect or run the saved nominal model directly.

The completed package includes assumed parameter and case manifests, raw native waveforms, interpolated threshold events, integration-step and tolerance comparisons, source-decomposition and symmetry checks, PWM settling comparisons, figures and a generated validation summary. See `SC01A/README.md` and `SC01A/results/SC01A_Validation_Summary.md`.

SC-01A uses prescribed finite voltage/current edges and behavioral inductive excitation. It does not yet use a selected-device inverter or a receiver decoder.

## Completed implementation: SC-01B selected-device source

`SC01B` contains the native IAUC100N04S6L014 half-bridge, UCC27211A-informed behavioral gate drive, independently executed original vendor equations, frozen operating cases, integration refinement and energy accounting. Run `sc01b_startup`, then `study=sc01b_main` from that folder. See `SC01B/results/verification/SC01B_Validation_Summary.md` for the actual pass/fail matrix.

The 47 ohm external gate-resistance case is retained as a failed stress point: both engines reproduce the large current spike, and native internal branch logs establish simultaneous channel conduction. A zero overlap at the arbitrary 6 V gate midpoint does not establish zero channel overlap. Gate-drive mitigation and physical source identification remain open. SC-01B has not yet been connected to the receiver network.

## Subsequent circuits

1. SC-01B gate-drive mitigation, source identification and coupling-network integration
2. Controller power input and decoupling
3. Encoder receiver with filtering, clamps and supported decoder behavior
4. Protocol-specific transceiver and termination network
5. Distributed cable model where propagation delay requires it
6. Common-mode choke, grounding, shielding and isolation comparisons

Keep parameter provenance, circuit schematic, native waveforms, convergence evidence and validity limits with every case. Physical validation requires measurement comparisons.
