function study = sc01a_main(outputFolder)
%SC01A_MAIN Execute regressions and native campaign in a fresh directory.
arguments
    outputFolder (1,1) string = ""
end
sc01aRoot=fileparts(mfilename('fullpath'));
sc01aProjectRoot=fileparts(fileparts(sc01aRoot));
addpath(fullfile(sc01aRoot,'functions'));
sc01aOutput=sc01a_prepare_output_folder(outputFolder,fullfile(sc01aRoot,'results'),"sc01a_workflow");
oldConfig=Simulink.fileGenControl('getConfig');
cacheCleanup=onCleanup(@()Simulink.fileGenControl('setConfig','config',oldConfig));
Simulink.fileGenControl('set','CacheFolder',fullfile(sc01aOutput,'cache'), ...
    'CodeGenFolder',fullfile(sc01aOutput,'codegen'),'createDir',true);
run(fullfile(sc01aProjectRoot,'03_MATLAB','startup_project.m'));
sc01aLegacyTests=runtests(fullfile(sc01aProjectRoot,'03_MATLAB','tests'));
run(fullfile(sc01aRoot,'sc01a_startup.m'));
sc01aCircuitTests=runtests(fullfile(sc01aRoot,'tests'));
sc01aTests=[sc01aLegacyTests(:);sc01aCircuitTests(:)];
writetable(table(sc01aTests),fullfile(sc01aOutput,'sc01a_tests.csv'));
assert(all([sc01aTests.Passed]),'SC01A:TestsFailed','Project and circuit tests must pass.');
study=run_sc01a(fullfile(sc01aOutput,'campaign'));
study.tests=table(sc01aTests);
study.meta.workflowOutputFolder=sc01aOutput;
save(fullfile(study.meta.outputFolder,'sc01a_study.mat'),'study','-v7');
write_sc01a_summary(study,study.meta.outputFolder);
fprintf('SC-01A workflow completed. Results: %s\n',sc01aOutput);
end
