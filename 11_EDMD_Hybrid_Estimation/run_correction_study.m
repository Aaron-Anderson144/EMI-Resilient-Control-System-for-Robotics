function result = run_correction_study(sourceRun,outputRoot)
%RUN_CORRECTION_STUDY Validate a causal weighting rule, then test fresh runs.
% Frozen original predictors are not retrained. No motor commands are sent.
root=fileparts(mfilename('fullpath'));
if nargin<1 || strlength(string(sourceRun))==0
    latest=jsondecode(fileread(fullfile(root,'results','latest_run.json')));
    sourceRun=fullfile(root,'results',latest.folder);
end
if nargin<2,outputRoot=fullfile(root,'results','correction_studies');end
oldPath=path;restore=onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(fullfile(root,'code'));
source=load(fullfile(sourceRun,'selected_models.mat'),'models','names');
development=load(fullfile(sourceRun,'development_records.mat'),'validation');
assert(numel(source.models)==4,'HybridCorrection:Source','Expected the original four-way benchmark.');
if ~isfolder(outputRoot),mkdir(outputRoot);end
runDir=tempname(outputRoot);mkdir(runDir);fprintf('CORRECTION_STUDY_OUTPUT %s\n',runDir);
plan=struct('schema','hybrid-correction-study-v1','sourceRun',string(sourceRun), ...
    'createdLocal',char(datetime('now')),'lookbackWindows',[20,100,250], ...
    'minimumImprovements',[0,.1,.25],'allowedWeights',[0,.25,.5,1], ...
    'domainMargin',.1,'alwaysOffCandidate',true,'warmupSeconds',.2,'originStride',20, ...
    'selectionHorizonSamples',50,'testHorizonsSamples',[1,20,50,100,250], ...
    'nominalAllowance_counts',.1,'encoderCountsPerRevolution',4096, ...
    'selection','Minimum equal-trajectory validation 50 ms RMSE among candidates whose nominal mean RMSE is no more than physics plus 0.1 encoder count. Select separately for each frozen learned model.', ...
    'allowanceMeaning','A declared research screen, not an established robot requirement; report absolute nominal errors alongside it.', ...
    'gateInformation','Completed one-step innovation prediction errors through each origin and training-history ranges; no truth, regime labels, future innovations or future inputs.', ...
    'gateRollout','Weight fixed at origin; same weighted innovation updates forecast output and internal posterior.', ...
    'coreTestSeeds',[230101:230110,230201:230210,230301:230310,230401:230410], ...
    'coreTestRegimes',["nominal","varied","nonlinear","stress"], ...
    'transientSeeds',231101:231106,'changedControllerSeeds',231201:231206, ...
    'scope','Fresh hypothetical healthy-data tests conditional on recorded future voltage. Includes explicit load steps/reversals/controller change; no receiver faults, hardware or improved closed-loop-control claim.');
