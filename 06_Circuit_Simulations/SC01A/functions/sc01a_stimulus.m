function s = sc01a_stimulus(p,c)
%SC01A_STIMULUS Finite-ramp sources and exact piecewise-constant M*dI/dt.
% Voltage/current are independent bench excitations, not a motor inverter.
arguments
    p (1,1) struct
    c (1,1) struct
end
assert(isequaln(p,c.params),'SC01A:CaseParameterMismatch', ...
    'Pass the selected case.params to the stimulus builder.');
edgeTimes=p.source.edgeTime_s;
edgeSigns=c.polarity;
if c.periods>0
    period=1/p.source.pwmFrequency_Hz;
    rising=p.source.edgeTime_s+(0:c.periods-1)*period;
    falling=rising+p.source.duty*period;
    edgeTimes=reshape([rising;falling],1,[]);
    edgeSigns=repmat([1 -1],1,c.periods)*c.polarity;
end
knots=[0 c.stopTime_s edgeTimes edgeTimes+p.source.voltageRise_s ...
    edgeTimes+p.source.currentRise_s];
logicTime=NaN;
if isfinite(c.logicTransitionOffset_s)
    logicTime=p.source.edgeTime_s+c.logicTransitionOffset_s;
    knots=[knots logicTime logicTime+p.driver.transitionTime_s];
end
knots=unique(knots(knots>=0 & knots<=c.stopTime_s)).';
n=numel(knots);
va=zeros(n,1); ic=zeros(n,1); derivative=zeros(n,1);
for k=1:numel(edgeTimes)
    va=va+edgeSigns(k)*p.source.voltageStep_V*min(max((knots-edgeTimes(k))/p.source.voltageRise_s,0),1);
    ic=ic+edgeSigns(k)*p.source.currentStep_A*min(max((knots-edgeTimes(k))/p.source.currentRise_s,0),1);
    mask=knots>=edgeTimes(k) & knots<edgeTimes(k)+p.source.currentRise_s;
    derivative(mask)=derivative(mask)+edgeSigns(k)*p.source.currentStep_A/p.source.currentRise_s;
end
vd=ones(n,1)*p.driver.differential_V*c.logicSign;
if isfinite(logicTime)
    vd=-p.driver.differential_V+2*p.driver.differential_V*min(max((knots-logicTime)/p.driver.transitionTime_s,0),1);
end
vp=p.driver.commonMode_V+vd/2;
vn=p.driver.commonMode_V-vd/2;
values=[va*c.capacitive ic*c.shared vp vn ...
    p.coupling.Mp_H*derivative*c.inductive p.coupling.Mn_H*derivative*c.inductive];
s.voltageAggressor=timeseries(values(:,1),knots);
s.currentCommutation=timeseries(values(:,2),knots);
s.sourcePositive=timeseries(values(:,3),knots);
s.sourceNegative=timeseries(values(:,4),knots);
s.inducedPositive=timeseries(values(:,5),knots);
s.inducedNegative=timeseries(values(:,6),knots);
s.inducedPositive=setinterpmethod(s.inducedPositive,'zoh');
s.inducedNegative=setinterpmethod(s.inducedNegative,'zoh');
s.knots_s=knots;
s.values=values;
s.case=c;
sys=sc01a_state_space(p);
u0=[values(1,2);values(1,3)+values(1,5);values(1,4)+values(1,6);0];
s.initialState=-sys.A\(sys.B*u0);
end
