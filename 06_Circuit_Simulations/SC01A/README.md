# SC-01A: Finite-Edge Electrical Coupling Harness

This is the project's native Simscape circuit layer. It resolves prescribed 100 ns voltage edges and 200 ns commutation-current ramps through an explicit differential receiver network. It complements the earlier 1 kHz control model; it does not replace that model's controller or connect a new waveform-to-count mapping to it.

## Run

From this folder in MATLAB:

```matlab
sc01a_main
```

The full project workflow runs the current control/sensitivity regressions, the circuit-equation and threshold tests, sixteen deterministic circuit cases, three maximum-step settings, three tighter-tolerance runs, repeated-period settling checks, figures and a generated report. Each invocation creates a unique `results/sc01a_workflow_<UTC stamp>` folder. Test results stay at its top level; native traces, figures, the MAT study and report go under `campaign`. `study.meta.outputFolder` records that campaign path, and `study.meta.workflowOutputFolder` records the workflow path.

Choose an explicit new or empty destination with `study=sc01a_main("C:/path/to/new-sc01a")`. For the circuit campaign alone, run `sc01a_startup`, then `study=run_sc01a("C:/path/to/new-circuit-campaign")`; omitting its output argument creates a unique `results/sc01a_<UTC stamp>` folder. Both reject populated folders or existing files before tests, simulations or output writes. Use the callable names directly rather than `run("sc01a_main.m")`. Existing saved evidence under `results` is preserved.

The saved `models/EMI_SC01A_Finite_Edge.slx` contains nominal parameters and input data in its model workspace. It can be opened and run directly without preparing base-workspace variables. `simulate_sc01a_simscape` temporarily overrides model-workspace parameters and sources for each case, then restores the stored defaults. A successful campaign no longer rebuilds the saved model or overwrites its diagram; `build_sc01a_model` is an explicit regeneration step. Campaign caches and generated figures use the new output folder.

For one case:

```matlab
sc01a_startup
c = sc01a_case("combined_rise",sc01a_parameters());
p = c.params;
s = sc01a_stimulus(p,c);
settings = struct('stopTime_s',c.stopTime_s, ...
    'maxStep_s',0.25e-9,'relativeTolerance',1e-5,'absoluteTolerance',1e-9);
r = simulate_sc01a_simscape(p,s,settings);
```

Use `c.params`, since balanced and stress cases deliberately change circuit values. `sc01a_case` rejects unknown case names. `sc01a_stimulus` and the independent reference reject mismatched parameter structures.

Requirements are MATLAB, Simulink and Simscape for the circuit; Control System Toolbox is also needed for the original project regressions in `sc01a_main`. This implementation uses native Foundation Electrical components available in the installed MathWorks environment. It does not use Specialized Power Systems blocks or a signal-only imitation of an electrical circuit.

## Circuit and source definitions

The receiver's ground is the electrical reference. Two ideal transmitter sources reference a common sender-ground node and feed the receiver through separate source resistors. Each leg includes a prescribed series `M*dI/dt` voltage source. An independent aggressor voltage source couples through two actual capacitors. The sender ground returns through a real resistor and inductor; a prescribed current source injects the commutation test current into that node.

| Group | Nominal assumed values |
|---|---|
| Source voltage | 24 V step in 100 ns, first edge at 1 microsecond |
| Source current | 3 A signed commutation perturbation in 200 ns |
| Repetition | 20 kHz, 50% duty; 10 and 20 periods |
| Intended source | +2 or -2 V open-circuit differential; 2.5 V common mode; 100 ns transitions |
| Source resistances | 47 / 53 ohm |
| Aggressor coupling | 10 / 9 pF |
| Behavioral inductive terms | 20 / 17 nH times prescribed current slope |
| Differential receiver load | 120 ohm and 100 pF |
| Receiver line-to-ground capacitances | 50 / 70 pF |
| Receiver bias/leakage returns | 10 / 20 kilohm |
| Shared return | 25 milliohm and 20 nH |
| Illustrative diagnostics | 0.20 V noise-delta threshold, +/-0.20 V total-input band, 7 V common-mode magnitude limit |

