function validate_phase3_scenario(scenario, params)
%VALIDATE_PHASE3_SCENARIO Validate the declared Phase 3 simulation fixture.
% Bias/packet windows can extend beyond the record for censoring. A disabled
% packet window has two +Inf bounds. Point events can be +Inf or after the
% record; the profile generator must leave those events unexposed, never
% move them to the final sample. Existing encoder/Phase 2B contracts remain.
id='EMIProject:InvalidPhase3Scenario';
assert(isstruct(scenario) && isscalar(scenario),id,'Phase 3 scenario must be a scalar structure.');
validate_parameters(params);
required={'name','description','expectation','encoder','phase2b','actualParameters', ...
    'initialPlantState','referenceTimes_s','referenceValues_rad','loadTorque_Nm', ...
    'assumedLoadTorque_Nm','benignNoiseStandardDeviation_rad','noiseSeed', ...
    'bias_rad','biasStartTime_s','biasStopTime_s','rampRate_rad_s', ...
    'packetDropStartTime_s','packetDropStopTime_s','nonfiniteSampleTime_s','resetRequestTime_s'};
for k=1:numel(required)
    assert(isfield(scenario,required{k}),id,'Required scenario field is missing: %s.',required{k});
end
assert(localText(scenario.name) && strlength(strtrim(string(scenario.name)))>0,id, ...
    'Scenario name must be nonempty scalar text.');
assert(localText(scenario.description),id,'Scenario description must be scalar text; empty is allowed.');
assert(localText(scenario.expectation) && any(string(scenario.expectation)== ...
    ["clean","detect","observe","unobservable"]),id,'Unsupported scenario expectation.');
assert(isstruct(scenario.actualParameters) && isscalar(scenario.actualParameters),id, ...
    'Actual parameters must be a scalar parameter structure.');
validate_parameters(scenario.actualParameters);
assert(scenario.actualParameters.control.sampleTime_s==params.control.sampleTime_s,id, ...
    'Actual and nominal plant sample times must match.');
assert(localFiniteArray(scenario.initialPlantState) && ...
    isequal(size(scenario.initialPlantState),[3,1]),id,'Initial plant state must be a finite real three-by-one vector.');
times=scenario.referenceTimes_s;values=scenario.referenceValues_rad;
assert(localFiniteArray(times) && isvector(times) && numel(times)>=2 && ...
    localFiniteArray(values) && isvector(values) && numel(values)==numel(times),id, ...
    'Reference times and values must be equal-length finite real vectors with at least two knots.');
times=double(times(:));
assert(times(1)==0 && all(diff(times)>0),id,'Reference knots must start at zero and increase strictly.');
for name=["loadTorque_Nm","assumedLoadTorque_Nm","benignNoiseStandardDeviation_rad", ...
        "bias_rad","rampRate_rad_s","noiseSeed"]
    assert(localFiniteScalar(scenario.(name)),id,'Scenario %s must be a finite real numeric scalar.',name);
end
assert(scenario.benignNoiseStandardDeviation_rad>=0,id,'Benign noise standard deviation cannot be negative.');
seed=double(scenario.noiseSeed);
assert(seed>=0 && seed<=2^32-1 && seed==fix(seed),id,'Noise seed must be an integer in [0,2^32-1].');
localWindow(scenario.biasStartTime_s,scenario.biasStopTime_s,false,id,'bias');
localWindow(scenario.packetDropStartTime_s,scenario.packetDropStopTime_s,true,id,'packet drop');
for name=["nonfiniteSampleTime_s","resetRequestTime_s"]
    value=scenario.(name);
    assert(localNonnegativeTime(value),id, ...
        'Point event %s must be a nonnegative finite time or +Inf (disabled).',name);
end
validate_encoder_scenario(scenario.encoder,params);
validate_phase2b_scenario(scenario.phase2b,params);
end

function localWindow(first,last,allowDisabled,id,label)
assert(localNonnegativeTime(first) && localNonnegativeTime(last),id, ...
    'The %s window needs nonnegative numeric scalar bounds.',label);
if allowDisabled && isinf(first) && isinf(last),return;end
assert(isfinite(first) && isfinite(last) && double(last)>double(first),id, ...
    'The %s window must have finite increasing bounds; only a packet window with two +Inf bounds is disabled.',label);
end

function valid=localNonnegativeTime(value)
valid=isnumeric(value) && isreal(value) && isscalar(value) && ~isnan(value) && value>=0;
end

function valid=localFiniteScalar(value)
valid=isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
end

function valid=localFiniteArray(value)
valid=isnumeric(value) && isreal(value) && all(isfinite(value),'all');
end

function valid=localText(value)
valid=(isstring(value) && isscalar(value) && ~ismissing(value)) || ...
    (ischar(value) && (isrow(value) || isempty(value)));
end
