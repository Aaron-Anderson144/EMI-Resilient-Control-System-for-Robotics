function result = run_verification(sourceRun,correctionRun,diagnosticRun,outputRoot)
%RUN_VERIFICATION Test the code and reproduce saved research evidence.
% Repeats existing seeds to verify reproducibility, not new generalization.
% Separate output roots preserve all original models and latest pointers.
root=fileparts(mfilename('fullpath'));
if nargin<1 || strlength(string(sourceRun))==0
    sourceRun=localLatest(fullfile(root,'results'),'latest_run.json');
end
if nargin<2 || strlength(string(correctionRun))==0
    correctionRun=localLatest(fullfile(root,'results','correction_studies'),'latest_correction_study.json');
end
if nargin<3 || strlength(string(diagnosticRun))==0
    diagnosticRun=localLatest(fullfile(root,'results','diagnostics'),'latest_diagnostics.json');
end
if nargin<4,outputRoot=fullfile(root,'results','verifications');end
oldPath=path;restore=onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(fullfile(root,'code'),fullfile(root,'tests'));
if ~isfolder(outputRoot),mkdir(outputRoot);end
runDir=tempname(outputRoot);mkdir(runDir);
fprintf('VERIFICATION_OUTPUT %s\n',runDir);
checks=table('Size',[0,3],'VariableTypes',{'string','logical','string'}, ...
    'VariableNames',{'check','passed','detail'});
pointer=fileread(fullfile(root,'results','latest_run.json'));
originalPlan=jsondecode(fileread(fullfile(sourceRun,'study_plan.json')));
correctionPlan=jsondecode(fileread(fullfile(correctionRun,'study_plan.json')));
plan=struct('schema','hybrid-verification-v1','sourceRun',string(sourceRun), ...
    'correctionRun',string(correctionRun),'diagnosticRun',string(diagnosticRun), ...
    'createdLocal',char(datetime('now')), ...
    'scope','Code verification and reproduction of already examined simulated forecasts; no new unseen test, hardware, receiver-fault or closed-loop validation.', ...
    'tableAbsoluteTolerance',1e-12,'tableRelativeTolerance',1e-10, ...
    'modelAbsoluteTolerance',1e-12,'modelRelativeTolerance',1e-10);
hybrid_write_json(fullfile(runDir,'verification_plan.json'),plan);
writetable(localSourceSnapshot(root),fullfile(runDir,'source_hashes.csv'));
unitResults=runtests(fullfile(root,'tests'));
writetable(table(unitResults),fullfile(runDir,'test_results.csv'));
record("automated_tests",all([unitResults.Passed]),sprintf('%d tests; %d passed.', ...
    numel(unitResults),sum([unitResults.Passed])));

dev=load(fullfile(sourceRun,'development_records.mat'),'training','validation');
held=load(fullfile(sourceRun,'test_records.mat'),'test');
fresh=load(fullfile(correctionRun,'test_records.mat'),'test');
localSeeds(dev.training,originalPlan.trainingSeeds);
localSeeds(dev.validation,originalPlan.validationSeeds);
localSeeds(held.test,originalPlan.testSeeds);
newSeeds=[correctionPlan.coreTestSeeds(:);correctionPlan.transientSeeds(:);correctionPlan.changedControllerSeeds(:)];
localSeeds(fresh.test,newSeeds);
records=[dev.training,dev.validation,held.test,fresh.test];
seeds=cellfun(@(r)r.seed,records);
record("disjoint_splits",numel(unique(seeds))==numel(seeds), ...
    sprintf('%d distinct planned seeds across all four splits.',numel(seeds)));
duplicates=false;
for a=1:numel(records)
    for b=1:a-1
        duplicates=duplicates || (isequal(records{a}.y,records{b}.y)&&isequal(records{a}.u,records{b}.u));
    end
