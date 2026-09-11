function study=run_phase3_motion_study(outputFolder)
%RUN_PHASE3_MOTION_STUDY Fixed optional shaping policy and new motion cases.
% Preserves the requested task trajectory and every nonreference fixture.
arguments
 outputFolder (1,1) string
end
require_empty_phase3_output_folder(outputFolder);
if ~isfolder(outputFolder),mkdir(outputFolder);end
fixtures=phase3_motion_fixtures();
options=struct('maxVelocity_rad_s',10,'maxAcceleration_rad_s2',200,'positionLimit_rad',deg2rad(120));
policies=["RAW","GOVERNED"];
plan=struct('id',"PHASE3-MOTION-STUDY-V1",'fixtures',fixtures,'options',options,'policies',policies, ...
 'selectionRule',"One analytically bounded policy declared before data; no parameter search or evaluation-driven retuning.", ...
 'controller',"Historical Phase 3 normal/degraded PIDF, caps, slew, observer thresholds and reset/latch rules unchanged.", ...
 'initialization',"Governor starts at the declared observer initial position with zero reference velocity. t=0 has no elapsed update.", ...
 'referenceContract',"Requested position admission +/-120 deg; shaped finite-difference speed<=10 rad/s and acceleration<=200 rad/s^2. These are reference bounds, not plant-speed or stop/hold guarantees.", ...
 'cleanGates',"No alarms/non-normal samples; actual speed<=20 rad/s; received source-time candidate rate<=25 rad/s; final requested error and last-0.1-second requested RMSE<=0.5 deg.", ...
 'faultGates',"Require the declared new alarm or stop response after exposure and by its fixed deadline, plus declared stop/reset-release requirements. Preexisting response earns no detection credit.", ...
 'diagnostics',"Unknown model/load cases retain results without a clean/recovery performance claim. All records require finite command, bounds, stopped-zero and reset-evidence invariants.", ...
 'defaultsChanged',false,'physicalValidation',false);
writeJson(fullfile(outputFolder,'frozen_design.json'),plan);
save(fullfile(outputFolder,'frozen_design.mat'),'plan','-v7');
mkdir(fullfile(outputFolder,'design_source_identity'));
write_run_manifest(fullfile(outputFolder,'design_source_identity'),fileparts(fileparts(mfilename('fullpath'))), ...
 struct('workflow',"frozen_motion_envelope_design",'beforeCampaign',true));
study.plan=plan;study.results=cell(numel(fixtures),2);study.metrics=table();study.cleanMetrics=table();
identityRows=cell(numel(fixtures),1);
for k=1:numel(fixtures)
 fixture=fixtures(k);p=fixture.params;s=fixture.scenario;cfg=phase3_configuration(p);
 clean=phase3_matched_clean_scenario(s,p);
 raw=phase3_fault_profiles(p,s);rawClean=phase3_fault_profiles(p,clean);
 [governed,trace]=phase3_motion_profiles(p,s,cfg,options);
 [governedClean,cleanTrace]=phase3_motion_profiles(p,clean,cfg,options);
 nonReferenceExact=unchangedExceptReference(raw,governed)&&unchangedExceptReference(rawClean,governedClean);
 sharedReference=isequal(trace,cleanTrace);
 raw=addRawMotion(raw,governed.motionConfiguration);
 rawClean=addRawMotion(rawClean,governedClean.motionConfiguration);
 profilePairs={{raw,rawClean},{governed,governedClean}};
 for j=1:2
  pair=profilePairs{j};
  record.fault=simulate_phase3_actuator(p,s,true,cfg,pair{1});
  record.clean=simulate_phase3_actuator(p,clean,true,cfg,pair{2});
  record.metrics=phase3_motion_metrics(record.fault,record.clean,fixture,policies(j));
  cleanFixture=fixture;cleanFixture.id=fixture.id+"_matched_clean";
  cleanFixture.kind="diagnostic";cleanFixture.responseKind="none";cleanFixture.alarmDeadline_s=NaN;
  cleanFixture.requireStop=false;cleanFixture.requireResetRelease=false;
  record.cleanMetrics=phase3_motion_metrics(record.clean,record.clean,cleanFixture,policies(j));
  record.trace=pair{1}.motionTrace;record.fixture=fixture;record.policy=policies(j);
  record.nonReferenceProfilesExact=nonReferenceExact;record.matchedShapingExact=sharedReference;
  folder=fullfile(outputFolder,fixture.partition,policies(j),fixture.id);
  mkdir(folder);
  a=record.fault.timeSeries;a.requestedReference_rad=pair{1}.requestedReference_rad;
  b=record.clean.timeSeries;b.requestedReference_rad=pair{2}.requestedReference_rad;
  writetable(a,fullfile(folder,'response.csv'));
  writetable(b,fullfile(folder,'matched_clean_response.csv'));
  writetable(record.trace,fullfile(folder,'motion_trace.csv'));
  save(fullfile(folder,'paired_run.mat'),'record','-v7');
  study.results{k,j}=record;
  study.metrics=[study.metrics;struct2table(record.metrics)]; %#ok<AGROW>
  study.cleanMetrics=[study.cleanMetrics;struct2table(record.cleanMetrics)]; %#ok<AGROW>
 end
 sameConfiguration=isequaln(study.results{k,1}.fault.run.configuration,study.results{k,2}.fault.run.configuration);
 identityRows{k}=struct('Fixture',fixture.id,'NonReferenceProfilesExact',nonReferenceExact, ...
  'FaultCleanShapingExact',sharedReference,'ControllerObserverConfigurationExact',sameConfiguration);
 writetable(study.metrics,fullfile(outputFolder,'motion_metrics.csv'));
 writetable(study.cleanMetrics,fullfile(outputFolder,'matched_clean_metrics.csv'));
 fprintf('Motion envelope: %d/%d fixtures complete (%s).\n',k,numel(fixtures),fixture.id);
