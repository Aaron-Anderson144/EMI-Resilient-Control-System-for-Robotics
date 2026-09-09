# Low-gate recrossing audit

The audited window is the low-side off command minus 0.1 microseconds through plus 0.5 microseconds: nominally 3.619–4.219 microseconds. Thresholds are 1.2, 6 and 10.8 V for the declared 12 V driver. The original finest CSVs are read without filtering, alignment or waveform changes.

| Case | Engine | 1.2 V falls / rises | 6 V falls / rises | 10.8 V falls / rises | Extra falling crossings | Post-first-10% gate peak (V) | Strict counterpart gate result |
|---|---|---:|---:|---:|---:|---:|---|
| nominal | native | 2 / 1 | 1 / 0 | 1 / 0 | 1 | 2.12804 | fail |
| nominal | spice | 2 / 1 | 1 / 0 | 1 / 0 | 1 | 2.12804 | fail |
| holdout_bus18 | native | 2 / 1 | 1 / 0 | 1 / 0 | 1 | 1.94147 | fail |
| holdout_bus18 | spice | 2 / 1 | 1 / 0 | 1 / 0 | 1 | 1.94147 | fail |
| holdout_load4ohm | native | 2 / 1 | 1 / 0 | 1 / 0 | 1 | 2.1462 | fail |
| holdout_load4ohm | spice | 2 / 1 | 1 / 0 | 1 / 0 | 1 | 2.1462 | fail |
| holdout_bus30_load16_gate10 | native | 2 / 1 | 1 / 0 | 1 / 0 | 1 | 2.01202 | fail |
| holdout_bus30_load16_gate10 | spice | 2 / 1 | 1 / 0 | 1 / 0 | 1 | 2.01203 | fail |
| holdout_gate47 | native | 0 / 0 | 1 / 0 | 1 / 0 | 0 | 10% not reached | fail |
| holdout_gate47 | spice | 0 / 0 | 1 / 0 | 1 / 0 | 0 | 10% not reached | fail |

## Interpretation

The conservative event rule requires a complete ordered first passage and no repeated directed threshold crossings. An off-gate bump can rise back above 1.2 V and then fall through it again, creating a second falling crossing even though the first 10/50/90% timings match closely between engines. Such traces fail the counterpart-gate rule; agreement between two engines does not turn an unresolved event classification into a pass.

A bump accompanying the opposite switch-node transition is consistent with Miller coupling in the modeled gate network. This physical interpretation is an inference from timing and the modeled capacitance network. Crossing 1.2 V alone does not prove channel conduction or shoot-through; actual channel-current logs must be evaluated separately.

The 47-ohm gate finest CSVs became available during this audit. Neither engine has a 1.2 V falling crossing in the fixed counterpart window. The native low gate remains at 1.76554 V at 4.219 microseconds, so the complete-transition and endpoint checks fail separately from the recrossing failures in the other four cases. The broader oscillatory/channel-current problem remains a separate diagnostic.

## First-falling timing agreement

- nominal: maximum difference among available first 10/50/90% low-gate falling crossings = 4.73325e-05 ns.
- holdout_bus18: maximum difference among available first 10/50/90% low-gate falling crossings = 6.11679e-05 ns.
- holdout_load4ohm: maximum difference among available first 10/50/90% low-gate falling crossings = 5.79764e-05 ns.
- holdout_bus30_load16_gate10: maximum difference among available first 10/50/90% low-gate falling crossings = 1.00231e-05 ns.
- holdout_gate47: maximum difference among available first 50/90% low-gate falling crossings = 7.47479e-05 ns.

Exact crossing times, directions, endpoint states and post-fall peak times are preserved in gate_recrossing_diagnosis.json. The audit does not relax any criterion or establish physical hardware validity.
