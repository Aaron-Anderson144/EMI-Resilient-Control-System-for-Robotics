function study=run_phase3_tuning_study(outputFolder)
%RUN_PHASE3_TUNING_STUDY Frozen tuning grid, then separate candidate evaluation.
arguments
 outputFolder (1,1) string
end
require_empty_phase3_output_folder(outputFolder);
if ~isfolder(outputFolder),mkdir(outputFolder);end
fixtures=phase3_tuning_fixtures();criteria=phase3_tuning_criteria();
training=find(string({fixtures.partition})=="tuning");
evaluation=find(string({fixtures.partition})=="evaluation");
policies=struct('id',{},'options',{},'description',{});
for ratio=[.5,.75,1]
 for filter=[0,.02,.05]
  id=string(sprintf('G%03d_F%03d',round(100*ratio),round(1000*filter)));
  policies(end+1)=struct('id',id,'options',struct('degradedBandwidthRatio',ratio, ...
   'referenceTimeConstant_s',filter),'description', ...
   string(sprintf('%.0f%% degraded tuning target; %.0f ms degraded/recovery reference filter; historical caps and slew',100*ratio,1000*filter)));
 end
end
historical=find(string({policies.id})=="G050_F050");
plan=struct('id',"PHASE3-TUNING-STUDY-V1",'fixtures',fixtures,'policies',policies,'criteria',criteria, ...
 'historicalPolicy',policies(historical).id,'selectionRule', ...
 "Eligible candidates must pass every tuning gate and improve mean normalized window RMSE by at least 10%. Choose lowest score, then declaration order. If none qualifies, evaluate the lowest-score nonhistorical candidate diagnostically, without eligibility. Freeze choice before evaluation; no retuning using evaluation outcomes.", ...
 'limitsStudy',"Selected identical gains/filter with mode caps alone removed, slew alone relaxed, and both removed. Limit activity and response changes reported separately; these are diagnostic comparators, not promotion candidates.", ...
 'defaultsChanged',false,'physicalValidation',false);
writeJson(fullfile(outputFolder,'frozen_design.json'),plan);
save(fullfile(outputFolder,'frozen_design.mat'),'plan','-v7');
mkdir(fullfile(outputFolder,'design_source_identity'));
write_run_manifest(fullfile(outputFolder,'design_source_identity'),fileparts(fileparts(mfilename('fullpath'))), ...
 struct('workflow',"frozen_phase3_tuning_design",'beforeCandidateRuns',true));
study.plan=plan;study.tuningResults=cell(numel(training),numel(policies));
study.tuningMetrics=table();
for j=1:numel(policies)
 for k=1:numel(training)
  fixture=fixtures(training(k));
  record=runPair(fixture,policies(j),fullfile(outputFolder,'tuning'));
  study.tuningResults{k,j}=record;
  study.tuningMetrics=[study.tuningMetrics;struct2table(record.metrics)]; %#ok<AGROW>
 end
 writetable(study.tuningMetrics,fullfile(outputFolder,'tuning_metrics.csv'));
 fprintf('Tuning grid: %d/%d policies complete (%s).\n',j,numel(policies),policies(j).id);
end
assessments=cell(numel(policies),1);caseAssessments=cell(numel(policies),1);
base=study.tuningMetrics(study.tuningMetrics.Policy==policies(historical).id,:);
for j=1:numel(policies)
 candidate=study.tuningMetrics(study.tuningMetrics.Policy==policies(j).id,:);
 [assessments{j},caseAssessments{j}]=phase3_tuning_assess(candidate,base,criteria);
 caseAssessments{j}.Policy=repmat(policies(j).id,height(candidate),1);
