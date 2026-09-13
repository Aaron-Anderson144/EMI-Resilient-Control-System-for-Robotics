function [summary,perRun,endpoints] = hybrid_score(models,names,records,horizons,stride,warmupSeconds)
%HYBRID_SCORE Common-origin forecasts; true position is an OFFLINE target only.
% Empty models require names "Nominal physics" or "Persistent innovation".
% Nonempty models forecast nominal-observer innovations with scalar EDMD.
% Numerical failure yields infinite error and remains in every denominator.
% Optional endpoints retain paired OFFLINE diagnostics in radians/seconds.
% Reversal labels never enter forecasting. Default origins exclude t < .2 s.
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
    'HybridScore:Arguments','Provide named predictors and nonempty records.');
horizons=unique(horizons,'sorted');maxH=max(horizons);delays=zeros(size(models));
for a=1:numel(models)
    if isempty(models{a})
        assert(ismember(names(a),["Nominal physics","Persistent innovation"]), ...
            'HybridScore:ModelName','An empty model must name one of the two baselines.');
    else
        assert(isstruct(models{a}) && isfield(models{a},'delay'), ...
            'HybridScore:Model','A learned predictor must be an EDMD model.');
        delays(a)=models{a}.delay;
    end
end
maxDelay=max(delays);rows=repmat(localRow(),0,1);
% Samples 1:100 are invalidated by hybrid_prepare_records. Every history
% coordinate, including persistence's oldest of 20 innovations, must follow.
historyMinimum=101+maxDelay;
if any(cellfun(@isempty,models) & names=="Persistent innovation")
    historyMinimum=max(historyMinimum,120);
end
retainEndpoints=nargout>2;
if retainEndpoints
    endpointBlocks=cell(numel(records)*numel(models)*numel(horizons),1);
    endpointBlockCount=0;
