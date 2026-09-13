function [weights,diagnostic] = hybrid_correction_weight(model,innovations,inputs,origins)
%HYBRID_CORRECTION_WEIGHT Frozen rule using completed one-step errors only.
% The selected weight is held fixed at each forecast origin. No truth,
% regime label, future measurement or future input enters this function.
% Healthy synchronous data only; this is not an encoder fault classifier.
policy=model.correctionPolicy;
required={'windowSamples','minRelativeImprovement','weights','domainMargin'};
assert(isstruct(policy)&&all(isfield(policy,required)), ...
    'HybridWeight:Policy','Provide a frozen correction policy.');
window=policy.windowSamples;
assert(isscalar(window)&&isfinite(window)&&window>=1&&window==floor(window), ...
    'HybridWeight:Policy','Window must be a positive integer.');
assert(isscalar(policy.minRelativeImprovement)&&isfinite(policy.minRelativeImprovement)&& ...
    policy.minRelativeImprovement>=0&&policy.minRelativeImprovement<1&& ...
    isscalar(policy.domainMargin)&&isfinite(policy.domainMargin)&&policy.domainMargin>=0, ...
    'HybridWeight:Policy','Invalid improvement or domain margin.');
candidates=double(policy.weights(:)');
assert(~isempty(candidates)&&all(isfinite(candidates))&&all(candidates>=0&candidates<=1)&&any(candidates==0), ...
    'HybridWeight:Policy','Weights must be in [0,1] and include zero.');
candidates=unique(candidates,'sorted');
origins=double(origins(:)');
assert(~isempty(origins)&&all(isfinite(origins))&&all(origins>=1&origins==floor(origins)), ...
    'HybridWeight:Origins','Origins must be positive sample indices.');
last=max(origins);d=model.delay;
assert(numel(innovations)>=last&&numel(inputs)>=last-1, ...
    'HybridWeight:Data','Insufficient observed history.');
r=double(innovations(1:last));r=r(:);u=double(inputs(1:last-1));u=u(:);
assert(isreal(r)&&isreal(u)&&all(isfinite(r))&&all(isfinite(u)), ...
    'HybridWeight:Data','History through the origins must be finite and real.');
assert(isfield(model,'training')&&all(isfield(model.training,{'minimumHistory','maximumHistory'})), ...
    'HybridWeight:Domain','Training-domain limits are required.');
low=model.training.minimumHistory(:);high=model.training.maximumHistory(:);
assert(numel(low)==2*d+1&&numel(high)==numel(low)&&all(isfinite(low))&&all(isfinite(high))&&all(high>=low), ...
    'HybridWeight:Domain','Invalid training-domain limits.');
margin=policy.domainMargin*max(high-low,model.historyScale(:));
% First 100 samples are the same observer warmup used by fitting.
firstTarget=102+d;prediction=NaN(last,1);
if firstTarget<=last
    previous=(firstTarget:last)-1;
    H=reshape(r(previous-(0:d)'),d+1,numel(previous));
    if d>0,H=[H;reshape(u(previous-(1:d)'),d,numel(previous))];end
    z=edmd_lift(model,H);
    znext=model.A*z+model.B*((u(previous)'-model.inputMean)/model.inputScale);
    prediction(firstTarget:last)=(model.outputMean+model.C*znext)';
end
weights=zeros(size(origins));reason=repmat("insufficient_history",size(origins));
baselineMSE=NaN(size(origins));selectedMSE=baselineMSE;relativeGain=baselineMSE;
inDomain=false(size(origins));candidateNonfinite=false(size(origins));
for j=1:numel(origins)
    origin=origins(j);begin=origin-window+1;
    if begin<firstTarget,continue;end
    history=r(origin-(0:d));
    if d>0,history=[history;u(origin-(1:d))];end
    inDomain(j)=all(history>=low-margin&history<=high+margin);
    if ~inDomain(j),reason(j)="outside_training_domain";continue;end
    observed=r(begin:origin);predicted=prediction(begin:origin);
    baselineMSE(j)=mean(observed.^2);
    candidateNonfinite(j)=any(~isfinite(predicted));
    if candidateNonfinite(j),reason(j)="learned_numeric_failure";continue;end
    mse=mean((observed-predicted*candidates).^2,1);
    [best,index]=min(mse);selectedMSE(j)=best;
    relativeGain(j)=(baselineMSE(j)-best)/max(baselineMSE(j),eps*model.outputScale^2);
    if candidates(index)>0&&relativeGain(j)>policy.minRelativeImprovement
        weights(j)=candidates(index);reason(j)="past_one_step_improvement";
    else
        selectedMSE(j)=baselineMSE(j);reason(j)="physics_preferred";
    end
end
diagnostic=table(origins',weights',reason',baselineMSE',selectedMSE',relativeGain', ...
    inDomain',candidateNonfinite','VariableNames',{'originIndex','correctionWeight','reason', ...
    'pastPhysicsMSE','pastSelectedMSE','pastRelativeImprovement','historyInTrainingDomain','learnedCandidateNonfinite'});
end
