function capacity=phase3_stop_hold_capacity(t,fixture,mechanism)
%PHASE3_STOP_HOLD_CAPACITY Timed passive capacity; no plant-state feedback.
if fixture.failedEngagement,capacity=zeros(size(t));return;end
if fixture.preEngaged,level=ones(size(t));
else,level=min(1,max(0,(t-fixture.engagementDelay_s)/fixture.ramp_s));end
if fixture.releaseTime_s>=0 && ~fixture.failedRelease
 level=level.*min(1,max(0,1-(t-fixture.releaseTime_s)/fixture.ramp_s));
end
capacity=mechanism.capacity_Nm*level;
end
