function [modelSummary,singularSpectrum,rolloutSummary] = hybrid_model_diagnostics(models,names,records,horizons,stride,warmupSeconds)
%HYBRID_MODEL_DIAGNOSTICS Read-only fit and held-out rollout diagnostics.
% Defaults and common origins match hybrid_score. Empty baselines are skipped.
% modelSummary and singularSpectrum describe stored training fits, never a refit.
% rolloutSummary contains rowScope="run" and "trajectory_equal_weight" rows.
% One-step errors use held-out reference-observer innovations at common origins.
% Recursive consistency compares the propagated quadratic coordinates against
% a diagnostic re-lift of their decoded predicted base history. That re-lift is
% NEVER fed back into the forecast. No truth, future observation, or correction
% enters recursive prediction. Future supplied inputs retain hybrid_forecast's
% conditional-prediction meaning. Every failed origin remains in denominators.
% Spectra and algebraic consistency are not physical/closed-loop certificates.
arguments
    models (1,:) cell
    names (1,:) string
    records (1,:) cell
    horizons (1,:) double {mustBeInteger,mustBePositive} = [1,20,50,100,250]
    stride (1,1) double {mustBeInteger,mustBePositive} = 20
    warmupSeconds (1,1) double {mustBeFinite,mustBeNonnegative} = .2
end
assert(numel(models)==numel(names) && ~isempty(models) && ...
    numel(unique(names))==numel(names) && ~isempty(records), ...
    'HybridDiagnostics:Arguments','Provide unique named models and nonempty records.');
learned=find(~cellfun(@isempty,models));
modelRows=repmat(localModelRow(),0,1);spectrumRows=repmat(localSpectrumRow(),0,1);
rows=repmat(localRolloutRow(),0,1);delays=zeros(size(models));
for a=learned
    model=models{a};localValidateModel(model);delays(a)=model.delay;
    [description,spectrum]=localDescribe(model,names(a));
    modelRows(end+1,1)=description; %#ok<AGROW>
    spectrumRows=[spectrumRows;spectrum]; %#ok<AGROW>
end
modelSummary=struct2table(modelRows);singularSpectrum=struct2table(spectrumRows);
if isempty(learned),rolloutSummary=struct2table(rows);return;end
horizons=unique(horizons,'sorted');maxH=max(horizons);maxDelay=max(delays);
% Match hybrid_score and exclude every sample invalidated by preparation,
% including persistence's 20-sample history when that baseline is present.
historyMinimum=101+maxDelay;
if any(cellfun(@isempty,models) & names=="Persistent innovation")
    historyMinimum=max(historyMinimum,120);
