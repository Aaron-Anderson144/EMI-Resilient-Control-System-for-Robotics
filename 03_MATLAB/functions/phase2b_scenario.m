function scenario = phase2b_scenario(name, params)
%PHASE2B_SCENARIO Return one named Phase 2B fault configuration.

arguments
    name (1,1) string
    params (1,1) struct
end

name = lower(strtrim(name));
validate_parameters(params);

scenario.name = name;
scenario.description = "";

scenario.coupling.capacitiveEnabled = false;
scenario.coupling.inductiveEnabled = false;
scenario.coupling.sharedImpedanceEnabled = false;
scenario.groundOffset.enabled = false;

scenario.communication.fixedDelayEnabled = false;
scenario.communication.jitterEnabled = false;
scenario.communication.packetLossEnabled = false;
if isfield(params,'supply')
    supplyDefaults=params.supply;
else
    % Historical v0.2 parameter archives retain their no-supply behavior.
    supplyDefaults=struct('startTime_s',params.phase2b.source.startTime_s, ...
        'stopTime_s',params.phase2b.source.stopTime_s,'sagVoltage_V',0.5, ...
        'interruptionVoltage_V',0,'controllerStatePolicy',"hold");
end
scenario.supply = struct('enabled',false, ...
    'voltage_V',params.electrical.nominalVoltage_V, ...
    'startTime_s',supplyDefaults.startTime_s,'stopTime_s',supplyDefaults.stopTime_s, ...
    'controllerStatePolicy',supplyDefaults.controllerStatePolicy);

switch name
    case "none"
        scenario.description = "Phase 2B reference case with every new mechanism disabled";
    case "capacitive_coupling"
        scenario.description = "Reduced-order capacitive near-field coupling only";
        scenario.coupling.capacitiveEnabled = true;
    case "inductive_coupling"
        scenario.description = "Reduced-order inductive near-field coupling only";
        scenario.coupling.inductiveEnabled = true;
    case "shared_impedance"
        scenario.description = "Shared-return impedance coupling only";
        scenario.coupling.sharedImpedanceEnabled = true;
    case "combined_coupling"
        scenario.description = "Capacitive, inductive, and shared-return coupling together";
        scenario.coupling.capacitiveEnabled = true;
        scenario.coupling.inductiveEnabled = true;
        scenario.coupling.sharedImpedanceEnabled = true;
    case "ground_offset"
        scenario.description = "Controller/receiver ground-reference offset only";
        scenario.groundOffset.enabled = true;
    case "communication_delay"
        scenario.description = "Fixed deterministic communication delay only";
        scenario.communication.fixedDelayEnabled = true;
    case "communication_jitter"
        scenario.description = "Seeded bounded communication jitter only";
        scenario.communication.jitterEnabled = true;
    case "packet_loss"
        scenario.description = "Seeded packet loss with hold-last reception only";
        scenario.communication.packetLossEnabled = true;
    case {"combined_phase2b", "combined_supply"}
        scenario.description = "Exploratory combination of every Phase 2B mechanism";
        scenario.coupling.capacitiveEnabled = true;
        scenario.coupling.inductiveEnabled = true;
        scenario.coupling.sharedImpedanceEnabled = true;
        scenario.groundOffset.enabled = true;
        scenario.communication.fixedDelayEnabled = true;
        scenario.communication.jitterEnabled = true;
        scenario.communication.packetLossEnabled = true;
        if name=="combined_supply"
            scenario.description="Combined Phase 2B faults and motor-supply interruption";
            scenario.supply.enabled=true;
            scenario.supply.voltage_V=supplyDefaults.interruptionVoltage_V;
        end
    case "supply_sag"
        scenario.description="Reduced motor-bus voltage; controller remains powered";
        scenario.supply.enabled=true;
        scenario.supply.voltage_V=supplyDefaults.sagVoltage_V;
    case {"supply_interruption", "supply_interruption_reset"}
        scenario.description="Motor bus unavailable; plant and load remain active";
        scenario.supply.enabled=true;
        scenario.supply.voltage_V=supplyDefaults.interruptionVoltage_V;
        if name=="supply_interruption_reset"
            scenario.supply.controllerStatePolicy="reset";
        end
    otherwise
        error("phase2b_scenario:UnknownScenario", ...
            "Unknown Phase 2B scenario '%s'.", name);
end

physicalEnabled = scenario.coupling.capacitiveEnabled || ...
    scenario.coupling.inductiveEnabled || ...
    scenario.coupling.sharedImpedanceEnabled;
communicationEnabled = scenario.communication.fixedDelayEnabled || ...
    scenario.communication.jitterEnabled || ...
    scenario.communication.packetLossEnabled;

starts = [];
stops = [];
if physicalEnabled
    starts(end + 1) = params.phase2b.source.startTime_s;
    stops(end + 1) = params.phase2b.source.stopTime_s;
end
if scenario.groundOffset.enabled
    starts(end + 1) = params.phase2b.groundOffset.startTime_s;
    stops(end + 1) = params.phase2b.groundOffset.stopTime_s;
end
if communicationEnabled
    starts(end + 1) = params.phase2b.communication.startTime_s;
    stops(end + 1) = params.phase2b.communication.stopTime_s;
end
if scenario.supply.enabled
    starts(end+1)=scenario.supply.startTime_s;
    stops(end+1)=scenario.supply.stopTime_s;
end

scenario.physicalEnabled = physicalEnabled;
scenario.communicationEnabled = communicationEnabled;
if isempty(starts)
    scenario.analysisStartTime_s = NaN;
    scenario.analysisStopTime_s = NaN;
else
    scenario.analysisStartTime_s = min(starts);
    scenario.analysisStopTime_s = max(stops);
end
end
