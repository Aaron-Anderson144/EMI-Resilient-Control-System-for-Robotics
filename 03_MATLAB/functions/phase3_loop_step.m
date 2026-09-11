function [state,sample]=phase3_loop_step(state,plantOutput,externalMeasurement)
%PHASE3_LOOP_STEP Sensor fixture, observer, supervisor and controller, in order.
% plantOutput is used ONLY to generate the sensor signal. Monitor/control
% helpers receive measurement/timestamp, applied voltage, bus, reference,
% and explicit reset. Fault masks and true state never enter decisions.
% With a third argument, the strict decoded-measurement packet replaces the
% entire primary sensor/communication fixture. plantOutput is then ignored;
% use [] to make the plant-truth boundary explicit. Independent-reference
% reacquisition must be disabled. See phase3_external_measurement.
k=state.sampleIndex+1;run=state.run;f=run.profiles;cfg=run.configuration;
assert(k<=numel(f.time_s),'EMIProject:Phase3RecordEnd','Sample beyond fixture.');
external=nargin>=3;
if external
 assert(~cfg.reacquisitionEnabled,'EMIProject:ExternalMeasurementIndependentReference', ...
  'External decoded measurements require independent-reference reacquisition disabled.');
 [measurement,sensor,source,received]=phase3_external_measurement( ...
  externalMeasurement,k,state.lastReceivedMeasurement_rad);
 state.sensorHistory(k)=sensor;state.previousSensorMeasurement_rad=sensor;
 state.lastReceivedMeasurement_rad=measurement;
else
 sensor=plantOutput(1)+f.encoder.additive_rad(k)+f.physical.equivalentEncoderError_rad(k)+f.bias_rad(k)+f.benignNoise_rad(k);
 if f.encoder.dropoutActive(k),sensor=state.previousSensorMeasurement_rad;end
 if f.nonfinite(k),sensor=NaN;end
 state.sensorHistory(k)=sensor;state.previousSensorMeasurement_rad=sensor;
 source=f.communication.acceptedSourceIndex(k);received=f.communication.sampleReceived(k);
 if received,state.lastReceivedMeasurement_rad=state.sensorHistory(source);end
 measurement=state.lastReceivedMeasurement_rad;
end
[state.observer,obs]=phase3_observer_step(state.observer,measurement,source,received,state.previousAppliedVoltage_V);
% A separate synthetic position sensor is constructed here, at the same
% boundary as the primary encoder. Only its scalar measurement, timestamp,
% declared uncertainty and request enter the reconstruction helper.
ref=struct('currentIndex',k,'stopped',logical(run.protectionEnabled&&state.supervisor.mode==4), ...
 'request',false,'sampleReceived',false,'position_rad',0,'sourceIndex',0, ...
 'uncertainty_rad',0,'previousAppliedVoltage_V',state.previousAppliedVoltage_V);
if ~external && cfg.reacquisitionEnabled && isfield(f,'independentReference')
 r=f.independentReference;
 ref.request=r.request(k);ref.sampleReceived=r.sampleReceived(k);
 ref.position_rad=plantOutput(1)+double(r.error_rad(k));
 ref.sourceIndex=double(r.sourceIndex(k));ref.uncertainty_rad=double(r.uncertainty_rad(k));
end
[state.reacquisition,reacq]=phase3_reacquisition_step(state.reacquisition,ref);
if reacq.committed
 state.observer=phase3_observer_reanchor(state.observer,reacq.estimatedState);
 obs.estimatedState=state.observer.estimatedState;
 obs.estimatedPosition_rad=state.observer.estimatedState(1);
 % Reference samples never earn primary credibility, and this tick cannot
 % release the latch even if a reset coincides with successful reconstruction.
 obs.credibleFresh=false;obs.estimateUsable=false;
 obs.gateReason="independent_reference_reanchor";
