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

phase2bPositiveValues = [
    params.phase2b.source.switchingVoltageStep_V
    params.phase2b.source.pwmFrequency_Hz
    params.phase2b.source.voltageRiseTime_s
    params.phase2b.source.voltageFallTime_s
    params.phase2b.source.currentStep_A
    params.phase2b.source.currentRiseTime_s
    params.phase2b.source.observedBasebandFrequency_Hz
    params.phase2b.receiver.differentialTermination_Ohm
    params.phase2b.receiver.differentialCapacitance_F
    params.phase2b.receiver.bandwidth_Hz
    params.phase2b.receiver.differentialNoiseMargin_V
    params.phase2b.receiver.commonModeLimit_V
    params.phase2b.receiver.minimumPulseWidth_s
    params.phase2b.receiver.systemLevelEquivalentSensitivity_rad_V
    params.phase2b.metrics.recoveryThreshold_rad
    params.phase2b.metrics.recoveryDwellSamples
    params.phase2b.metrics.crossValidationTolerance_rad
];

if any(~isfinite(phase2bPositiveValues)) || ...
        any(phase2bPositiveValues <= 0)
    error('EMIProject:InvalidPhase2BPositiveParameter', ...
        'Positive Phase 2B parameters must be finite and greater than zero.');
end

phase2bNonnegativeValues = [
    params.phase2b.receiver.maxSpuriousCountsPerSample
    params.phase2b.coupling.capacitive.linePositive_F
    params.phase2b.coupling.capacitive.lineNegative_F
    params.phase2b.coupling.inductive.linePositive_H
    params.phase2b.coupling.inductive.lineNegative_H
    params.phase2b.coupling.shared.returnResistance_Ohm
    params.phase2b.coupling.shared.returnInductance_H
    params.phase2b.communication.fixedDelay_samples
    params.phase2b.communication.maximumJitter_samples
    params.phase2b.communication.jitterRandomSeed
    params.phase2b.communication.packetLossRandomSeed
];

if any(~isfinite(phase2bNonnegativeValues)) || ...
        any(phase2bNonnegativeValues < 0) || ...
        ~isfinite(params.phase2b.groundOffset.voltage_V)
    error('EMIProject:InvalidPhase2BNonnegativeParameter', ...
        'Phase 2B magnitudes, delays, and seeds must be finite and nonnegative.');
end


attenuationValues = [
    params.phase2b.coupling.capacitive.pathTransferLinear
    params.phase2b.coupling.inductive.pathTransferLinear
    params.phase2b.coupling.shared.commonModeToDifferential
    params.phase2b.groundOffset.commonModeToDifferential
];

if any(~isfinite(attenuationValues)) || ...
        any(attenuationValues < 0) || any(attenuationValues > 1)
    error('EMIProject:InvalidPhase2BAttenuation', ...
        'Phase 2B attenuation factors must lie between zero and one.');
end


phase2bWindows = [
    params.phase2b.source.startTime_s, ...
        params.phase2b.source.stopTime_s
    params.phase2b.groundOffset.startTime_s, ...
        params.phase2b.groundOffset.stopTime_s
    params.phase2b.communication.startTime_s, ...
        params.phase2b.communication.stopTime_s
];

if any(~isfinite(phase2bWindows), 'all') || ...
        any(phase2bWindows(:, 1) < 0) || ...
        any(phase2bWindows(:, 2) <= phase2bWindows(:, 1)) || ...
        any(phase2bWindows(:, 2) > params.simulation.stopTime_s)
    error('EMIProject:InvalidPhase2BWindow', ...
        'Each Phase 2B window must lie within the simulation.');
end


if params.phase2b.source.observedBasebandFrequency_Hz >= ...
        0.5 / params.control.sampleTime_s
    error('EMIProject:Phase2BFrequencyAboveNyquist', ...
        'The receiver-equivalent frequency must remain below Nyquist.');
end


probability = params.phase2b.communication.packetLossProbability;
if ~isfinite(probability) || probability < 0 || probability > 1
    error('EMIProject:InvalidPacketLossProbability', ...
        'Packet-loss probability must lie between zero and one.');
end


integerValues = [
    params.phase2b.communication.fixedDelay_samples
    params.phase2b.communication.maximumJitter_samples
    params.phase2b.communication.jitterRandomSeed
    params.phase2b.communication.packetLossRandomSeed
    params.phase2b.metrics.recoveryDwellSamples
];

if any(integerValues ~= floor(integerValues))
    error('EMIProject:InvalidPhase2BIntegerParameter', ...
        'Delay, jitter, seed, and dwell values must be integers.');
end


if params.phase2b.communication.lossBehavior ~= "hold-last"
    error('EMIProject:UnsupportedCommunicationLossBehavior', ...
        'Phase 2B currently supports only hold-last packet-loss behavior.');
end
end
