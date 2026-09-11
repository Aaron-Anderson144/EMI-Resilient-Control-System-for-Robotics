function state=phase3_loop_initialize(run)
%PHASE3_LOOP_INITIALIZE Shared sampled sensor/control logic, no plant dynamics.
cfg=run.configuration;
Ts=run.params.control.sampleTime_s;
assert(cfg.observer.sampleTime_s==Ts&&cfg.supervisor.sampleTime_s==Ts&&cfg.control.sampleTime_s==Ts,'EMIProject:Phase3SampleTime','All control sample times must match.');
assert(isscalar(cfg.minimumOperatingVoltage_V)&&isfinite(cfg.minimumOperatingVoltage_V)&&cfg.minimumOperatingVoltage_V>0,'EMIProject:Phase3SupplyThreshold','Supply threshold must be finite and positive.');
% Fixture explicitly declares assumed load independently from actual load.
% This declared input takes precedence; the effective cfg is saved in run.
cfg.observer.assumedLoadTorque_Nm=run.scenario.assumedLoadTorque_Nm;
% Older saved runs have no optional independent-reference capability.
if ~isfield(cfg,'reacquisitionEnabled'),cfg.reacquisitionEnabled=false;end
assert(islogical(cfg.reacquisitionEnabled)&&isscalar(cfg.reacquisitionEnabled), ...
 'EMIProject:InvalidReacquisitionConfiguration','Reacquisition enable must be logical.');
if ~isfield(cfg,'reacquisition'),cfg.reacquisition=phase3_reacquisition_configuration(cfg.observer);end
assert(cfg.reacquisition.sampleTime_s==Ts,'EMIProject:Phase3SampleTime', ...
 'Independent reference reconstruction must use the loop sample time.');
assert(isequal(cfg.reacquisition.A,cfg.observer.A)&&isequal(cfg.reacquisition.B,cfg.observer.B)&& ...
 isequal(cfg.reacquisition.C,cfg.observer.C),'EMIProject:ReacquisitionModelMismatch', ...
 'Reference reconstruction must use the active observer model.');
cfg.reacquisition.assumedLoadTorque_Nm=run.scenario.assumedLoadTorque_Nm;
if isfield(run.profiles,'independentReference')
 validate_phase3_reference_profile(run.profiles.independentReference,numel(run.profiles.time_s));
end
state.run=run;state.run.configuration=cfg;
state.sampleIndex=0;state.sensorHistory=zeros(numel(run.profiles.time_s),1);
state.lastReceivedMeasurement_rad=0;state.previousSensorMeasurement_rad=0;
state.previousAppliedVoltage_V=0;
state.observer=phase3_observer_initialize(cfg.observer);
state.reacquisition=phase3_reacquisition_initialize(cfg.reacquisition);
state.supervisor=phase3_supervisor_initialize();
state.controller=phase3_control_initialize();
controller=design_baseline_controller(run.params,actuator_state_space(run.params));
[state.legacyA,state.legacyB,state.legacyC,state.legacyD]=ssdata(ss(controller.discrete));
state.legacyControllerState=zeros(size(state.legacyA,1),1);
end
