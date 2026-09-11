function supply = supply_fault_profile(time_s, params, scenario)
%SUPPLY_FAULT_PROFILE Sampled motor-bus voltage with half-open fault windows.
% Controller and sensor power remain available. A zero drive bus inhibits
% applied voltage while retaining plant dynamics and the external load.
% During zero supply the controller's next state is held or reset to zero;
% this is an explicit software policy, not an MCU brownout/reset simulation.
validate_parameters(params);
validateattributes(time_s,{'numeric'},{'real','vector','nonempty','finite'});
time_s=time_s(:);
assert(all(diff(time_s)>0),'EMIProject:InvalidTimeVector', ...
    'Supply time must be strictly increasing.');
supply.voltage_V=repmat(params.electrical.nominalVoltage_V,size(time_s));
supply.configuredWindowActive=false(size(time_s));
supply.controllerStatePolicy="hold";
if isfield(scenario,'supply')
    fault=scenario.supply;
    validate_supply_scenario(fault,params);
    supply.controllerStatePolicy=string(fault.controllerStatePolicy);
    if fault.enabled
        supply.configuredWindowActive=time_s>=fault.startTime_s & time_s<fault.stopTime_s;
        supply.voltage_V(supply.configuredWindowActive)=fault.voltage_V;
    end
end
supply.commandLimit_V=min(params.control.voltageLimit_V,supply.voltage_V);
supply.driveAvailable=supply.voltage_V>0;
end
