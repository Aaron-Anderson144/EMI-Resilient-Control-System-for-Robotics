function a=receiver_v2_analyze(p,s,maxCell)
%RECEIVER_V2_ANALYZE Continuous bounds, root isolation and domain occupation.
% On every cell, deviation from endpoint linear interpolation is bounded by
% sup|y''| h^2/8. Stable modal exponentials supply a bound, not a coarse-sample
% continuity claim. Adaptive subdivision resolves nonmonotone threshold cells.
counts=max(1,ceil(s.h/maxCell));idx=repelem((1:numel(s.h)).',counts);
first=repelem(cumsum([0;counts(1:end-1)]),counts);
order=(0:numel(idx)-1).'-first;
lo=order.*s.h(idx)./counts(idx);hi=(order+1).*s.h(idx)./counts(idx);
rows=[1 0 0;0 1 0;1 -1 0;.5 .5 0;s.circuit.gx;0 0 1];
inrows=zeros(6,4);inrows(5,:)=s.circuit.gu;
trip=unique([[p.receiver.thresholdPairs.rise_V],[p.receiver.thresholdPairs.fall_V]]);
levels={[-18 -15 15 18],[-18 -15 15 18],[-18 -15 trip 15 18],[],[],[]};
unresolved=false;maxRound=p.numerics.maxAdaptiveRounds;
for round=0:maxRound
    refine=false(size(idx));left=zeros(numel(idx),6);right=left;err=left;
    for q=1:6
        [left(:,q),dl,m2]=receiver_v2_signal(s,idx,lo,rows(q,:),inrows(q,:));
        right(:,q)=receiver_v2_signal(s,idx,hi,rows(q,:),inrows(q,:));
        err(:,q)=m2.*(hi-lo).^2/8;
        ymin=min(left(:,q),right(:,q))-err(:,q);
        ymax=max(left(:,q),right(:,q))+err(:,q);
        if q<=5
            refine=refine | ymax>max([left(:,q);right(:,q)])+p.numerics.extremaAllowance_V/4 ...
                | ymin<min([left(:,q);right(:,q)])-p.numerics.extremaAllowance_V/4;
        end
        monotone=(dl-m2.*(hi-lo)>=0)|(dl+m2.*(hi-lo)<=0);
        for level=levels{q}
            % A sign-changing cell can contain three or more roots. Only a
            % certified monotone cell may be handed to a single bisection.
            ambiguous=ymin<=level & ymax>=level & ~monotone;
            refine=refine|ambiguous;
        end
    end
    if ~any(refine),break,end
    if round==maxRound,unresolved=true;break,end
    refine=refine & (hi-lo)>p.numerics.rootTolerance_s/4;
    if ~any(refine),unresolved=true;break,end
    mid=(lo(refine)+hi(refine))/2;
    idx=[idx(~refine);idx(refine);idx(refine)];
    lo=[lo(~refine);lo(refine);mid];hi=[hi(~refine);mid;hi(refine)];
end
[~,perm]=sort(s.t(idx)+lo);idx=idx(perm);lo=lo(perm);hi=hi(perm);
left=left(perm,:);right=right(perm,:);err=err(perm,:);
a.minSample=min([left;right],[],1);a.maxSample=max([left;right],[],1);
a.minBound=min(min(left,right)-err,[],1);a.maxBound=max(max(left,right)+err,[],1);
a.extremaBoundWidth=max([a.minSample(1:5)-a.minBound(1:5),a.maxBound(1:5)-a.maxSample(1:5)]);
a.returnCurrentBoundWidth_A=max(a.minSample(6)-a.minBound(6),a.maxBound(6)-a.maxSample(6));
a.unresolved=unresolved;a.adaptiveRounds=round;a.cells=numel(idx);
events=zeros(0,4); % [absolute time,signal index,level,direction]
for q=1:3
    for level=levels{q}
        hit=find((left(:,q)-level).*(right(:,q)-level)<0 | ...
            (left(:,q)==level & right(:,q)~=level) | ...
            (right(:,q)==level & left(:,q)~=level));
        if isempty(hit),continue,end
        il=idx(hit);ll=lo(hit);rr=hi(hit);yl=left(hit,q)-level;
        rightExact=right(hit,q)==level;ll(rightExact)=rr(rightExact);
        for it=1:ceil(log2(max((rr-ll))/p.numerics.rootTolerance_s))+1
            mm=(ll+rr)/2;ym=receiver_v2_signal(s,il,mm,rows(q,:),inrows(q,:))-level;
            move=(yl.*ym>0);ll(move)=mm(move);yl(move)=ym(move);rr(~move)=mm(~move);
        end
        time=s.t(il)+(ll+rr)/2;
        direction=sign(right(hit,q)-left(hit,q));
        events=[events;time,repmat(q,numel(hit),1),repmat(level,numel(hit),1),direction]; %#ok<AGROW>
    end
end
events=sortrows(events,[2 3 1]);
if ~isempty(events)
    closePair=all(diff(events(:,2:3))==0,2)&abs(diff(events(:,1)))<=p.numerics.rootTolerance_s;
    sameDirection=diff(events(:,4))==0;
    if any(closePair&~sameDirection),a.unresolved=true;unresolved=true;end
    duplicate=[false;closePair&sameDirection];
    events(duplicate,:)=[];
end
events=sortrows(events,[1 2 3]);a.events=events;
domainEvents=events(abs(events(:,3))==15,:);
bounds=unique([0;domainEvents(:,1);s.t(end)]);mid=(bounds(1:end-1)+bounds(2:end))/2;
ii=discretize(mid,s.t);tau=mid-s.t(ii);volt=zeros(numel(mid),3);
for q=1:3,volt(:,q)=receiver_v2_signal(s,ii,tau,rows(q,:));end
outside=any(abs(volt)>15,2);width=diff(bounds);
a.timeOutsideDomain_s=sum(width(outside));
a.firstViolation_s=NaN;if any(outside),a.firstViolation_s=bounds(find(outside,1));end
a.timeOutsidePin_s=sum(width(any(abs(volt(:,1:2))>15,2)));
a.timeOutsideDifferential_s=sum(width(abs(volt(:,3))>15));
if any(a.minSample(1:3)<-15|a.maxSample(1:3)>15),a.domainStatus='outside';
elseif unresolved||any(a.minBound(1:3)<-15|a.maxBound(1:3)>15),a.domainStatus='unresolved';
else,a.domainStatus='inside';end
a.stressFlag=any(a.minSample(1:3)<-18|a.maxSample(1:3)>18);
a.stressUnresolved=~a.stressFlag&&any(a.minBound(1:3)<-18|a.maxBound(1:3)>18);
% Retained display samples are never used to establish the continuous bounds.
ti=unique([linspace(0,s.t(end),6001).';s.fixture.transitions(:,1)]);
ii=discretize(ti,s.t);ii(end)=numel(s.h);tau=ti-s.t(ii);
x=zeros(numel(ti),3);dx=x;
for q=1:3,[x(:,q),dx(:,q)]=receiver_v2_signal(s,ii,tau,eye_row(q));end
u=s.u0(ii,:)+s.u1(ii,:).*tau;g=x*s.circuit.gx.'+u*s.circuit.gu.';
n=p.network;ip=(g+u(:,2)-x(:,1))/n.driverRp_Ohm;in=(g+u(:,3)-x(:,2))/n.driverRn_Ohm;
icp=s.circuit.cp_pF*1e-12*(u(:,4)-dx(:,1));icn=n.Ccn_pF*1e-12*(u(:,4)-dx(:,2));
a.trace=table(ti,x(:,1),x(:,2),x(:,1)-x(:,2),g,x(:,3),ip,in,icp,icn, ...
    (x(:,1)-x(:,2))/n.termination_Ohm,dx(:,1),dx(:,2), ...
    'VariableNames',{'time_s','vp_V','vn_V','vd_V','driverGround_V','returnCurrent_A', ...
    'driverP_A','driverN_A','couplingP_A','couplingN_A','termination_A','slewP_V_s','slewN_V_s'});
% Current and slew extrema receive analytical envelopes on the same cells.
outRows=[(s.circuit.gx-[1 0 0])/n.driverRp_Ohm; ...
    (s.circuit.gx-[0 1 0])/n.driverRn_Ohm;[1 -1 0]/n.termination_Ohm];
outIn=[(s.circuit.gu+[0 1 0 0])/n.driverRp_Ohm; ...
    (s.circuit.gu+[0 0 1 0])/n.driverRn_Ohm;zeros(1,4)];
a.maxAbsCircuitCurrent_A=zeros(1,3);
for q=1:3
    [yl,~,m2]=receiver_v2_signal(s,idx,lo,outRows(q,:),outIn(q,:));
    yr=receiver_v2_signal(s,idx,hi,outRows(q,:),outIn(q,:));
    a.maxAbsCircuitCurrent_A(q)=max(max(abs(yl),abs(yr))+m2.*(hi-lo).^2/8);
end
% For derivatives, endpoint plus integral |y''| is a conservative bound.
a.maxAbsPinSlew_V_s=zeros(1,2);a.maxAbsCouplingCurrent_A=zeros(1,2);
for q=1:2
    [~,dy,m2]=receiver_v2_signal(s,idx,lo,eye_row(q));
    a.maxAbsPinSlew_V_s(q)=max(abs(dy)+m2.*(hi-lo));
    cap=[s.circuit.cp_pF*1e-12,n.Ccn_pF*1e-12];
    a.maxAbsCouplingCurrent_A(q)=max(cap(q)*(abs(s.u0(idx,4)-dy)+m2.*(hi-lo)));
end
a.clampCurrent_A=NaN;
end
function r=eye_row(q)
r=zeros(1,3);r(q)=1;
end
