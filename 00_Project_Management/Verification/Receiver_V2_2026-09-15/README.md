# Receiver V2 checkpoint - 15 September 2026

The THVD1450DR receiver/circuit contract, Signal Lab characterization workflow and conditional PLAN-V2 protocol are complete within their declared scope. This is an electrical simulation checkpoint. The causal motor/controller comparison remains a separate implementation and acceptance task.

## Findings

- 40 electrical records, each evaluated under 16 receiver variants: 640 cases.
- All 640 passed continuous voltage-domain and declared numerical checks; no unresolved cases.
- All 320 clean cases passed count, domain and delay guards.
- No final count error at the end of these six-microsecond records.
- 80 variant cases (40 matched pulse-law pairs) changed output-edge count between transport and inertial assumptions. Transient edge behavior remains model-dependent.
- Worst clean transition delay is approximately 150.5 ns. The largest coarse/fine voltage difference is approximately 0.02875 mV and largest retained voltage-envelope gap approximately 0.249 mV, against a 1 mV characterization allowance. These are not the pending native four-way acceptance tests.

These findings preserve a null final-count result and justify retaining all sixteen receiver variants. They do not establish physical receiver behavior, actuator disturbance or mitigation benefit. Extra/missed edge fields are net count excess/deficit, not a matched-event classification.

## Verification

- Nine receiver-engine tests passed, including independent KCL and augmented matrix propagation, multiple roots in one interval, grazing, pulse/event ordering, joint quadrature decoding, reverse motion and initially high input.
- Workbench backend 33/33, MATLAB adapter 9/9, and desktop boundary 7/7 checks passed.
- A real characterization run was launched from Signal Lab and retained with its logs, plots, events, tables and configuration/code/source identities.
- Independent CSV audit reconstructed all 640 cases, 40 complete variant groups, 320 clean/exposed pairs, summary counts and pulse-law comparisons.
- Original PLAN-V1 hashes are checked by the V2 protocol verifier. No old evaluation was opened.

Each verification count has its own scope; do not sum them into a scientific acceptance claim. See the test CSVs/logs, browser-smoke.json, independent_audit.json and workbench_run.json.

## Next experiment

PLAN-V2 retains the four original treatments and scoring rules, with 16 receiver variants and new reserved integrated fixtures. It specifies 256 development and 1,536 evaluation logical records, plus 256 separate closure diagnostics. The protocol is finalized, but evaluation remains closed until the new causal motor/receiver implementation, native numerical agreement, complete development acceptance and independent implementation freeze pass.

Run `python 04_EMI_Models/verify_four_way_v2.py` from the project to verify protocol/evidence identities. A protocol verification is not permission to bypass the evaluation gates.

## Files

- summary.json / cases.csv: full variant results and numerical status.
- parameters.json / source_identity.json: exact assumptions and source identities.
- report.md / characterization.png: generated report and plot.
- independent_audit.json / audit_characterization.py: separate coverage and summary reconstruction.
- workbench_run.json: link to the full saved detail records; those remain in the workbench run and portable app.
