function [row,recovery,episodes,bursts]=fourway_v2_metrics(exposed,clean,burstEnd,burstStart)
% Retain the original frozen scoring with stricter V2 identity/rejection gates.
assert(exposed.fixture.exposed&&~clean.fixture.exposed&& ...
 isequaln(exposed.fixture.variant,clean.fixture.variant), ...
 'EMIProject:V2Companion','Companion must retain the entire V2 hypothesis.');
canonical=fourway_v2_variant(exposed.fixture.variant.id);
assert(isequaln(canonical,exposed.fixture.variant),'EMIProject:V2Variant','Variant parameters changed.');
[row,recovery,episodes,bursts]=fourway_metrics(exposed,clean,burstEnd,burstStart);
row.Variant=canonical.id;
row.ReceiverNumericsPass=~any(exposed.timeSeries.receiverNumericalRejected)&& ...
 ~any(exposed.timeSeries.shadowNumericalRejected);
row.CleanNumericsPass=~any(clean.timeSeries.receiverNumericalRejected)&& ...
 ~any(clean.timeSeries.shadowNumericalRejected);
row.ShadowDomainPass=~any(exposed.timeSeries.shadowDomainFailed)&&~any(clean.timeSeries.shadowDomainFailed);
row.ReceiverStressPass=~any(exposed.timeSeries.receiverStressFailed);
row.CleanGuardPass=row.CleanGuardPass&&row.CleanNumericsPass&&row.ShadowDomainPass;
row.ExecutionGuardPass=row.ExecutionGuardPass&&row.ReceiverNumericsPass&&row.CleanGuardPass;
row.TaskSuccess=row.TaskSuccess&&row.ExecutionGuardPass;
recovery.Variant=repmat(canonical.id,height(recovery),1);
episodes.Variant=repmat(canonical.id,height(episodes),1);
bursts.Variant=repmat(canonical.id,height(bursts),1);
end
