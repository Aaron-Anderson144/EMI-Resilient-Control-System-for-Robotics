function [row,recovery,episodes,burstAttribution]=fourway_metrics(exposed,clean,burstEnd_s,burstStart_s)
%FOURWAY_METRICS Offline PLAN-V1 scoring; no metric is supplied to control.
a=exposed.timeSeries;b=clean.timeSeries;f=exposed.fixture;c=f.design;
if nargin<4
 source=fourway_source_metadata(f.phase_s,f.closure_s);
 burstStart_s=source.burst_first_derivative_s;
end
validateattributes(burstStart_s,{'numeric'},{'real','finite','numel',2});
validateattributes(burstEnd_s,{'numeric'},{'real','finite','numel',2});
assert(all(burstStart_s(:)<burstEnd_s(:))&&burstEnd_s(1)<burstStart_s(2), ...
 'EMIProject:FourWayBurstSupport','Burst derivative support is inconsistent.');
assert(isequal(a.time_s,b.time_s),'EMIProject:FourWayPair','Companion sample grids differ.');
assert(f.id==clean.fixture.id && f.arm==clean.fixture.arm && f.Cdiff_pF==clean.fixture.Cdiff_pF && ...
 f.Ccp_pF==clean.fixture.Ccp_pF && f.Ccn_pF==clean.fixture.Ccn_pF && ...
 f.task_sign==clean.fixture.task_sign && f.phase_s==clean.fixture.phase_s && ...
 f.closure_s==clean.fixture.closure_s && ...
 f.run.protectionEnabled==clean.fixture.run.protectionEnabled && ~clean.fixture.exposed, ...
 'EMIProject:FourWayPair','Companion does not retain its own treatment and task.');
t=a.time_s;Ts=exposed.run.params.control.sampleTime_s;pair=rad2deg(a.position_rad-b.position_rad);
requested=rad2deg(a.position_rad-a.requestedReference_rad);shaped=rad2deg(a.position_rad-a.reference_rad);
window=false(size(t));
for j=1:size(c.metrics.window_s,1)
 window=window|(t>=c.metrics.window_s(j,1)&t<c.metrics.window_s(j,2));
end
tail=t>=t(end)-c.metrics.tail_s;
row=struct('Fixture',f.id,'Partition',f.partition,'Arm',f.arm,'Ccp_pF',f.Ccp_pF, ...
 'Ccn_pF',f.Ccn_pF,'Cdiff_pF',f.Cdiff_pF,'TaskSign',f.task_sign,'Phase_ns',f.phase_s*1e9, ...
 'Closure_s',f.closure_s,'Samples',height(a));
expectedTime=(0:c.task.sample_time_s:c.task.stop_time_s)';
row.CompleteFinite=matchingGrid(t,expectedTime)&&Ts==c.task.sample_time_s&& ...
 all(isfinite([a.position_rad;a.velocity_rad_s;a.current_A;a.command_V]));