end
record("distinct_measured_trajectories",~duplicates,"No identical measurement/input record across splits.");
candidate=readtable(fullfile(sourceRun,'validation_candidates.csv'));
frozen=jsondecode(fileread(fullfile(sourceRun,'selection_frozen.json')));
for degree=1:2
    eligible=find(candidate.degree==degree);[~,minimum]=min(candidate.validation50msRMSE_rad(eligible));
    record("original_selection_degree_"+degree, ...
        frozen.selectedCandidateIds(degree)==candidate.candidateId(eligible(minimum)), ...
        "Stored candidate is the minimum validation loss in its degree family.");
end
record("selection_order_recorded",frozen.selectionCompleteBeforeTestGeneration, ...
    "Recorded execution order agrees with reviewed runner; not independent preregistration.");

% The original runner repeats all 18 fits and validation scores, then its
% 40 original evaluation trajectories, within this verification directory.
reproduced=run_experiment(fullfile(runDir,'reproduced_original'));
repeatSource=char(reproduced.outputDirectory);
localCompareTables(fullfile(sourceRun,'validation_candidates.csv'), ...
    fullfile(repeatSource,'validation_candidates.csv'),{'candidateId'},{'fitAndScoreSeconds'});
localCompareTables(fullfile(sourceRun,'selected_models.csv'), ...
    fullfile(repeatSource,'selected_models.csv'),{'candidateId'},{'fitAndScoreSeconds'});
oldModels=load(fullfile(sourceRun,'selected_models.mat'),'models','names');
newModels=load(fullfile(repeatSource,'selected_models.mat'),'models','names');
localEqual(oldModels,newModels,"refitted_models");
record("refit_and_validation_reproduction",true,"All 18 validation candidates and both selected fits reproduce.");
newDev=load(fullfile(repeatSource,'development_records.mat'),'training','validation');
newHeld=load(fullfile(repeatSource,'test_records.mat'),'test');
localRecordsEqual([dev.training,dev.validation,held.test],[newDev.training,newDev.validation,newHeld.test]);
record("original_data_reproduction",true,"All 76 original measured inputs, outputs, times and true states reproduce.");
localCompareTables(fullfile(sourceRun,'forecast_per_run.csv'),fullfile(repeatSource,'forecast_per_run.csv'), ...
    {'modelName','regime','runName','horizonSamples'},{});
localCompareTables(fullfile(sourceRun,'forecast_summary.csv'),fullfile(repeatSource,'forecast_summary.csv'), ...
    {'modelName','regime','horizonSamples'},{});
localCompareTables(fullfile(sourceRun,'paired_comparisons_50ms.csv'),fullfile(repeatSource,'paired_comparisons_50ms.csv'), ...
    {'regime','baseline'},{});
originalBenefit=jsondecode(fileread(fullfile(sourceRun,'benefit_screen.json')));
repeatedBenefit=jsondecode(fileread(fullfile(repeatSource,'benefit_screen.json')));
localEqual(originalBenefit,repeatedBenefit,"benefit_screen");
record("original_forecast_and_benefit_reproduction",true,"Forecasts, paired bootstrap comparisons and the negative EDMD benefit screen reproduce.");

% Reproduce the selected causal rule and every saved diagnostic table. All
% repeated seeds retain their original development/evaluation status.
repeatedCorrection=run_correction_study(sourceRun,fullfile(runDir,'reproduced_correction'));
repeatCorrection=char(repeatedCorrection.outputDirectory);
localCompareTables(fullfile(correctionRun,'validation_candidates.csv'), ...
    fullfile(repeatCorrection,'validation_candidates.csv'),{'baseModel','candidateId'},{});
oldWeighted=load(fullfile(correctionRun,'selected_models.mat'),'models','names','selection');
newWeighted=load(fullfile(repeatCorrection,'selected_models.mat'),'models','names','selection');
localEqual(oldWeighted,newWeighted,"weighted_models_and_policies");
policyCandidates=readtable(fullfile(correctionRun,'validation_candidates.csv'),'TextType','string');
for k=1:numel(oldWeighted.selection)
    selection=oldWeighted.selection(k);
    rows=policyCandidates(policyCandidates.baseModel==selection.baseModel,:);
    eligibility=isfinite(rows.validationRMSE_rad)&rows.nominalValidationRMSE_rad<=rows.nominalLimit_rad;
    assert(isequal(eligibility,logical(rows.eligible)),'HybridVerification:Eligibility','Stored eligibility is inconsistent.');
    rows=rows(eligibility,:);[~,j]=min(rows.validationRMSE_rad);
    assert(selection.candidateId==rows.candidateId(j),'HybridVerification:Selection','Wrong eligible policy selected.');
