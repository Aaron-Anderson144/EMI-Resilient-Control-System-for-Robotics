function validate_encoder_scenario(scenario,params)
%VALIDATE_ENCODER_SCENARIO Validate actual caller-supplied fault settings.
id = 'EMIProject:InvalidEncoderScenario';
localField(scenario,"name",id);
name = scenario.name;
if ~((isstring(name) && isscalar(name) && ~ismissing(name) && strlength(name) > 0) || ...
        (ischar(name) && isrow(name) && ~isempty(name)))
    error(id,'Scenario name must be scalar text.');
end
for group = ["gaussian","sinusoid","countJump","dropout"]
    flag = localField(scenario,group+".enabled",id);
    if ~islogical(flag) || ~isscalar(flag)
        error(id,'Scenario enabled flags must be logical scalars.');
    end
end
for group = ["gaussian","sinusoid","dropout"]
    first = localNumber(scenario,group+".startTime_s",'EMIProject:InvalidFaultWindow');
    last = localNumber(scenario,group+".stopTime_s",'EMIProject:InvalidFaultWindow');
    if first < 0 || last <= first || last > params.simulation.stopTime_s
        error('EMIProject:InvalidFaultWindow','Scenario windows must lie within the simulation.');
    end
end
for path = ["gaussian.standardDeviation_rad","sinusoid.amplitude_rad","sinusoid.frequency_Hz"]
    value = localNumber(scenario,path,'EMIProject:InvalidFaultMagnitude');
    if value < 0, error('EMIProject:InvalidFaultMagnitude','Fault magnitudes must be nonnegative.'); end
end
localNumber(scenario,"sinusoid.phase_rad",'EMIProject:InvalidFaultPhase');
seed = localNumber(scenario,"gaussian.randomSeed",'EMIProject:InvalidRandomSeed');
if seed < 0 || seed > 2^32-1 || seed ~= fix(seed)
    error('EMIProject:InvalidRandomSeed','Random seed must be an integer in [0, 2^32-1].');
end
counts = localNumber(scenario,"countJump.magnitude_counts",'EMIProject:InvalidCountJumpMagnitude');
if abs(counts) > flintmax || counts ~= fix(counts)
    error('EMIProject:InvalidCountJumpMagnitude','Count jump must be a representable signed integer.');
end
when = localNumber(scenario,"countJump.time_s",'EMIProject:InvalidCountJumpTime');
if when < 0 || when > params.simulation.stopTime_s
    error('EMIProject:InvalidCountJumpTime','Count-jump time must lie within the simulation.');
end
behavior = localField(scenario,"dropout.behavior",'EMIProject:UnsupportedDropoutBehavior');
validText = (isstring(behavior) && isscalar(behavior) && ~ismissing(behavior)) || ...
    (ischar(behavior) && isrow(behavior));
if ~validText || string(behavior) ~= "hold-last"
    error('EMIProject:UnsupportedDropoutBehavior','Only hold-last dropout behavior is supported.');
end
if isfield(scenario,'supply'), validate_supply_scenario(scenario.supply,params); end
end

function value = localNumber(scenario,path,id)
value = localField(scenario,path,id);
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
    error(id,'Scenario %s must be a finite real numeric scalar.',path);
end
end

function value = localField(value,path,id)
parts = split(path,'.');
for k = 1:numel(parts)
    if ~isstruct(value) || ~isscalar(value) || ~isfield(value,parts(k))
        error(id,'Scenario field %s is missing or malformed.',path);
    end
    value = value.(parts(k));
end
end
