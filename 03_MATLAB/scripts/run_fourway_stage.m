function campaign=run_fourway_stage(partition,outputFolder,acceptancePath)
%RUN_FOURWAY_STAGE Execute declared development or frozen evaluation arms.
% Evaluation requires a separately saved accepting implementation freeze.
arguments
 partition (1,1) string {mustBeMember(partition,["development","evaluation"])}
 outputFolder (1,1) string = ""
 acceptancePath (1,1) string = ""
end
root=fileparts(fileparts(mfilename('fullpath')));project=fileparts(root);
verified=fourway_verify_freeze();
if partition=="evaluation"
 fourway_require_acceptance(acceptancePath);
end
outputFolder=prepare_fresh_output_folder(outputFolder,fullfile(root,'results','development'),"fourway_"+partition);
matrix=readtable(fullfile(project,'04_EMI_Models','four_way_emi_fixtures.csv'),'TextType','string');
matrix=matrix(matrix.partition==partition,:);arms=["BASELINE","EM_ONLY","SW_ONLY","COMBINED"];
metrics=table();recovery=table();episodes=table();burstAttribution=table();records=table();
for i=1:height(matrix)
 for arm=arms
  pair=cell(1,2);
  for exposureIndex=1:2
   exposed=exposureIndex==2;fixture=fourway_fixture(matrix.id(i),arm,exposed);
   kind="clean";if exposed,kind="exposed";end
   recordId=matrix.id(i)+"_"+arm+"_"+kind;recordFolder=fullfile(outputFolder,recordId);mkdir(recordFolder);
   fprintf('FOURWAY %s: %s\n',partition,recordId);
   tic;result=simulate_fourway_actuator(fixture);elapsed=toc;
   fourway_write_record(result,recordFolder);
   pair{exposureIndex}=result;
   records=[records;table(recordId,fixture.id,arm,kind,elapsed, ...
    'VariableNames',{'Record','Fixture','Arm','Kind','Elapsed_s'})]; %#ok<AGROW>
   writetable(records,fullfile(outputFolder,'record_index.csv'));
  end
  source=fourway_source_metadata(fixture.phase_s,fixture.closure_s);
  [m,r,e,ba]=fourway_metrics(pair{2},pair{1},source.burst_last_derivative_s,source.burst_first_derivative_s);
  metrics=[metrics;m];recovery=[recovery;r];episodes=[episodes;e];burstAttribution=[burstAttribution;ba]; %#ok<AGROW>
  writetable(metrics,fullfile(outputFolder,'metrics.csv'));writetable(recovery,fullfile(outputFolder,'recovery.csv'));
  if ~isempty(episodes),writetable(episodes,fullfile(outputFolder,'detection_episodes.csv'));end
  writetable(burstAttribution,fullfile(outputFolder,'burst_attribution.csv'));
  clear pair result
 end
end
campaign=struct('partition',partition,'outputFolder',outputFolder,'metrics',metrics, ...
 'recovery',recovery,'episodes',episodes,'burstAttribution',burstAttribution,'records',records,'frozenInputs',verified);
if partition=="evaluation",campaign.assessment=fourway_assess(metrics);end
save(fullfile(outputFolder,'campaign.mat'),'campaign','-v7');
summary=struct('partition',partition,'logical_records',height(records),'unique_executions',height(records), ...
 'paired_results',height(metrics),'all_execution_clean_guards_pass',all(metrics.ExecutionGuardPass), ...
 'physical_validation',false);
if partition=="evaluation",summary.assessment=campaign.assessment;end
fid=fopen(fullfile(outputFolder,'stage_summary.json'),'w');fprintf(fid,'%s\n',jsonencode(summary,'PrettyPrint',true));fclose(fid);
fprintf('FOURWAY %s COMPLETE: %d records, execution/clean guards=%d.\n',partition,height(records),all(metrics.ExecutionGuardPass));
end
