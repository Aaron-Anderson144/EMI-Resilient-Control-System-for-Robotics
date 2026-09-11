function f=phase3_fault_profiles(p,s)
%PHASE3_FAULT_PROFILES Frozen exogenous profiles shared by matched runs.
validate_parameters(p);validate_phase3_scenario(s,p);
Ts=p.control.sampleTime_s;n=round(p.simulation.stopTime_s/Ts)+1;
f.time_s=(0:n-1)'*Ts;t=f.time_s;
assert(s.actualParameters.control.sampleTime_s==Ts,'EMIProject:Phase3SampleTime','Actual and nominal sample times must match.');
assert(iscolumn(s.initialPlantState)&&numel(s.initialPlantState)==3&&all(isfinite(s.initialPlantState)),'EMIProject:Phase3InitialState','Initial plant state must be finite3x1.');
assert(numel(s.referenceTimes_s)==numel(s.referenceValues_rad)&&s.referenceTimes_s(1)==0&&all(diff(s.referenceTimes_s)>0)&&all(isfinite(s.referenceValues_rad)),'EMIProject:Phase3Reference','Reference knots must start at zero and increase.');
f.reference_rad=interp1(s.referenceTimes_s,s.referenceValues_rad,t,'previous','extrap');
f.loadTorque_Nm=repmat(s.loadTorque_Nm,n,1);
assert(all(isfinite(f.loadTorque_Nm)),'EMIProject:Phase3Load','Load must be finite.');
f.encoder=encoder_fault_profile(t,p,s.encoder);
f.physical=physical_coupling_profile(t,p,s.phase2b);
f.communication=communication_channel_profile(t,p,s.phase2b);
f.supply=supply_fault_profile(t,p,s.phase2b);
dropWindow=t>=s.packetDropStartTime_s&t<s.packetDropStopTime_s;
if any(dropWindow)
 f.communication.packetDropped=f.communication.packetDropped|dropWindow;
 schedule=schedule_timestamped_packets(f.communication.transmitDelay_samples,f.communication.packetDropped);
 fields=fieldnames(schedule);for j=1:numel(fields),f.communication.(fields{j})=schedule.(fields{j});end
 f.communication.measurementAge_s=f.communication.measurementAge_samples*Ts;
end
% Recount only after all forced drops and their final rescheduling. The
% source-window union avoids counting overlapping fault opportunities twice.
f.communication.packetSummary=packet_profile_summary(f.communication, ...
 f.communication.configuredWindowActive|dropWindow);
f.communication.transmittedPacketCount=f.communication.packetSummary.record.transmittedPacketCount;
f.communication.droppedPacketCount=f.communication.packetSummary.record.droppedPacketCount;
f.communication.acceptedPacketCount=f.communication.packetSummary.record.acceptedPacketCount;
stream=RandStream('mt19937ar','Seed',s.noiseSeed);
f.benignNoise_rad=s.benignNoiseStandardDeviation_rad*randn(stream,n,1);
biasWindow=t>=s.biasStartTime_s&t<s.biasStopTime_s;
f.bias_rad=zeros(n,1);f.bias_rad(biasWindow)=s.bias_rad+s.rampRate_rad_s*(t(biasWindow)-s.biasStartTime_s);
f.nonfinite=false(n,1);
if isfinite(s.nonfiniteSampleTime_s)&&s.nonfiniteSampleTime_s<=t(end),[~,idx]=min(abs(t-s.nonfiniteSampleTime_s));f.nonfinite(idx)=true;end
f.resetRequest=false(n,1);
if isfinite(s.resetRequestTime_s)&&s.resetRequestTime_s<=t(end)
 [~,idx]=min(abs(t-s.resetRequestTime_s));f.resetRequest(idx)=true;
end
% Truth masks below are ONLY for offline scoring, never passed to FDI.
f.sensorFaultAtSource=f.encoder.anyFaultActive|f.physical.configuredWindowActive|f.bias_rad~=0|f.nonfinite;
f.sourceFault=f.sensorFaultAtSource|f.communication.configuredWindowActive|dropWindow|f.supply.configuredWindowActive;
f.receiverFault=false(n,1);
accepted=find(f.communication.sampleReceived);
f.receiverFault(accepted)=f.sensorFaultAtSource(f.communication.acceptedSourceIndex(accepted));
f.receiverFault=f.receiverFault|dropWindow|f.supply.configuredWindowActive|f.communication.configuredWindowActive;
end
