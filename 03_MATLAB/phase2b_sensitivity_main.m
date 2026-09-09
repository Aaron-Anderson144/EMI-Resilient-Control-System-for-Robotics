%PHASE2B_SENSITIVITY_MAIN Run the complete reproducible sensitivity workflow.
matlabRoot = fileparts(mfilename('fullpath'));
run(fullfile(matlabRoot,'startup_project.m'));
sensitivityOutput = fullfile(matlabRoot,'results','sensitivity');
if ~isfolder(sensitivityOutput), mkdir(sensitivityOutput); end
sensitivityTests = runtests(fullfile(matlabRoot,'tests'));
writetable(table(sensitivityTests),fullfile(sensitivityOutput,'phase2b_sensitivity_tests.csv'));
assert(all([sensitivityTests.Passed]),'EMIProject:SensitivityTestsFailed', ...
    'All project tests must pass before the sensitivity study.');
sensitivityStudy = run_phase2b_sensitivity_study(sensitivityOutput);
sensitivityStudy.validation = validate_phase2b_sensitivity(sensitivityStudy,sensitivityOutput);
study = sensitivityStudy;
save(fullfile(sensitivityOutput,'phase2b_sensitivity_study.mat'),'study','-v7');
write_phase2b_sensitivity_summary(study,sensitivityTests,sensitivityOutput);
fprintf('Sensitivity workflow finished. Outputs: %s\n',sensitivityOutput);
