%PHASE3_MOTION_MAIN Optional reference shaping with unchanged observer policy.
startup_project;
matlabRoot=fileparts(mfilename('fullpath'));
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
motionOutput=fullfile(matlabRoot,'results','development',['phase3_motion_',stamp]);
mkdir(motionOutput);
Simulink.fileGenControl('set','CacheFolder',fullfile(motionOutput,'cache'), ...
 'CodeGenFolder',fullfile(motionOutput,'codegen'),'createDir',true);
suite=[matlab.unittest.TestSuite.fromClass(?TestPhase3ReferenceGovernor), ...
 matlab.unittest.TestSuite.fromClass(?TestPhase3MotionFixtures), ...
 matlab.unittest.TestSuite.fromClass(?TestPhase3MotionEnvelope)];
motionTests=run(suite);writetable(table(motionTests),fullfile(motionOutput,'motion_tests.csv'));assertSuccess(motionTests);
motionStudy=run_phase3_motion_study(fullfile(motionOutput,'campaign'));
motionValidation=validate_phase3_motion_study(motionStudy,fullfile(motionOutput,'simulink'));
plot_phase3_motion_study(motionStudy,fullfile(motionOutput,'figures'));
write_run_manifest(motionOutput,matlabRoot,struct('workflow',"optional_motion_envelope", ...
 'tests',numel(motionTests),'numericalRuns',motionStudy.totalNumericalRuns, ...
 'simulinkRuns',height(motionValidation),'studyAccepted',motionStudy.accepted, ...
 'defaultsChanged',false,'physicalValidation',false));
fprintf('Motion-envelope evidence: %s\nDeclared numerical acceptance: %d\n',motionOutput,motionStudy.accepted);
