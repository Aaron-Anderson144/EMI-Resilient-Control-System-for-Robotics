function row=phase3_motion_metrics(result,matchedClean,fixture,policyId)
%PHASE3_MOTION_METRICS Score requested motion separately from shaped motion.
% Plant truth and fault exposure are offline evidence only. Candidate sensor
% rates use source time and the preceding TRUSTED measurement, including
% rejected finite candidates, exactly at the observer's pre-rate boundary.
a=result.timeSeries;b=matchedClean.timeSeries;t=result.time_s;
f=result.run.profiles;cf=matchedClean.run.profiles;
Ts=result.run.params.control.sampleTime_s;n=numel(t);
assert(isequal(t,matchedClean.time_s)&&istable(a)&&istable(b)&& ...
 height(a)==n&&height(b)==n&&n>=2&&isequal(a.time_s,t)&&isequal(b.time_s,t), ...
 'EMIProject:MotionAlignment','Matched records and time-series rows must share one sample grid.');
assert(iscolumn(t)&&all(isfinite(t))&& ...
 all(abs(t-(0:n-1)'*Ts)<=64*eps(max([1;abs(t)]))), ...
 'EMIProject:MotionAlignment','Motion evidence must start at zero on the configured sample grid.');
required={'requestedReference_rad','motionTrace','motionConfiguration','motionGoverned'};
assert(all(isfield(f,required))&&all(isfield(cf,required)), ...
 'EMIProject:InvalidMotionMetricsInput','Both matched profiles must retain motion provenance.');
assert(isequal(f.requestedReference_rad,cf.requestedReference_rad)&& ...
 isequal(f.reference_rad,cf.reference_rad)&&isequal(a.reference_rad,f.reference_rad)&& ...
 isequal(b.reference_rad,cf.reference_rad)&&isequal(f.motionConfiguration,cf.motionConfiguration)&& ...
 isequal(f.motionGoverned,cf.motionGoverned), ...
 'EMIProject:MotionAlignment','Matched runs must use identical requested and applied references and motion policy.');
assert(islogical(f.motionGoverned)&&isscalar(f.motionGoverned), ...
 'EMIProject:InvalidMotionMetricsInput','Motion applicability must be explicitly logical.');
window=fixture.window_s;
assert(isfloat(window)&&isreal(window)&&isequal(size(window),[1,2])&&all(isfinite(window))&& ...
 window(1)>=t(1)&&window(2)<=t(end)&&window(2)>window(1), ...
 'EMIProject:InvalidMotionWindow','The fixed motion-scoring window must lie inside the record.');
indices=find(t>=window(1)&t<window(2));
assert(numel(indices)>=2,'EMIProject:InvalidMotionWindow','Scoring requires at least two samples.');
assert(any(string(fixture.kind)==["clean","fault","diagnostic"])&& ...
 any(string(fixture.responseKind)==["alarm","stop","none"])&& ...
 islogical(fixture.requireStop)&&isscalar(fixture.requireStop)&& ...
 islogical(fixture.requireResetRelease)&&isscalar(fixture.requireResetRelease)&& ...
 isfloat(fixture.alarmDeadline_s)&&isreal(fixture.alarmDeadline_s)&&isscalar(fixture.alarmDeadline_s)&& ...
 (isnan(fixture.alarmDeadline_s)||(isfinite(fixture.alarmDeadline_s)&&fixture.alarmDeadline_s>=0)), ...
 'EMIProject:InvalidMotionMetricsInput','Fixture behavior requirements are invalid.');
motion=f.motionConfiguration;phase3_reference_governor_initialize(motion);
trace=f.motionTrace;cleanTrace=cf.motionTrace;
traceNames={'Time_s','Requested_rad','SlewReference_rad','ShapedReference_rad','Velocity_rad_s','Acceleration_rad_s2'};
assert(istable(trace)&&istable(cleanTrace)&&height(trace)==n&&height(cleanTrace)==n&& ...
 all(ismember(traceNames,trace.Properties.VariableNames))&& ...
 all(ismember(traceNames,cleanTrace.Properties.VariableNames))&& ...
 isequal(trace.Time_s,t)&&isequal(cleanTrace.Time_s,t)&&isequaln(trace,cleanTrace), ...
 'EMIProject:MotionAlignment','Matched governor traces must share the record sample grid and values.');
requested=f.requestedReference_rad;commanded=a.reference_rad;
assert(isfloat(requested)&&isreal(requested)&&isequal(size(requested),[n,1])&& ...
 all(isfinite(requested))&&isequal(trace.Requested_rad,requested)&& ...
 isequal(trace.ShapedReference_rad,commanded), ...
 'EMIProject:MotionAlignment','Requested and shaped reference evidence must match the saved profiles.');
velocity=[0;diff(commanded)/Ts];acceleration=[0;diff(velocity)/Ts];
requestedError=a.position_rad-requested;commandError=a.position_rad-commanded;
shapingError=commanded-requested;disturbance=a.position_rad-b.position_rad;
tail=t>=max(t(1),t(end)-.100)-64*eps(max(1,t(end)));
row.Fixture=string(fixture.id);row.Partition=string(fixture.partition);row.Kind=string(fixture.kind);
row.Policy=string(policyId);row.ReferenceGoverned=f.motionGoverned;
row.WindowStart_s=window(1);row.WindowStop_s=window(2);row.WindowSamples=numel(indices);
row.RequestedWindowRMSE_deg=rad2deg(rms(requestedError(indices)));
row.CommandWindowRMSE_deg=rad2deg(rms(commandError(indices)));
row.ShapingWindowRMSE_deg=rad2deg(rms(shapingError(indices)));
row.WindowDisturbanceRMSE_deg=rad2deg(rms(disturbance(indices)));
row.FullRequestedRMSE_deg=rad2deg(rms(requestedError));
row.FinalRequestedError_deg=rad2deg(abs(requestedError(end)));
row.FinalRequestedTailRMSE_deg=rad2deg(rms(requestedError(tail)));
row.MaxTrueVelocity_rad_s=max(abs(a.velocity_rad_s));
[row.MaxCandidateMeasurementRate_rad_s,row.CandidateMeasurementRateSamples]=candidateRates(a,result.run.configuration.observer);
row.MaxReferenceVelocity_rad_s=max(abs(velocity));
row.MaxReferenceAcceleration_rad_s2=max(abs(acceleration));
row.WindowPeakCurrent_A=max(abs(a.current_A(indices)));row.FullPeakCurrent_A=max(abs(a.current_A));
row.AlarmSamples=nnz(a.alarm);row.FirstAlarm_s=firstTime(t,a.alarm~=0);
row.SafeStopDuration_s=nnz(a.mode(1:end-1)==4)*Ts;row.FinalMode=a.mode(end);
row.StopOccurred=any(a.mode==4);
releases=find([false;a.mode(1:end-1)==4&a.mode(2:end)~=4]);
row.ResetReleaseOccurred=any(a.resetRequest(releases)==1);
row.ReferenceTracePass=all(abs(trace.Velocity_rad_s-velocity)<=1e-9)&& ...
 all(abs(trace.Acceleration_rad_s2-acceleration)<=1e-6);
row.ReferenceBoundsPass=row.ReferenceTracePass&& ...
 row.MaxReferenceVelocity_rad_s<=motion.maxVelocity_rad_s+1e-9&& ...
 row.MaxReferenceAcceleration_rad_s2<=motion.maxAcceleration_rad_s2+1e-6&& ...
 all(abs(commanded)<=motion.positionLimit_rad+1e-12);
traceValues=trace{:,traceNames};
row.FinitePass=all(isfinite([result.state(:);a.position_rad;a.velocity_rad_s;a.current_A; ...
 a.command_V;a.unsaturatedCommand_V;a.commandLimit_V;requested;commanded;traceValues(:)]));
row.CommandBoundsPass=all(abs(a.command_V)<=a.commandLimit_V+1e-12)&& ...
 all(abs(a.command_V)<=f.supply.commandLimit_V+1e-12)&&all(a.commandLimit_V>=0);
row.StopZeroPass=all(a.command_V(a.mode==4)==0);
row.CommitsRemainStopped=all(a.mode(a.reacquisitionCommitted~=0)==4& ...
 a.command_V(a.reacquisitionCommitted~=0)==0&~a.credibleFresh(a.reacquisitionCommitted~=0));
row.ReleaseEvidencePass=true;
requiredRelease=result.run.configuration.supervisor.safeStopRelease_samples;
for k=reshape(releases,1,[])
 first=k-requiredRelease+1;
 row.ReleaseEvidencePass=row.ReleaseEvidencePass&&first>=1&&a.resetRequest(k)==1&& ...
  all(a.credibleFresh(first:k)~=0&a.alarm(first:k)==0&a.supplyHealthy(first:k)~=0)&& ...
  ~a.reacquisitionCommitted(k);
end
row.CommandInvariantsPass=row.FinitePass&&row.ReferenceTracePass&&row.CommandBoundsPass&& ...
 row.StopZeroPass&&row.CommitsRemainStopped&&row.ReleaseEvidencePass;
response=a.alarm~=0|a.mode~=0;
row.FirstReceiverExposure_s=firstTime(t,f.receiverFault~=0);
row.FirstResponse_s=firstTime(t,response);row.FirstStop_s=firstTime(t,a.mode==4);
row.PreexistingAlarm=false;row.PreexistingResponse=false;
row.FirstPostExposureAlarm_s=NaN;row.FirstPostExposureResponse_s=NaN;
row.FirstPostExposureStop_s=NaN;
if isfinite(row.FirstReceiverExposure_s)
 before=t<row.FirstReceiverExposure_s;after=~before;
 row.PreexistingAlarm=any(a.alarm(before)~=0);row.PreexistingResponse=any(response(before));
 row.FirstPostExposureAlarm_s=firstTime(t,after&a.alarm~=0);
 row.FirstPostExposureResponse_s=firstTime(t,after&response);
 row.FirstPostExposureStop_s=firstTime(t,after&a.mode==4);
end
row.BehaviorApplicable=row.Kind~="diagnostic";
row.AlarmDeadlinePass=true;
if row.Kind=="fault"&&isfinite(fixture.alarmDeadline_s)
 requiredResponse=row.FirstPostExposureAlarm_s;
 if string(fixture.responseKind)=="stop",requiredResponse=row.FirstPostExposureStop_s;end
 row.AlarmDeadlinePass=string(fixture.responseKind)~="none"&&~row.PreexistingResponse&& ...
  isfinite(requiredResponse)&&requiredResponse<=fixture.alarmDeadline_s+1e-12;
end
row.CleanAlarmPass=~any(a.alarm~=0|a.mode~=0);
row.ActualVelocityPass=row.MaxTrueVelocity_rad_s<=20+1e-10;
row.CandidateMeasurementRatePass=row.CandidateMeasurementRateSamples>0&& ...
 isfinite(row.MaxCandidateMeasurementRate_rad_s)&& ...
 row.MaxCandidateMeasurementRate_rad_s<=result.run.configuration.observer.rateLimit_rad_s+1e-10;
row.FinalRequestedTrackingPass=row.FinalRequestedError_deg<=.5+1e-10&& ...
 row.FinalRequestedTailRMSE_deg<=.5+1e-10;
row.DeclaredBehaviorPass=true;
if row.Kind=="clean"
 row.DeclaredBehaviorPass=row.ReferenceBoundsPass&&row.CleanAlarmPass&&row.ActualVelocityPass&& ...
  row.CandidateMeasurementRatePass&&row.FinalRequestedTrackingPass;
elseif row.Kind=="fault"
 row.DeclaredBehaviorPass=row.ReferenceBoundsPass&&row.AlarmDeadlinePass&& ...
  (~fixture.requireStop||row.StopOccurred)&& ...
  (~fixture.requireResetRelease||(row.ResetReleaseOccurred&&row.FinalMode==0));
end
end

function value=firstTime(time,condition)
k=find(condition,1);value=NaN;if ~isempty(k),value=time(k);end
end

function [peak,count]=candidateRates(a,c)
lastSeen=0;lastTrusted=0;trustedValue=NaN;lastAnchor=1;peak=NaN;count=0;
for k=1:height(a)
 source=a.sourceIndex(k);
 valid=a.sampleReceived(k)~=0&&isfinite(source)&&source==fix(source)&&source>=1&&source<=k;
 if valid&&source>lastSeen
  lastSeen=source;
  available=source>=max(lastAnchor,k-c.historyCapacity+1);
  age=(k-source)*c.sampleTime_s;
  if available&&age<=c.maxMeasurementAge_s+64*eps(max(c.sampleTime_s,c.maxMeasurementAge_s))&& ...
    isfinite(a.receivedMeasurement_rad(k))&&lastTrusted>0
   rate=abs((a.receivedMeasurement_rad(k)-trustedValue)/((source-lastTrusted)*c.sampleTime_s));
   count=count+1;if count==1,peak=rate;else,peak=max(peak,rate);end
  end
  if a.measurementAccepted(k)~=0
   lastTrusted=source;trustedValue=a.receivedMeasurement_rad(k);
  end
 end
 % Reconstruction occurs after the observer's measurement gate this tick.
 if a.reacquisitionCommitted(k)~=0,lastAnchor=k;end
end
end
