function campaign=run_fourway_v2_stage(partition,outputFolder,acceptancePath,variantIndex)
% Full declared campaign; every failed execution remains explicitly indexed.
arguments
 partition (1,1) string {mustBeMember(partition,["development","evaluation"])}
 outputFolder (1,1) string
 acceptancePath (1,1) string = ""
 variantIndex (1,1) double {mustBeInteger,mustBeNonnegative} = 0
end
verified=fourway_v2_verify_freeze();
if partition=="evaluation",fourway_v2_require_acceptance(acceptancePath);end
if variantIndex==0
 campaign=run_fourway_v2_parallel(partition,outputFolder,acceptancePath,verified);return;
end
assert(variantIndex<=16,'EMIProject:V2Variant','Invalid variant index.');
assert(~isfolder(outputFolder),'EMIProject:V2Output','Use a fresh output directory for each attempt.');mkdir(outputFolder);
matrix=readtable(fullfile(fourway_v2_root(),'04_EMI_Models','four_way_emi_v2_fixtures.csv'),'TextType','string');
matrix=matrix(matrix.stage==partition,:);arms=["BASELINE","EM_ONLY","SW_ONLY","COMBINED"];
variants=fourway_v2_variant();metrics=table();recovery=table();episodes=table();bursts=table();records=table();pairFailures=table();
for v=variantIndex
 for i=1:height(matrix)
  for arm=arms
   pair=cell(1,2);
   for exposureIndex=1:2
    exposed=exposureIndex==2;fixture=fourway_v2_fixture(matrix.fixture_id(i),arm,exposed,variants(v).id);
    kind="clean";if exposed,kind="exposed";end
    recordId=fixture.id+"_"+variants(v).id+"_"+arm+"_"+kind;
    recordFolder=fullfile(outputFolder,recordId);mkdir(recordFolder);
    fprintf('FOURWAY V2 %s: %s\n',partition,recordId);timer=tic;status="passed";errorText="";
    try
     result=simulate_fourway_v2_actuator(fixture);fourway_v2_write_record(result,recordFolder);pair{exposureIndex}=result;
    catch failure
     status="failed";errorText=string(getReport(failure,'extended','hyperlinks','off'));
     fid=fopen(fullfile(recordFolder,'failure.txt'),'w');fprintf(fid,'%s\n',errorText);fclose(fid);
     fprintf(2,'%s FAILED: %s\n',recordId,failure.message);
    end
    elapsed=toc(timer);
    records=[records;table(recordId,fixture.id,variants(v).id,arm,kind,elapsed,status,errorText, ...
     'VariableNames',{'Record','Fixture','Variant','Arm','Kind','Elapsed_s','Status','Error'})]; %#ok<AGROW>
    writetable(records,fullfile(outputFolder,'record_index.csv'));
   end
   try
    assert(~isempty(pair{1})&&~isempty(pair{2}),'EMIProject:V2PairMissing','At least one companion execution failed.');
    source=fourway_source_metadata(fixture.phase_s,fixture.closure_s);
    [m,r,e,b]=fourway_v2_metrics(pair{2},pair{1},source.burst_last_derivative_s,source.burst_first_derivative_s);
    metrics=[metrics;m];recovery=[recovery;r];episodes=[episodes;e];bursts=[bursts;b]; %#ok<AGROW>
    writetable(metrics,fullfile(outputFolder,'metrics.csv'));writetable(recovery,fullfile(outputFolder,'recovery.csv'));
    writetable(episodes,fullfile(outputFolder,'detection_episodes.csv'));writetable(bursts,fullfile(outputFolder,'burst_attribution.csv'));
   catch failure
    errorText=string(getReport(failure,'extended','hyperlinks','off'));
    pairFailures=[pairFailures;table(fixture.id,variants(v).id,arm,errorText, ...
     'VariableNames',{'Fixture','Variant','Arm','Error'})]; %#ok<AGROW>
    writetable(pairFailures,fullfile(outputFolder,'pair_failures.csv'));
   end
   clear pair result
  end
 end
end
expected=height(matrix)*4*2;complete=height(records)==expected&&all(records.Status=="passed")&&height(metrics)==expected/2&&isempty(pairFailures);
guards=complete;if complete,guards=all(metrics.ExecutionGuardPass);end
campaign=struct('design_id',"FOUR-WAY-EMI-PLAN-V2",'partition',partition,'outputFolder',outputFolder, ...
 'metrics',metrics,'recovery',recovery,'episodes',episodes,'burstAttribution',bursts,'records',records, ...
 'pairFailures',pairFailures,'frozenInputs',verified);
summary=struct('design_id',"FOUR-WAY-EMI-PLAN-V2",'partition',partition,'logical_records',height(records), ...
 'expected_records',expected,'unique_executions',height(records),'failed_records',sum(records.Status~="passed"), ...
 'paired_results',height(metrics),'failed_pairs',height(pairFailures),'complete',complete, ...
 'all_execution_clean_guards_pass',guards,'physical_validation',false,'receiver_hypotheses',1,'partial_worker',true);
save(fullfile(outputFolder,'campaign.mat'),'campaign','-v7');
fid=fopen(fullfile(outputFolder,'stage_summary.json'),'w');fprintf(fid,'%s\n',jsonencode(summary,'PrettyPrint',true));fclose(fid);
fprintf('FOURWAY V2 %s COMPLETE: %d records; complete=%d, guards=%d.\n',partition,height(records),complete,guards);
end
