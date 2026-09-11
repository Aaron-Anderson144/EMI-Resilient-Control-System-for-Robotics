function validation=validate_phase3_tuning_study(study,outputFolder)
%VALIDATE_PHASE3_TUNING_STUDY Exercise selected settings in independent plant.
% Fixed coverage rule: all 12 selected evaluation cases, original tuning
% freeze, three historical evaluation counterparts, both no-extra-limit
% stress cases, and the two single-limit ablations of evaluation stress.
if ~isfolder(outputFolder),mkdir(outputFolder);end
runs={};labels=struct('RunIndex',{},'Fixture',{},'Policy',{},'Purpose',{});
for k=1:size(study.evaluationResults,1)
 append(study.evaluationResults{k,2},"selected evaluation");
end
selected=study.selection.selectedIndex;
append(study.tuningResults{1,selected},"selected original motion freeze");
for k=[1,10,11]
 append(study.evaluationResults{k,1},"historical counterpart");
end
for k=1:2
 append(study.limiterResults{k,4},"both extra limits removed");
end
for j=[2,3]
 append(study.limiterResults{2,j},"single-limit ablation");
end
writetable(struct2table(labels),fullfile(outputFolder,'tuning_simulink_run_index.csv'));
validation=validate_phase3_simulink(runs,outputFolder);
 function append(record,purpose)
  runs{end+1,1}=record.fault;
  labels(end+1)=struct('RunIndex',numel(runs),'Fixture',record.metrics.Fixture, ...
   'Policy',record.metrics.Policy,'Purpose',purpose);
 end
end