end
for r=1:numel(records)
    rec=records{r};[trace,config]=hybrid_reference_observer(rec);
    u=double(rec.u(:));dt=rec.sampleTime;n=numel(u);
    first=max(historyMinimum,ceil(warmupSeconds/dt)+1);
    origins=first:stride:n-maxH;
    assert(~isempty(origins),'HybridDiagnostics:ShortRecord','No common forecast origins remain.');
    futureInputs=reshape(u(origins+(0:maxH-1)'),maxH,numel(origins));
    innovations=trace.innovation(:);innovationRecord=rec;innovationRecord.y=innovations;
    for a=learned
        model=models{a};d=model.delay;baseCount=2*d+1;
        pairs=edmd_snapshot_pairs({innovationRecord},d);
        [present,columns]=ismember(origins,pairs.sampleIndex);
        assert(all(present),'HybridDiagnostics:Origins','Common origins need valid snapshot pairs.');
        assert(abs(model.sampleTime-pairs.sampleTime)<max(1e-12,dt*1e-8), ...
            'HybridDiagnostics:SampleTime','Model and held-out sample times differ.');
        H=pairs.H(:,columns);target=edmd_lift(model,pairs.Hnext(:,columns));
        z=edmd_lift(model,H);
        oneStep=model.A*z+model.B*((pairs.U(columns)-model.inputMean)/model.inputScale);
        oneFailed=any(~isfinite(oneStep),1);
        liftedRelative=localRelativeError(oneStep(2:end,:),target(2:end,:),oneFailed);
        decoded=model.outputMean+model.C*oneStep;
        decodedFailed=oneFailed | ~isfinite(decoded);
        decodedRMSE=localRMSE(decoded-innovations(origins+1)',decodedFailed);
        outputScale=localField(model,'outputScale',model.historyScale(1));
        % Use the production forecast to classify combined physics/innovation
        % failures; this diagnostic recursion observes z without changing it.
        [~,forecastDiagnostic]=hybrid_forecast(config,trace.posterior(origins,:)', ...
            H(1:d+1,:),H(d+2:end,:),futureInputs,model,"learned");
        failed=false(1,numel(origins));
        for step=1:maxH
            z=model.A*z+model.B*((futureInputs(step,:)-model.inputMean)/model.inputScale);
            failed=failed | any(~isfinite(z),1) | forecastDiagnostic.nonfinite(step,:);
            if ~ismember(step,horizons),continue;end
            row=localRolloutRow();row.rowScope="run";row.modelName=names(a);
            row.runIndex=r;row.runName="run_"+r;
            if isfield(rec,'id'),row.runName=string(rec.id);end
            if isfield(rec,'regime'),row.regime=string(rec.regime);end
            if isfield(rec,'seed'),row.seed=rec.seed;end
            row.horizonSamples=step;row.horizonSeconds=step*dt;row.runCount=1;
            row.forecastCount=numel(origins);row.nonfiniteForecastCount=sum(failed);
            row.nonfiniteForecastFraction=sum(failed)/numel(origins);
            row.oneStepPairCount=numel(origins);row.oneStepNonfiniteCount=sum(decodedFailed);
            row.oneStepLiftedRelativeError=liftedRelative;
            row.oneStepInnovationRMSE=decodedRMSE;
            row.oneStepInnovationNormalizedRMSE=decodedRMSE/outputScale;
            row.constantCoordinateRMSE=localRMSE(z(1,:)-1,failed);
            if model.degree==2
                % Decode every predicted history coordinate, including past
                % inputs, with the original training-only affine scaling.
                predictedHistory=model.historyMean+model.historyScale.*z(2:baseCount+1,:);
                diagnosticFailed=failed | any(~isfinite(predictedHistory),1);
                relifted=NaN(size(z));finiteColumns=~diagnosticFailed;
                if any(finiteColumns)
                    relifted(:,finiteColumns)=edmd_lift(model,predictedHistory(:,finiteColumns));
                end
                diagnosticFailed=diagnosticFailed | any(~isfinite(relifted),1);
                quadratic=baseCount+2:size(z,1);
                row.quadraticConsistencyRMSE=localRMSE(z(quadratic,:)-relifted(quadratic,:),diagnosticFailed);
                row.quadraticConsistencyRelativeError=localRelativeError( ...
                    z(quadratic,:),relifted(quadratic,:),diagnosticFailed);
                row.consistencyNonfiniteCount=sum(diagnosticFailed);
            else
                row.quadraticConsistencyRMSE=0;row.quadraticConsistencyRelativeError=0;
                row.consistencyNonfiniteCount=sum(failed);
                if any(failed)
                    row.quadraticConsistencyRMSE=Inf;row.quadraticConsistencyRelativeError=Inf;
                end
            end
            rows(end+1,1)=row; %#ok<AGROW>
        end
    end
end
% Arithmetic means of trajectory metrics, not pooled snapshots. No omitnan,
% finite-only filtering, or loss of failed runs is allowed in aggregation.
perRun=struct2table(rows);
for a=learned
    selected=perRun(perRun.modelName==names(a),:);
    for regime=unique(selected.regime,'stable')'
        for h=horizons
            group=selected(selected.regime==regime & selected.horizonSamples==h,:);
            row=localRolloutRow();row.rowScope="trajectory_equal_weight";
            row.modelName=names(a);row.regime=regime;row.runCount=height(group);
            row.horizonSamples=h;row.horizonSeconds=group.horizonSeconds(1);
            for field=["forecastCount","nonfiniteForecastCount","oneStepPairCount", ...
                    "oneStepNonfiniteCount","consistencyNonfiniteCount"]
                row.(field)=sum(group.(field));
            end
            for field=["nonfiniteForecastFraction","oneStepLiftedRelativeError", ...
                    "oneStepInnovationRMSE","oneStepInnovationNormalizedRMSE", ...
                    "constantCoordinateRMSE","quadraticConsistencyRMSE", ...
                    "quadraticConsistencyRelativeError"]
                row.(field)=mean(group.(field));
            end
            rows(end+1,1)=row; %#ok<AGROW>
        end
    end
end
rolloutSummary=struct2table(rows);
end

function localValidateModel(model)
assert(isstruct(model) && isscalar(model) && all(isfield(model, ...
    {'A','B','C','delay','degree','sampleTime','historyMean','historyScale', ...
    'inputMean','inputScale','outputMean'})), ...
    'HybridDiagnostics:Model','Provide a fitted EDMD model.');
b=2*model.delay+1;features=b+1;
if model.degree==2,features=features+b*(b+1)/2;end
assert(ismember(model.degree,[1,2]) && model.delay>=0 && mod(model.delay,1)==0 && ...
    isequal(size(model.A),[features,features]) && isequal(size(model.B),[features,1]) && ...
    isequal(size(model.C),[1,features]) && isequal(size(model.historyMean),[b,1]) && ...
    isequal(size(model.historyScale),[b,1]) && all(isfinite(model.historyMean)) && ...
    all(isfinite(model.historyScale) & model.historyScale>0) && ...
    isfinite(model.inputScale) && model.inputScale>0, ...
    'HybridDiagnostics:Model','Dictionary dimensions and training scales must be valid.');
end

function [row,spectrum]=localDescribe(model,name)
row=localModelRow();row.modelName=name;row.delay=model.delay;row.degree=model.degree;
row.featureCount=size(model.A,1);row.ridge=localField(model,'ridge',NaN);
row.svdTolerance=localField(model,'svdTolerance',NaN);
training=localField(model,'training',struct());
row.storedRegressorRank=localField(training,'regressorRank',NaN);
s=localField(training,'singularValues',zeros(0,1));s=s(:);
assert(isreal(s) && all(isfinite(s) & s>=0),'HybridDiagnostics:Spectrum', ...
    'Stored singular values must be finite nonnegative values.');
row.storedSingularValueCount=numel(s);row.positiveSingularValueCount=sum(s>0);
spectrum=repmat(localSpectrumRow(),0,1);
if ~isempty(s)
    row.largestSingularValue=max(s);row.smallestSingularValue=min(s);
    positive=s(s>0);
    if ~isempty(positive)
        row.smallestPositiveSingularValue=min(positive);
        row.positiveSpectrumCondition=max(positive)/min(positive);
    end
    assert(isfinite(row.svdTolerance) && row.svdTolerance>0 && ...
        isfinite(row.ridge) && row.ridge>=0,'HybridDiagnostics:TrainingMetadata', ...
        'Stored singular values require their training ridge and truncation tolerance.');
    keep=s>row.svdTolerance*s(1) & s>0;
    row.recomputedRetainedRank=sum(keep);
    row.storedRankMatchesThreshold=row.storedRegressorRank==sum(keep);
    if any(keep)
        row.smallestRetainedSingularValue=min(s(keep));
        row.retainedSpectrumCondition=max(s(keep))/min(s(keep));
    end
    for j=1:numel(s)
        entry=localSpectrumRow();entry.modelName=name;entry.singularIndex=j;
        entry.singularValue=s(j);entry.retained=keep(j);
        if keep(j)
            entry.ridgeFilterFactor=s(j)^2/(s(j)^2+row.ridge);
            entry.inverseGain=s(j)/(s(j)^2+row.ridge);
        end
        spectrum(end+1,1)=entry; %#ok<AGROW>
    end
end
constantExpected=zeros(1,size(model.A,2));constantExpected(1)=1;
row.constantCoordinateResidual=norm([model.A(1,:)-constantExpected,model.B(1)],Inf);
if ~isfinite(row.constantCoordinateResidual),row.constantCoordinateResidual=Inf;end
row.constantCoordinateIsExact=row.constantCoordinateResidual==0;
if row.constantCoordinateIsExact,row.knownConstantEigenvalue=1;end
if all(isfinite(model.A),'all')
    row.fullSpectralRadius=max(abs(eig(model.A)));
    affineEigenvalues=eig(model.A(2:end,2:end));
    row.affineSpectralRadius=max(abs(affineEigenvalues));
    row.affineEigenvaluesOutsideUnitCircle=sum(abs(affineEigenvalues)>1+1e-10);
    row.affineSpectrumInterpretationValid=row.constantCoordinateIsExact;
else
    row.fullSpectralRadius=Inf;row.affineSpectralRadius=Inf;
end
end

function value=localField(object,name,default)
if isfield(object,name),value=object.(name);else,value=default;end
end

function value=localRMSE(error,failed)
if any(failed) || any(~isfinite(error),'all'),value=Inf;return;end
% norm avoids intermediate squaring overflow for large but finite values.
value=norm(error(:))/sqrt(numel(error));
end

function value=localRelativeError(predicted,target,failed)
if any(failed) || any(~isfinite(predicted),'all') || any(~isfinite(target),'all')
    value=Inf;return;
end
numerator=norm(predicted(:)-target(:));denominator=norm(target(:));
if denominator==0
    if numerator==0,value=0;else,value=Inf;end
else
    value=numerator/denominator;
end
if ~isfinite(value),value=Inf;end
end

function row=localModelRow()
row=struct('modelName',"",'delay',0,'degree',0,'featureCount',0,'ridge',NaN, ...
    'svdTolerance',NaN,'storedRegressorRank',NaN,'recomputedRetainedRank',NaN, ...
    'storedRankMatchesThreshold',false,'storedSingularValueCount',0, ...
    'positiveSingularValueCount',0,'largestSingularValue',NaN,'smallestSingularValue',NaN, ...
    'smallestPositiveSingularValue',NaN,'smallestRetainedSingularValue',NaN, ...
    'positiveSpectrumCondition',NaN,'retainedSpectrumCondition',NaN, ...
    'constantCoordinateResidual',NaN,'constantCoordinateIsExact',false, ...
    'knownConstantEigenvalue',NaN,'fullSpectralRadius',NaN,'affineSpectralRadius',NaN, ...
    'affineEigenvaluesOutsideUnitCircle',NaN,'affineSpectrumInterpretationValid',false, ...
    'ridgeScope',"Regressor SVD before exact bookkeeping-row overrides", ...
    'coupledSensitivityStatus',"Not computed: physical state and normalized lift mix units; no raw augmented norm reported", ...
    'interpretation',"Fit diagnostics only; no physical or closed-loop stability certificate");
end

function row=localSpectrumRow()
row=struct('modelName',"",'singularIndex',0,'singularValue',NaN,'retained',false, ...
    'ridgeFilterFactor',0,'inverseGain',0);
end

function row=localRolloutRow()
row=struct('rowScope',"",'modelName',"",'regime',"unspecified",'runName',"", ...
    'runIndex',0,'seed',NaN,'horizonSamples',0,'horizonSeconds',0,'runCount',0, ...
    'forecastCount',0,'nonfiniteForecastCount',0,'nonfiniteForecastFraction',0, ...
    'oneStepPairCount',0,'oneStepNonfiniteCount',0,'oneStepLiftedRelativeError',NaN, ...
    'oneStepInnovationRMSE',NaN,'oneStepInnovationNormalizedRMSE',NaN, ...
    'constantCoordinateRMSE',NaN,'quadraticConsistencyRMSE',NaN, ...
    'quadraticConsistencyRelativeError',NaN,'consistencyNonfiniteCount',0);
end