end
study.identity=struct2table(vertcat(identityRows{:}));
writetable(study.identity,fullfile(outputFolder,'profile_and_configuration_identity.csv'));
% Reproduce the original noisy-reversal rejection without relabelling it.
matlabRoot=fileparts(fileparts(mfilename('fullpath')));
previousPath=fullfile(matlabRoot,'results','development','phase3_tuning_20260910_141100', ...
 'campaign','evaluation','G050_F050','eval_benign_noise_reversal','paired_run.mat');
study.historicalRegressionApplicable=isfile(previousPath);
study.historicalRegressionExact=true;
if study.historicalRegressionApplicable
 prior=load(previousPath,'record');now=study.results{1,1}.fault;
 study.historicalRegressionExact=isequaln(prior.record.fault.time_s,now.time_s)&& ...
  isequaln(prior.record.fault.state,now.state)&&isequaln(prior.record.fault.timeSeries,now.timeSeries);
end
writeJson(fullfile(outputFolder,'historical_reversal_regression.json'),struct( ...
 'applicable',study.historicalRegressionApplicable,'exact',study.historicalRegressionExact,'priorEvidence',string(previousPath)));
governed=study.metrics(study.metrics.Policy=="GOVERNED",:);
required=governed.BehaviorApplicable;
study.totalNumericalRuns=4*numel(fixtures);
study.executionInvariantsPassed=all(study.metrics.CommandInvariantsPass)&&all(study.cleanMetrics.CommandInvariantsPass)&& ...
 all(governed.ReferenceBoundsPass)&&all(study.identity.NonReferenceProfilesExact)&& ...
 all(study.identity.FaultCleanShapingExact)&&all(study.identity.ControllerObserverConfigurationExact)&& ...
 study.historicalRegressionExact;
study.declaredBehaviorPassed=all(governed.DeclaredBehaviorPass(required));
study.accepted=study.executionInvariantsPassed&&study.declaredBehaviorPassed;
study.defaultsChanged=false;
study.recommendation="retain_optional_motion_profile_and_record_failed_requirements";
if study.accepted,study.recommendation="optional_motion_profile_meets_declared_numerical_cases";end
save(fullfile(outputFolder,'phase3_motion_study.mat'),'study','-v7');
decision=struct('accepted',study.accepted,'executionInvariantsPassed',study.executionInvariantsPassed, ...
 'declaredBehaviorPassed',study.declaredBehaviorPassed,'requiredBehaviorCases',nnz(required), ...
 'passedBehaviorCases',nnz(governed.DeclaredBehaviorPass(required)), ...
 'numericalRuns',study.totalNumericalRuns,'historicalRegressionApplicable',study.historicalRegressionApplicable, ...
 'historicalRegressionExact',study.historicalRegressionExact,'recommendation',study.recommendation, ...
 'defaultsChanged',false,'physicalValidation',false);
writeJson(fullfile(outputFolder,'decision.json'),decision);
write_run_manifest(outputFolder,matlabRoot,struct('workflow',"fixed_motion_envelope_evaluation", ...
 'numericalRuns',study.totalNumericalRuns,'studyAccepted',study.accepted,'defaultsChanged',false,'physicalValidation',false));
fprintf('Motion study complete: %d numerical runs; declared acceptance=%d.\n',study.totalNumericalRuns,study.accepted);
end

function f=addRawMotion(f,cfg)
f.requestedReference_rad=f.reference_rad;f.motionGoverned=false;f.motionConfiguration=cfg;
n=numel(f.time_s);v=[0;diff(f.reference_rad)/cfg.sampleTime_s];a=[0;diff(v)/cfg.sampleTime_s];
f.motionTrace=table(f.time_s,f.reference_rad,f.reference_rad,f.reference_rad,v,a, ...
 'VariableNames',{'Time_s','Requested_rad','SlewReference_rad','ShapedReference_rad','Velocity_rad_s','Acceleration_rad_s2'});
assert(height(f.motionTrace)==n);
end

function same=unchangedExceptReference(original,shaped)
names=fieldnames(original);names(strcmp(names,'reference_rad'))=[];same=true;
for k=1:numel(names),same=same&&isfield(shaped,names{k})&&isequaln(original.(names{k}),shaped.(names{k}));end
end

function writeJson(path,value)
fid=fopen(path,'w');assert(fid>=0,'EMIProject:MotionOutput','Cannot write study evidence.');
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
