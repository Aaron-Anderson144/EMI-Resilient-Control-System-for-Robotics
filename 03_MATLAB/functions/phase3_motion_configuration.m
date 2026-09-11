function config = phase3_motion_configuration(params, observer, options)
%PHASE3_MOTION_CONFIGURATION Opt-in causal reference motion contract.
% Bounds apply to the generated reference, not actual plant motion. They
% neither qualify hardware nor replace the observer/supervisor or a stop.
if nargin<3,options=struct();end
id='EMIProject:InvalidPhase3MotionConfiguration';
assert(isstruct(options) && isscalar(options),id,'Motion options must be a scalar structure.');
config=struct('maxVelocity_rad_s',10,'maxAcceleration_rad_s2',200, ...
    'positionLimit_rad',deg2rad(120));
names=fieldnames(options);allowed=fieldnames(config);
assert(all(ismember(names,allowed)),id,'Only the three declared reference motion limits may be overridden.');
for k=1:numel(names),config.(names{k})=options.(names{k});end
for k=1:numel(allowed)
    name=allowed{k};value=config.(name);
    assert(isfloat(value) && isreal(value) && isscalar(value) && isfinite(value) && value>0,id, ...
        '%s must be a positive finite real double or single scalar.',name);
    config.(name)=double(value);
end
validate_parameters(params);validate_phase3_observer_configuration(observer);
assert(params.control.sampleTime_s==observer.sampleTime_s,id,'Motion and observer sample times must agree.');
config.sampleTime_s=double(params.control.sampleTime_s);
config.observerRateLimit_rad_s=double(observer.rateLimit_rad_s);
config.observerPositionLimit_rad=double(observer.positionLimit_rad);
config.initialPosition_rad=double(observer.initialEstimate(1));
assert(config.maxVelocity_rad_s<=.5*config.observerRateLimit_rad_s,id, ...
    'Reference speed cannot exceed half the declared observer rate limit.');
assert(config.positionLimit_rad<=.8*config.observerPositionLimit_rad,id, ...
    'Reference position range cannot exceed 80 percent of the observer position limit.');
assert(abs(config.initialPosition_rad)<=config.positionLimit_rad,id, ...
    'The declared observer initial position must lie inside the reference request range.');
% Divide the two physical bounds before multiplying by time: small A and V
% can cancel without premature underflow in A*Ts.
config.beta=min(1,(config.maxAcceleration_rad_s2/config.maxVelocity_rad_s)*(config.sampleTime_s/2));
assert(isfinite(config.beta) && config.beta>0 && config.beta<=1 && ...
    isfinite(config.maxVelocity_rad_s*config.sampleTime_s) && config.maxVelocity_rad_s*config.sampleTime_s>0,id, ...
    'The motion step and smoothing coefficient must be finite and representable.');
config.assumptions="Causal requested-position shaping from declared observer initial position; generated-reference velocity and acceleration bounds only; no plant truth or fault-mask input; no hardware motion/stop guarantee";
end
