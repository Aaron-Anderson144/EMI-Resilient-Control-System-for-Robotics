function row=phase3_tuning_metrics(result,matchedClean,fixture,policyId)
%PHASE3_TUNING_METRICS Fixed-calendar tracking and actual clipping evidence.
% Fault masks and true state are offline scoring inputs only. Current^2*time
% and voltage^2*time are effort proxies, not motor/semiconductor heat.
a=result.timeSeries;b=matchedClean.timeSeries;t=result.time_s;
assert(isequal(t,matchedClean.time_s),'EMIProject:TuningAlignment','Matched clean run must have the same sample grid.');
window=fixture.targetWindow_s;Ts=result.run.params.control.sampleTime_s;
assert(isnumeric(window)&&isreal(window)&&numel(window)==2&&all(isfinite(window))&& ...
 window(1)>=t(1)&&window(2)<=t(end)&&window(2)>window(1), ...
 'EMIProject:InvalidTuningWindow','The fixed scoring window must be within the record.');
indices=find(t>=window(1)&t<window(2));
assert(numel(indices)>=2,'EMIProject:InvalidTuningWindow','Scoring needs at least two samples.');
activity=phase3_control_activity(result);
tracking=a.position_rad-a.reference_rad;delta=a.position_rad-b.position_rad;
row.Fixture=string(fixture.id);row.Partition=string(fixture.partition);row.Policy=string(policyId);
row.ExpectClean=fixture.expectClean;
row.WindowStart_s=window(1);row.WindowStop_s=window(2);row.WindowSamples=numel(indices);
row.WindowTrackingRMSE_deg=rad2deg(sqrt(mean(tracking(indices).^2)));
row.WindowDisturbanceRMSE_deg=rad2deg(sqrt(mean(delta(indices).^2)));
row.WindowPeakError_deg=rad2deg(max(abs(tracking(indices))));
row.WindowPeakCurrent_A=max(abs(a.current_A(indices)));
row.WindowCurrentSquared_A2s=sum(a.current_A(indices).^2)*Ts;
row.WindowVoltageSquared_V2s=sum(a.command_V(indices).^2)*Ts;
row.WindowCommandVariation_V=sum(abs(diff(a.command_V(max(1,indices(1)-1):indices(end)))));
row.FullTrackingRMSE_deg=rad2deg(sqrt(mean(tracking.^2)));
row.FullPeakCurrent_A=max(abs(a.current_A));
row.FinalTrackingError_deg=rad2deg(abs(tracking(end)));
row.AlarmSamples=nnz(a.alarm);row.FirstAlarm_s=localFirst(t,a.alarm~=0);
row.SafeStopDuration_s=nnz(a.mode(1:end-1)==4)*Ts;
row.ModeTransitions=nnz(diff([0;a.mode]));row.FinalMode=a.mode(end);
row.RecoveryConfirmed=false;row.FirstConfirmedNormal_s=NaN;
firstResponse=find(a.mode~=0,1);
if ~isempty(firstResponse)
 dwell=ceil(.050/Ts)+1;
 for k=firstResponse+1:height(a)-dwell+1
  if all(a.mode(k:k+dwell-1)==0)
   row.RecoveryConfirmed=true;row.FirstConfirmedNormal_s=t(k);break
  end
 end
end
row.ReanchorCommits=nnz(a.reacquisitionCommitted);
row.ModeCapClipped_samples=nnz(activity.ModeCapClipped);
row.BusCapClipped_samples=nnz(activity.BusCapClipped);
row.CoincidentCapClipped_samples=nnz(activity.CoincidentCapClipped);
row.SlewClipped_samples=nnz(activity.SlewClipped);
row.AmplitudeClipped_samples=nnz(activity.AmplitudeClipped);
row.HardStop_samples=nnz(activity.HardStop);row.Rebased_samples=nnz(activity.Rebased);
row.AmplitudeCorrectionMagnitude_Vs=sum(abs(activity.AmplitudeCorrection_V(1:end-1)))*Ts;
row.AntiWindupCorrectionMagnitude_V=sum(abs(activity.AntiWindupCorrection_V));
row.FiniteStateAndCommand=all(isfinite([result.state(:);a.command_V;a.reference_rad;a.unsaturatedCommand_V;a.commandLimit_V]));
row.CommandBoundsPass=all(abs(a.command_V)<=a.commandLimit_V+1e-12)& ...
 all(abs(a.command_V)<=result.run.profiles.supply.commandLimit_V+1e-12);
row.StoppedCommandZero=all(a.command_V(a.mode==4)==0);
row.CleanFalseAlarmPass=~fixture.expectClean||row.AlarmSamples==0;
row.CommitsRemainStopped=all(a.mode(a.reacquisitionCommitted~=0)==4& ...
 a.command_V(a.reacquisitionCommitted~=0)==0&~a.credibleFresh(a.reacquisitionCommitted~=0));
row.ReleaseEvidencePass=true;
releases=find([false;a.mode(1:end-1)==4&a.mode(2:end)~=4]);
required=result.run.configuration.supervisor.safeStopRelease_samples;
for k=reshape(releases,1,[])
 first=k-required+1;
 row.ReleaseEvidencePass=row.ReleaseEvidencePass&&first>=1&&a.resetRequest(k)==1&& ...
  all(a.credibleFresh(first:k)~=0&a.alarm(first:k)==0&a.supplyHealthy(first:k)~=0);
end
row.InvariantsPass=row.FiniteStateAndCommand&&row.CommandBoundsPass&&row.StoppedCommandZero&& ...
 row.CleanFalseAlarmPass&&row.CommitsRemainStopped&&row.ReleaseEvidencePass;
end

function value=localFirst(time,condition)
index=find(condition,1);value=NaN;if ~isempty(index),value=time(index);end
end
