function [cfg, policy] = phase3_tuning_configuration(params, options)
%PHASE3_TUNING_CONFIGURATION Bounded controller-only development candidates.
% Default output equals phase3_configuration(params). Only degraded PIDF
% gains and the four listed supervisory actuation settings may change.
% Observer, reference reacquisition, normal control, anti-windup, supply
% threshold, persistence, dwell, latch and reset policy remain unchanged.
if nargin<2,options=struct();end
id='EMIProject:InvalidPhase3TuningConfiguration';
assert(isstruct(options) && isscalar(options),id,'Tuning options must be a scalar structure.');
policy=struct('degradedBandwidthRatio',.5,'referenceTimeConstant_s',.050, ...
    'suspectedVoltageLimitScale',.5,'degradedVoltageLimitScale',.25, ...
    'nonNormalSlewRate_V_s',200);
allowed=fieldnames(policy);names=fieldnames(options);
assert(all(ismember(names,allowed)),id,'Only the five declared controller tuning options may be changed.');
for k=1:numel(names),policy.(names{k})=options.(names{k});end
for k=1:numel(allowed)
    name=allowed{k};value=policy.(name);
    assert(isfloat(value) && isreal(value) && isscalar(value) && isfinite(value),id, ...
        '%s must be a finite real double or single scalar.',name);
    policy.(name)=double(value);
end
assert(policy.degradedBandwidthRatio>=.25 && policy.degradedBandwidthRatio<=1,id, ...
    'Degraded bandwidth ratio must lie in [0.25,1].');
assert(policy.referenceTimeConstant_s>=0 && policy.referenceTimeConstant_s<=.1,id, ...
    'Reference time constant must lie in [0,0.1] seconds.');
assert(policy.degradedVoltageLimitScale>=0 && ...
    policy.degradedVoltageLimitScale<=policy.suspectedVoltageLimitScale && ...
    policy.suspectedVoltageLimitScale<=1,id, ...
    'Voltage scales must satisfy 0 <= degraded <= suspected <= 1.');
assert(policy.nonNormalSlewRate_V_s>0,id,'Nonnormal slew rate must be positive.');
% Validate options before any plant/controller design. Invalid options must
% not trigger a costly tuning operation or be hidden by invalid parameters.
cfg=phase3_configuration(params);
if policy.degradedBandwidthRatio==1
    cfg.control.degraded=cfg.control.normal;
elseif policy.degradedBandwidthRatio~=.5
    degradedParams=params;
    degradedParams.control.targetBandwidth_rad_s= ...
        params.control.targetBandwidth_rad_s*policy.degradedBandwidthRatio;
    controller=design_baseline_controller(degradedParams);
    cfg.control.degraded=struct('Kp',controller.continuous.Kp, ...
        'Ki',controller.continuous.Ki,'Kd',controller.continuous.Kd,'Tf',controller.continuous.Tf);
end
cfg.supervisor.referenceTimeConstant_s=policy.referenceTimeConstant_s;
cfg.supervisor.suspectedVoltageLimitScale=policy.suspectedVoltageLimitScale;
cfg.supervisor.degradedVoltageLimitScale=policy.degradedVoltageLimitScale;
cfg.supervisor.nonNormalSlewRate_V_s=policy.nonNormalSlewRate_V_s;
% Lossless IEEE-double encodings give a stable, field-order-independent ID.
% Remove trailing zero hex digits only; separators preserve each field.
values=cellfun(@(name)policy.(name),allowed);
parts=regexprep(cellstr(num2hex(values(:))),'0+$','');
parts(cellfun(@isempty,parts))={'0'};
policy.id="phase3_tuning_"+string(strjoin(parts,'_'));
end
