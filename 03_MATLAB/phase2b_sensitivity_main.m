function study = phase2b_sensitivity_main(outputFolder)
%PHASE2B_SENSITIVITY_MAIN Run sensitivity in a fresh evidence directory.
arguments
    outputFolder (1,1) string = ""
end
matlabRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(matlabRoot,'functions'));
sensitivityOutput=prepare_fresh_output_folder(outputFolder, ...
    fullfile(matlabRoot,'results','development'),"phase2b_sensitivity_workflow");
run(fullfile(matlabRoot,'startup_project.m'));
oldConfig=Simulink.fileGenControl('getConfig');
cacheCleanup=onCleanup(@()Simulink.fileGenControl('setConfig','config',oldConfig));
Simulink.fileGenControl('set','CacheFolder',fullfile(sensitivityOutput,'cache'), ...
    'CodeGenFolder',fullfile(sensitivityOutput,'codegen'),'createDir',true);
sensitivityTests = runtests(fullfile(matlabRoot,'tests'));
writetable(table(sensitivityTests),fullfile(sensitivityOutput,'phase2b_sensitivity_tests.csv'));
assert(all([sensitivityTests.Passed]),'EMIProject:SensitivityTestsFailed', ...
    'All project tests must pass before the sensitivity study.');
campaignFolder=fullfile(sensitivityOutput,'campaign');
sensitivityStudy = run_phase2b_sensitivity_study(campaignFolder);
sensitivityStudy.validation = validate_phase2b_sensitivity(sensitivityStudy,fullfile(campaignFolder,'validation'));
study = sensitivityStudy;
study.metadata.workflowOutputFolder=sensitivityOutput;
save(fullfile(campaignFolder,'phase2b_sensitivity_study.mat'),'study','-v7');
write_phase2b_sensitivity_summary(study,sensitivityTests,campaignFolder);
fprintf('Sensitivity workflow finished. Outputs: %s\n',sensitivityOutput);
end
