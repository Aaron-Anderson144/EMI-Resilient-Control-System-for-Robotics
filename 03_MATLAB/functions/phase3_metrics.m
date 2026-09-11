function row=phase3_metrics(protected,baseline,protectedClean,baselineClean)
%PHASE3_METRICS Offline truth scoring, separate from every online decision.
a=protected.timeSeries;b=baseline.timeSeries;ac=protectedClean.timeSeries;bc=baselineClean.timeSeries;
t=a.time_s;Ts=protected.run.params.control.sampleTime_s;s=protected.run.scenario;f=protected.run.profiles;
row.Scenario=s.name;row.Expectation=s.expectation;row.Samples=numel(t);
row.FiniteStateAndCommand=all(isfinite([protected.state(:);baseline.state(:);a.command_V;b.command_V]));
row.CommandBoundsPass=all(abs(a.command_V)<=a.commandLimit_V+1e-12)&all(abs(a.command_V)<=f.supply.commandLimit_V+1e-12);
row.StoppedCommandIsZero=all(a.command_V(a.mode==4)==0);
row.FalseAlarmEpisodes=NaN;row.FalseAlarmDuration_s=NaN;
row.SourceOnset_s=NaN;row.FirstReceiverExposure_s=NaN;row.SourceToReceiver_s=NaN;
row.FirstResponse_s=NaN;row.DetectionDelay_s=NaN;row.DetectionStatus="not_applicable";
row.RecoveryDelay_s=NaN;row.RecoveryStatus="not_triggered";
row.FinalMode=a.mode(end);row.StopDuration_s=sum(a.mode(1:end-1)==4)*Ts;
row.AlarmDuration_s=sum(a.alarm(1:end-1)~=0)*Ts;
row.PeakObserverPositionError_deg=rad2deg(max(abs(a.estimatedPosition_rad-a.position_rad)));
faultIndices=find(f.sourceFault);exposed=find(f.receiverFault);
if s.expectation=="clean"
 active=a.mode~=0;row.FalseAlarmEpisodes=sum(diff([false;active])==1);
 row.FalseAlarmDuration_s=sum(active(1:end-1))*Ts;
elseif isempty(faultIndices)
 row.DetectionStatus="unexposed";
else
 row.SourceOnset_s=t(faultIndices(1));
 if isempty(exposed)
  row.DetectionStatus="unexposed";
 else
  first=exposed(1);last=exposed(end);row.FirstReceiverExposure_s=t(first);
  row.SourceToReceiver_s=t(first)-row.SourceOnset_s;
  searchEnd=t(last)+protected.run.configuration.observer.maxMeasurementAge_s;
  response=find(t>=t(first)&t<=searchEnd+64*eps(max(1,searchEnd))&a.mode~=0,1);
  if first>1 && a.mode(first-1)~=0
   row.DetectionStatus="preexisting_response";
  elseif isempty(response)
   if t(end)<searchEnd-64*eps(max(1,searchEnd))
    row.DetectionStatus="right_censored";
   else
    row.DetectionStatus="missed";
   end
  else
   row.DetectionStatus="detected";row.FirstResponse_s=t(response);
   row.DetectionDelay_s=t(response)-t(first);
  end
  if any(a.mode~=0)
   row.RecoveryStatus="right_censored";
   % Separate offline confirmation: 50ms continuously normal. Delay below
   % names the START of that confirmed interval, not its final timestamp.
   dwell=ceil(.05/Ts)+1;
   start=max(last+1,find(a.mode~=0,1));
   for j=start:numel(t)-dwell+1
    if all(a.mode(j:j+dwell-1)==0)
     row.RecoveryStatus="recovered";row.RecoveryDelay_s=t(j)-t(last);break
    end
   end
  end
 end
end
row.TrackingRMSEProtected_deg=rad2deg(sqrt(mean((a.position_rad-a.reference_rad).^2)));
row.TrackingRMSEBaseline_deg=rad2deg(sqrt(mean((b.position_rad-b.reference_rad).^2)));
row.PeakPositionDeltaProtected_deg=rad2deg(max(abs(a.position_rad-ac.position_rad)));
row.PeakPositionDeltaBaseline_deg=rad2deg(max(abs(b.position_rad-bc.position_rad)));
row.PeakCommandDeltaProtected_V=max(abs(a.command_V-ac.command_V));
row.PeakCommandDeltaBaseline_V=max(abs(b.command_V-bc.command_V));
row.PeakCurrentProtected_A=max(abs(a.current_A));row.PeakCurrentBaseline_A=max(abs(b.current_A));
row.CommandEnergyProtected_V2s=sum(a.command_V(1:end-1).^2)*Ts;
row.CommandEnergyBaseline_V2s=sum(b.command_V(1:end-1).^2)*Ts;
row.ControlVariationProtected_V=sum(abs(diff(a.command_V)));row.ControlVariationBaseline_V=sum(abs(diff(b.command_V)));
end
