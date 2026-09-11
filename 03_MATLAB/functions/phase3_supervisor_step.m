function [next, settings] = phase3_supervisor_step(state, input, cfg)
%PHASE3_SUPERVISOR_STEP Pure, current-sample supervisory state transition.
% No packet within the detector's grace period is neutral unless alarm is
% asserted. Missing credible observations interrupt all recovery evidence.
% safe_stop commands zero voltage; it makes no physical safety claim.
validateConfiguration(cfg);
validateState(state);
validateInput(input);
next = state;

if ~input.supplyHealthy || ~input.estimateUsable
    next = enterStop(next);
elseif state.mode == 4
    next.badCount = 0;
    next.nonNormalCount = 0;
    if ~input.alarm && input.credibleFresh
        next.goodCount = min(state.goodCount+1,cfg.safeStopRelease_samples);
    else
        next.goodCount = 0;
    end
    if input.resetRequest && next.goodCount >= cfg.safeStopRelease_samples
        next.mode = 3;
        next.goodCount = 1; % Current credible sample anchors recovery dwell.
        next.nonNormalCount = 1;
    end
else
    if input.alarm
        next.badCount = min(state.badCount+1,cfg.badPersistence_samples);
        next.goodCount = 0;
    else
        next.badCount = 0;
        if input.credibleFresh
            next.goodCount = min(state.goodCount+1,max( ...
                cfg.recoveryQualification_samples,cfg.recoveryDwell_samples));
        else
            next.goodCount = 0;
        end
    end
    if state.mode ~= 0
        next.nonNormalCount = state.nonNormalCount+1;
    end
    % A non-normal timeout has priority even if recovery could finish now.
    if state.mode ~= 0 && next.nonNormalCount >= cfg.maxNonNormalTime_samples
        next = enterStop(next);
    else
        switch state.mode
            case 0
                next.goodCount = 0;
                if input.alarm
                    next.mode = 1;
                    next.nonNormalCount = 1;
                end
            case 1
                if next.badCount >= cfg.badPersistence_samples
                    next.mode = 2;
                elseif next.goodCount >= cfg.recoveryQualification_samples
                    next.mode = 3;
                    next.goodCount = 1;
                end
            case 2
                if next.goodCount >= cfg.recoveryQualification_samples
                    next.mode = 3;
                    next.goodCount = 1;
                end
            case 3
                if input.alarm
                    next.mode = 2;
                elseif next.goodCount >= cfg.recoveryDwell_samples
                    next.mode = 0;
                    next.badCount = 0;
                    next.goodCount = 0;
                    next.nonNormalCount = 0;
                end
        end
    end
end

modeNames = ["normal","suspected","degraded","recovery","safe_stop"];
settings.mode = next.mode;
settings.modeName = modeNames(next.mode+1);
settings.driveEnabled = next.mode ~= 4;
settings.useDegradedGains = next.mode == 2 || next.mode == 3;
settings.rebaseController = next.mode ~= state.mode;
settings.transitionReason = "none";
if settings.rebaseController
    if ~input.supplyHealthy
        settings.transitionReason = "supply_low";
    elseif ~input.estimateUsable
        settings.transitionReason = "estimate_unusable";
    elseif next.mode == 4
        settings.transitionReason = "qualification_timeout";
    elseif state.mode == 4
        settings.transitionReason = "qualified_reset";
    elseif input.alarm
        settings.transitionReason = "alarm";
    else
        settings.transitionReason = "credible_dwell";
    end
end
settings.referenceTimeConstant_s = 0;
if settings.useDegradedGains
    settings.referenceTimeConstant_s = cfg.referenceTimeConstant_s;
end
if next.mode == 0
    settings.voltageLimitScale = cfg.normalVoltageLimitScale;
    settings.commandSlewRate_V_s = cfg.normalSlewRate_V_s;
else
    settings.commandSlewRate_V_s = cfg.nonNormalSlewRate_V_s;
    if next.mode == 1
        settings.voltageLimitScale = cfg.suspectedVoltageLimitScale;
    elseif next.mode == 4
        settings.voltageLimitScale = 0;
    else
        settings.voltageLimitScale = cfg.degradedVoltageLimitScale;
    end
end
end

function state = enterStop(state)
state.mode = 4;
state.badCount = 0;
state.goodCount = 0;
state.nonNormalCount = 0;
end

function validateConfiguration(cfg)
id = 'EMIProject:InvalidPhase3SupervisorConfiguration';
derived = {'badPersistence_samples','recoveryQualification_samples', ...
    'recoveryDwell_samples','maxNonNormalTime_samples','safeStopRelease_samples'};
try
    overrides = rmfield(cfg,[{'sampleTime_s'},derived]);
    expected = phase3_supervisor_configuration(cfg.sampleTime_s,overrides);
    if ~isequal(cfg,expected)
        error(id,'Derived policy counts do not match the configured durations.');
    end
catch caught
    error(id,'Invalid supervisor configuration: %s',caught.message);
end
end

function validateInput(input)
id = 'EMIProject:InvalidPhase3SupervisorInput';
names = {'alarm','credibleFresh','supplyHealthy','estimateUsable','resetRequest'};
if ~isstruct(input) || ~isscalar(input)
    error(id,'Supervisor input must be a scalar structure.');
end
for k = 1:numel(names)
    if ~isfield(input,names{k}) || ~islogical(input.(names{k})) || ~isscalar(input.(names{k}))
        error(id,'%s must be a logical scalar.',names{k});
    end
end
end

function validateState(state)
id = 'EMIProject:InvalidPhase3SupervisorState';
names = {'mode','badCount','goodCount','nonNormalCount'};
if ~isstruct(state) || ~isscalar(state)
    error(id,'Supervisor state must be a scalar structure.');
end
for k = 1:numel(names)
    if ~isfield(state,names{k})
        error(id,'Missing state field: %s.',names{k});
    end
    value = state.(names{k});
    if ~isfloat(value) || ~isscalar(value) || ~isreal(value) || ...
            ~isfinite(value) || value < 0 || value ~= fix(value) || value > flintmax-2
        error(id,'%s must be a finite nonnegative integer scalar.',names{k});
    end
end
if state.mode > 4
    error(id,'Mode must be one of the stable IDs 0 through 4.');
end
end
