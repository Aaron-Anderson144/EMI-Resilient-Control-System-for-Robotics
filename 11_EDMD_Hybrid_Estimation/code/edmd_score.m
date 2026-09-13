function metrics = edmd_score(model,records,horizons)
%EDMD_SCORE Endpoint errors over whole held-out runs, conditional on inputs.
% Each origin initializes once from measured history, then runs freely to H.
% Rejects gaps and domain-invalid runs via the same snapshot validation.
arguments
    model struct
    records (1,:) cell
    horizons (1,:) double {mustBeInteger,mustBePositive} = [1,20,50]
end
p=edmd_snapshot_pairs(records,model.delay);
assert(abs(p.sampleTime-model.sampleTime)<max(1e-12,p.sampleTime*1e-8), ...
    'EDMD:SampleTime','Evaluation sample time differs from training.');
n=numel(horizons); count=zeros(n,1); rmse=nan(n,1); peak=nan(n,1);
outOfRange=zeros(n,1);
unusable=zeros(n,1);
for j=1:n
    H=horizons(j); errors=[];
    for a=1:numel(p.U)
        r=p.runIndex(a); k=p.sampleIndex(a); rec=records{r};
        if k+H>numel(rec.y) || ~all(rec.valid(k-model.delay:k+H)) || ...
                ~all(isfinite(rec.y(k-model.delay:k+H))) || ...
                ~all(isfinite(rec.u(k-model.delay:k+H))), continue; end
        try
            [prediction,info]=edmd_predict(model,rec.y(k:-1:k-model.delay), ...
                rec.u(k-1:-1:k-model.delay),rec.u(k:k+H-1));
        catch err
            if ~strcmp(err.identifier,'EDMD:Divergence'), rethrow(err); end
            unusable(j)=unusable(j)+1;
            errors(end+1)=Inf; %#ok<AGROW>
            continue
        end
        errors(end+1)=prediction(end)-rec.y(k+H); %#ok<AGROW>
        outOfRange(j)=outOfRange(j)+info.historyOutsideTrainingRange+ ...
            (~info.historyOutsideTrainingRange && info.inputOutsideTrainingRange);
    end
    count(j)=numel(errors);
    if ~isempty(errors), rmse(j)=sqrt(mean(errors.^2)); peak(j)=max(abs(errors)); end
end
metrics=table(horizons',horizons'*model.sampleTime,count,rmse,peak,outOfRange,unusable, ...
    'VariableNames',{'horizonSamples','horizonSeconds','forecastCount', ...
    'outputRMSE','peakAbsoluteError','outsideTrainingRangeCount','unusableForecastCount'});
end
