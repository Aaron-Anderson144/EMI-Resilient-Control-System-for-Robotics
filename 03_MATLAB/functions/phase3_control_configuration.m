function cfg = phase3_control_configuration(params)
%PHASE3_CONTROL_CONFIGURATION Tune normal and half-bandwidth PIDF policies.
% The gains remain assumed-model designs, not hardware-qualified settings.
validate_parameters(params);
rejectIntegerClasses(params);
normal = design_baseline_controller(params);
degradedParams = params;
degradedParams.control.targetBandwidth_rad_s = ...
    params.control.targetBandwidth_rad_s*0.5;
degraded = design_baseline_controller(degradedParams);
cfg.sampleTime_s = params.control.sampleTime_s;
cfg.nominalCommandLimit_V = min(params.control.voltageLimit_V, ...
    params.electrical.nominalVoltage_V);
cfg.antiWindupTrackingTime_s = 0.020;
cfg.antiWindupGain = -expm1(-cfg.sampleTime_s/cfg.antiWindupTrackingTime_s);
cfg.normal = coefficients(normal.continuous);
cfg.degraded = coefficients(degraded.continuous);
end

function gains = coefficients(controller)
gains.Kp = controller.Kp;
gains.Ki = controller.Ki;
gains.Kd = controller.Kd;
gains.Tf = controller.Tf;
end

function rejectIntegerClasses(value)
names = fieldnames(value);
for k = 1:numel(names)
    item = value.(names{k});
    if isstruct(item)
        rejectIntegerClasses(item);
    elseif isnumeric(item) && ~isfloat(item)
        error('EMIProject:InvalidPhase3ControlConfiguration', ...
            'Phase 3 numeric configuration fields must use double or single scalars.');
    end
end
end