hybrid_write_json(fullfile(runDir,'study_plan.json'),plan);
[~,physicsValidation]=hybrid_score({[]},"Nominal physics",development.validation,50,20,.2);
nominalPhysics=mean(physicsValidation.truthRMSE(physicsValidation.regime=="nominal"));
nominalLimit=nominalPhysics+plan.nominalAllowance_counts*2*pi/plan.encoderCountsPerRevolution;
candidateRows=table;chosen=cell(1,2);selection=cell(1,2);
for m=1:2
    base=source.models{m+2};candidate=0;bestScore=Inf;
    policies={struct('windowSamples',20,'minRelativeImprovement',0,'weights',0,'domainMargin',.1)};
    for window=plan.lookbackWindows
        for improvement=plan.minimumImprovements
            policies{end+1}=struct('windowSamples',window,'minRelativeImprovement',improvement, ...
                'weights',plan.allowedWeights,'domainMargin',plan.domainMargin); %#ok<AGROW>
        end
    end
    for j=1:numel(policies)
        candidate=candidate+1;model=base;model.correctionPolicy=policies{j};
        [~,scores]=hybrid_score({model},"candidate",development.validation,50,20,.2);
        score=mean(scores.truthRMSE);nominal=mean(scores.truthRMSE(scores.regime=="nominal"));
        eligible=isfinite(score)&&nominal<=nominalLimit;
        row=table(string(source.names(m+2)),candidate,policies{j}.windowSamples, ...
            policies{j}.minRelativeImprovement,numel(policies{j}.weights)==1, ...
            score,nominal,nominalLimit,eligible,'VariableNames',{'baseModel','candidateId', ...
            'windowSamples','minRelativeImprovement','alwaysOff','validationRMSE_rad', ...
            'nominalValidationRMSE_rad','nominalLimit_rad','eligible'});
        candidateRows=[candidateRows;row]; %#ok<AGROW>
        if eligible&&score<bestScore
            bestScore=score;chosen{m}=model;
            selected=struct('baseModel',string(source.names(m+2)),'candidateId',candidate, ...
                'policy',policies{j},'validationRMSE_rad',score,'nominalValidationRMSE_rad',nominal);
        end
    end
    assert(~isempty(chosen{m}),'HybridCorrection:Selection','No eligible policy, including physics fallback.');
    selection{m}=selected;
    fprintf('Selected %s policy: window %d, improvement %.2f, validation %.6g deg.\n', ...
        selected.baseModel,selected.policy.windowSamples,selected.policy.minRelativeImprovement,rad2deg(bestScore));
end
selection=[selection{:}];
writetable(candidateRows,fullfile(runDir,'validation_candidates.csv'));
models=[source.models,chosen];names=[source.names,"Weighted linear hybrid","Weighted EDMD hybrid"];
save(fullfile(runDir,'selected_models.mat'),'models','names','selection');
hybrid_write_json(fullfile(runDir,'selection_frozen.json'),struct('selection',selection, ...
    'selectionCompleteBeforeTestGeneration',true,'nominalLimit_rad',nominalLimit,'timeLocal',char(datetime('now'))));
fprintf('CORRECTION_SELECTION_FROZEN. Generating fresh test trajectories.\n');
referenceRoot=fullfile(root,'reference_project');
[test,testMeta]=study_generate_records(referenceRoot,plan.coreTestSeeds,repelem(plan.coreTestRegimes,10),3);
scenario=struct('motionScenario',"smooth_reversal",'loadScenario',"step",'controllerGainScale',1);
[transient,transientMeta]=study_generate_records(referenceRoot,plan.transientSeeds,repmat("nonlinear",1,6),3,scenario);
scenario.controllerGainScale=.75;
[changed,changedMeta]=study_generate_records(referenceRoot,plan.changedControllerSeeds,repmat("stress",1,6),3,scenario);
for j=1:6
    transient{j}.regime="nonlinear_transient";changed{j}.regime="stress_changed_controller";
end
test=[test,transient,changed];
save(fullfile(runDir,'test_records.mat'),'test','testMeta','transientMeta','changedMeta','-v7.3');
[summary,perRun,endpoints]=hybrid_score(models,names,test,plan.testHorizonsSamples,20,.2);
writetable(summary,fullfile(runDir,'forecast_summary.csv'));
writetable(perRun,fullfile(runDir,'forecast_per_run.csv'));
writetable(endpoints,fullfile(runDir,'forecast_endpoints.csv'));
[events,eventRuns,paired]=hybrid_endpoint_summary(endpoints,["Nominal physics","Persistent innovation","Linear hybrid","Weighted linear hybrid"]);
writetable(events,fullfile(runDir,'event_summary.csv'));writetable(eventRuns,fullfile(runDir,'event_per_run.csv'));
writetable(paired,fullfile(runDir,'paired_comparisons.csv'));
weights=localWeightSummary(endpoints);writetable(weights,fullfile(runDir,'weight_usage.csv'));
result=struct('schema',plan.schema,'sourceRun',string(sourceRun),'outputDirectory',string(runDir), ...
    'selection',selection,'testRunCount',numel(test),'testEndpointCount',height(endpoints), ...
    'scope',plan.scope,'completedLocal',char(datetime('now')));
