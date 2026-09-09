# SC-01A circuit physics and numerical verification

Date: 2026-09-09. This document describes the implemented circuit, its independent equations, and the acceptance criteria used by the recorded campaign. The core campaign passed 67 automated tests and 51 native simulations across 16 deterministic cases, including step and tolerance refinements. These are software/circuit-model verification results with assumed parameters, not physical validation. Detailed evidence is in `results/SC01A_Validation_Summary.md` and the accompanying CSV/MAT records.

## Circuit and conventions

The prescribed commutation source injects current `I` into sender ground `vg`. An explicit 25 mOhm + 20 nH series return joins sender ground to receiver ground. The two intended drivers are referenced to sender ground and include behavioral `Mp*dI/dt` / `Mn*dI/dt` series voltages, then 47 / 53 Ohm source resistances. The receiver has 120 Ohm and 100 pF between the lines, 50 / 70 pF shunts to receiver ground, and 10 / 20 kOhm bias/leakage resistors to receiver ground. Separate 10 / 9 pF capacitors connect the aggressor voltage node to the lines. These are declared development assumptions.

The native model uses electrical conserving connections, one receiver-ground electrical reference, and one Solver Configuration block for its connected physical network. MathWorks requires one Solver Configuration block per topologically distinct physical network: [Solver Configuration](https://www.mathworks.com/help/simscape/ref/solverconfiguration.html).

The builder explicitly sets capacitor series resistance/parallel conductance and inductor series resistance/parallel conductance to zero so the ideal native network matches the three-state reference. This avoids silently introducing the Foundation Capacitor's default 1 microOhm ESR or the Inductor's default 1 nS parallel conductance. Additional parasitics require declared values and a correspondingly revised reference. See [Capacitor](https://www.mathworks.com/help/simscape/ref/capacitor.html) and [Inductor](https://www.mathworks.com/help/simscape/ref/inductor.html).

## Independent equations including bias currents

Let `vp,vn` be receiver line voltages; `ir` flow through return R/L from sender to receiver ground; `ip,in` flow from the drivers into the lines. Let `gp=1/Rp`, `gn=1/Rn`, `gd=1/Rd`, `gbp=1/Rbp`, `gbn=1/Rbn`. The series-source voltages are `ep=Vsource_cm+Vsource_diff/2+Mp*dI/dt` and `en=Vsource_cm-Vsource_diff/2+Mn*dI/dt`. For source-decomposition cases, the mutual-source waveform and the return-injection waveform may be independently disabled.

```
vg = (I-ir-gp*ep-gn*en+gp*vp+gn*vn)/(gp+gn)
ip = gp*(vg+ep-vp)
in = gn*(vg+en-vn)
dir/dt = (vg-Rr*ir)/Lr

C = [ Cgp+Cpa+Cd,  -Cd;
      -Cd,          Cgn+Cna+Cd ]

C*[dvp/dt; dvn/dt] =
  [ip-gd*(vp-vn)-gbp*vp+Cpa*dVa/dt;
   in+gd*(vp-vn)-gbn*vn+Cna*dVa/dt]

Vdiff = vp-vn
Vcm = (vp+vn)/2
```

All capacitor currents must use their complete terminal-voltage derivatives. Thus the actual capacitive current into the plus line is `Cpa*(dVa/dt-dvp/dt)`, not always `Cpa*dVa/dt`. Positive passive-device voltage/current conventions should follow their terminal labels; MathWorks describes these conventions in its [Resistor reference](https://www.mathworks.com/help/simscape/ref/resistor.html).

The loaded return obeys `vg=Rr*ir+Lr*dir/dt`, with `I=ir+ip+in`. Substituting prescribed `I` for actual `ir` is generally incorrect. The prescribed `M*dI/dt` elements intentionally do not establish reciprocal mutual inductance or passivity of a complete inductance matrix.

## Initial steady state

Before each first edge, solve the actual DC network. With source derivatives zero, solve the following system for `vp,vn,vg`:

```
[gp+gd+gbp, -gd,       -gp;
 -gd,       gn+gd+gbn, -gn;
 Rr*gbp,    Rr*gbn,      1] * [vp;vn;vg] =
 [gp*ep; gn*en; Rr*I]

ir = I-gbp*vp-gbn*vn
```

Initialize each capacitor with its own terminal voltage, including `Va-vp`, `Va-vn`, `vp-vn`, `vp`, and `vn` according to polarity. The implemented negative-edge cases are signed bench perturbations from 0 to -24 V / -3 A, and therefore start at the zero-excitation operating point. They are not physical 24-to-0 V / 3-to-0 A turn-off waveforms; that separate case would start from the nonzero pre-edge operating point. Even at zero commutation current, the return current is slightly nonzero because the line bias currents return through this branch. Simscape's steady-state initialization can independently reproduce this operating point; it finds the steady state for held-constant initial inputs. Verify its result numerically instead of only enabling the setting. See [Solver Configuration](https://www.mathworks.com/help/simscape/ref/solverconfiguration.html).

The ±2 V differential and 2.5 V common-mode levels are open-circuit driver stimuli. With the nominal termination, source resistances and bias returns, the independent DC solve and native high-level baseline give `vp=3.060288841273 V`, `vn=1.974371354072 V`, `Vdiff=1.085917487201 V`, `Vcm=2.517330097673 V`, `vg=-10.118686296 microV`, and `ir=-0.404747451831 mA`. Receiver common mode and differential level change with loading, imbalance and ground movement; thresholds use the actual receiver voltage.

## Equation and symmetry checks

- Confirm finite-ramp definitions: 24 V / 100 ns gives `2.4e8 V/s`; 3 A / 200 ns gives `1.5e7 A/s`. These are full-ramp durations; their 10–90% durations are 80% as long.
- In an isolated fixed-line capacitive check, 10 / 9 pF produce 2.4 / 2.16 mA during the voltage ramp. In the actual circuit verify the full terminal-voltage current equations above.
- Confirm behavioral induced voltages 0.300 / 0.255 V and 0.045 V differential before loading. Confirm both edge polarities.
- In an isolated unloaded return check, the 3 A plateau gives 0.075 V resistive drop and a positive 200 ns ramp adds 0.300 V inductive voltage. In the full circuit check the measured `ir` identity instead.
- Check KCL at both lines and sender ground, and KVL across return R/L, using analytic or solver-internal derivatives when possible.
- A truly balanced common-mode test needs `Rp=Rn`, `Cgp=Cgn`, `Rbp=Rbn`, `Cpa=Cna`, and `Mp=Mn`, as well as symmetric source timing and polarity. Equal coupling capacitance or mutual terms alone do not balance the deliberately asymmetric receiver network. Test disturbance differential relative to its matching intended-only baseline.
- For superposition, keep every passive element fixed and disable independent source excitations. Hold `Va` constant to disable capacitive excitation; removing Cpa/Cna changes the network and is a separate ablation. Verify `combined-baseline=sum(isolated-baseline)` for Vdiff, Vcm and branch currents. Use the same fixed network and appropriate steady-state initialization for all terms.

The implemented `zero_coupling` case physically omits zero-valued aggressor-to-line capacitors, zeroes the mutual-source gains, and disables shared-current injection. It is a distinct topology check, not a term in the fixed-network source decomposition. Line-to-ground and differential capacitances remain present, keeping the two-line capacitance matrix positive definite.

For the fully balanced case, the independent differential mode has gain `0.544464609800363` and time constant `7.336660617059891 ns`, from `Gmode=1/50+2/120+1/15000` and `Cmode=(60+9.5+200) pF`. Its DC receiver differential is `1.088929219601 V`. The refined native balanced common-mode excitation produced only `5.46e-14 V` differential disturbance. This is a symmetry/implementation check, not a realistic matching tolerance.

## Solver, convergence and event checks

The native conserving model uses variable-step `ode23t`, with local fixed-step solving and input filtering disabled. The source conversion receives the analytic aggressor-voltage derivative. MathWorks recommends implicit solvers for physical systems and explains event handling in [Setting Up Solvers for Physical Models](https://www.mathworks.com/help/simscape/ug/setting-up-solvers-for-physical-models.html). Its input-handling documentation explains why automatic filtering would add smoothing and lag: [Filtering Input Signals and Providing Time Derivatives](https://www.mathworks.com/help/simscape/ug/filtering-input-signals-and-providing-time-derivatives.html).

Finite current ramps create rectangular behavioral induced-voltage pulses: their voltage-source corners remain discontinuous. The final source adapter encodes discontinuities with duplicate-time left/right values and uses From Workspace interpolation and zero-crossing detection with continuous sample time. MathWorks documents that duplicate-time discontinuities are detected when interpolation is enabled for variable-step simulation: [From Workspace](https://www.mathworks.com/help/simulink/slref/fromworkspace.html). This preserves the prescribed pulses without smoothing. The independent reference includes every ramp/PWM/victim-transition boundary in its affine segments. A dense exported time grid alone does not constrain integration accuracy.

- Reference agreement compares every native point in short records. Long records use 100,001 selected native points plus neighborhoods around every source corner. The algebraic ground output can jump at source corners; points within `1e-15 s` of those exact timestamps are excluded only from pointwise ground error because left/right conventions differ. State voltages and return current remain checked at all selected points.
- Each of the 16 cases uses maximum integration steps of 1 ns, 0.5 ns and 0.25 ns, at relative tolerance `1e-5` and absolute tolerance `1e-9`. Capacitive rise, combined rise and stress fall repeat the finest step with tolerances `1e-6` / `1e-10`. The 32 successive-step and three tolerance comparisons passed. Actual settings, errors and ratios are saved. Warning diagnostics are part of acceptance; numerical agreement alone does not justify accepting minimum-step or tolerance warnings.
- For each differential, common-mode and ground disturbance peak, the implemented criterion is `abs(Pfine-Pcoarse) <= max(0.01*abs(Pfine), 1e-4 V)`. The denominator uses the refined disturbance peak, avoiding dilution by the intended DC signal.
- Areas are the trapezoidal integrals of the absolute differential/common-mode disturbance over the case record. The implemented criterion is `abs(Afine-Acoarse) <= max(0.01*abs(Afine), 1e-11 V*s)`. Its fixed dimensional floor is `0.1 mV * 100 ns`, using the nominal voltage-ramp duration, not the record length. Absolute area avoids cancellation between opposite disturbance polarities. Signed areas are not a reported campaign metric.
- Crossings are matched by channel, threshold level, direction and chronological order. Counts and classifications must match; the largest crossing-time change and the largest noise-exposure/receiver-band-duration change must each be at most 1 ns. Near-threshold sampled extrema or plateaus are classified as grazing and cannot pass refinement. These are event-convergence checks, not estimates of physical receiver propagation delay.
- PWM settling compares corresponding final complete periods from 10- and 20-period records on a common 0.25 ns grid. Differential/common-mode voltage differences must be at most 0.1 mV, and return-current difference at most 0.1 mA. Recorded maximum differences were 5.74 microV differential, 54.14 microV common mode and 2.73 microA return current. Whole-record integrated areas are not used for this twice-longer-record comparison.

The matrix-exponential oracle has no integration timestep error within correctly constructed affine segments, but its sampled peak/exposure extraction still requires convergence or continuous root/maximum evaluation. This is distinct from refinement of the actual native solver.

## Interpretation of threshold records

The output explicitly distinguishes a noise-delta diagnostic from the total intended-plus-disturbance receiver input. Receiver-band residence measures time inside ±0.20 V on the total differential input. Crossing records include channel, threshold, direction and interpolated time. A deliberate victim transition naturally traverses that band; its residence is not labeled a receiver fault. Common-mode reporting includes the total peak and whether the inherited ±7 V limit is exceeded. No 50 ns glitch filter, hysteresis, receiver delay or decoder is implemented. These assumptions are not a selected receiver model or an EMC standard. TI discusses differential sensitivity separately from common-mode operation in [422 and 485 Overview and System Configurations](https://www.ti.com/lit/an/slla070d/slla070d.pdf).

The refined nominal combined rise produced `51.734 mV` peak differential disturbance and stayed outside the illustrative receiver band. The exploratory `stress_fall` case uses 300 / 5 pF aggressor capacitances and a signed negative edge; it produced `1.823459 V` peak differential disturbance, reached `-0.737542 V` total differential input, and spent `15.394 ns` inside the band. These are deterministic voltage records under assumed stress inputs; they do not establish how a real receiver would respond.

Threshold exposure does not establish a digital receiver output pulse, a guaranteed glitch-rejection result, an encoder count error, a reliability estimate, or hardware validity. This harness validates deterministic circuit-model implementation. Physical coupling measurements, selected device models, line propagation and a complete receiver/decoder remain subsequent work.
