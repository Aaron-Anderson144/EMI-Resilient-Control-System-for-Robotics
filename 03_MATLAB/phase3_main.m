%PHASE3_MAIN Reproduce the numerical prototype in a new evidence directory.
startup_project;
matlabRoot=fileparts(mfilename('fullpath'));
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
phase3Output=fullfile(matlabRoot,'results','development',['phase3_',stamp]);
mkdir(phase3Output);
Simulink.fileGenControl('set','CacheFolder',fullfile(tempdir,['emi_phase3_cache_',stamp]), ...
 'CodeGenFolder',fullfile(tempdir,['emi_phase3_codegen_',stamp]),'createDir',true);
phase3Suite=matlab.unittest.TestSuite.fromFolder(fullfile(matlabRoot,'tests'));
phase3Suite=phase3Suite(contains(string({phase3Suite.Name}),'Phase3'));
phase3Tests=run(phase3Suite);writetable(table(phase3Tests),fullfile(phase3Output,'phase3_tests.csv'));assertSuccess(phase3Tests);
phase3Study=run_phase3_study(fullfile(phase3Output,'campaign'));
phase3Validation=validate_phase3_simulink([phase3Study.protected;phase3Study.baseline],fullfile(phase3Output,'simulink'));
phase3Ablation=run_phase3_ablation(phase3Study,fullfile(phase3Output,'ablation'));
plot_phase3_study(phase3Study,fullfile(phase3Output,'figures'));
write_run_manifest(phase3Output,matlabRoot,struct('workflow',"phase3_complete_prototype", ...
 'unitTests',numel(phase3Tests),'pairedCases',numel(phase3Study.scenarios),'simulinkRuns',height(phase3Validation)));
fprintf('Phase3 evidence saved to%s\n',phase3Output);
