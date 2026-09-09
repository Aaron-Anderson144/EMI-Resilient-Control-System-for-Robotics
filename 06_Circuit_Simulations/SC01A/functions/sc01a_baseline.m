function r = sc01a_baseline(p,s,time_s)
%SC01A_BASELINE Avoid storing unneeded derivative arrays for constant DC runs.
arguments
    p (1,1) struct
    s (1,1) struct
    time_s (:,1) double
end
constant=all(s.values==s.values(1,:),'all');
if ~constant
    r=sc01a_reference(p,s,time_s);return;
end
single=sc01a_reference(p,s,[0;min(s.knots_s(end),1e-9)]);
r.time_s=time_s;
for name=["positive_V","negative_V","ground_V","returnCurrent_A"]
    r.(name)=repmat(single.(name)(1),numel(time_s),1);
end
r.differential_V=r.positive_V-r.negative_V;
r.commonMode_V=(r.positive_V+r.negative_V)/2;
end