hybrid_write_json(fullfile(runDir,'execution.json'),result);
localReport(summary,weights,selection,plan,runDir);
[~,folder]=fileparts(runDir);
hybrid_write_json(fullfile(outputRoot,'latest_correction_study.json'),struct('folder',string(folder)));
fprintf('CORRECTION_STUDY_COMPLETE: %d fresh trajectories.\n',numel(test));
end

function out=localWeightSummary(endpoints)
rows=cell(0,1);j=0;
for name=["Weighted linear hybrid","Weighted EDMD hybrid"]
    group=endpoints(endpoints.modelName==name&endpoints.horizonSamples==50,:);
    for regime=unique(group.regime,'stable')'
        e=group(group.regime==regime,:);j=j+1;
        rows{j}=struct('modelName',name,'regime',regime,'originCount',height(e), ...
            'physicsFallbackFraction',mean(e.correctionWeight==0), ...
            'meanWeight',mean(e.correctionWeight),'learnedFailureCount',sum(e.learnedCandidateNonfinite)); %#ok<AGROW>
    end
end
out=struct2table(vertcat(rows{:}));
end

function localReport(summary,weights,selection,plan,folder)
fid=fopen(fullfile(folder,'Correction_Study_Report.md'),'w','n','UTF-8');
assert(fid>=0,'HybridCorrection:Report','Could not create report.');cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# Causal correction weighting study\n\n');
fprintf(fid,'The original learned models are frozen. A rule selected on development trajectories chooses a fixed rollout weight using completed one-step prediction errors and training-domain checks. Evaluation uses 52 fresh trajectories generated only after selection.\n\n');
for k=1:numel(selection)
    s=selection(k);fprintf(fid,'- %s: window %d samples, minimum past relative improvement %.2f, available weights %s.\n', ...
        s.baseModel,s.policy.windowSamples,s.policy.minRelativeImprovement,mat2str(s.policy.weights));
end
fprintf(fid,'\nSelection requires nominal validation RMSE within %.2f encoder count of physics, an explicit research allowance rather than an established robot requirement. This is not a guarantee on new cases.\n\n',plan.nominalAllowance_counts);
fprintf(fid,'## Fresh 50 ms results\n\n| Condition | Model | Mean trajectory RMSE (degrees) | Failed endpoints |\n|---|---|---:|---:|\n');
rows=summary(summary.horizonSamples==50,:);
for j=1:height(rows)
    fprintf(fid,'| %s | %s | %.6g | %d |\n',rows.regime(j),rows.modelName(j),rad2deg(rows.truthRMSE(j)),rows.nonfiniteForecastCount(j));
end
fprintf(fid,'\n## Correction use\n\n| Condition | Model | Physics-only origins (%%) | Mean correction weight |\n|---|---|---:|---:|\n');
for j=1:height(weights)
    fprintf(fid,'| %s | %s | %.2f | %.4f |\n',weights.regime(j),weights.modelName(j),100*weights.physicsFallbackFraction(j),weights.meanWeight(j));
end
fprintf(fid,'\nAll methods receive the same recorded future voltages and use healthy synchronous observations. Explicit load steps and reversals test transients; the changed-controller arm scales both acquisition-controller gains to 75%%. The original protection/controller implementation is not connected to this correction. No EMI receiver, missing-sample recovery, hardware or improved closed-loop-control result is established.\n\n');
fprintf(fid,'Use trajectory-level paired comparisons, not independent-sample claims from overlapping origins. Any subsequent tuning makes these test cases development evidence and requires new evaluation data.\n');
end
