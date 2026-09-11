function report=run_fourway_receiver_tests(outputFolder)
%RUN_FOURWAY_RECEIVER_TESTS Reproducible focused circuit/receiver acceptance.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'03_MATLAB','functions'));
if nargin<1,outputFolder=fullfile(root,'06_Circuit_Simulations','FOUR_WAY','results','receiver_focused_acceptance');end
if ~exist(outputFolder,'dir'),mkdir(outputFolder);end
results=runtests(fullfile(root,'06_Circuit_Simulations','FOUR_WAY','tests','TestFourwayReceiver.m'));
save(fullfile(outputFolder,'test_results.mat'),'results');
tableResult=table(string({results.Name}).',[results.Passed].',[results.Failed].',[results.Incomplete].',[results.Duration].',...
 'VariableNames',{'Name','Passed','Failed','Incomplete','Duration_s'});
writetable(tableResult,fullfile(outputFolder,'test_results.csv'));
report=struct('design_id','FOUR-WAY-EMI-PLAN-V1','tests',numel(results),...
 'passed',sum([results.Passed]),'failed',sum([results.Failed]),'incomplete',sum([results.Incomplete]),...
 'independent_KCL_return_law_cases',120,'KCL_absolute_residual_gate_A_or_V',1e-12,...
 'independent_augmented_exponential_cases',30,'expm_absolute_state_gate',1e-12,...
 'engine_function',fourway_build_engine(),'source',fourway_replay());
report.source=rmfield(report.source,{'time_s','switch_V'});
report.accepted=all([results.Passed])&&~any([results.Failed])&&~any([results.Incomplete]);
fid=fopen(fullfile(outputFolder,'acceptance.json'),'w');cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
assert(report.accepted,'FOURWAY:ReceiverUnitFailure','Focused circuit/receiver tests failed; saved diagnostics must be retained.');
end
