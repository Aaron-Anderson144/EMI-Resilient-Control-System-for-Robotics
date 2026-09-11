function [state, sample] = phase3_reference_governor_step(state, requested_rad)
%PHASE3_REFERENCE_GOVERNOR_STEP One elapsed sample of causal request shaping.
% q_next = clip(request,q +/- V*Ts); r_next = r + beta*(q_next-r).
% Let w=(q_next-q)/Ts. The exact-arithmetic recurrence is
% v_next=(1-beta)*v_previous+beta*w. Thus |v|<=V and
% |a|<=2*beta*V/Ts<=A. Both q and r remain in the convex hull of the
% declared initial position and requests seen so far, including retargeting.
% An invalid request is a software-contract error, not a hardware stop.
inputId='EMIProject:InvalidReferenceGovernorRequest';
assert(localScalar(requested_rad),inputId,'Requested position must be a finite real double or single scalar.');
id='EMIProject:InvalidReferenceGovernorState';
assert(isstruct(state) && isscalar(state) && isfield(state,'config'),id,'A scalar initialized governor state is required.');
validated=phase3_reference_governor_initialize(state.config);c=validated.config;
assert(abs(double(requested_rad))<=c.positionLimit_rad,inputId,'Requested position exceeds the declared reference position range.');
for name={'sampleIndex','slewReference_rad','shapedReference_rad','velocity_rad_s'}
    assert(isfield(state,name{1}) && localScalar(state.(name{1})),id,'Governor %s must be a finite floating-point scalar.',name{1});
end
assert(state.sampleIndex>=0 && state.sampleIndex==fix(state.sampleIndex) && state.sampleIndex<flintmax-1,id, ...
    'Governor elapsed-sample count must be a representable nonnegative integer.');
q=double(state.slewReference_rad);r=double(state.shapedReference_rad);v=double(state.velocity_rad_s);
expectedLag=((1-c.beta)*c.sampleTime_s*v)/c.beta;
roundoff=128*eps(max([1,abs(q),abs(r)]));
assert(abs(q)<=c.positionLimit_rad && abs(r)<=c.positionLimit_rad && ...
    abs(v)<=c.maxVelocity_rad_s+roundoff/c.sampleTime_s && ...
    isfinite(expectedLag) && abs((q-r)-expectedLag)<=roundoff,id, ...
    'Governor state is outside the declared range or inconsistent with the velocity recurrence.');
if state.sampleIndex==0
    assert(q==c.initialPosition_rad && r==c.initialPosition_rad && v==0,id, ...
        'The initial governor state must equal the declared position with zero reference speed.');
end
requested_rad=double(requested_rad);
nextQ=min(max(requested_rad,q-c.maxVelocity_rad_s*c.sampleTime_s),q+c.maxVelocity_rad_s*c.sampleTime_s);
nextR=r+c.beta*(nextQ-r);
nextV=(nextR-r)/c.sampleTime_s;acceleration=(nextV-v)/c.sampleTime_s;
assert(all(isfinite([nextQ,nextR,nextV,acceleration])),id,'Governor arithmetic exceeded finite numeric range.');
assert(abs(nextV)<=c.maxVelocity_rad_s+roundoff/c.sampleTime_s && ...
    abs(acceleration)<=c.maxAcceleration_rad_s2+2*roundoff/c.sampleTime_s^2,id, ...
    'Governor velocity or acceleration exceeded its declared bound beyond numerical roundoff.');
state.config=c;state.sampleIndex=double(state.sampleIndex)+1;
state.slewReference_rad=nextQ;state.shapedReference_rad=nextR;state.velocity_rad_s=nextV;
sample=struct('request_rad',requested_rad,'slewReference_rad',nextQ,'shapedReference_rad',nextR, ...
    'velocity_rad_s',nextV,'acceleration_rad_s2',acceleration);
end

function valid=localScalar(value)
valid=isfloat(value) && isreal(value) && isscalar(value) && isfinite(value);
end
