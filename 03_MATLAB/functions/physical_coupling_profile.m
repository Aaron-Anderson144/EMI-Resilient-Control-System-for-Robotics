function profile = physical_coupling_profile(time_s, params, scenario)
%PHYSICAL_COUPLING_PROFILE Build reduced-order receiver-equivalent EMI signals.
% The edge-derived peak voltages are mapped to a controller-rate baseband
% envelope. This does not resolve the motor PWM waveform at the 1 kHz
% controller sample rate.

arguments
    time_s (:,1) double
    params (1,1) struct
    scenario (1,1) struct
end

validate_parameters(params);
if isempty(time_s) || any(~isfinite(time_s)) || any(diff(time_s) <= 0)
    error('EMIProject:InvalidTimeVector', ...
        'The time vector must be finite and strictly increasing.');
end

p = params.phase2b;
sourceMask = time_s >= p.source.startTime_s & time_s < p.source.stopTime_s;
groundMask = time_s >= p.groundOffset.startTime_s & ...
    time_s < p.groundOffset.stopTime_s;

dvdt_V_s = p.source.switchingVoltageStep_V / p.source.voltageRiseTime_s;
didt_A_s = p.source.currentStep_A / p.source.currentRiseTime_s;
deltaC_F = p.coupling.capacitive.linePositive_F - ...
    p.coupling.capacitive.lineNegative_F;
deltaM_H = p.coupling.inductive.linePositive_H - ...
    p.coupling.inductive.lineNegative_H;

receiverGain = 1 / sqrt(1 + ...
    (p.source.observedBasebandFrequency_Hz / p.receiver.bandwidth_Hz)^2);

capacitiveCurrentPeak_A = deltaC_F * dvdt_V_s;
capacitiveVoltagePeak_V = p.coupling.capacitive.pathTransferLinear * ...
    p.receiver.differentialTermination_Ohm * capacitiveCurrentPeak_A * receiverGain;
inductiveVoltagePeak_V = p.coupling.inductive.pathTransferLinear * ...
    deltaM_H * didt_A_s * receiverGain;
sharedReturnVoltagePeak_V = ...
    p.coupling.shared.returnResistance_Ohm * p.source.currentStep_A + ...
    p.coupling.shared.returnInductance_H * didt_A_s;
sharedDifferentialVoltagePeak_V = ...
    p.coupling.shared.commonModeToDifferential * sharedReturnVoltagePeak_V * receiverGain;

phase = 2 * pi * p.source.observedBasebandFrequency_Hz .* ...
    (time_s - p.source.startTime_s);

profile.capacitiveCurrent_A = zeros(size(time_s));
profile.capacitiveVoltage_V = zeros(size(time_s));
profile.inductiveVoltage_V = zeros(size(time_s));
profile.sharedImpedanceVoltage_V = zeros(size(time_s));
profile.groundCommonModeVoltage_V = zeros(size(time_s));
profile.groundDifferentialVoltage_V = zeros(size(time_s));

if scenario.coupling.capacitiveEnabled
    profile.capacitiveCurrent_A(sourceMask) = ...
        capacitiveCurrentPeak_A .* sin(phase(sourceMask));
    profile.capacitiveVoltage_V(sourceMask) = ...
        capacitiveVoltagePeak_V .* sin(phase(sourceMask));
end
if scenario.coupling.inductiveEnabled
    profile.inductiveVoltage_V(sourceMask) = ...
        inductiveVoltagePeak_V .* cos(phase(sourceMask));
end
if scenario.coupling.sharedImpedanceEnabled
    profile.sharedImpedanceVoltage_V(sourceMask) = ...
        sharedDifferentialVoltagePeak_V .* sin(phase(sourceMask) + pi / 4);
end
if scenario.groundOffset.enabled
    profile.groundCommonModeVoltage_V(groundMask) = p.groundOffset.voltage_V;
    profile.groundDifferentialVoltage_V(groundMask) = ...
        p.groundOffset.commonModeToDifferential * p.groundOffset.voltage_V;
end

profile.receiverDifferentialVoltage_V = ...
    profile.capacitiveVoltage_V + ...
    profile.inductiveVoltage_V + ...
    profile.sharedImpedanceVoltage_V + ...
    profile.groundDifferentialVoltage_V;
profile.equivalentEncoderError_rad = ...
    p.receiver.systemLevelEquivalentSensitivity_rad_V .* ...
    profile.receiverDifferentialVoltage_V;

profile.sourceWindowActive = sourceMask & scenario.physicalEnabled;
profile.groundWindowActive = groundMask & scenario.groundOffset.enabled;
profile.configuredWindowActive = ...
    profile.sourceWindowActive | profile.groundWindowActive;
profile.receiverMarginExceeded = ...
    abs(profile.receiverDifferentialVoltage_V) > ...
    p.receiver.differentialNoiseMargin_V;
profile.receiverMarginUtilization = ...
    abs(profile.receiverDifferentialVoltage_V) ./ ...
    p.receiver.differentialNoiseMargin_V;
profile.commonModeLimitExceeded = ...
    abs(profile.groundCommonModeVoltage_V) > ...
    p.receiver.commonModeLimit_V;

profile.derived.dvdt_V_s = dvdt_V_s;
profile.derived.didt_A_s = didt_A_s;
profile.derived.deltaC_F = deltaC_F;
profile.derived.deltaM_H = deltaM_H;
profile.derived.receiverGain = receiverGain;
profile.derived.terminationPole_Hz = 1 / (2 * pi * ...
    p.receiver.differentialTermination_Ohm * ...
    p.receiver.differentialCapacitance_F);
profile.derived.capacitiveCurrentPeak_A = capacitiveCurrentPeak_A;
profile.derived.capacitiveVoltagePeak_V = capacitiveVoltagePeak_V;
profile.derived.inductiveVoltagePeak_V = inductiveVoltagePeak_V;
profile.derived.sharedReturnVoltagePeak_V = sharedReturnVoltagePeak_V;
profile.derived.sharedDifferentialVoltagePeak_V = sharedDifferentialVoltagePeak_V;
profile.derived.worstCaseAlignedDifferentialVoltagePeak_V = ...
    abs(capacitiveVoltagePeak_V) + abs(inductiveVoltagePeak_V) + ...
    abs(sharedDifferentialVoltagePeak_V);
profile.derived.groundDifferentialVoltage_V = ...
    p.groundOffset.commonModeToDifferential * p.groundOffset.voltage_V;
end
