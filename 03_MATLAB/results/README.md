# Generated MATLAB Results

Running `main` creates baseline data and figures in this folder. Generated CSV, MAT, and PNG files are excluded from version control by default because they can be reproduced from the source and parameter set.

Running `phase2_main` creates one dataset per encoder scenario, a metrics table, a MAT workspace, and the comparative Phase 2 figure. `validate_phase2_simulink` creates the numerical MATLAB/Simulink comparison table.

The 2026-09-08 Phase 2B evidence package includes automated-test results, per-scenario time series, matched-baseline metrics, a parameter/scenario manifest, packet-loss statistical evidence, a Simulink smoke-test table, and a MATLAB/Simulink cross-validation table. See `Phase2B_Validation_Summary.md` for the recorded result. Any Phase 2B summary must identify the model as reduced-order, receiver-equivalent, assumed-parameter, and not physically validated.

The Phase 2B pipeline writes `phase2b_<scenario>_timeseries.csv`, `phase2b_metrics.csv`, `phase2b_scenario_manifest.csv`, `phase2b_fault_study.mat`, `phase2b_receiver_faults_and_response.png`, `phase2b_packet_loss_monte_carlo.csv`, `phase2b_simulink_smoke_test.csv`, and `phase2b_simulink_validation.csv`. These outputs remain reproducible analysis artifacts; do not manually edit them.
