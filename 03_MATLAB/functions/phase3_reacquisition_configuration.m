function config = phase3_reacquisition_configuration(observerConfig, overrides)
%PHASE3_REACQUISITION_CONFIGURATION Independent-reference reanchor contract.
% This is a provisional assumed-model calculation, not a sensor integrity
% claim. Position errors must have the supplied deterministic bounds. Actual
% applied voltage, the constant assumed load, timestamps and model are exact
% assumptions here; unknown model/input/load error is NOT covered by the
% reported state uncertainty. State order is [position;velocity;current].
arguments
    observerConfig (1,1) struct
    overrides (1,1) struct = struct()
end
validate_phase3_observer_configuration(observerConfig);
id='EMIProject:InvalidReacquisitionConfiguration';
config.observerConfiguration=observerConfig;
config.sampleTime_s=double(observerConfig.sampleTime_s);
config.A=double(observerConfig.A);config.B=double(observerConfig.B);config.C=[1,0,0];
config.windowDuration_s=.050;
config.positionLimit_rad=double(observerConfig.positionLimit_rad);
config.velocityLimit_rad_s=double(observerConfig.rateLimit_rad_s);
config.currentLimit_A=12;
config.minReferenceUncertainty_rad=1e-8;
config.maxReferenceUncertainty_rad=deg2rad(.01);
config.maxStateUncertainty=[deg2rad(.05);.10;.05];
config.maxFitResidual_rad=deg2rad(.02);
config.maxNormalizedCondition=1e6;
config.minNormalizedSingularValue=1e-8;
config.assumedLoadTorque_Nm=double(observerConfig.assumedLoadTorque_Nm);
config.tunableFields={'windowDuration_s','positionLimit_rad','velocityLimit_rad_s', ...
    'currentLimit_A','minReferenceUncertainty_rad','maxReferenceUncertainty_rad', ...
    'maxStateUncertainty','maxFitResidual_rad','maxNormalizedCondition', ...
    'minNormalizedSingularValue','assumedLoadTorque_Nm'};
names=fieldnames(overrides);
assert(all(ismember(names,config.tunableFields)),id,'Only declared reacquisition tunables may be overridden.');
for k=1:numel(names),config.(names{k})=overrides.(names{k});end
positive=setdiff(config.tunableFields,{'maxStateUncertainty','assumedLoadTorque_Nm'});
for k=1:numel(positive)
    name=positive{k};
    assert(localScalar(config.(name)) && config.(name)>0,id,'%s must be a positive finite real scalar.',name);
    config.(name)=double(config.(name));
end
assert(localScalar(config.assumedLoadTorque_Nm),id,'Assumed load must be a finite real scalar.');
config.assumedLoadTorque_Nm=double(config.assumedLoadTorque_Nm);
assert(config.windowDuration_s>=.050 && config.maxNormalizedCondition>=1,id, ...
    'Qualification must cover at least 50 ms and the condition limit must be at least one.');
assert(config.minReferenceUncertainty_rad<=config.maxReferenceUncertainty_rad,id, ...
    'Minimum reference uncertainty must not exceed its maximum.');
assert(config.positionLimit_rad<=observerConfig.positionLimit_rad && ...
    config.velocityLimit_rad_s<=observerConfig.rateLimit_rad_s && config.currentLimit_A<=12,id, ...
    'Reanchor bounds cannot exceed the observer position/rate limits or the provisional 12 A limit.');
assert(isnumeric(config.maxStateUncertainty) && isreal(config.maxStateUncertainty) && ...
    isvector(config.maxStateUncertainty) && numel(config.maxStateUncertainty)==3 && ...
    all(isfinite(config.maxStateUncertainty)) && all(config.maxStateUncertainty>0),id, ...
    'Maximum state uncertainty must contain three positive finite bounds.');
config.maxStateUncertainty=double(config.maxStateUncertainty(:));
config.stateLimits=[config.positionLimit_rad;config.velocityLimit_rad_s;config.currentLimit_A];
assert(all(config.maxStateUncertainty<config.stateLimits),id,'Uncertainty limits must be smaller than state limits.');
config.windowSamples=max(51,ceil(config.windowDuration_s/config.sampleTime_s)+1);
assert(isfinite(config.windowSamples) && config.windowSamples<=2001,id, ...
    'The bounded qualification window supports at most 2001 samples.');
n=config.windowSamples;config.observability=zeros(n,3);transition=eye(3);
for j=1:n
    config.observability(j,:)=config.C*transition;
    if j<n,transition=config.A*transition;end
end
assert(all(isfinite(config.observability),'all') && all(isfinite(transition),'all'),id, ...
    'The model must have finite window propagation.');
% Normalize columns by declared state limits and rows by position limit, so
% conditioning does not depend on mixing radians, radians/second and amps.
scale=diag(config.stateLimits);
[U,S,V]=svd(config.observability*scale/config.positionLimit_rad,'econ');
singular=diag(S);config.normalizedMinimumSingularValue=singular(end);
config.normalizedCondition=realmax;
if singular(end)>0,config.normalizedCondition=singular(1)/singular(end);end
if ~isfinite(config.normalizedCondition),config.normalizedCondition=realmax;end
config.modelQualified=config.normalizedCondition<=config.maxNormalizedCondition && ...
    singular(end)>=config.minNormalizedSingularValue;
config.initialStateMap=zeros(3,n);config.currentStateMap=zeros(3,n);
config.residualUncertaintyMap=zeros(n,n);
if config.modelQualified
    config.initialStateMap=scale*V*diag(1./singular)*U'/config.positionLimit_rad;
    config.currentStateMap=transition*config.initialStateMap;
    config.residualUncertaintyMap=abs(eye(n)-config.observability*config.initialStateMap);
    assert(all(isfinite(config.currentStateMap),'all') && ...
        all(isfinite(config.residualUncertaintyMap),'all'),id,'Reconstruction maps must remain finite.');
end
config.assumptions="External independent position reference with deterministic per-sample error bounds; synchronized timestamps; exact assumed actuator model, actual applied voltage and constant assumed load; no unknown model-error allowance; provisional software limits";
end

function valid=localScalar(value)
valid=isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
end
