function study=run_phase3_study(outputFolder)
%RUN_PHASE3_STUDY Fixed numerical prototype acceptance and matched evidence.
arguments
 outputFolder (1,1) string
end
require_empty_phase3_output_folder(outputFolder);
if ~isfolder(outputFolder),mkdir(outputFolder);end
p=actuator_parameters();p.simulation.stopTime_s=3;cfg=phase3_configuration(p);cases=phase3_test_scenarios(p);
n=numel(cases);study.parameters=p;study.configuration=cfg;study.scenarios=cases;
study.protected=cell(n,1);study.baseline=cell(n,1);study.protectedClean=cell(n,1);study.baselineClean=cell(n,1);
rows=cell(n,1);events=cell(n,1);
for j=1:n
 s=cases(j);profiles=phase3_fault_profiles(p,s);clean=phase3_matched_clean_scenario(s,p);cleanProfiles=phase3_fault_profiles(p,clean);
 study.protected{j}=simulate_phase3_actuator(p,s,true,cfg,profiles);
 study.baseline{j}=simulate_phase3_actuator(p,s,false,cfg,profiles);
 study.protectedClean{j}=simulate_phase3_actuator(p,clean,true,cfg,cleanProfiles);
 study.baselineClean{j}=simulate_phase3_actuator(p,clean,false,cfg,cleanProfiles);
 rows{j}=phase3_metrics(study.protected{j},study.baseline{j},study.protectedClean{j},study.baselineClean{j});
 a=study.protected{j}.timeSeries;idx=find(diff([0;a.mode])~=0);
 previous=[0;a.mode(1:end-1)];
 events{j}=table(repmat(s.name,numel(idx),1),a.time_s(idx),previous(idx),a.mode(idx),a.alarm(idx), ...
  a.credibleFresh(idx),a.estimateUsable(idx),a.resetRequest(idx),a.supplyHealthy(idx),a.gateReason(idx),a.transitionReason(idx), ...
  'VariableNames',{'Scenario','Time_s','PreviousMode','Mode','Alarm','CredibleFresh','EstimateUsable','ResetRequest','SupplyHealthy','GateReason','TransitionReason'});
 writetable(a,fullfile(outputFolder,s.name+"_protected.csv"));
 writetable(study.baseline{j}.timeSeries,fullfile(outputFolder,s.name+"_baseline.csv"));
 fprintf('Phase3 %d/%d: %s\n',j,n,s.name);
end
study.metrics=struct2table(vertcat(rows{:}));study.events=vertcat(events{:});
writetable(study.metrics,fullfile(outputFolder,'phase3_metrics.csv'));
writetable(study.events,fullfile(outputFolder,'phase3_transitions.csv'));
fid=fopen(fullfile(outputFolder,'phase3_configuration_and_scenarios.json'),'w');
assert(fid>=0,'Cannot write configuration manifest.');cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(struct('configuration',cfg,'scenarios',cases),'PrettyPrint',true));clear cleanup
save(fullfile(outputFolder,'phase3_study.mat'),'study','-v7');
m=study.metrics;assert(all(m.FiniteStateAndCommand&m.CommandBoundsPass&m.StoppedCommandIsZero),'EMIProject:Phase3CampaignFailed','Finite records, voltage bounds or stop command failed.');
assert(all(m.FalseAlarmEpisodes(m.Expectation=="clean")==0),'EMIProject:Phase3CampaignFailed','Nuisance response in a declared clean fixture.');
assert(all(m.DetectionStatus(m.Expectation=="detect")=="detected"),'EMIProject:Phase3CampaignFailed','Required detection fixture missed.');
assert(m.DetectionStatus(m.Scenario=="freeze_at_rest")=="missed",'EMIProject:Phase3CampaignFailed','Stationary freeze must remain explicitly unobservable.');
study.accepted=true;
write_run_manifest(outputFolder,fileparts(fileparts(mfilename('fullpath'))),struct('workflow',"phase3_prototype",'pairedCases',n,'simulations',4*n,'physicalValidation',false));
save(fullfile(outputFolder,'phase3_study.mat'),'study','-v7');
end
