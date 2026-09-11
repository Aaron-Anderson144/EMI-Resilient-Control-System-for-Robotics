function result = simulate_faulted_actuator(params, scenario)
%SIMULATE_FAULTED_ACTUATOR Run a sample-by-sample closed-loop simulation.
%
% Encoder faults are applied inside the feedback loop. A dropout uses the
% last accepted encoder value, representing a stale sample at the receiver.

validate_parameters(params);

sampleTime_s = params.control.sampleTime_s;
time_s = (0:sampleTime_s:params.simulation.stopTime_s).';
sampleCount = numel(time_s);

theta_ref_rad = zeros(sampleCount, 1);
theta_ref_rad(time_s >= params.simulation.stepTime_s) = ...
    params.simulation.stepAmplitude_rad;

faultProfile = encoder_fault_profile(time_s, params, scenario);

continuousPlant = actuator_state_space(params);
discretePlant = ss(c2d(continuousPlant, sampleTime_s, 'zoh'));
[plantA, plantB, plantC, plantD] = ssdata(discretePlant);

controller = design_baseline_controller(params, continuousPlant);
discreteController = ss(controller.discrete);
[controllerA, controllerB, controllerC, controllerD] = ...
    ssdata(discreteController);

plantState = zeros(size(plantA, 1), 1);
controllerState = zeros(size(controllerA, 1), 1);
previousDriveVoltage_V = 0;
lastValidEncoder_rad = 0;

theta_rad = zeros(sampleCount, 1);
omega_rad_s = zeros(sampleCount, 1);
current_A = zeros(sampleCount, 1);
theta_measured_rad = zeros(sampleCount, 1);
position_error_rad = zeros(sampleCount, 1);
voltage_cmd_unsaturated_V = zeros(sampleCount, 1);
voltage_cmd_V = zeros(sampleCount, 1);
measurement_stale = false(sampleCount, 1);
availableLimit_V = min(params.control.voltageLimit_V,params.electrical.nominalVoltage_V);

for sampleIndex = 1:sampleCount
    plantOutput = plantC * plantState + ...
        plantD * [previousDriveVoltage_V; params.mechanical.nominalLoadTorque_Nm];

    theta_rad(sampleIndex) = plantOutput(1);
    omega_rad_s(sampleIndex) = plantOutput(2);
    current_A(sampleIndex) = plantOutput(3);

    rawEncoder_rad = theta_rad(sampleIndex) + ...
        faultProfile.additive_rad(sampleIndex);

    if faultProfile.dropoutActive(sampleIndex)
        theta_measured_rad(sampleIndex) = lastValidEncoder_rad;
        measurement_stale(sampleIndex) = true;
    else
        theta_measured_rad(sampleIndex) = rawEncoder_rad;
        lastValidEncoder_rad = rawEncoder_rad;
    end

    position_error_rad(sampleIndex) = ...
        theta_ref_rad(sampleIndex) - theta_measured_rad(sampleIndex);

    rawCommand = controllerC * controllerState + ...
        controllerD * position_error_rad(sampleIndex);
    voltage_cmd_unsaturated_V(sampleIndex) = rawCommand;
    voltage_cmd_V(sampleIndex) = min( ...
        max(rawCommand, -availableLimit_V), availableLimit_V);

    if sampleIndex < sampleCount
        controllerState = controllerA * controllerState + ...
            controllerB * position_error_rad(sampleIndex);
        plantState = plantA * plantState + ...
            plantB * [voltage_cmd_V(sampleIndex); params.mechanical.nominalLoadTorque_Nm];
        previousDriveVoltage_V = voltage_cmd_V(sampleIndex);
    end
end

true_tracking_error_rad = theta_ref_rad - theta_rad;
measurement_error_rad = theta_measured_rad - theta_rad;
responseMask = time_s >= params.simulation.stepTime_s;

metrics.scenario = scenario.name;
metrics.trackingRMSE_rad = sqrt(mean( ...
    true_tracking_error_rad(responseMask).^2));
metrics.maximumTrackingError_rad = max(abs( ...
    true_tracking_error_rad(responseMask)));
metrics.measurementRMSE_rad = sqrt(mean(measurement_error_rad.^2));
metrics.maximumMeasurementError_rad = max(abs(measurement_error_rad));
metrics.peakVoltageCommand_V = max(abs(voltage_cmd_V));
metrics.saturatedSampleCount = nnz( ...
    abs(voltage_cmd_unsaturated_V) > availableLimit_V);
metrics.faultedSampleCount = nnz(faultProfile.anyFaultActive);
metrics.dropoutSampleCount = nnz(faultProfile.dropoutActive);
metrics.finalTrackingError_rad = true_tracking_error_rad(end);

result.params = params;
result.scenario = scenario;
result.profile = faultProfile;
result.metrics = metrics;
result.timeSeries = table( ...
    time_s, theta_ref_rad, theta_rad, theta_measured_rad, ...
    omega_rad_s, current_A, true_tracking_error_rad, ...
    measurement_error_rad, voltage_cmd_unsaturated_V, voltage_cmd_V, ...
    faultProfile.gaussian_rad, faultProfile.sinusoidal_rad, ...
    faultProfile.countJump_rad, faultProfile.dropoutActive, ...
    measurement_stale, ...
    'VariableNames', { ...
        'time_s', ...
        'theta_ref_rad', ...
        'theta_rad', ...
        'theta_measured_rad', ...
        'omega_rad_s', ...
        'current_A', ...
        'true_tracking_error_rad', ...
        'measurement_error_rad', ...
        'voltage_cmd_unsaturated_V', ...
        'voltage_cmd_V', ...
        'gaussian_fault_rad', ...
        'sinusoidal_fault_rad', ...
        'count_jump_fault_rad', ...
        'dropout_active', ...
        'measurement_stale'});
end
