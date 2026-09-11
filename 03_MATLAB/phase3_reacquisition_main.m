%PHASE3_REACQUISITION_MAIN Reproduce optional independent-reference recovery.
startup_project;
matlabRoot=fileparts(mfilename('fullpath'));
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
recoveryOutput=fullfile(matlabRoot,'results','development',['phase3_reacquisition_',stamp]);
mkdir(recoveryOutput);
Simulink.fileGenControl('set','CacheFolder',fullfile(recoveryOutput,'cache'), ...
 'CodeGenFolder',fullfile(recoveryOutput,'codegen'),'createDir',true);
suite=[matlab.unittest.TestSuite.fromClass(?TestPhase3Reacquisition), ...
 matlab.unittest.TestSuite.fromClass(?TestPhase3ReacquisitionIntegration)];
recoveryTests=run(suite);
writetable(table(recoveryTests),fullfile(recoveryOutput,'reacquisition_tests.csv'));assertSuccess(recoveryTests);
recoveryStudy=run_phase3_reacquisition_study(fullfile(recoveryOutput,'campaign'));
recoveryValidation=validate_phase3_simulink(recoveryStudy.runs,fullfile(recoveryOutput,'simulink'));
plot_phase3_reacquisition_study(recoveryStudy,fullfile(recoveryOutput,'figures'));
write_run_manifest(recoveryOutput,matlabRoot,struct('workflow',"independent_reference_recovery", ...
 'tests',numel(recoveryTests),'numericalRuns',numel(recoveryStudy.runs), ...
 'simulinkRuns',height(recoveryValidation),'physicalValidation',false));
fprintf('Independent-reference recovery evidence: %s\n',recoveryOutput);
