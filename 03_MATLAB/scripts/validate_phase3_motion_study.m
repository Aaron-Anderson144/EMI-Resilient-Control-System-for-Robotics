function validation=validate_phase3_motion_study(study,outputFolder)
%VALIDATE_PHASE3_MOTION_STUDY All shaped cases plus both raw development cases.
if ~isfolder(outputFolder),mkdir(outputFolder);end
runs=cell(size(study.results,1)+2,1);rows=cell(size(runs));
for k=1:size(study.results,1)
 r=study.results{k,2};runs{k}=r.fault;
 rows{k}=struct('RunIndex',k,'Fixture',r.fixture.id,'Policy',r.policy);
end
for j=1:2
 k=size(study.results,1)+j;r=study.results{j,1};runs{k}=r.fault;
 rows{k}=struct('RunIndex',k,'Fixture',r.fixture.id,'Policy',r.policy);
end
writetable(struct2table(vertcat(rows{:})),fullfile(outputFolder,'motion_simulink_run_index.csv'));
validation=validate_phase3_simulink(runs,outputFolder);
end
