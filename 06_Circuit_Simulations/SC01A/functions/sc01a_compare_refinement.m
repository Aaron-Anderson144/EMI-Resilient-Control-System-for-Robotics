function check = sc01a_compare_refinement(coarse,fine,p)
%SC01A_COMPARE_REFINEMENT Compare waveform metrics and matched event times.
arguments
    coarse (1,1) struct
    fine (1,1) struct
    p (1,1) struct
end
cm=coarse.metrics; fm=fine.metrics;
voltageNames=["PeakDM_V","PeakCM_V","PeakGround_V"];
areaNames=["AbsAreaDM_Vs","AbsAreaCM_Vs"];
voltagePassed=true; areaPassed=true;
worstVoltageRatio=0; worstAreaRatio=0;
for name=voltageNames
    gate=max(p.verification.voltageFloor_V,p.verification.relativeGate*abs(fm.(name)));
    ratio=abs(cm.(name)-fm.(name))/gate;
    worstVoltageRatio=max(worstVoltageRatio,ratio);
    voltagePassed=voltagePassed && ratio<=1;
end
for name=areaNames
    areaFloor=p.verification.voltageFloor_V*p.source.voltageRise_s;
    gate=max(areaFloor,p.verification.relativeGate*abs(fm.(name)));
    ratio=abs(cm.(name)-fm.(name))/gate;
    worstAreaRatio=max(worstAreaRatio,ratio);
    areaPassed=areaPassed && ratio<=1;
end
eventCountsMatch=height(coarse.events)==height(fine.events);
eventTiming=Inf;
if eventCountsMatch && isequal(coarse.events.Channel,fine.events.Channel) && ...
        isequal(coarse.events.Level_V,fine.events.Level_V) && ...
        isequal(coarse.events.Direction,fine.events.Direction)
    if isempty(fine.events), eventTiming=0;
    else, eventTiming=max(abs(coarse.events.Time_s-fine.events.Time_s)); end
end
durationDifference=max(abs([cm.NoiseExposure_s-fm.NoiseExposure_s, ...
    cm.ReceiverBand_s-fm.ReceiverBand_s]));
check.WorstVoltageGateRatio=worstVoltageRatio;
check.WorstAreaGateRatio=worstAreaRatio;
check.EventCountsMatch=eventCountsMatch;
check.MaxEventTimeDifference_s=eventTiming;
check.MaxExposureDifference_s=durationDifference;
check.Grazing=cm.Grazing || fm.Grazing;
check.Passed=voltagePassed && areaPassed && eventCountsMatch && ...
    eventTiming<=p.verification.timeGate_s && durationDifference<=p.verification.timeGate_s && ~check.Grazing;
end
