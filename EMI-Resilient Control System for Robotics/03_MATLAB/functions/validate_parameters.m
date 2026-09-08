function validate_parameters(params)
%VALIDATE_PARAMETERS Validate the minimum physical and simulation inputs.

positiveValues = [
    params.electrical.nominalVoltage_V
    params.electrical.resistance_Ohm
    params.electrical.inductance_H
    params.motor.torqueConstant_Nm_A
    params.motor.backEmfConstant_V_s_rad
    params.mechanical.inertia_kg_m2
    params.mechanical.viscousDamping_Nm_s_rad
    params.sensor.encoderCountsPerRevolution
    params.control.sampleTime_s
    params.control.targetBandwidth_rad_s
    params.control.voltageLimit_V
    params.simulation.stopTime_s
    params.simulation.stepAmplitude_rad
    params.simulation.settlingBandFraction
];

if any(~isfinite(positiveValues)) || any(positiveValues <= 0)
    error('EMIProject:InvalidPositiveParameter', ...
        'Positive physical and simulation parameters must be finite and greater than zero.');
end

if params.simulation.stepTime_s < 0 || ...
        params.simulation.stepTime_s >= params.simulation.stopTime_s
    error('EMIProject:InvalidStepTime', ...
        'The step time must be nonnegative and less than the stop time.');
end

if ~isfinite(params.mechanical.nominalLoadTorque_Nm)
    error('EMIProject:InvalidLoadTorque', ...
        'The nominal load torque must be finite.');
end

if params.simulation.settlingBandFraction >= 1
    error('EMIProject:InvalidSettlingBand', ...
        'The settling-band fraction must be less than one.');
end

if params.control.sampleTime_s * params.control.targetBandwidth_rad_s > 0.1
    warning('EMIProject:LowSamplingRatio', ...
        'Controller sampling may be too slow relative to the target bandwidth.');
end

faultWindows = [
    params.faults.encoder.gaussian.startTime_s, ...
        params.faults.encoder.gaussian.stopTime_s
    params.faults.encoder.sinusoid.startTime_s, ...
        params.faults.encoder.sinusoid.stopTime_s
    params.faults.encoder.dropout.startTime_s, ...
        params.faults.encoder.dropout.stopTime_s
];

if any(~isfinite(faultWindows), 'all') || ...
        any(faultWindows(:, 1) < 0) || ...
        any(faultWindows(:, 2) <= faultWindows(:, 1)) || ...
        any(faultWindows(:, 2) > params.simulation.stopTime_s)
    error('EMIProject:InvalidFaultWindow', ...
        'Each fault window must lie within the simulation and have positive duration.');
end

if params.faults.encoder.countJump.time_s < 0 || ...
        params.faults.encoder.countJump.time_s > params.simulation.stopTime_s
    error('EMIProject:InvalidCountJumpTime', ...
        'The count-jump time must lie within the simulation.');
end

if params.faults.encoder.gaussian.standardDeviation_rad < 0 || ...
        params.faults.encoder.sinusoid.amplitude_rad < 0 || ...
        params.faults.encoder.sinusoid.frequency_Hz < 0
    error('EMIProject:InvalidFaultMagnitude', ...
        'Fault magnitudes and frequency must be nonnegative.');
end

if params.faults.encoder.dropout.behavior ~= "hold-last"
    error('EMIProject:UnsupportedDropoutBehavior', ...
        'Phase 2 currently supports only hold-last dropout behavior.');
end
end