end
study.tuningAssessment=struct2table(vertcat(assessments{:}));
study.tuningCaseAssessment=vertcat(caseAssessments{:});
writetable(study.tuningAssessment,fullfile(outputFolder,'tuning_assessment.csv'));
writetable(study.tuningCaseAssessment,fullfile(outputFolder,'tuning_case_assessment.csv'));
eligible=find(study.tuningAssessment.Eligible);
if isempty(eligible)
 pool=setdiff((1:numel(policies))',historical,'stable');
 diagnosticOnly=true;
else
 pool=eligible;diagnosticOnly=false;
end
[~,order]=sort(study.tuningAssessment.TrackingScore(pool));selected=pool(order(1));
study.selection=struct('policy',policies(selected),'tuningAssessment',assessments{selected}, ...
 'diagnosticOnly',diagnosticOnly,'selectedIndex',selected,'historicalIndex',historical, ...
 'evaluationStarted',false,'defaultsChanged',false);
writeJson(fullfile(outputFolder,'frozen_selection.json'),study.selection);
save(fullfile(outputFolder,'tuning_checkpoint.mat'),'study','-v7');
fprintf('Frozen selection: %s; diagnostic-only=%d. Evaluation starts now.\n',policies(selected).id,diagnosticOnly);
noLimits=policies(selected);noLimits.id="NO_EXTRA_LIMITS";
noLimits.options.suspectedVoltageLimitScale=1;noLimits.options.degradedVoltageLimitScale=1;
noLimits.options.nonNormalSlewRate_V_s=10000;
noLimits.description="Selected gains/filter with mode caps removed and nonnormal slew relaxed; diagnostic only.";
evaluationPolicies=[policies(historical),policies(selected),noLimits];
study.evaluationPolicies=evaluationPolicies;
study.evaluationStarted=true;
study.evaluationResults=cell(numel(evaluation),3);study.evaluationMetrics=table();
for j=1:3
 for k=1:numel(evaluation)
  record=runPair(fixtures(evaluation(k)),evaluationPolicies(j),fullfile(outputFolder,'evaluation'));
  study.evaluationResults{k,j}=record;
  study.evaluationMetrics=[study.evaluationMetrics;struct2table(record.metrics)]; %#ok<AGROW>
 end
 writetable(study.evaluationMetrics,fullfile(outputFolder,'evaluation_metrics.csv'));
 fprintf('Separate evaluation: %d/3 policies complete (%s).\n',j,evaluationPolicies(j).id);
end
base=study.evaluationMetrics(study.evaluationMetrics.Policy==policies(historical).id,:);
candidate=study.evaluationMetrics(study.evaluationMetrics.Policy==policies(selected).id,:);
[study.evaluationAssessment,study.evaluationCaseAssessment]=phase3_tuning_assess(candidate,base,criteria);
writetable(struct2table(study.evaluationAssessment),fullfile(outputFolder,'evaluation_assessment.csv'));
writetable(study.evaluationCaseAssessment,fullfile(outputFolder,'evaluation_case_assessment.csv'));
% Limit-only comparisons cannot affect the already-frozen selection.
noMode=policies(selected);noMode.id="NO_MODE_CAP";
noMode.options.suspectedVoltageLimitScale=1;noMode.options.degradedVoltageLimitScale=1;
noSlew=policies(selected);noSlew.id="RELAXED_SLEW";noSlew.options.nonNormalSlewRate_V_s=10000;
limitPolicies=[policies(selected),noMode,noSlew,noLimits];
stressIds=["capped_reversal","eval_opposite_capped_reversal"];
study.limiterResults=cell(2,4);study.limiterMetrics=table();
newLimiterPairs=0;
for k=1:2
 fixture=fixtures(find(string({fixtures.id})==stressIds(k),1));
 for j=1:4
  if j==1&&k==1
   record=study.tuningResults{find(string({fixtures(training).id})==stressIds(k),1),selected};
  elseif j==1&&k==2
   record=study.evaluationResults{find(string({fixtures(evaluation).id})==stressIds(k),1),2};
  elseif j==4&&k==2
   record=study.evaluationResults{find(string({fixtures(evaluation).id})==stressIds(k),1),3};
  else
   record=runPair(fixture,limitPolicies(j),fullfile(outputFolder,'limiter_ablation'));newLimiterPairs=newLimiterPairs+1;
  end
  study.limiterResults{k,j}=record;
  study.limiterMetrics=[study.limiterMetrics;struct2table(record.metrics)]; %#ok<AGROW>
 end
end
writetable(study.limiterMetrics,fullfile(outputFolder,'limiter_metrics.csv'));
study.totalNumericalRuns=2*(numel(training)*numel(policies)+3*numel(evaluation)+newLimiterPairs);
study.candidateMeetsAllComparativeGates=~diagnosticOnly&&study.evaluationAssessment.Eligible;
study.defaultsChanged=false;
study.evaluationCompleted=true;
study.recommendation="retain_historical_default";
if study.candidateMeetsAllComparativeGates,study.recommendation="candidate_meets_declared_comparative_gates_for_further_evaluation";end
allMetrics=[study.tuningMetrics;study.evaluationMetrics;study.limiterMetrics];
study.executionAccepted=all(allMetrics.InvariantsPass);
save(fullfile(outputFolder,'phase3_tuning_study.mat'),'study','-v7');
writeJson(fullfile(outputFolder,'decision.json'),struct('selectedPolicy',policies(selected), ...
 'tuningAssessment',study.selection.tuningAssessment,'evaluationAssessment',study.evaluationAssessment, ...
 'recommendation',study.recommendation,'defaultsChanged',false,'totalNumericalRuns',study.totalNumericalRuns, ...
 'evaluationCompleted',study.evaluationCompleted, ...
 'executionAccepted',study.executionAccepted,'physicalValidation',false));
write_run_manifest(outputFolder,fileparts(fileparts(mfilename('fullpath'))), ...
 struct('workflow',"phase3_frozen_tuning_and_separate_evaluation",'numericalRuns',study.totalNumericalRuns, ...
 'defaultsChanged',false,'physicalValidation',false));
assert(study.executionAccepted,'EMIProject:TuningExecutionFailed','A declared execution/command/latch/clean invariant failed; evidence retained.');
fprintf('Tuning study complete: %d numerical runs; %s.\n',study.totalNumericalRuns,study.recommendation);
end

function record=runPair(fixture,policy,outputFolder)
p=fixture.params;s=fixture.scenario;
[cfg,exactPolicy]=phase3_tuning_configuration(p,policy.options);
cfg.reacquisitionEnabled=fixture.useIndependentReference;
f=phase3_fault_profiles(p,s);clean=phase3_matched_clean_scenario(s,p);cf=phase3_fault_profiles(p,clean);
if fixture.useIndependentReference
 f.independentReference=phase3_reference_profile(f.time_s,fixture.referenceOptions);
 cf.independentReference=phase3_reference_profile(cf.time_s,fixture.referenceOptions);
end
record.fault=simulate_phase3_actuator(p,s,true,cfg,f);
record.clean=simulate_phase3_actuator(p,clean,true,cfg,cf);
record.metrics=phase3_tuning_metrics(record.fault,record.clean,fixture,policy.id);
record.activity=phase3_control_activity(record.fault);record.fixture=fixture;record.policy=exactPolicy;
folder=fullfile(outputFolder,policy.id,fixture.id);if ~isfolder(folder),mkdir(folder);end
writetable(record.fault.timeSeries,fullfile(folder,'response.csv'));
writetable(record.clean.timeSeries,fullfile(folder,'matched_clean_response.csv'));
writetable(record.activity,fullfile(folder,'control_activity.csv'));
save(fullfile(folder,'paired_run.mat'),'record','-v7');
end

function writeJson(path,value)
fid=fopen(path,'w');assert(fid>=0,'EMIProject:TuningOutput','Cannot open study manifest.');
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
