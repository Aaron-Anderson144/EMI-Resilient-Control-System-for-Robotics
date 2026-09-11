function [next, command_V, diagnostics] = phase3_control_step(state, input, settings, cfg)
%PHASE3_CONTROL_STEP Pure PIDF, mode transfer, amplitude/slew bounds and AW.
% Normal unconstrained operation is the Tustin discretization of the tuned
% continuous parallel PIDF. The posterior observer estimate is supplied by
% the caller; no fault mask or plant truth is available to this function.
% A hard stop applies zero motor voltage, not a brake or open circuit.
validateAll(state,input,settings,cfg);
Ts = cfg.sampleTime_s;
if settings.useDegradedGains
    gains = cfg.degraded;
else
    gains = cfg.normal;
end
if settings.referenceTimeConstant_s > 0
    alpha = -expm1(-Ts/settings.referenceTimeConstant_s);
    filteredReference = state.filteredReference_rad + ...
        alpha*(input.reference_rad-state.filteredReference_rad);
else
    filteredReference = input.reference_rad;
end
error_rad = filteredReference-input.feedback_rad;
limit_V = min(input.availableLimit_V, ...
    cfg.nominalCommandLimit_V*settings.voltageLimitScale);
rebase = settings.rebaseController || state.previousMode ~= settings.mode || ...
    state.useDegradedGains ~= settings.useDegradedGains;
hardStop = ~settings.driveEnabled || input.availableLimit_V == 0;
if hardStop
    % Track zero output while stopped so a release can start at zero.
    integral = -gains.Kp*error_rad;
    derivative = 0;
    rawCommand = 0;
    slewCommand = 0;
    command_V = 0;
elseif rebase
    derivative = 0;
    integral = state.previousCommand_V-gains.Kp*error_rad;
    rawCommand = state.previousCommand_V;
    slewCommand = rawCommand;
    command_V = min(max(slewCommand,-limit_V),limit_V);
else
    integral = state.integral_V + ...
        gains.Ki*Ts/2*(error_rad+state.previousError_rad);
    denominator = 2*gains.Tf+Ts;
    derivative = (2*gains.Tf-Ts)/denominator*state.derivative_V + ...
        2*gains.Kd/denominator*(error_rad-state.previousError_rad);
    rawCommand = gains.Kp*error_rad+integral+derivative;
    slewStep_V = settings.commandSlewRate_V_s*Ts;
    slewCommand = min(max(rawCommand,state.previousCommand_V-slewStep_V), ...
        state.previousCommand_V+slewStep_V);
    % The available bus and a newly tighter mode limit override slew bounds.
    command_V = min(max(slewCommand,-limit_V),limit_V);
end
trackingCorrection = cfg.antiWindupGain*(command_V-rawCommand);
next = state;
next.integral_V = integral+trackingCorrection;
next.derivative_V = derivative;
next.previousError_rad = error_rad;
next.filteredReference_rad = filteredReference;
next.previousCommand_V = command_V;
next.previousMode = settings.mode;
next.useDegradedGains = settings.useDegradedGains;
if any(~isfinite([error_rad,rawCommand,command_V,next.integral_V, ...
        derivative,filteredReference]))
    error('EMIProject:Phase3ControlOverflow','Controller arithmetic exceeded finite numeric range.');
end
diagnostics.mode = settings.mode;
diagnostics.filteredReference_rad = filteredReference;
diagnostics.error_rad = error_rad;
diagnostics.rawCommand_V = rawCommand;
diagnostics.appliedCommand_V = command_V;
diagnostics.commandLimit_V = limit_V;
diagnostics.slewLimited = slewCommand ~= rawCommand;
diagnostics.amplitudeLimited = command_V ~= slewCommand;
diagnostics.hardStop = hardStop;
diagnostics.rebased = rebase || hardStop;
diagnostics.antiWindupCorrection_V = trackingCorrection;
diagnostics.integral_V = next.integral_V;
diagnostics.derivative_V = derivative;
end

function validateAll(state,input,settings,cfg)
id = 'EMIProject:InvalidPhase3ControlConfiguration';
requireStruct(cfg,id);
requireNumeric(cfg,{'sampleTime_s','nominalCommandLimit_V', ...
    'antiWindupTrackingTime_s','antiWindupGain'},id);
if cfg.sampleTime_s <= 0 || cfg.nominalCommandLimit_V <= 0 || ...
        cfg.antiWindupTrackingTime_s <= 0 || cfg.antiWindupGain <= 0 || ...
        cfg.antiWindupGain > 1 || abs(cfg.antiWindupGain- ...
        (-expm1(-cfg.sampleTime_s/cfg.antiWindupTrackingTime_s))) > 8*eps
    error(id,'Controller time constants, voltage bound or derived AW gain are invalid.');
end
for name = ["normal","degraded"]
    if ~isfield(cfg,name)
        error(id,'Missing controller gain set: %s.',name);
    end
    requireStruct(cfg.(name),id);
    requireNumeric(cfg.(name),{'Kp','Ki','Kd','Tf'},id);
    if cfg.(name).Tf < 0
        error(id,'Derivative filter time constants cannot be negative.');
    end
end
id = 'EMIProject:InvalidPhase3ControlInput';
requireStruct(input,id);
requireNumeric(input,{'reference_rad','feedback_rad','availableLimit_V'},id);
if input.availableLimit_V < 0
    error(id,'Available voltage limit cannot be negative.');
end
id = 'EMIProject:InvalidPhase3ControlState';
requireStruct(state,id);
requireNumeric(state,{'integral_V','derivative_V','previousError_rad', ...
    'filteredReference_rad','previousCommand_V','previousMode'},id);
requireLogical(state,{'useDegradedGains'},id);
if state.previousMode < 0 || state.previousMode > 4 || state.previousMode ~= fix(state.previousMode)
    error(id,'Previous mode must be an integer from 0 through 4.');
end
id = 'EMIProject:InvalidPhase3ControlSettings';
requireStruct(settings,id);
requireNumeric(settings,{'mode','voltageLimitScale', ...
    'referenceTimeConstant_s','commandSlewRate_V_s'},id);
requireLogical(settings,{'driveEnabled','useDegradedGains','rebaseController'},id);
if settings.mode < 0 || settings.mode > 4 || settings.mode ~= fix(settings.mode) || ...
        settings.voltageLimitScale < 0 || settings.voltageLimitScale > 1 || ...
        settings.referenceTimeConstant_s < 0 || settings.commandSlewRate_V_s <= 0 || ...
        settings.driveEnabled ~= (settings.mode ~= 4) || ...
        settings.useDegradedGains ~= any(settings.mode == [2,3])
    error(id,'Mode settings are inconsistent or outside their allowed ranges.');
end
end

function requireStruct(value,id)
if ~isstruct(value) || ~isscalar(value)
    error(id,'Inputs, state and configurations must be scalar structures.');
end
end

function requireNumeric(value,names,id)
for k = 1:numel(names)
    if ~isfield(value,names{k})
        error(id,'Missing field: %s.',names{k});
    end
    x = value.(names{k});
    if ~isfloat(x) || ~isscalar(x) || ~isreal(x) || ~isfinite(x)
        error(id,'%s must be a finite real double or single scalar.',names{k});
    end
end
end

function requireLogical(value,names,id)
for k = 1:numel(names)
    if ~isfield(value,names{k}) || ~islogical(value.(names{k})) || ~isscalar(value.(names{k}))
        error(id,'%s must be a logical scalar.',names{k});
    end
end
end
