function cfg = phase3_supervisor_configuration(sampleTime_s, overrides)
%PHASE3_SUPERVISOR_CONFIGURATION Explicit, assumed supervisory policy.
% Durations are elapsed time: N consecutive observations span (N-1)*Ts.
% Thresholds therefore include the first observation and cannot fire early.
if nargin < 2
    overrides = struct();
end
cfg.sampleTime_s = sampleTime_s;
cfg.badPersistence_s = 0.005;
cfg.recoveryQualification_s = 0.010;
cfg.recoveryDwell_s = 0.050;
cfg.maxNonNormalTime_s = 0.500;
cfg.safeStopRelease_s = 0.050;
cfg.referenceTimeConstant_s = 0.050;
cfg.normalVoltageLimitScale = 1.0;
cfg.suspectedVoltageLimitScale = 0.5;
cfg.degradedVoltageLimitScale = 0.25;
cfg.normalSlewRate_V_s = 10000;
cfg.nonNormalSlewRate_V_s = 200;
id = 'EMIProject:InvalidPhase3SupervisorConfiguration';
if ~isstruct(overrides) || ~isscalar(overrides)
    error(id,'Overrides must be a scalar structure.');
end
names = fieldnames(overrides);
for k = 1:numel(names)
    name = names{k};
    if strcmp(name,'sampleTime_s') || ~isfield(cfg,name)
        error(id,'Unknown or immutable configuration field: %s.',name);
    end
    cfg.(name) = overrides.(name);
end
names = fieldnames(cfg);
for k = 1:numel(names)
    value = cfg.(names{k});
    if ~isfloat(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value)
        error(id,'%s must be a finite real double or single scalar.',names{k});
    end
end
durations = {'badPersistence','recoveryQualification','recoveryDwell', ...
    'maxNonNormalTime','safeStopRelease'};
if cfg.sampleTime_s <= 0 || cfg.referenceTimeConstant_s < 0 || ...
        cfg.normalSlewRate_V_s <= 0 || cfg.nonNormalSlewRate_V_s <= 0
    error(id,'Sample time and slew rates must be positive; reference time constant cannot be negative.');
end
scales = [cfg.degradedVoltageLimitScale,cfg.suspectedVoltageLimitScale, ...
    cfg.normalVoltageLimitScale];
if any(scales < 0 | scales > 1) || any(diff(scales) < 0)
    error(id,'Voltage scales must satisfy 0 <= degraded <= suspected <= normal <= 1.');
end
for k = 1:numel(durations)
    seconds = cfg.([durations{k},'_s']);
    ratio = seconds/cfg.sampleTime_s;
    if seconds <= 0 || ~isfinite(ratio) || ratio > flintmax-2
        error(id,'Policy durations must be positive and have representable sample counts.');
    end
    nearest = round(ratio);
    if abs(ratio-nearest) <= 32*eps(max(1,abs(ratio)))
        ratio = nearest;
    end
    cfg.([durations{k},'_samples']) = max(1,ceil(ratio))+1;
end
end
