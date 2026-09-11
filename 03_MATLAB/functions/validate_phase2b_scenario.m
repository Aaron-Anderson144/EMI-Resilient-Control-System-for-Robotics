function validate_phase2b_scenario(scenario,params)
%VALIDATE_PHASE2B_SCENARIO Check flags, metric window and optional supply.
id = 'EMIProject:InvalidPhase2BScenario';
paths = ["coupling.capacitiveEnabled","coupling.inductiveEnabled", ...
    "coupling.sharedImpedanceEnabled","groundOffset.enabled", ...
    "communication.fixedDelayEnabled","communication.jitterEnabled", ...
    "communication.packetLossEnabled","physicalEnabled","communicationEnabled"];
flags = false(size(paths));
for k = 1:numel(paths)
    value = localField(scenario,paths(k),id);
    if ~islogical(value) || ~isscalar(value)
        error(id,'Scenario %s must be a logical scalar.',paths(k));
    end
    flags(k) = value;
end
name = localField(scenario,"name",id);
if ~((isstring(name) && isscalar(name) && ~ismissing(name) && strlength(name) > 0) || ...
        (ischar(name) && isrow(name) && ~isempty(name)))
    error(id,'Scenario name must be nonempty scalar text.');
end
if flags(8) ~= any(flags(1:3)) || flags(9) ~= any(flags(5:7))
    error(id,'Derived physical/communication flags must match the enabled mechanisms.');
end
supplyEnabled = false;
if isfield(scenario,'supply')
    validate_supply_scenario(scenario.supply,params);
    supplyEnabled = scenario.supply.enabled;
end
first = localField(scenario,"analysisStartTime_s",id);
last = localField(scenario,"analysisStopTime_s",id);
if ~isnumeric(first) || ~isscalar(first) || ~isreal(first) || ...
        ~isnumeric(last) || ~isscalar(last) || ~isreal(last)
    error(id,'Analysis bounds must be real numeric scalars.');
end
hasFault = any(flags(1:7)) || supplyEnabled;
if ~hasFault && isnan(first) && isnan(last), return; end
if ~isfinite(first) || ~isfinite(last) || first < 0 || last <= first || ...
        last > params.simulation.stopTime_s
    error(id,'An active scenario requires finite, ordered analysis bounds within the simulation.');
end
% Wider common comparison windows are allowed, including physical_only.
starts = []; stops = [];
if flags(8)
    starts(end+1) = params.phase2b.source.startTime_s;
    stops(end+1) = params.phase2b.source.stopTime_s;
end
if flags(4)
    starts(end+1) = params.phase2b.groundOffset.startTime_s;
    stops(end+1) = params.phase2b.groundOffset.stopTime_s;
end
if flags(9)
    starts(end+1) = params.phase2b.communication.startTime_s;
    stops(end+1) = params.phase2b.communication.stopTime_s;
end
if supplyEnabled
    starts(end+1) = scenario.supply.startTime_s;
    stops(end+1) = scenario.supply.stopTime_s;
end
if hasFault && (first > min(starts) || last < max(stops))
    error(id,'Analysis bounds must enclose every enabled fault window.');
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