end
record("correction_selection_reproduction",true,"All 20 candidate scores, eligibility and both minimum-loss eligible policies reproduce.");
newFresh=load(fullfile(repeatCorrection,'test_records.mat'),'test');
localRecordsEqual(fresh.test,newFresh.test);
correctionFiles={
    'forecast_per_run.csv',{'modelName','regime','runName','horizonSamples'};
    'forecast_summary.csv',{'modelName','regime','horizonSamples'};
    'forecast_endpoints.csv',{'modelName','regime','runName','horizonSamples','originIndex'};
    'event_per_run.csv',{'modelName','regime','runName','horizonSamples','eventGroup'};
    'event_summary.csv',{'modelName','regime','horizonSamples','eventGroup'};
    'paired_comparisons.csv',{'modelName','baseline','regime','runName','horizonSamples','eventGroup'};
    'weight_usage.csv',{'modelName','regime'}};
for k=1:size(correctionFiles,1)
    localCompareTables(fullfile(correctionRun,correctionFiles{k,1}), ...
        fullfile(repeatCorrection,correctionFiles{k,1}),correctionFiles{k,2},{});
end
record("correction_evidence_reproduction",true,"All 52 additional records, 199680 endpoints, events, paired comparisons and weight usage reproduce.");
repeatedDiagnostic=run_diagnostics(sourceRun,fullfile(runDir,'reproduced_diagnostics'));
repeatDiagnostic=char(repeatedDiagnostic.outputDirectory);
diagnosticFiles={
    'forecast_endpoints.csv',{'modelName','regime','runName','horizonSamples','originIndex'};
    'event_per_run.csv',{'modelName','regime','runName','horizonSamples','eventGroup'};
    'event_summary.csv',{'modelName','regime','horizonSamples','eventGroup'};
    'event_paired_comparisons.csv',{'modelName','baseline','regime','runName','horizonSamples','eventGroup'};
    'model_diagnostics.csv',{'modelName'};
    'singular_spectrum.csv',{'modelName','singularIndex'};
    'lifted_rollout_diagnostics.csv',{'modelName','regime','runName','horizonSamples','rowScope'}};
for k=1:size(diagnosticFiles,1)
    localCompareTables(fullfile(diagnosticRun,diagnosticFiles{k,1}), ...
        fullfile(repeatDiagnostic,diagnosticFiles{k,1}),diagnosticFiles{k,2},{});
end
record("diagnostic_evidence_reproduction",true,"All 102400 diagnostic endpoints and saved event, spectral and lifted-rollout tables reproduce.");
record("original_default_preserved",strcmp(pointer,fileread(fullfile(root,'results','latest_run.json'))), ...
    "The original experiment/replay pointer is unchanged.");
result=struct('schema',plan.schema,'outputDirectory',string(runDir), ...
    'verificationPassed',all(checks.passed),'automatedTests',numel(unitResults), ...
    'passedTests',sum([unitResults.Passed]),'checksPassed',height(checks), ...
    'distinctRecordedTrajectories',numel(records), ...
    'originalReproduction',string(repeatSource),'correctionReproduction',string(repeatCorrection), ...
    'diagnosticReproduction',string(repeatDiagnostic), ...
    'edmdBenefitScreen',originalBenefit, ...
    'hardwareValidation',"not established",'closedLoopValidation',"not established", ...
    'scope',plan.scope,'completedLocal',char(datetime('now')));