end
for r=1:numel(records)
    rec=records{r};localValidateRecord(rec);
    [trace,config]=hybrid_reference_observer(rec);
    y=double(rec.y(:));u=double(rec.u(:));truth=double(rec.truth(:,1));n=numel(y);dt=rec.sampleTime;
    assert(isequal(size(trace.posterior),[n,3]) && numel(trace.innovation)==n, ...
        'HybridScore:Observer','Reference trace dimensions do not match the record.');
    first=max(historyMinimum,ceil(warmupSeconds/dt)+1);
    origins=first:stride:n-maxH;
    assert(~isempty(origins),'HybridScore:ShortRecord','No common forecast origins remain.');
    futureInputs=reshape(u(origins+(0:maxH-1)'),maxH,numel(origins));
    innovations=trace.innovation(:);posterior=trace.posterior(origins,:)';
    runName="run_"+r;if isfield(rec,'id'),runName=string(rec.id);end
    regime="unspecified";if isfield(rec,'regime'),regime=string(rec.regime);end
    seed=NaN;if isfield(rec,'seed'),seed=rec.seed;end
    if retainEndpoints
        [reversalAvailable,reversalTimes]=localReversalTimes(rec);
    end
    for a=1:numel(models)
        correctionWeight=1;
        correctionReason=repmat("unweighted_learned",numel(origins),1);
        if isempty(models{a}) && names(a)=="Nominal physics"
            mode="physics";history=zeros(0,numel(origins));inputHistory=history;
            correctionReason(:)="nominal_physics";
        elseif isempty(models{a})
            mode="persistent";
            correctionReason(:)="persistent_innovation";
            history=reshape(innovations(origins-(0:19)'),20,numel(origins));
            inputHistory=zeros(0,numel(origins));
        else
            mode="learned";d=models{a}.delay;
            history=reshape(innovations(origins-(0:d)'),d+1,numel(origins));
            inputHistory=zeros(d,numel(origins));
            if d>0,inputHistory=reshape(u(origins-(1:d)'),d,numel(origins));end
            if isfield(models{a},'correctionPolicy')
                [correctionWeight,weightDiagnostic]=hybrid_correction_weight(models{a},innovations,u,origins);
                correctionReason=weightDiagnostic.reason;
            end
        end
        [forecast,diagnostic]=hybrid_forecast(config,posterior,history,inputHistory, ...
            futureInputs,models{a},mode,correctionWeight);
        for h=horizons
            predicted=forecast(h,:)';target=truth(origins+h);measured=y(origins+h);
            failed=~isfinite(predicted) | diagnostic.nonfinite(h,:)';
            truthError=predicted-target;measuredError=predicted-measured;
            row=localRow();row.modelName=names(a);row.regime=regime;row.runName=runName;
            row.runIndex=r;row.seed=seed;row.horizonSamples=h;row.horizonSeconds=h*dt;
            row.forecastCount=numel(origins);row.nonfiniteForecastCount=sum(failed);
            row.catastrophicForecastCount=sum(failed | abs(truthError)>deg2rad(10));
            row.catastrophicFraction=row.catastrophicForecastCount/row.forecastCount;
            if any(failed)
                row.truthRMSE=Inf;row.measurementRMSE=Inf;row.peakAbsoluteError=Inf;
                row.posteriorTruthRMSE=Inf;
            else
                row.truthRMSE=sqrt(mean(truthError.^2));
                row.measurementRMSE=sqrt(mean(measuredError.^2));
                row.peakAbsoluteError=max(abs(truthError));
                row.posteriorTruthRMSE=sqrt(mean((diagnostic.posteriorPosition(h,:)'-target).^2));
            end
            rows(end+1,1)=row; %#ok<AGROW>
            if retainEndpoints
                endpointBlockCount=endpointBlockCount+1;
                count=numel(origins);originIndex=origins(:);targetIndex=originIndex+h;
                originTimeSeconds=double(rec.t(originIndex));originTimeSeconds=originTimeSeconds(:);
                targetTimeSeconds=double(rec.t(targetIndex));targetTimeSeconds=targetTimeSeconds(:);
                nearReversal=false(count,1);
                for reversalTime=reversalTimes(:)'
                    nearReversal=nearReversal | abs(targetTimeSeconds-reversalTime)<=.05+1e-12;
                end
                posteriorPosition=diagnostic.posteriorPosition(h,:)';
                endpointWeight=correctionWeight(:);
                if isscalar(endpointWeight),endpointWeight=repmat(endpointWeight,count,1);end
                learnedCandidateNonfinite=false(count,1);
                if isfield(diagnostic,'learnedCandidateNonfinite')
                    learnedCandidateNonfinite=diagnostic.learnedCandidateNonfinite(h,:)';
                end
                endpointBlocks{endpointBlockCount}=table(repmat(names(a),count,1), ...
                    repmat(regime,count,1),repmat(runName,count,1),repmat(r,count,1), ...
                    repmat(seed,count,1),originIndex,originTimeSeconds,targetIndex,targetTimeSeconds, ...
                    repmat(h,count,1),repmat(h*dt,count,1),predicted,target,measured, ...
                    truthError,measuredError,diagnostic.predictedInnovation(h,:)', ...
                    posteriorPosition,posteriorPosition-target,failed,repmat(reversalAvailable,count,1), ...
                    nearReversal,reversalAvailable & ~nearReversal,repmat(.05,count,1), ...
                    targetTimeSeconds<.2,endpointWeight,learnedCandidateNonfinite,correctionReason, ...
                    'VariableNames',{'modelName','regime','runName','runIndex','seed', ...
                    'originIndex','originTimeSeconds','targetIndex','targetTimeSeconds', ...
                    'horizonSamples','horizonSeconds','predictedPosition','truePosition', ...
                    'measuredPosition','truthError','measurementError','predictedInnovation', ...
                    'posteriorPosition','posteriorTruthError','nonfinite','reversalLabelAvailable', ...
                    'nearReversal','awayFromReversal','reversalWindowSeconds','targetInStartup', ...
                    'correctionWeight','learnedCandidateNonfinite','correctionReason'});
            end
        end
    end
end
perRun=struct2table(rows);summaryRows=repmat(localSummaryRow(),0,1);
for name=names
    for regime=unique(perRun.regime,'stable')'
        for h=horizons
            group=perRun(perRun.modelName==name & perRun.regime==regime & perRun.horizonSamples==h,:);
            row=localSummaryRow();row.modelName=name;row.regime=regime;
            row.horizonSamples=h;row.horizonSeconds=group.horizonSeconds(1);
            row.runCount=height(group);row.forecastCount=sum(group.forecastCount);
            row.truthRMSE=mean(group.truthRMSE);row.measurementRMSE=mean(group.measurementRMSE);
            row.posteriorTruthRMSE=mean(group.posteriorTruthRMSE);
            row.medianTruthRMSE=median(group.truthRMSE);row.worstTruthRMSE=max(group.truthRMSE);
            row.peakAbsoluteError=max(group.peakAbsoluteError);
            row.nonfiniteForecastCount=sum(group.nonfiniteForecastCount);
            row.catastrophicForecastCount=sum(group.catastrophicForecastCount);
            row.catastrophicFraction=row.catastrophicForecastCount/row.forecastCount;
            summaryRows(end+1,1)=row; %#ok<AGROW>
        end
    end
end
summary=struct2table(summaryRows);
if retainEndpoints,endpoints=vertcat(endpointBlocks{1:endpointBlockCount});end
end

function [available,times]=localReversalTimes(rec)
% Use OFFLINE truth velocity. An initial start from zero is not a reversal.
% Across a zero plateau, date the event at the first opposite nonzero sample.
available=size(rec.truth,2)>=2 && all(isfinite(rec.truth(:,2)));
times=zeros(0,1);
if ~available,return;end
indices=find(rec.truth(:,2)~=0);
if numel(indices)<2,return;end
signs=sign(rec.truth(indices,2));
changed=indices(find(signs(2:end)~=signs(1:end-1))+1);
times=double(rec.t(changed));times=times(:);
end

function localValidateRecord(rec)
assert(isstruct(rec) && all(isfield(rec,{'y','u','t','valid','sampleTime','truth'})), ...
    'HybridScore:Record','Record needs observation/input/time/validity and offline truth.');
n=numel(rec.y);dt=rec.sampleTime;
assert(n>=3 && isvector(rec.y) && isvector(rec.u) && isvector(rec.t) && ...
    numel(rec.u)==n && numel(rec.t)==n && numel(rec.valid)==n && ...
    isreal(rec.y) && isreal(rec.u) && isreal(rec.t) && ...
    all(isfinite(rec.y(:))) && all(isfinite(rec.u(:))) && all(isfinite(rec.t(:))) && ...
    all(rec.valid(:)==1) && (~isfield(rec,'domainValid') || isequal(rec.domainValid,true)) && ...
    isnumeric(rec.truth) && isreal(rec.truth) && size(rec.truth,1)==n && ...
    size(rec.truth,2)>=1 && all(isfinite(rec.truth(:,1))), ...
    'HybridScore:Record','Clean records need finite fresh observations and finite offline position truth.');
assert(isscalar(dt) && isfinite(dt) && dt>0 && ...
    all(abs(diff(rec.t(:))-dt)<max(1e-12,dt*1e-8)), ...
    'HybridScore:Timestamps','Timestamps must be uniform and contiguous.');
end

function row=localRow()
row=struct('modelName',"",'regime',"",'runName',"",'runIndex',0,'seed',NaN, ...
    'horizonSamples',0,'horizonSeconds',0,'forecastCount',0, ...
    'truthRMSE',NaN,'measurementRMSE',NaN,'posteriorTruthRMSE',NaN,'peakAbsoluteError',NaN, ...
    'catastrophicForecastCount',0,'catastrophicFraction',0,'nonfiniteForecastCount',0);
end

function row=localSummaryRow()
row=struct('modelName',"",'regime',"",'horizonSamples',0,'horizonSeconds',0, ...
    'runCount',0,'forecastCount',0,'truthRMSE',NaN,'measurementRMSE',NaN, ...
    'posteriorTruthRMSE',NaN,'medianTruthRMSE',NaN,'worstTruthRMSE',NaN, ...
    'peakAbsoluteError',NaN,'catastrophicForecastCount',0,'catastrophicFraction',0, ...
    'nonfiniteForecastCount',0);
end
