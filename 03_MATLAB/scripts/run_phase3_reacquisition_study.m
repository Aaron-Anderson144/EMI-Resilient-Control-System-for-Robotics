function study=run_phase3_reacquisition_study(outputFolder)
%RUN_PHASE3_REACQUISITION_STUDY Conditional independent-reference recovery.
arguments
 outputFolder (1,1) string
end
require_empty_phase3_output_folder(outputFolder);
if ~isfolder(outputFolder),mkdir(outputFolder);end
p=actuator_parameters();p.simulation.stopTime_s=3;
base=phase3_scenario("encoder_dropout",p);base.encoder=encoder_fault_scenario("dropout",p);
cfg=phase3_configuration(p);cfg.reacquisitionEnabled=true;
names=["original_no_reference","qualified_reference","no_explicit_request", ...
 "no_reset","reset_at_reanchor","missing_reference_sample","old_reference_timestamps", ...
 "reference_error_within_bound","understated_reference_noise","excess_reference_uncertainty", ...
 "persistent_primary_bias","loaded_moving_reference","unknown_load_reference", ...
 "undeclared_constant_reference_bias","delayed_returning_primary"];
n=numel(names);study.runs=cell(n,1);rows=cell(n,1);
for j=1:n
 s=base;s.name=names(j);options=struct();c=cfg;fp=p;
 switch names(j)
  case "original_no_reference",c.reacquisitionEnabled=false;
  case "no_explicit_request",options.requestTime_s=Inf;
  case "no_reset",s.resetRequestTime_s=Inf;
  case "reset_at_reanchor",s.resetRequestTime_s=1.5;
  case "old_reference_timestamps",options.timestampOffset_samples=-1;
  case "reference_error_within_bound"
   options.bias_rad=deg2rad(.002);options.noiseAmplitude_rad=deg2rad(.002);
  case "understated_reference_noise",options.noiseAmplitude_rad=deg2rad(.05);
  case "excess_reference_uncertainty",options.uncertainty_rad=deg2rad(.1);
  case "persistent_primary_bias"
   s.bias_rad=deg2rad(5);s.biasStartTime_s=1.0;s.biasStopTime_s=3.1;
  case {"loaded_moving_reference","unknown_load_reference"}
   s.encoder=encoder_fault_scenario("none",p);
   s.phase2b=phase2b_scenario("supply_interruption",p);
   s.loadTorque_Nm=.01;s.assumedLoadTorque_Nm=.01;
   if names(j)=="unknown_load_reference",s.assumedLoadTorque_Nm=0;end
  case "undeclared_constant_reference_bias",options.bias_rad=deg2rad(.8);
  case "delayed_returning_primary"
   fp.phase2b.communication.startTime_s=1.2;fp.phase2b.communication.stopTime_s=2.2;
   s.phase2b=phase2b_scenario("communication_delay",fp);
 end
 f=phase3_fault_profiles(fp,s);
 f.independentReference=phase3_reference_profile(f.time_s,options);
 if names(j)=="missing_reference_sample"
  [~,k]=min(abs(f.time_s-1.48));f.independentReference.sampleReceived(k)=false;
 end
 a=simulate_phase3_actuator(fp,s,true,c,f);study.runs{j}=a;t=a.timeSeries;
 commits=find(t.reacquisitionCommitted==1);commitTime=NaN;normalTime=NaN;maxAnchorError=NaN;
 if ~isempty(commits)
  commitTime=t.time_s(commits(1));
  maxAnchorError=max(abs(t.estimatedPosition_rad(commits)-t.position_rad(commits)));
  after=find(t.time_s>commitTime&t.mode==0,1);
  if ~isempty(after),normalTime=t.time_s(after);end
 end
 atRequest=find(t.reacquisitionRequest==1,1);requestReason="no_request";
 if ~isempty(atRequest),requestReason=t.reacquisitionReason(atRequest);end
 zeroStop=all(t.command_V(t.mode==4)==0);
 bounds=all(abs(t.command_V)<=t.commandLimit_V+1e-12);
 stoppedCommit=all(t.mode(commits)==4&t.command_V(commits)==0&t.credibleFresh(commits)==0&t.estimateUsable(commits)==0);
 rows{j}=struct('Scenario',names(j),'CommitCount',numel(commits),'CommitTime_s',commitTime, ...
  'FirstNormalAfterCommit_s',normalTime,'FinalMode',t.mode(end),'RequestReason',requestReason, ...
  'MaxPositionErrorAtCommit_rad',maxAnchorError,'StoppedCommandZero',zeroStop, ...
  'CommandBoundsPass',bounds,'CommitRemainsStopped',stoppedCommit, ...
  'TrackingRMSE_deg',rad2deg(sqrt(mean((t.position_rad-t.reference_rad).^2))), ...
  'FinalPosition_deg',rad2deg(t.position_rad(end)));
 writetable(t,fullfile(outputFolder,names(j)+".csv"));
 fprintf('Reacquisition %d/%d: %s, commits=%d, final mode=%d, request=%s\n', ...
  j,n,names(j),numel(commits),t.mode(end),requestReason);
end
study.summary=struct2table(vertcat(rows{:}));
writetable(study.summary,fullfile(outputFolder,'reacquisition_summary.csv'));
save(fullfile(outputFolder,'reacquisition_study.mat'),'study','-v7');
assert(all(study.summary.StoppedCommandZero&study.summary.CommandBoundsPass&study.summary.CommitRemainsStopped), ...
 'EMIProject:ReacquisitionCampaignFailed','Command or latch invariant failed.');
mustCommit=["qualified_reference","no_reset","reset_at_reanchor","reference_error_within_bound", ...
 "persistent_primary_bias","loaded_moving_reference","undeclared_constant_reference_bias","delayed_returning_primary"];
mustRefuse=["original_no_reference","no_explicit_request","missing_reference_sample", ...
 "old_reference_timestamps","understated_reference_noise","excess_reference_uncertainty","unknown_load_reference"];
assert(all(study.summary.CommitCount(ismember(names,mustCommit))==1), ...
 'EMIProject:ReacquisitionCampaignFailed','Expected reference reconstruction did not commit.');
assert(all(study.summary.CommitCount(ismember(names,mustRefuse))==0), ...
 'EMIProject:ReacquisitionCampaignFailed','An invalid/unrequested reference committed.');
remainStopped=["no_reset","reset_at_reanchor","persistent_primary_bias","undeclared_constant_reference_bias"];
assert(all(study.summary.FinalMode(ismember(names,remainStopped))==4), ...
 'EMIProject:ReacquisitionCampaignFailed','An unqualified reset released stop.');
recover=["qualified_reference","reference_error_within_bound","loaded_moving_reference","delayed_returning_primary"];
assert(all(study.summary.FinalMode(ismember(names,recover))==0), ...
 'EMIProject:ReacquisitionCampaignFailed','Expected separately reset recovery failed.');
study.accepted=true;
write_run_manifest(outputFolder,fileparts(fileparts(mfilename('fullpath'))), ...
 struct('workflow',"phase3_independent_reference_reacquisition",'numericalRuns',n, ...
 'independentSensor',"synthetic position with assumed deterministic bound", ...
 'physicalValidation',false,'unknownModelErrorCovered',false));
save(fullfile(outputFolder,'reacquisition_study.mat'),'study','-v7');
end