hybrid_write_json(fullfile(runDir,'execution.json'),result);
[~,folder]=fileparts(runDir);
hybrid_write_json(fullfile(outputRoot,'latest_verification.json'),struct('folder',string(folder)));
fprintf('VERIFICATION_COMPLETE: %d tests; %d audit stages; EDMD benefit all-regime pass=%d.\n', ...
    result.passedTests,result.checksPassed,originalBenefit.allRegimesPass);

    function record(name,passed,detail)
        checks=[checks;table(string(name),logical(passed),string(detail), ...
            'VariableNames',checks.Properties.VariableNames)]; %#ok<AGROW>
        writetable(checks,fullfile(runDir,'verification_checks.csv'));
        assert(passed,'HybridVerification:Check','Verification failed: %s',name);
    end
end

function folder=localLatest(root,file)
pointer=jsondecode(fileread(fullfile(root,file)));folder=fullfile(root,pointer.folder);
end

function localSeeds(records,expected)
actual=cellfun(@(r)r.seed,records);
assert(isequal(sort(actual(:)),sort(expected(:))),'HybridVerification:Seeds','Record seeds differ from plan.');
end

function localRecordsEqual(old,new)
assert(numel(old)==numel(new),'HybridVerification:Records','Record coverage changed.');
for k=1:numel(old)
    for field=["y","u","t","truth","seed","sampleTime","regime","offlineLoadTorque_Nm"]
        localEqual(old{k}.(field),new{k}.(field),"record_"+k+"_"+field);
    end
end
end

function localCompareTables(oldPath,newPath,keys,ignored)
a=readtable(oldPath,'TextType','string');b=readtable(newPath,'TextType','string');
a(:,ignored)=[];b(:,ignored)=[];
assert(isequal(a.Properties.VariableNames,b.Properties.VariableNames), ...
    'HybridVerification:Columns','Columns differ for %s.',oldPath);
a=sortrows(a,keys);b=sortrows(b,keys);
assert(height(a)==height(b),'HybridVerification:Rows','Row count differs for %s.',oldPath);
for name=string(a.Properties.VariableNames)
    localEqual(a.(name),b.(name),string(oldPath)+"_"+name);
end
end

function localEqual(a,b,label)
assert(isequal(size(a),size(b)),'HybridVerification:Shape','Shape differs: %s',label);
if isnumeric(a)||islogical(a)
    assert(isnumeric(b)||islogical(b),'HybridVerification:Type','Type differs: %s',label);
    equal=(a==b)|(isnan(a)&isnan(b))| ...
        (isfinite(a)&isfinite(b)&abs(double(a)-double(b))<=1e-12+1e-10*abs(double(a)));
    assert(all(equal,'all'),'HybridVerification:Numeric','Numeric values differ: %s',label);
elseif iscell(a)
    for k=1:numel(a),localEqual(a{k},b{k},label+"_cell_"+k);end
elseif isstruct(a)
    assert(isequal(sort(fieldnames(a)),sort(fieldnames(b))),'HybridVerification:Fields','Fields differ: %s',label);
    for k=1:numel(a)
        for name=string(fieldnames(a))'
            localEqual(a(k).(name),b(k).(name),label+"_"+name);
        end
    end
else
    assert(isequaln(a,b),'HybridVerification:Value','Values differ: %s',label);
end
end

function snapshot=localSourceSnapshot(root)
files=[dir(fullfile(root,'*.m'));dir(fullfile(root,'code','*.m'));dir(fullfile(root,'tests','*.m')); ...
    dir(fullfile(root,'reference_project','03_MATLAB','functions','*.m')); ...
    dir(fullfile(root,'reference_project','03_MATLAB','parameters','*.m'))];
paths=strings(numel(files),1);sha256=paths;
for k=1:numel(files)
    absolute=fullfile(files(k).folder,files(k).name);
    paths(k)=string(absolute(numel(root)+2:end));
    fid=fopen(absolute,'rb');assert(fid>=0,'HybridVerification:Source','Cannot read source.');
    cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,Inf,'*uint8');
    digest=java.security.MessageDigest.getInstance('SHA-256');
    digest.update(typecast(bytes,'int8'));sha256(k)=string(sprintf('%02x',typecast(digest.digest(),'uint8')));
    clear cleanup
end
snapshot=table(paths,sha256,'VariableNames',{'path','sha256'});
end
