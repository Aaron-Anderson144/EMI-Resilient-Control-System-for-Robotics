function cfg=phase3_configuration(params)
%PHASE3_CONFIGURATION Provisional numerical prototype, not hardware limits.
validate_parameters(params);
cfg.id="PHASE3-PROTOTYPE-V1.1";
cfg.observer=phase3_observer_configuration(params);
cfg.reacquisitionEnabled=false; % Requires an independent reference sensor.
cfg.reacquisition=phase3_reacquisition_configuration(cfg.observer);
cfg.supervisor=phase3_supervisor_configuration(params.control.sampleTime_s);
cfg.control=phase3_control_configuration(params);
cfg.minimumOperatingVoltage_V=0.5*params.electrical.nominalVoltage_V;
cfg.assumptions="Known zero initial state; measured applied motor voltage; timestamped position; assumed constant load; powered supervisor during motor-bus faults. Thresholds are provisional.";
end