All values are assumptions, with complete machine-readable values in `results/sc01a_parameters.json`. The driver source resistance, shunt capacitances and bias returns were added explicitly to make loading and common-mode conversion representable. They were not selected from a real receiver or cable.

The source levels are not receiver levels: the nominal high receiver input is approximately 1.085917 V differential and 2.517330 V common mode after loading. The source ramps specify full ramp durations; their 10–90% durations are 80% of those values. The 3 A slope is a commutation test-source input, not a forced motor-winding current slope.

The negative cases apply signed perturbations from zero to negative voltage/current. A physically selected 24-to-0 V or 3-to-0 A turn-off case would require its own nonzero pre-edge operating point. SC-01A deliberately uses source perturbations for controlled equation and polarity tests.

## Fidelity and numerical method

The capacitors use their full terminal-voltage current law. Shared return voltage uses actual branch current, which includes the reaction of the loaded signal circuit. No old path-transfer or common-mode conversion coefficient is applied on top of the explicit network. Native capacitor ESR and inductor leakage are set to zero to match the declared ideal-component equations.

The series inductive sources are a prescribed linear excitation check. They do not establish reciprocal mutual inductance or a passive multi-conductor inductance matrix. A real mutual network needs self-inductances, physical consistency and geometry/device data.

An independent three-state solution uses node voltages and return-inductor current, with exact affine-segment state propagation. It includes the bias/leakage currents and uses an independently checked loaded DC operating point. See `Circuit_Physics_and_Verification.md` for equations, independent checks and primary-source references.

The native variable-step solver uses explicit event times. Rectangular induced-voltage pulses and aggressor derivatives are encoded with left/right values at duplicate timestamps and continuous interpolation enabled, so source jumps are registered without filtering. Maximum integration step is refined from 1 to 0.5 to 0.25 ns. Smaller exported sample spacing alone is not considered a solver refinement. The adapter requires completion at the requested stop time and rejects any simulation warning after saving its diagnostic evidence. Accepted runs retain their warning count and engine execution metadata.

## Case matrix and comparison rules

- Isolated capacitive, inductive and shared-return excitations preserve every passive element of the nominal network. This is essential for valid source-decomposition superposition.
- Combined positive and signed negative perturbations check polarity. Fixed low logic and three victim-transition timings check total receiver input behavior.
- The fully balanced case balances source resistances, shunt capacitances, bias resistances and both coupling pairs. Equal coupling capacitors alone would not balance the original circuit.
- The zero-coupling case removes zero-valued capacitor branches exactly and disables the shared-current injection. This is a separate topology check, not a term used in superposition.
- The stress case uses 300/5 pF coupling and a negative bench edge. These are exploratory values; no hardware occurrence probability is implied.
- Corresponding final complete periods of 10- and 20-period PWM runs are compared for settling. Raw long-record traces are retained in MAT files; last-period CSVs are provided for convenience.

Threshold events are interpolated on the recorded waveform and matched by threshold, direction and channel. A threshold touch or plateau is flagged as grazing. Crossing/exposure changes must be below 1 ns and classifications must agree. Intentional victim-transition band residence is not a fault count. No receiver output pulse, encoder error or bus error is inferred without a supported receiver/decoder model.

## Saved data

`results/SC01A_Validation_Summary.md` and `results/raw` retain the historical campaign. A new full workflow writes `SC01A_Validation_Summary.md` within its own `campaign` folder, alongside case metrics, solver settings, native and reference sample counts, runtime and error values; convergence/tolerance/symmetry/period tables; threshold-event CSVs; short-case full refined time series; repeated-case last-period views; and the MAT study archive. Its `raw` child folder retains full refined native traces with their parameters and source definitions.

The model diagram is exported alongside the SLX. The source builder, independent reference, test suite and campaign functions make the case definitions and validation logic reviewable.

`sc01a_case_manifest.json` records every case with its full parameter structure; the accompanying CSV summarizes excitation choices and changing values. The combined-rise refinement PNG and three CSVs preserve the coarse, middle and fine native sample grids. The campaign metrics and tolerance table record warning counts and stop reasons.

SC-01B, selected-component characterization, receiver decoding, measured physical validation, supply interruption and resilient-control implementation remain subsequent work.
