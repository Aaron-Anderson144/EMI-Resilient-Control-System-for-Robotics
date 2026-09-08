%MAIN Run the Phase 1 clean analytical baseline.

matlabRoot = fileparts(mfilename('fullpath'));
run(fullfile(matlabRoot, 'startup_project.m'));
run(fullfile(matlabRoot, 'scripts', 'run_baseline.m'));

fprintf('\nPhase 1 analytical baseline completed.\n');
fprintf('Next: review results, then run build_baseline_model.\n');

