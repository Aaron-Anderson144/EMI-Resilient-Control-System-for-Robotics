function campaign=run_fourway_v2_parallel(partition,outputFolder,acceptancePath,verified)
% Independent whole-hypothesis workers; no circuit/control state is shared.
assert(~isfolder(outputFolder),'EMIProject:V2Output','Use a fresh campaign output directory.');mkdir(outputFolder);
fourway_v2_build_engine();
identity=fourway_v2_execution_identity();
fid=fopen(fullfile(outputFolder,'execution_identity.json'),'w');fprintf(fid,'%s\n',jsonencode(identity,'PrettyPrint',true));fclose(fid);
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',8);end
parts=cell(16,1);
parfor v=1:16
 workerFolder=fullfile(outputFolder,sprintf('worker_V%02d',v));
 parts{v}=run_fourway_v2_stage(partition,workerFolder,acceptancePath,v);
end
metrics=table();recovery=table();episodes=table();bursts=table();records=table();failures=table();
for v=1:16
 c=parts{v};metrics=[metrics;c.metrics];recovery=[recovery;c.recovery];episodes=[episodes;c.episodes]; %#ok<AGROW>
 bursts=[bursts;c.burstAttribution];records=[records;c.records];failures=[failures;c.pairFailures]; %#ok<AGROW>
 for k=1:height(c.records)
  source=fullfile(c.outputFolder,c.records.Record(k));target=fullfile(outputFolder,c.records.Record(k));
  assert(isfolder(source)&&~isfolder(target),'EMIProject:V2Records','Record move would overwrite existing evidence.');
  [ok,msg]=movefile(source,target);assert(ok,'EMIProject:V2Records','%s',msg);
 end
end
campaign=struct('design_id',"FOUR-WAY-EMI-PLAN-V2",'partition',partition,'outputFolder',outputFolder, ...
 'metrics',metrics,'recovery',recovery,'episodes',episodes,'burstAttribution',bursts,'records',records, ...
 'pairFailures',failures,'frozenInputs',verified);
expected=256;if partition=="evaluation",expected=1536;end
complete=height(records)==expected&&all(records.Status=="passed")&&numel(unique(records.Record))==expected&& ...
 height(metrics)==expected/2&&isempty(failures)&&numel(unique(metrics.Variant))==16;
guards=complete;if complete,guards=all(metrics.ExecutionGuardPass);end
summary=struct('design_id',"FOUR-WAY-EMI-PLAN-V2",'partition',partition,'logical_records',height(records), ...
 'expected_records',expected,'unique_executions',height(records),'failed_records',sum(records.Status~="passed"), ...
 'paired_results',height(metrics),'failed_pairs',height(failures),'complete',complete, ...
 'all_execution_clean_guards_pass',guards,'physical_validation',false,'receiver_hypotheses',16, ...
 'parallel_workers',pool.NumWorkers);
summary.execution_identity=identity;
if partition=="evaluation"&&complete,campaign.assessment=fourway_v2_assess(metrics);summary.assessment=campaign.assessment;end
writetable(records,fullfile(outputFolder,'record_index.csv'));writetable(metrics,fullfile(outputFolder,'metrics.csv'));
writetable(recovery,fullfile(outputFolder,'recovery.csv'));writetable(episodes,fullfile(outputFolder,'detection_episodes.csv'));
writetable(bursts,fullfile(outputFolder,'burst_attribution.csv'));writetable(failures,fullfile(outputFolder,'pair_failures.csv'));
save(fullfile(outputFolder,'campaign.mat'),'campaign','-v7');
fid=fopen(fullfile(outputFolder,'stage_summary.json'),'w');fprintf(fid,'%s\n',jsonencode(summary,'PrettyPrint',true));fclose(fid);
fprintf('FOURWAY V2 %s COMPLETE: %d records; complete=%d, guards=%d.\n',partition,height(records),complete,guards);
end
