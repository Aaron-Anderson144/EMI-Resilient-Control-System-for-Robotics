function signals = sc01a_simscape_signals(s)
%SC01A_SIMSCAPE_SIGNALS Exact workspace data for the physical source blocks.
% Rectangular induced voltages and dVa/dt use duplicate-time left/right
% values. From Workspace with Interpolate=on and ZeroCross=on recognizes
% these exact events. There is no pulse smoothing or filtering.
% https://www.mathworks.com/help/simulink/slref/fromworkspace.html
signals.sc01aVoltageAggressor=s.voltageAggressor;
signals.sc01aCurrentCommutation=s.currentCommutation;
signals.sc01aSourcePositive=s.sourcePositive;
signals.sc01aSourceNegative=s.sourceNegative;
signals.sc01aInducedPositive=piecewiseStepData(s.inducedPositive.Time, ...
    double(s.inducedPositive.Data));
signals.sc01aInducedNegative=piecewiseStepData(s.inducedNegative.Time, ...
    double(s.inducedNegative.Data));
t=s.voltageAggressor.Time(:); v=double(s.voltageAggressor.Data(:));
assert(all(diff(t)>0),'SC01A:RampTime', ...
    'Finite-ramp input times must increase strictly.');
dv=[diff(v)./diff(t);0];
signals.sc01aVoltageAggressorDerivative=piecewiseStepData(t,dv);
end

function data=piecewiseStepData(t,value)
% Each interval is constant; duplicate times specify instantaneous changes.
t=t(:); value=value(:); n=numel(t);
assert(n==numel(value) && all(diff(t)>0),'SC01A:StepTime', ...
    'Piecewise-constant input times must increase strictly.');
tt=zeros(2*n-1,1); vv=tt;
tt(1)=t(1); vv(1)=value(1);
tt(2:2:end)=t(2:end); tt(3:2:end)=t(2:end);
vv(2:2:end)=value(1:end-1); vv(3:2:end)=value(2:end);
data=[tt vv];
end
