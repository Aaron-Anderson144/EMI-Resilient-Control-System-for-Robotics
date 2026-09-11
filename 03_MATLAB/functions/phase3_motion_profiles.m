function [f, trace] = phase3_motion_profiles(p, s, cfg, options)
%PHASE3_MOTION_PROFILES Opt-in reference wrapper preserving exogenous profiles.
% cfg is the complete Phase 3 configuration. Only its observer declarations
% initialize the reference governor; plant truth and fault masks never enter
% the step helper. At t=0 no time has elapsed, so the shaped reference stays
% at the declared initial position even if the first request differs.
if nargin<4,options=struct();end
assert(isstruct(cfg) && isscalar(cfg) && isfield(cfg,'observer'), ...
    'EMIProject:InvalidPhase3MotionConfiguration','The Phase 3 configuration must contain its observer declaration.');
motion=phase3_motion_configuration(p,cfg.observer,options);
governor=phase3_reference_governor_initialize(motion);
f=phase3_fault_profiles(p,s);requested=f.reference_rad;n=numel(requested);
assert(all(isfinite(requested)) && all(abs(requested)<=motion.positionLimit_rad), ...
    'EMIProject:InvalidReferenceGovernorRequest','A declared reference request, including t=0, exceeds the motion contract.');
slew=repmat(motion.initialPosition_rad,n,1);shaped=slew;velocity=zeros(n,1);acceleration=zeros(n,1);
for k=2:n
    [governor,sample]=phase3_reference_governor_step(governor,requested(k));
    slew(k)=sample.slewReference_rad;shaped(k)=sample.shapedReference_rad;
    velocity(k)=sample.velocity_rad_s;acceleration(k)=sample.acceleration_rad_s2;
end
trace=table(f.time_s,requested,slew,shaped,velocity,acceleration, ...
    'VariableNames',{'Time_s','Requested_rad','SlewReference_rad','ShapedReference_rad','Velocity_rad_s','Acceleration_rad_s2'});
f.requestedReference_rad=requested;f.reference_rad=shaped;
f.motionConfiguration=motion;f.motionTrace=trace;
f.motionGoverned=true;
end
