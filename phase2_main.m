%PHASE2_MAIN Run the Phase 2 analytical encoder-fault study.

matlabRoot = fileparts(mfilename('fullpath'));
run(fullfile(matlabRoot, 'startup_project.m'));
run(fullfile(matlabRoot, 'scripts', 'run_phase2_fault_study.m'));

fprintf('\nPhase 2 analytical study completed.\n');
fprintf('Next: run build_phase2_model to generate the Simulink model.\n');

