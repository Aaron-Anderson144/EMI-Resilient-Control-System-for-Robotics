function [waves,summary]=sc01b_compare(candidate,reference,p,c,label)
%SC01B_COMPARE Direct time-aligned comparison, with no fitted delay/filter.
% Interpolate both traces onto the union of their native integration knots.
% The maximum of their piecewise-linear difference lies on that union.
fields=["switch_V","bus_V","highVgs_V","lowVgs_V","highVds_V","lowVds_V", ...
    "highCurrent_A","lowCurrent_A","highGateCurrent_A","lowGateCurrent_A", ...
    "loadCurrent_A","feedCurrent_A"];
a=p.validation.startTime_s;b=p.simulation.stopTime_s;
assert(candidate.time_s(1)<=a && reference.time_s(1)<=a && ...
    candidate.time_s(end)>=b-1e-14 && reference.time_s(end)>=b-1e-14, ...
    'SC01B:ComparisonWindow','Both traces must cover the declared window.');
b=min([b,candidate.time_s(end),reference.time_s(end)]);
t=unique([a;candidate.time_s(candidate.time_s>a & candidate.time_s<b); ...
    reference.time_s(reference.time_s>a & reference.time_s<b);b]);
rows=cell(numel(fields),1);initialRatio=0;
for k=1:numel(fields)
    field=fields(k);x=interp1(candidate.time_s,candidate.(field),t);y=interp1(reference.time_s,reference.(field),t);
    if endsWith(field,"_V"),floor=c.voltageAbsoluteTolerance_V;else,floor=c.currentAbsoluteTolerance_A;end
    amplitude=max(abs(y));limit=max(floor,c.relativeWaveformTolerance*amplitude);
    delta=x-y;maximum=max(abs(delta));
    initialReference=reference.(field)(1);initialCandidate=candidate.(field)(1);
    initialRatio=max(initialRatio,abs(initialCandidate-initialReference)/max(floor,c.relativeWaveformTolerance*abs(initialReference)));
    rows{k}=struct('Case',p.meta.case,'Comparison',string(label),'Signal',field, ...
        'MaxAbsoluteDifference',maximum,'ReferencePeakAbsolute',amplitude, ...
        'Limit',limit,'Pass',maximum<=limit,'PeakAbsoluteDifference',abs(max(abs(x))-amplitude), ...
        'RMSDifference',sqrt(sum(diff(t).*(delta(1:end-1).^2+delta(1:end-1).*delta(2:end)+delta(2:end).^2)/3)/(b-a)));
end
waves=struct2table(vertcat(rows{:}));
[mc,ec]=sc01b_metrics(candidate,p);[mr,er]=sc01b_metrics(reference,p);
assert(isequal(ec.EventId,er.EventId),'SC01B:EventIdentity','Event identities differ.');
timingFields=["SwitchT10_s","SwitchT50_s","SwitchT90_s","EdgeTime_s", ...
    "HighGateT10_s","HighGateT50_s","HighGateT90_s","LowGateT50_s","GateMidpointDeadTime_s"];
dc=ec{:,timingFields};dr=er{:,timingFields};
timingFinite=all(isfinite(dc),'all') && all(isfinite(dr),'all');
if timingFinite,maxTiming=max(abs(dc-dr),[],'all');else,maxTiming=Inf;end
energyFields=["HighTerminalEnergy_J","LowTerminalEnergy_J"];
energiesC=[mc.HighTerminalEnergy_J,mc.LowTerminalEnergy_J;ec{:,energyFields}];
energiesR=[mr.HighTerminalEnergy_J,mr.LowTerminalEnergy_J;er{:,energyFields}];
energyLimits=max(c.energyAbsoluteTolerance_J,c.relativeMetricTolerance*abs(energiesR));
energyRatio=max(abs(energiesC-energiesR)./energyLimits,[],'all');
summary=struct('Case',p.meta.case,'Comparison',string(label), ...
    'WaveformsPassed',all(waves.Pass),'MaxWaveformLimitRatio',max(waves.MaxAbsoluteDifference./waves.Limit), ...
    'InitialStatePassed',initialRatio<=1,'InitialStateMaxLimitRatio',initialRatio, ...
    'MaxEventTimeDifference_s',maxTiming,'EventTimingPassed',timingFinite && maxTiming<=c.eventTimeTolerance_s, ...
    'EventClassificationMatched',isequal(ec{:,classificationFields()},er{:,classificationFields()}), ...
    'AllEventsResolved',all(ec.Resolved) && all(er.Resolved), ...
    'MaxEnergyLimitRatio',energyRatio,'EnergyPassed',energyRatio<=1);
currentFields=["HighCurrentT10_s","HighCurrentT50_s","HighCurrentT90_s"];
currentKnown=ec.CurrentResolved & er.CurrentResolved;
summary.CurrentTimingComparedEvents=sum(currentKnown);
if any(currentKnown)
    summary.MaxCurrentEventTimeDifference_s=max(abs(ec{currentKnown,currentFields}-er{currentKnown,currentFields}),[],'all');
else
    summary.MaxCurrentEventTimeDifference_s=NaN;
end
summary.CurrentTimingPassed=isequal(ec.CurrentResolved,er.CurrentResolved) && ...
    (~any(currentKnown) || summary.MaxCurrentEventTimeDifference_s<=c.eventTimeTolerance_s);
summary.ExecutionComplete=true;summary.Diagnostic="";
summary.Pass=summary.WaveformsPassed && summary.InitialStatePassed && summary.EventTimingPassed && summary.CurrentTimingPassed && ...
    summary.EventClassificationMatched && summary.AllEventsResolved && summary.EnergyPassed;
end

function fields=classificationFields()
fields=["Resolved","VoltageResolved","GateResolved","CounterpartGateResolved","CurrentResolved", ...
    "Clipped","CounterpartGateClipped","VoltageGrazing","GateGrazing","VoltageRecrossingCount"];
end
