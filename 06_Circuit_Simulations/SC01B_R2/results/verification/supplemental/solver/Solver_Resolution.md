# SC-01B strict solver resolution — local investigation

The verified remedy keeps ngspice 41 and the original vendor equations. It expresses the existing linear command as a mathematically equivalent time-based behavioral voltage source and separates the fixed 1 ns transient suggested/printing increment (TSTEP) from the actual integration maximum (TMAX). Relative, current and voltage tolerances remain 1e-6, 1e-10 and 1e-8; trapezoidal integration and the original source-stepping initialization remain unchanged.

## Evidence and limits

All five final split-drive cases completed warning-free at TMAX 0.125 ns and 0.0625 ns. Nominal and the 30 V / 16 ohm / 10 ohm external-gate case also completed at 0.03125 ns. Each reached 5 us with finite, strictly increasing recorded integration times. Actual maximum time differences were audited against TMAX with only a 2e-20 s floating-point allowance. The files retain raw integration samples; no `interp`, filtering or fitted time shift is used.

For every final waveform comparison, all 12 exported traces pass the existing max(1% reference peak, 0.01 V/A) amplitude gate over 1–5 us, using the union of both time grids. The finer run is the reference. These are solver/waveform checks; the full native-engine event, energy, rating and source-suitability campaign remains the parent campaign’s responsibility.

| Comparison | Case | Largest voltage difference (mV) | Largest current difference (mA) | All 12 gates |
|---|---|---:|---:|---|
| 0.0625 vs 0.03125 ns | bus30load16gate10 | 1.058517 | 1.014602 | pass |
| 0.0625 vs 0.03125 ns | nominal | 0.390303 | 0.486105 | pass |
| 0.125 vs 0.0625 ns | bus18 | 0.605012 | 1.045007 | pass |
| 0.125 vs 0.0625 ns | bus30load16gate10 | 3.672546 | 2.473799 | pass |
| 0.125 vs 0.0625 ns | gate47 | 0.466776 | 0.823484 | pass |
| 0.125 vs 0.0625 ns | load4 | 1.532382 | 2.100843 | pass |
| 0.125 vs 0.0625 ns | nominal | 1.004797 | 1.310626 | pass |

The final physical drive tested here is the gate-investigation candidate: 12 V on, -1.5 V off, original charge resistances of 13/25/50 ohms, fixed 3 ohm discharge resistance, original 20 ns linear command ramps and 300 ns dead time. Its electrical suitability is evaluated separately.

All five 0.0625 ns runs were repeated with TSTEP 10 ns; every time/value array was exactly identical to its TSTEP 1 ns counterpart. The same solver remedy also completed the unchanged original-driver nominal and combined-extension strict runs at 0.0625 ns, and all 12 waveform gates passed against the earlier complete 0.125 ns exact-B-source runs. Thus completion does not depend on the physical gate-drive revision.

## Why the source and TSTEP controls changed

Original strict PWL nominal and combined runs stopped at the first command corner. Cleaning redundant PWL points, expressing the command as PULSE, shifting the corner 1 ps, varying gate resistance, and multiple numerical options did not cure the original first-corner failure. Replacing PWL by the exact clipped-linear B expression completed both original-driver strict 0.125 ns records and matched their original PWL baseline waveforms. However, shrinking both TSTEP and TMAX to 0.0625 ns exposed further rejected runs; B conversion alone was insufficient.

Holding TSTEP at 1 ns while independently enforcing smaller TMAX resolved the tested failures. The recorded first nonzero time of the final nominal half-step case changed from 0.625 ps (TSTEP=TMAX=0.0625 ns, aborted) to 6.25 ps (TSTEP=1 ns, TMAX=0.0625 ns, complete). TSTEP 10 ns gives the same 6.25 ps initial step and exactly the same full arrays. This demonstrates sensitivity to initialization/time-grid construction. The underlying internal solver defect or conditioning mechanism is not proven; do not describe a particular vendor equation as faulty.

The [ngspice 41 manual](https://ngspice.sourceforge.io/docs/ngspice-41-manual.pdf), section 15.3.10, distinguishes TSTEP from the enforced maximum TMAX and permits a computing interval smaller than the printing increment. Section 5.1 documents behavioral voltage expressions. This workaround does not relax convergence or amplitude acceptance.

## Adapter implementation

For each channel’s existing strictly increasing PWL points, begin with the initial value. For every non-flat segment from (t0,v0) to (t1,v1), add `(v1-v0)*min(max((time-t0)/(t1-t0),0),1)`. Use the resulting expression in `Bhcmd gh0 sw V=...` or `Blcmd gl0 0 V=...`. The expression is algebraically the same PWL function, not a smoothed replacement. Keep all gate-current measurement voltage sources and terminal waveforms. `verify_blinear.py::convert` provides the local implementation.

Use `tran 1e-9 <stopTime> 0 <maxStep>` for every mesh, recording both controls explicitly. With `wrdata` and without `interp`, the written data retain the actual internal time grid. Continue rejecting nonzero diagnostics, missing/nonfinite records and incomplete stop time, independently of process exit code.

## Preserved records

- `accepted_solver_audit.json` and `accepted_solver_runs.csv`: accepted run details, actual maximum step, initial step, finiteness, monotonicity, exact-array TSTEP sensitivity and waveform/deck/control hashes.
- `solver_source_identity.json`: unchanged vendor and executable hashes plus strict options.
- `all_trial_index.json` / `.csv`: full local trial index, including rejected attempts and excluded preliminary parameter-replacement attempts.
- `final_*`, `fixedout_*`, `original_final_*`: accepted numerical run folders containing exact deck, control, log, summary and raw waveform.
- `final_refinement_*.json`, `final_quarter_refinement_*.json`: per-signal comparisons.
- Earlier failed trials remain in their original local folders. Their incomplete traces are never accepted or extrapolated for comparisons.

Raised-cosine source trials also completed, but they alter the assumed source waveform and are not adopted. A current ngspice runtime was researched; SourceForge downloads returned HTML/HTTP 403 and no new executable was run. The validated remedy needs no runtime replacement.

Vendor SHA-256: `ef36d4c42564abafd708b31fae5d727ccb392b1079a05c599a137d2e34f6b92a`.

Executable SHA-256: `ef5ce0ae623d43810b2b528b31ac3941418eaca0f9aba802e407aba7df8863ac`.
