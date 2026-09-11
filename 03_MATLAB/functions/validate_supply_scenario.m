function validate_supply_scenario(supply,params)
%VALIDATE_SUPPLY_SCENARIO Validate a present supply configuration.
% Callers may omit scenario.supply entirely for a legacy, supply-enabled run.
if ~isstruct(supply) || ~isscalar(supply) || ...
        ~all(isfield(supply,{'enabled','voltage_V','startTime_s','stopTime_s','controllerStatePolicy'}))
    error('EMIProject:InvalidSupplyScenario','Supply scenario must contain the documented scalar fields.');
end
if ~islogical(supply.enabled) || ~isscalar(supply.enabled)
    error('EMIProject:InvalidSupplyScenario','Supply enabled must be a logical scalar.');
end
voltage = localNumber(supply.voltage_V,'EMIProject:InvalidSupplyVoltage');
if voltage < 0 || voltage > params.electrical.nominalVoltage_V
    error('EMIProject:InvalidSupplyVoltage','Supply voltage must lie between zero and nominal voltage.');
end
startTime = localNumber(supply.startTime_s,'EMIProject:InvalidSupplyWindow');
stopTime = localNumber(supply.stopTime_s,'EMIProject:InvalidSupplyWindow');
if startTime < 0 || stopTime <= startTime || stopTime > params.simulation.stopTime_s
    error('EMIProject:InvalidSupplyWindow','Supply window must lie within the simulation and have positive duration.');
end
policy = supply.controllerStatePolicy;
validText = (isstring(policy) && isscalar(policy) && ~ismissing(policy)) || ...
    (ischar(policy) && isrow(policy));
if ~validText || ~any(string(policy) == ["hold","reset"])
    error('EMIProject:InvalidSupplyStatePolicy','Controller state policy must be hold or reset.');
end
end

function value = localNumber(value,id)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
    error(id,'Supply numbers must be finite real numeric scalars.');
end
end
