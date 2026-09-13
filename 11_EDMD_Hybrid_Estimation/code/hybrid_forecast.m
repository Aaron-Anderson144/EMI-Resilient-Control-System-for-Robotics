function [forecast,diagnostic] = hybrid_forecast(config,posteriorAtOrigin,innovationHistory,newestFirstInputHistory,futureInputs,model,mode,correctionWeight)
%HYBRID_FORECAST Conditional predicted encoder positions from a causal origin.
% A single origin returns H-by-1. Batch origins use columns: state 3-by-M,
% newest-first histories (d+1)-by-M/d-by-M, future inputs H-by-M.
% Modes: physics (no future innovation), persistent (mean last 20), learned.
% Learned correctionWeight is a scalar or 1-by-origin row in [0,1], fixed
% through each rollout. The default is 1; other modes accept only weight 1.
% Weight 0 follows physics even if the independently propagated learned
% candidate fails. Diagnostics retain its raw innovation and sticky failure.
% predictedInnovation is the applied correction; rawPredictedInnovation is
% unweighted. correctionWeight is 1-by-origin; learnedCandidateNonfinite is
% H-by-origin and stays true after a candidate state/output first fails.
% No future observation or true state is consumed. Future inputs are supplied.
% Numerical failure remains NaN from its first occurrence through the horizon.
arguments
    config (1,1) struct
    posteriorAtOrigin double
    innovationHistory double
    newestFirstInputHistory double
    futureInputs double
    model = []
    mode (1,1) string {mustBeMember(mode,["physics","persistent","learned"])} = "physics"
    correctionWeight double = 1
end
if ~isfield(config,'dt') && isfield(config,'sampleTime'),config.dt=config.sampleTime;end
assert(all(isfield(config,{'A','B','C','L','dt'})) && ...
    isequal(size(config.A),[3,3]) && isequal(size(config.B),[3,1]) && ...
    isequal(size(config.C),[1,3]) && isequal(size(config.L),[3,1]), ...
    'HybridForecast:Configuration','A/B/C/L must be 3x3/3x1/1x3/3x1.');
assert(isreal(posteriorAtOrigin) && size(posteriorAtOrigin,1)==3 && ...
    size(posteriorAtOrigin,2)>=1,'HybridForecast:State','Posterior estimates need three rows.');
origins=size(posteriorAtOrigin,2);
assert(isreal(correctionWeight) && ...
    (isscalar(correctionWeight) || isequal(size(correctionWeight),[1,origins])) && ...
    all(isfinite(correctionWeight),'all') && ...
    all(correctionWeight>=0 & correctionWeight<=1,'all'), ...
    'HybridForecast:CorrectionWeight','Correction weight must be a finite scalar or 1-by-origin row in [0,1].');
assert(mode=="learned" || all(correctionWeight==1,'all'), ...
    'HybridForecast:CorrectionWeight','Only learned mode accepts correction weights other than 1.');
if isscalar(correctionWeight),correctionWeight=repmat(correctionWeight,1,origins);end
activeCorrection=correctionWeight>0;
if origins==1 && isvector(futureInputs),futureInputs=futureInputs(:);end
assert(isreal(futureInputs) && size(futureInputs,2)==origins && ...
    size(futureInputs,1)>=1 && all(isfinite(futureInputs),'all'), ...
    'HybridForecast:Inputs','Supply a finite H-by-origin applied-input matrix.');
if origins==1
    innovationHistory=innovationHistory(:);
    newestFirstInputHistory=newestFirstInputHistory(:);
end
if mode=="learned"
    assert(isstruct(model) && isfield(model,'delay') && ...
        size(innovationHistory,1)==model.delay+1 && size(innovationHistory,2)==origins && ...
        size(newestFirstInputHistory,1)==model.delay && ...
        (model.delay==0 || size(newestFirstInputHistory,2)==origins) && ...
        isreal(innovationHistory) && isreal(newestFirstInputHistory) && ...
        all(isfinite(innovationHistory),'all') && all(isfinite(newestFirstInputHistory),'all'), ...
        'HybridForecast:History','Learned histories must match the model delay and origin count.');
    assert(abs(model.sampleTime-config.dt)<max(1e-12,config.dt*1e-8), ...
        'HybridForecast:SampleTime','Model and nominal observer sample times differ.');
    if model.delay==0,newestFirstInputHistory=zeros(0,origins);end
    z=edmd_lift(model,[innovationHistory;newestFirstInputHistory]);
elseif mode=="persistent"
    assert(size(innovationHistory,1)>=20 && size(innovationHistory,2)==origins && ...
        isreal(innovationHistory) && all(isfinite(innovationHistory),'all'), ...
        'HybridForecast:History','Persistence needs at least 20 newest-first innovations.');
    persistentInnovation=mean(innovationHistory(1:20,:),1);
end
H=size(futureInputs,1);forecast=NaN(H,origins);predictedInnovations=forecast;
rawPredictedInnovations=forecast;learnedFailureHistory=false(H,origins);
learnedFailed=false(1,origins);
posteriorPositions=forecast;failed=any(~isfinite(posteriorAtOrigin),1);
x=posteriorAtOrigin;failureHistory=false(H,origins);
for step=1:H
    prior=config.A*x+config.B*futureInputs(step,:);
    if mode=="learned"
        z=model.A*z+model.B*((futureInputs(step,:)-model.inputMean)/model.inputScale);
        rawInnovation=model.outputMean+model.C*z;
        learnedFailed=learnedFailed | any(~isfinite(z),1) | ~isfinite(rawInnovation);
        % Index before multiplication: zero weight must never evaluate 0*Inf
        % or 0*NaN, and learned state propagation remains independent of x.
        innovation=zeros(1,origins);
        innovation(activeCorrection)=correctionWeight(activeCorrection).*rawInnovation(activeCorrection);
        failed=failed | (activeCorrection & learnedFailed);
    elseif mode=="persistent"
        innovation=persistentInnovation;
        rawInnovation=innovation;
    else
        innovation=zeros(1,origins);
        rawInnovation=innovation;
    end
    predicted=config.C*prior+innovation;
    x=prior+config.L*innovation;
    failed=failed | any(~isfinite(prior),1) | ~isfinite(innovation) | ...
        ~isfinite(predicted) | any(~isfinite(x),1);
    predicted(failed)=NaN;innovation(failed)=NaN;x(:,failed)=NaN;
    forecast(step,:)=predicted;predictedInnovations(step,:)=innovation;
    rawPredictedInnovations(step,:)=rawInnovation;learnedFailureHistory(step,:)=learnedFailed;
    posteriorPositions(step,:)=config.C*x;failureHistory(step,:)=failed;
end
diagnostic=struct('predictedInnovation',predictedInnovations, ...
    'rawPredictedInnovation',rawPredictedInnovations, ...
    'correctionWeight',correctionWeight,'learnedCandidateNonfinite',learnedFailureHistory, ...
    'posteriorPosition',posteriorPositions,'nonfinite',failureHistory, ...
    'mode',mode,'conditionalOnSuppliedInputs',true, ...
    'outputMeaning','Predicted encoder position; posteriorPosition is a distinct internal estimate');
end
