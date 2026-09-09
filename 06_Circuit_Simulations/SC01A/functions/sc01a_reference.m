function r = sc01a_reference(p,s,time_s)
%SC01A_REFERENCE Independent exact affine-segment state-transition solution.
% Evaluates the continuous LTI circuit without time-integration step error.
arguments
    p (1,1) struct
    s (1,1) struct
    time_s (:,1) double
end
assert(isequaln(p,s.case.params),'SC01A:ReferenceParameterMismatch', ...
    'Reference parameters must match the stimulus case.');
assert(all(isfinite(time_s)) && all(diff(time_s)>=0), ...
    'SC01A:InvalidTimes','Reference times must be finite and nondecreasing.');
assert(time_s(1)>=0 && time_s(end)<=s.knots_s(end)+1e-15, ...
    'SC01A:TimesOutsideRecord','Reference time is outside stimulus record.');
sys=sc01a_state_space(p);
[modes,diagonal]=eig(sys.A);
lambda=diag(diagonal);
assert(rcond(modes)>1e-10,'SC01A:IllConditionedModes','Reference modes need a more robust propagation method.');
x=zeros(3,numel(time_s)); u=zeros(4,numel(time_s)); dx=zeros(3,numel(time_s));
state=s.initialState;
for k=1:numel(s.knots_s)-1
    duration=s.knots_s(k+1)-s.knots_s(k);
    left=s.values(k,:);
    slope=(s.values(k+1,1:4)-left(1:4))/duration;
    u0=[left(2);left(3)+left(5);left(4)+left(6);slope(1)];
    u1=[slope(2);slope(3);slope(4);0];
    f0=sys.B*u0; f1=sys.B*u1;
    c1=-sys.A\f1;
    c0=sys.A\(c1-f0);
    coefficients=modes\(state-c0);
    if k<numel(s.knots_s)-1
        mask=time_s>=s.knots_s(k) & time_s<s.knots_s(k+1);
    else
        mask=time_s>=s.knots_s(k) & time_s<=s.knots_s(k+1)+1e-15;
    end
    tau=time_s(mask).'-s.knots_s(k);
    transient=real(modes*(coefficients.*exp(lambda.*tau)));
    x(:,mask)=c0+c1.*tau+transient;
    dx(:,mask)=c1+sys.A*transient;
    u(:,mask)=u0+u1.*tau;
    state=c0+c1*duration+real(modes*(coefficients.*exp(lambda*duration)));
end
r.time_s=time_s;
r.positive_V=x(1,:).'; r.negative_V=x(2,:).';
r.returnCurrent_A=x(3,:).';
r.ground_V=(sys.groundState*x+sys.groundInput*u).';
r.differential_V=r.positive_V-r.negative_V;
r.commonMode_V=(r.positive_V+r.negative_V)/2;
r.state=x.'; r.derivative=dx.'; r.inputs=u.';
end
