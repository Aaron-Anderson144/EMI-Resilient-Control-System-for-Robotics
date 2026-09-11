function config = phase3_observer_configuration(params, overrides)
%PHASE3_OBSERVER_CONFIGURATION Assumed-model observer and provisional gates.
% All limits are software-development assumptions, not identified hardware
% limits. Overrides replace only the explicitly listed tunable fields.
arguments
    params (1,1) struct
    overrides (1,1) struct = struct()
end
validate_parameters(params);
config.sampleTime_s = params.control.sampleTime_s;
config.historyDuration_s = .032;
config.maxMeasurementAge_s = .020;
config.maxPredictionTime_s = .250;
config.positionLimit_rad = pi;
config.rateLimit_rad_s = 25;
config.residualTrip_rad = deg2rad(.5);
config.residualClear_rad = deg2rad(.25);
config.assumedLoadTorque_Nm = params.mechanical.nominalLoadTorque_Nm;
config.initialEstimate = zeros(3,1);
config.poleRates_rad_s = [80,100,120];
tunable = fieldnames(config);
tunable(strcmp(tunable,'sampleTime_s')) = [];
names = fieldnames(overrides);
assert(all(ismember(names,tunable)), 'EMIProject:InvalidObserverConfiguration', ...
    'Observer overrides must name declared tunable fields; sample time comes from params.');
for k=1:numel(names)
    config.(names{k}) = overrides.(names{k});
end
plant = ss(c2d(actuator_state_space(params),config.sampleTime_s,'zoh'));
[config.A,config.B] = ssdata(plant);
config.C = [1,0,0];
% Validate tunables before they participate in pole or capacity arithmetic.
validate_phase3_observer_configuration(config,false);
numericFields=fieldnames(config);
for k=1:numel(numericFields)
    if isnumeric(config.(numericFields{k}))
        config.(numericFields{k})=double(config.(numericFields{k}));
    end
end
config.initialEstimate = double(config.initialEstimate(:));
config.poleRates_rad_s = double(config.poleRates_rad_s(:).');
config.targetDiscretePoles = exp(-config.poleRates_rad_s*config.sampleTime_s);
assert(all(config.targetDiscretePoles>0 & config.targetDiscretePoles<1) && ...
    numel(unique(config.targetDiscretePoles))==3, ...
    'EMIProject:InvalidObserverConfiguration','Observer poles must be distinct and representable inside the unit circle.');
% Predict then correct: posterior error evolves as (I-K*C)*A.
config.correctionGain = place(config.A',(config.C*config.A)',config.targetDiscretePoles)';
config.historyCapacity = ceil(config.historyDuration_s/config.sampleTime_s)+1;
config.assumptions = "Three-state assumed actuator; measured applied voltage is known; constant assumed load; declared initial estimate; timestamp integrity is assumed; provisional thresholds are not hardware limits";
validate_phase3_observer_configuration(config);
end
