function state = phase3_reference_governor_initialize(config)
%PHASE3_REFERENCE_GOVERNOR_INITIALIZE Declared position, zero reference speed.
id='EMIProject:InvalidPhase3MotionConfiguration';
assert(isstruct(config) && isscalar(config),id,'A scalar motion configuration is required.');
positive={'maxVelocity_rad_s','maxAcceleration_rad_s2','positionLimit_rad', ...
    'sampleTime_s','observerRateLimit_rad_s','observerPositionLimit_rad','beta'};
for k=1:numel(positive)
    name=positive{k};
    assert(isfield(config,name) && localScalar(config.(name)) && config.(name)>0,id, ...
        '%s must be a positive finite floating-point scalar.',name);
    config.(name)=double(config.(name));
end
assert(isfield(config,'initialPosition_rad') && localScalar(config.initialPosition_rad),id, ...
    'The declared initial position must be finite and real.');
config.initialPosition_rad=double(config.initialPosition_rad);
expected=min(1,(config.maxAcceleration_rad_s2/config.maxVelocity_rad_s)*(config.sampleTime_s/2));
step=config.maxVelocity_rad_s*config.sampleTime_s;
assert(config.maxVelocity_rad_s<=.5*config.observerRateLimit_rad_s && ...
    config.positionLimit_rad<=.8*config.observerPositionLimit_rad && ...
    abs(config.initialPosition_rad)<=config.positionLimit_rad && ...
    isfinite(expected) && expected>0 && config.beta<=1 && config.beta==expected && ...
    isfinite(step) && step>0,id,'Motion limits, initial position or derived smoothing coefficient are inconsistent.');
state=struct('config',config,'sampleIndex',0,'slewReference_rad',config.initialPosition_rad, ...
    'shapedReference_rad',config.initialPosition_rad,'velocity_rad_s',0);
end

function valid=localScalar(value)
valid=isfloat(value) && isreal(value) && isscalar(value) && isfinite(value);
end
