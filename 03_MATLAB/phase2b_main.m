%PHASE2B_MAIN Generate and verify all Phase 2B software artifacts.

matlabRoot = fileparts(mfilename('fullpath'));
run(fullfile(matlabRoot, 'startup_project.m'));

run(fullfile(matlabRoot, 'scripts', 'run_phase2b_study.m'));
run(fullfile(matlabRoot, 'scripts', ...
    'run_phase2b_packet_loss_monte_carlo.m'));
build_phase2b_model(false);
smoke_test_phase2b_model();
validate_phase2b_simulink();

fprintf('Phase 2B study, model, smoke tests, and cross-validation completed.\n');
