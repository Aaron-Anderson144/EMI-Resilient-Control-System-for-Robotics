%PHASE3_TUNING_MAIN Reproduce frozen grid and separate controller evaluation.
% Creates fresh evidence; does not modify phase3_configuration defaults.
startup_project;
matlabRoot=fileparts(mfilename('fullpath'));
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
tuningOutput=fullfile(matlabRoot,'results','development',['phase3_tuning_',stamp]);
mkdir(tuningOutput);
Simulink.fileGenControl('set','CacheFolder',fullfile(tuningOutput,'cache'), ...
 'CodeGenFolder',fullfile(tuningOutput,'codegen'),'createDir',true);
suite=[matlab.unittest.TestSuite.fromClass(?TestPhase3TuningTools), ...
 matlab.unittest.TestSuite.fromClass(?TestPhase3TuningFixtures), ...
 matlab.unittest.TestSuite.fromClass(?TestPhase3TuningAssessment)];
tuningTests=run(suite);
writetable(table(tuningTests),fullfile(tuningOutput,'tuning_tests.csv'));assertSuccess(tuningTests);
try
 tuningStudy=run_phase3_tuning_study(fullfile(tuningOutput,'campaign'));
catch exception
 if ~strcmp(exception.identifier,'EMIProject:TuningExecutionFailed'),rethrow(exception);end
 saved=load(fullfile(tuningOutput,'campaign','phase3_tuning_study.mat'),'study');
 tuningStudy=saved.study;
 fprintf('STUDY REQUIREMENT FAILURE retained: %s\n',exception.message);
 % Finish independent integration/plot diagnostics without clearing failure.
end
tuningValidation=validate_phase3_tuning_study(tuningStudy,fullfile(tuningOutput,'simulink'));
plot_phase3_tuning_study(tuningStudy,fullfile(tuningOutput,'figures'));
write_run_manifest(tuningOutput,matlabRoot,struct('workflow',"frozen_controller_tuning", ...
 'tests',numel(tuningTests),'numericalRuns',tuningStudy.totalNumericalRuns, ...
 'simulinkRuns',height(tuningValidation),'studyRequirementsPassed',tuningStudy.executionAccepted, ...
 'defaultsChanged',false,'physicalValidation',false));
fprintf('Declared study execution/clean requirements passed: %d\n',tuningStudy.executionAccepted);
fprintf('Controller tuning evidence: %s\n',tuningOutput);