end
healthy=f.supply.voltage_V(k)>=cfg.minimumOperatingVoltage_V;
if run.protectionEnabled
 input=struct('alarm',obs.alarm,'credibleFresh',obs.credibleFresh,'supplyHealthy',healthy, ...
  'estimateUsable',obs.estimateUsable,'resetRequest',f.resetRequest(k)&&~reacq.committed);
 [state.supervisor,settings]=phase3_supervisor_step(state.supervisor,input,cfg.supervisor);
 feedback=obs.estimatedPosition_rad;
 % No feedback is used to command stopped motion. Keep original estimate
 % diagnostics, but prevent nonfinite arithmetic from defeating zero output.
 if ~settings.driveEnabled && ~isfinite(feedback),feedback=0;end
 controlInput=struct('reference_rad',f.reference_rad(k),'feedback_rad',feedback, ...
  'availableLimit_V',f.supply.commandLimit_V(k));
 [state.controller,command,control]=phase3_control_step(state.controller,controlInput,settings,cfg.control);
 mode=state.supervisor.mode;limit=control.commandLimit_V;raw=control.rawCommand_V;
 transitionReason=settings.transitionReason;
else
 error=f.reference_rad(k)-measurement;
 raw=state.legacyC*state.legacyControllerState+state.legacyD*error;
 limit=f.supply.commandLimit_V(k);command=min(max(raw,-limit),limit);
 if f.supply.driveAvailable(k)
  state.legacyControllerState=state.legacyA*state.legacyControllerState+state.legacyB*error;
 elseif f.supply.controllerStatePolicy=="reset"
  state.legacyControllerState(:)=0;
 end
 mode=0;transitionReason="none";
end
sample=struct('command_V',command,'reference_rad',f.reference_rad(k), ...
 'sensorMeasurement_rad',sensor,'receivedMeasurement_rad',measurement, ...
 'estimatedPosition_rad',obs.estimatedState(1),'estimatedVelocity_rad_s',obs.estimatedState(2), ...
 'estimatedCurrent_A',obs.estimatedState(3),'innovation_rad',obs.innovation_rad, ...
 'mode',mode,'alarm',obs.alarm,'measurementAccepted',obs.measurementAccepted, ...
 'credibleFresh',obs.credibleFresh,'estimateUsable',obs.estimateUsable, ...
 'predictionAge_s',obs.predictionAge_s,'commandLimit_V',limit,'unsaturatedCommand_V',raw, ...
 'sourceIndex',source,'sampleReceived',received,'resetRequest',f.resetRequest(k), ...
 'supplyHealthy',healthy,'gateReason',obs.gateReason,'transitionReason',transitionReason, ...
 'referencePosition_rad',ref.position_rad,'referenceSourceIndex',ref.sourceIndex, ...
 'referenceReceived',ref.sampleReceived,'reacquisitionRequest',ref.request, ...
 'reacquisitionQualified',reacq.qualified,'reacquisitionCommitted',reacq.committed, ...
 'reacquisitionPositionBound_rad',reacq.stateUncertainty(1), ...
 'reacquisitionVelocityBound_rad_s',reacq.stateUncertainty(2), ...
 'reacquisitionCurrentBound_A',reacq.stateUncertainty(3), ...
 'reacquisitionFitResidual_rad',reacq.fitResidual_rad, ...
 'referenceUncertainty_rad',ref.uncertainty_rad,'reacquisitionReason',reacq.reason);
if external
 % Preserve the historical sample schema when the new boundary is unused.
 % Activity flags identify the actual sequential limit operations, including
 % cases where a mode rebase or hard stop also changes the final command.
 if run.protectionEnabled
  sample.commandSlewLimited=control.slewLimited;
  sample.commandAmplitudeLimited=control.amplitudeLimited;
  sample.controllerRebased=control.rebased;
 else
  sample.commandSlewLimited=false;
  sample.commandAmplitudeLimited=command~=raw;
  sample.controllerRebased=false;
 end
end
state.sampleIndex=k;state.previousAppliedVoltage_V=command;
end