row.CommandBoundsPass=all(abs(a.command_V)<=24+1e-12)&&all(abs(a.command_V)<=a.commandLimit_V+1e-12);
row.StoppedCommandZero=all(a.command_V(a.mode==4)==0);
row.ReceiverDomainPass=~any(a.receiverDomainFailed);
row.CausalPackets=isequal(a.sourceIndex,(1:height(a))')&&all(a.sampleReceived);
row.WindowPairedRMSE_deg=rmsValue(pair(window));row.WindowPairedPeak_deg=max(abs(pair(window)));
row.FullPairedRMSE_deg=rmsValue(pair);row.FullPairedPeak_deg=max(abs(pair));
row.RequestedRMSE_deg=rmsValue(requested);row.ShapedRMSE_deg=rmsValue(shaped);
row.FinalRequestedError_deg=abs(requested(end));row.TailRequestedRMSE_deg=rmsValue(requested(tail));
row.TailPairedRMSE_deg=rmsValue(pair(tail));
row.FinalPairedError_deg=abs(pair(end));row.FinalShapedError_deg=abs(shaped(end));
row.TailShapedRMSE_deg=rmsValue(shaped(tail));
row.PeakSpeed_rad_s=max(abs(a.velocity_rad_s));row.PeakCurrent_A=max(abs(a.current_A));
row.CurrentSquaredIntegral_A2s=trapz(t,a.current_A.^2);
row.PlantExtremaMethod="sampled_1ms";
if isfield(exposed,'intervalStats')
 row.PeakSpeed_rad_s=max(exposed.intervalStats.peakAbsVelocity_rad_s);
 row.PeakCurrent_A=max(exposed.intervalStats.peakAbsCurrent_A);
 row.CurrentSquaredIntegral_A2s=sum(exposed.intervalStats.currentSquaredIntegral_A2s);
 row.PlantExtremaMethod="continuous_affine_interval";
end
row.CommandEnergy_V2s=sum(a.command_V(1:end-1).^2)*Ts;
row.CommandVariation_V=sum(abs(diff(a.command_V)));
row.CommandPeak_V=max(abs(a.command_V));
row.ReducedCapSamples=sum(a.commandLimit_V<24);row.StoppedSamples=sum(a.mode==4);
row.SlewLimitedSamples=sum(a.commandSlewLimited);row.AmplitudeLimitedSamples=sum(a.commandAmplitudeLimited);
row.IdealMinusDecodedPeak_counts=max(abs(a.idealMinusDecodedCount));
row.IdealMinusDecodedFinal_counts=a.idealMinusDecodedCount(end);
row.EMICountPeak_counts=max(abs(a.emiCountError));row.EMICountFinal_counts=a.emiCountError(end);
row.DecoderAuditPresent=isfield(exposed,'decoderAudit');
auditFields=["observedTransitions","shadowTransitions","extraTransitions", ...
 "missingTransitions","invalidTransitions","eventMatchingAllowance_s"];
metricFields=["ObservedTransitions","ShadowTransitions","ExtraTransitions", ...
 "MissingTransitions","InvalidTransitions","EventMatchingAllowance_s"];
for j=1:numel(auditFields)
 row.(metricFields(j))=NaN;
 if row.DecoderAuditPresent,row.(metricFields(j))=exposed.decoderAudit.(auditFields(j));end
end
row.QuantizationPeak_rad=max(abs(a.continuousQuantizationError_rad));
row.AlarmSamples=sum(a.alarm~=0);row.NonnormalSamples=sum(a.mode~=0);
cleanRequest=rad2deg(b.position_rad-b.requestedReference_rad);
row.CleanAlarmSamples=sum(b.alarm~=0);row.CleanNonnormalSamples=sum(b.mode~=0);
row.CleanSampledCountPeak_counts=max(abs(b.idealMinusDecodedCount));
row.CleanFinalRequestedError_deg=abs(cleanRequest(end));row.CleanTailRequestedRMSE_deg=rmsValue(cleanRequest(tail));
row.CleanCompleteFinite=matchingGrid(b.time_s,expectedTime)&& ...
 clean.run.params.control.sampleTime_s==c.task.sample_time_s&& ...
 all(isfinite([b.position_rad;b.velocity_rad_s;b.current_A;b.command_V]));
row.CleanCommandBoundsPass=all(abs(b.command_V)<=24+1e-12)&&all(abs(b.command_V)<=b.commandLimit_V+1e-12);
row.CleanStoppedCommandZero=all(b.command_V(b.mode==4)==0);
row.CleanCausalPackets=isequal(b.sourceIndex,(1:height(b))')&&all(b.sampleReceived);
row.CleanDecoderAuditPresent=isfield(clean,'decoderAudit');
row.CleanSequencePass=false;row.CleanDelayPass=false;
row.CleanMaximumDelay_s=NaN;row.CleanCountConservationPass=false;
if row.CleanDecoderAuditPresent
 row.CleanSequencePass=clean.decoderAudit.cleanSequencePass;
 row.CleanDelayPass=clean.decoderAudit.cleanDelayPass;
 row.CleanMaximumDelay_s=clean.decoderAudit.cleanMaximumDelay_s;
 row.CleanCountConservationPass=clean.decoderAudit.cleanCountConservationPass;
end
row.CleanGuardPass=row.CleanCompleteFinite&&row.CleanCommandBoundsPass&& ...
 row.CleanStoppedCommandZero&&row.CleanCausalPackets&& ...
 row.CleanDecoderAuditPresent&&row.CleanSequencePass&&row.CleanDelayPass&&row.CleanCountConservationPass&& ...
 ~any(b.receiverDomainFailed)&&row.CleanSampledCountPeak_counts<=1&& ...
 row.CleanFinalRequestedError_deg<=.5&&row.CleanTailRequestedRMSE_deg<=.5&& ...
 (~f.run.protectionEnabled||(row.CleanAlarmSamples==0&&row.CleanNonnormalSamples==0));
recovery=repmat(struct('Fixture',f.id,'Arm',f.arm,'Burst',0,'LastSourceDerivative_s',0, ...
 'RecoveryStart_s',NaN,'Confirmation_s',NaN,'Delay_s',NaN,'Status',"right_censored",'WithinLimit',false),2,1);
dwell=round(c.metrics.recovery_dwell_s/Ts);
for j=1:2
 recovery(j).Burst=j;recovery(j).LastSourceDerivative_s=burstEnd_s(j);
 good=abs(pair)<=c.metrics.task_rmse_deg;
 if f.run.protectionEnabled,good=good&a.mode==0;end
 first=find(t>=burstEnd_s(j),1);
 for k=first:height(a)-dwell
  if all(good(k:k+dwell))
   recovery(j).RecoveryStart_s=t(k);recovery(j).Confirmation_s=t(k+dwell);
   recovery(j).Delay_s=t(k)-burstEnd_s(j);recovery(j).Status="recovered";
   recovery(j).WithinLimit=recovery(j).Delay_s<=c.metrics.recovery_limit_s;break
  end
 end
end
recovery=struct2table(recovery);
row.Burst1Recovery_s=recovery.Delay_s(1);row.Burst2Recovery_s=recovery.Delay_s(2);
row.Burst1RecoveryStatus=recovery.Status(1);row.Burst2RecoveryStatus=recovery.Status(2);
row.ExecutionGuardPass=row.CompleteFinite&&row.CommandBoundsPass&&row.StoppedCommandZero&& ...
 row.ReceiverDomainPass&&row.CausalPackets&&row.DecoderAuditPresent&&row.CleanGuardPass;
row.TaskSuccess=row.ExecutionGuardPass&&row.WindowPairedRMSE_deg<=c.metrics.task_rmse_deg&& ...
 row.WindowPairedPeak_deg<=c.metrics.task_peak_deg&&row.FinalRequestedError_deg<=.5&& ...
 row.TailRequestedRMSE_deg<=.5&&all(recovery.WithinLimit);
% Each zero-to-nonzero shadow disagreement is a separate opportunity.
active=a.emiCountError~=0;starts=find(diff([false;active])==1);ends=find(diff([active;false])==-1);
alarmActive=a.alarm~=0;alarmOnsets=alarmActive&~[false;alarmActive(1:end-1)];
episodes=table('Size',[0,9],'VariableTypes', ...
 {'string','string','double','double','double','double','double','double','string'}, ...
 'VariableNames',{'Fixture','Arm','Episode','OriginBurst','FirstCorruptPacket_s', ...
 'LastCorruptPacket_s','FirstAlarm_s','DetectionDelay_s','Status'});
for j=1:numel(starts)
 k=starts(j);last=ends(j);delay=NaN;detected=NaN;status="missed";
 if ~f.run.protectionEnabled
  status="unprotected_diagnostic";
 elseif k>1&&a.alarm(k-1)~=0
  status="preexisting_alarm";
 else
  response=find(a.alarm(k:last)~=0,1);
  if ~isempty(response),detected=t(k+response-1);delay=detected-t(k);status="detected";
  elseif last==height(a),status="right_censored";end
 end
 originBurst=find(t(k)>=burstStart_s,1,'last');if isempty(originBurst),originBurst=0;end
 erow=table(f.id,f.arm,j,originBurst,t(k),t(last),detected,delay,status, ...
  'VariableNames',{'Fixture','Arm','Episode','OriginBurst','FirstCorruptPacket_s','LastCorruptPacket_s', ...
  'FirstAlarm_s','DetectionDelay_s','Status'});
 episodes=[episodes;erow]; %#ok<AGROW>
end
% Alarm onsets without a simultaneous shadow disagreement are false-alarm
% opportunities. A continuing alarm after corruption clears is retained as
% an alarm/no-disagreement sample diagnostic, not counted as a new alarm.
row.CorruptionEpisodes=numel(starts);row.FalseAlarmEpisodes=sum(alarmOnsets&~active);
row.NoncorruptionAlarmSamples=sum(alarmActive&~active);
cleanAlarm=b.alarm~=0;
row.CleanFalseAlarmEpisodes=sum(cleanAlarm&~[false;cleanAlarm(1:end-1)]);
if isempty(starts),row.DetectionStatus="no_detectable_opportunity";else,row.DetectionStatus="see_episode_table";end
burstAttribution=table();
for j=1:2
 before=find(t<burstStart_s(j),1,'last');
 preexisting=~isempty(before)&&active(before);
 selected=episodes(episodes.OriginBurst==j,:);
 status="no_detectable_opportunity";
 firstNew=NaN;delay=NaN;
 if ~isempty(selected)
  firstNew=selected.FirstCorruptPacket_s(1);delay=selected.DetectionDelay_s(1);
  status=selected.Status(1);
 end
 if preexisting,status="preexisting_corruption";end
 row.(sprintf('Burst%dDetectionStatus',j))=status;
 row.(sprintf('Burst%dPreexistingCorruption',j))=preexisting;
 row.(sprintf('Burst%dNewCorruptionEpisodes',j))=height(selected);
 burstRow=table(f.id,f.arm,j,burstStart_s(j),burstEnd_s(j),preexisting, ...
  height(selected),firstNew,delay,status,'VariableNames', ...
  {'Fixture','Arm','Burst','FirstSourceDerivative_s','LastSourceDerivative_s', ...
  'PreexistingCorruption','NewCorruptionEpisodes','FirstNewCorruptPacket_s', ...
  'FirstNewDetectionDelay_s','Status'});
 burstAttribution=[burstAttribution;burstRow]; %#ok<AGROW>
end
row=struct2table(row);
end

function value=rmsValue(x)
value=sqrt(mean(x.^2));
end

function pass=matchingGrid(actual,expected)
pass=isequal(size(actual),size(expected))&&all(abs(actual-expected)<=1e-12);
end
