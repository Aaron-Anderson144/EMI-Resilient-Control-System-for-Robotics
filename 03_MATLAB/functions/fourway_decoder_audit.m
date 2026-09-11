function audit=fourway_decoder_audit(result)
%FOURWAY_DECODER_AUDIT Offline state-transition and clean-delay checks.
% Extra/missing events match identical directed A/B transitions one-to-one
% within 1 us on the same intended trajectory. This is a descriptive event
% alignment rule, independent of sampled count error and hypothesis gates.
r=result.receiver.decoder;s=result.shadow.decoder;
i=1;j=1;extra=0;missing=0;matched=0;allowance=1e-6;
while i<=size(r,1)&&j<=size(s,1)
 same=isequal(r(i,[2,3,7,8]),s(j,[2,3,7,8]));
 if same&&abs(r(i,1)-s(j,1))<=allowance
  matched=matched+1;i=i+1;j=j+1;
 elseif r(i,1)<s(j,1)-allowance
  extra=extra+1;i=i+1;
 elseif s(j,1)<r(i,1)-allowance
  missing=missing+1;j=j+1;
 elseif i<size(r,1)&&isequal(r(i+1,[2,3,7,8]),s(j,[2,3,7,8]))&&abs(r(i+1,1)-s(j,1))<=allowance
  extra=extra+1;i=i+1;
 else
  missing=missing+1;j=j+1;
 end
end
extra=extra+size(r,1)-i+1;missing=missing+size(s,1)-j+1;
audit=struct('observedTransitions',size(r,1),'shadowTransitions',size(s,1), ...
 'matchedTransitions',matched,'extraTransitions',extra,'missingTransitions',missing, ...
 'invalidTransitions',sum(r(:,6)),'eventMatchingAllowance_s',allowance, ...
 'cleanSequencePass',false,'cleanDelayPass',false,'cleanMaximumDelay_s',NaN, ...
 'cleanCountConservationPass',false);
if result.fixture.exposed,return,end
% Construct the independent intended Gray increments without using plant q.
ab=result.intendedTransitions;previous=[0,0];q=0;expected=zeros(0,3);
gray=[0,0;1,0;1,1;0,1];
for k=1:size(ab,1)
 current=ab(k,2:3);
 if isequal(current,previous),continue,end
 old=find(all(gray==previous,2));next=find(all(gray==current,2));step=mod(next-old,4);
 if step==1,increment=1;elseif step==3,increment=-1;else,increment=0;end
 q=q+increment;expected(end+1,:)=[ab(k,1),increment,q];previous=current; %#ok<AGROW>
end
audit.cleanSequencePass=size(expected,1)==size(r,1)&&isequal(expected(:,2),r(:,4))&& ...
 isequal(expected(:,3),r(:,5))&&~any(r(:,6));
if audit.cleanSequencePass
 delay=r(:,1)-expected(:,1);audit.cleanMaximumDelay_s=max([0;delay]);
 audit.cleanDelayPass=all(delay>=-1e-12&delay<=1e-6);
 audit.cleanCountConservationPass=audit.cleanDelayPass&&max(abs(result.timeSeries.idealMinusDecodedCount))<=1;
end
end
