# Saved evidence and repeatability audit

The saved numerical records reproduce their reported results. A gap in the
standalone four-way CSV audit was found and corrected in a separate V2 script.
The original script and historical results were kept unchanged.

| Check | Result |
| --- | --- |
| Saved four-way development | All 352 numerical checks pass across 16 records and 8 pairs. |
| Fresh four-way development | All 352 numerical checks pass across 16 records and 8 pairs. |
| V2 pair coverage, saved and fresh development | Both campaigns pass exact indexed pair coverage and the original numerical audit. |
| Original SC01B saved exports | All five native/SPICE waveform comparisons and both engines' energy closure checks pass. Modeled channel overlap remains in all five cases. |
| SC01B_R2 saved exports | All five cases pass the independent checks, including zero modeled channel overlap above the declared current floor. |
| Python unit tests | 10 pass: 6 V2 pair-coverage tests and 4 existing SC01B_R2 audit tests. |
| Saved EDMD summary arithmetic | All 6,702 checked identities pass: 3,892 in the direct study and 2,810 in the hybrid study. |

The original SC01B result remains a known negative result. In its 47 Ω case,
simultaneous positive modeled channel current reaches 183.464 A, with both
channels above the audit current floor for 304.193 ns. Agreement between
exported waveforms does not resolve that overlap or the original campaign's
known simulation and event-resolution failures. This check did not rerun those
historical simulations. The original audit's successful process exit is not
an overall acceptance decision.

The four-way audit initially checked the number of metric rows without
checking unique pair coverage. A read-only probe substituted eight copies of
the first valid pair in memory. The original auditor returned success even
though seven pairs were missing. The actual saved file contains all eight
distinct pairs, so its reported results were unaffected.

`audit_exported_records_v2.py` now requires consistent partition labels, all
four arms for each indexed fixture, one clean and one exposed record per pair,
and exactly one metric row for every indexed pair. It then runs the original
numerical checks. Focused tests reject duplicate, missing, unexpected, and
inconsistent identities. The main acceptance checks already verify exact
pair coverage; this finding concerns the standalone auditor and does not show
that an incomplete campaign passed the main acceptance checks. The new script
and test are outside the 16-file design freeze. Usage is documented in the
FOUR_WAY README.

Fresh development reproduces all 181 CSV files emitted by the campaign
generator exactly: 6,205,957 numeric fields and 144,292 text fields match.
The 16 elapsed-time entries are excluded. The first inventory comparison
also found a saved-only `domain_and_clean_decoder_summary.csv`. That is a
historical supplemental table; `run_fourway_stage.m` does not generate it.
The initial missing-file result is preserved, and a separate report states
the narrower generator-output comparison. The supplemental table was not
copied into the fresh run or claimed as regenerated.

The fresh hybrid EDMD experiment reproduces all 18 validation candidates and
both selected models exactly apart from elapsed time. The per-run forecast
CSV and main forecast-summary CSV are byte-identical to the saved run. The
regime and paired-comparison summaries agree within rounding, with a maximum
difference of about 1.03 × 10⁻¹² in a paired summary field. The benefit decision
is identical: no regime passes the declared EDMD benefit screen. This repeats
training and testing with known seeds and confirms reproducibility; it adds
no new independent test trajectories.

The independent EDMD arithmetic check recomputes central summary values,
forecast counts, paired gains and wins, and benefit decisions from saved
per-trajectory metrics. It does not recreate predictions or bootstrap
confidence intervals. The direct and hybrid studies retain their stated
simulation limits; these results make no physical EMI immunity claim.

All outputs below are fresh. No planned evaluation or closure campaign data
was opened. This report covers the Python and saved-evidence checks; the
main verification report covers the separate MATLAB, native-simulation, and
legacy-replay runs.

Evidence and commands:

- [Initial audit commands and exit codes](commands.json), [V2 commands](supplemental_commands.json), and [fresh development commands](fresh_development_commands.json). Matching `.log` files preserve console output.
- [Saved four-way audit](four_way_saved_records.json) and [fresh four-way audit](four_way_original_fresh_records.json).
- [Original coverage-gap probe](fourway_metric_coverage_probe.json), [saved V2 audit](four_way_v2_saved_records.json), and [fresh V2 audit](four_way_v2_fresh_records.json).
- [Original SC01B audit](sc01b_original_saved_records.json) and [SC01B_R2 audit](sc01b_r2_saved_records.json).
- [V2 unit-test log](four_way_v2_python_tests.log) and [SC01B_R2 unit-test log](sc01b_r2_python_tests.log).
- [Initial development inventory comparison](fresh_development_repeatability.json) and [generator-output repeatability](fresh_development_generator_repeatability.json).
- [Saved EDMD arithmetic](edmd_summary_arithmetic.json) and [fresh EDMD repeatability](fresh_edmd_repeatability.json).
