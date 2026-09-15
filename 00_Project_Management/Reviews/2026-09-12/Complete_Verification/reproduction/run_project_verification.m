function run_project_verification()
% Fresh verification records, separate from all saved research campaigns.
projectRoot='C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics';
outputRoot='C:\Users\adand\Documents\Codex\2026-09-12\a\outputs\Project_Verification_2026-09-12';
workRoot=fileparts(mfilename('fullpath'));
oldPath=path; cleanupPath=onCleanup(@()path(oldPath)); %#ok<NASGU>
oldDirectory=pwd; cleanupDirectory=onCleanup(@()cd(oldDirectory)); %#ok<NASGU>
cd(fullfile(projectRoot,'03_MATLAB'));startup_project;
a=fullfile(projectRoot,'06_Circuit_Simulations','SC01A');
b=fullfile(projectRoot,'06_Circuit_Simulations','SC01B_R2');
fw=fullfile(projectRoot,'06_Circuit_Simulations','FOUR_WAY');
addpath(fullfile(a,'functions'),fullfile(a,'scripts'), ...
    fullfile(b,'functions'),fullfile(b,'scripts'),b);
Simulink.fileGenControl('set','CacheFolder',fullfile(workRoot,'cache'), ...
    'CodeGenFolder',fullfile(workRoot,'codegen'),'createDir',true);
environment=struct('matlabVersion',version,'release',version('-release'), ...
    'products',ver,'timeLocal',char(datetime('now')));
try,environment.compiler=mex.getCompilerConfigurations('C++','Selected');
catch caught,environment.compilerError=caught.message;end
save(fullfile(outputRoot,'matlab_environment.mat'),'environment');
environment=rmfield(environment,intersect(fieldnames(environment),{'compiler'}));
writeJson(fullfile(outputRoot,'matlab_environment.json'),environment);
freeze=fourway_verify_freeze();writeJson(fullfile(outputRoot,'freeze_verification.json'),freeze);
fprintf('FROZEN_INPUTS_VERIFIED %d\n',freeze.frozen_files_verified);
suite=[matlab.unittest.TestSuite.fromFolder(fullfile(projectRoot,'03_MATLAB','tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(a,'tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(b,'tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(fw,'tests'))];
fprintf('MAIN_SUITE_START %d\n',numel(suite));
started=tic;mainResults=run(suite);mainElapsed=toc(started);
writetable(table(mainResults),fullfile(outputRoot,'all_project_tests.csv'));
save(fullfile(outputRoot,'all_project_tests.mat'),'mainResults');
mainSummary=summaryFor(mainResults,mainElapsed);
writeJson(fullfile(outputRoot,'main_test_summary.json'),mainSummary);
fprintf('MAIN_SUITE_COMPLETE passed=%d failed=%d incomplete=%d\n', ...
    mainSummary.passed,mainSummary.failed,mainSummary.incomplete);

% Run the hybrid suite separately to avoid reference-path collisions.
hybrid=fullfile(projectRoot,'11_EDMD_Hybrid_Estimation');
addpath(fullfile(hybrid,'code'),fullfile(hybrid,'tests'),hybrid,'-begin');
fprintf('HYBRID_SUITE_START\n');started=tic;
hybridResults=runtests(fullfile(hybrid,'tests'));hybridElapsed=toc(started);
writetable(table(hybridResults),fullfile(outputRoot,'hybrid_tests.csv'));
save(fullfile(outputRoot,'hybrid_tests.mat'),'hybridResults');
hybridSummary=summaryFor(hybridResults,hybridElapsed);
writeJson(fullfile(outputRoot,'hybrid_test_summary.json'),hybridSummary);
fprintf('HYBRID_SUITE_COMPLETE passed=%d failed=%d incomplete=%d\n', ...
    hybridSummary.passed,hybridSummary.failed,hybridSummary.incomplete);
writeJson(fullfile(outputRoot,'test_summary.json'),struct('main',mainSummary,'hybrid',hybridSummary, ...
    'allPassed',mainSummary.failed==0 && mainSummary.incomplete==0 && ...
    hybridSummary.failed==0 && hybridSummary.incomplete==0));
fprintf('TEST_PHASE_COMPLETE\n');
end

function s=summaryFor(r,elapsed)
s=struct('tests',numel(r),'passed',sum([r.Passed]),'failed',sum([r.Failed]), ...
    'incomplete',sum([r.Incomplete]),'elapsedSeconds',elapsed, ...
    'failedNames',string({r(~[r.Passed]).Name}));
end

function writeJson(file,value)
fid=fopen(file,'w');assert(fid>=0);c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
