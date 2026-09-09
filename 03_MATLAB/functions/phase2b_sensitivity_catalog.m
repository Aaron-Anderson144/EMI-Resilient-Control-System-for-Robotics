function catalog = phase2b_sensitivity_catalog(params)
%PHASE2B_SENSITIVITY_CATALOG Exploratory ranges, not physical uncertainty bounds.
% Signed imbalance sweeps preserve the arithmetic mean of the paired lines.
% Bandwidth is the existing BASEBAND gain parameter, not a circuit pole model.
arguments
    params (1,1) struct
end
p = params.phase2b;
rows = {
 "cap_imbalance", "Capacitive imbalance", "pF", -5, (p.coupling.capacitive.linePositive_F-p.coupling.capacitive.lineNegative_F)*1e12, 5, "linear", "response", "virtual.cap_imbalance", 1e-12
 "ind_imbalance", "Inductive imbalance", "nH", -15, (p.coupling.inductive.linePositive_H-p.coupling.inductive.lineNegative_H)*1e9, 15, "linear", "response", "virtual.ind_imbalance", 1e-9
 "voltage_rise", "Voltage rise time", "ns", 25, p.source.voltageRiseTime_s*1e9, 400, "log", "response", "source.voltageRiseTime_s", 1e-9
 "current_rise", "Current rise time", "ns", 50, p.source.currentRiseTime_s*1e9, 800, "log", "response", "source.currentRiseTime_s", 1e-9
 "voltage_step", "Aggressor voltage step", "V", 6, p.source.switchingVoltageStep_V, 48, "log", "response", "source.switchingVoltageStep_V", 1
 "current_step", "Commutation current step", "A", 0.5, p.source.currentStep_A, 6, "log", "response", "source.currentStep_A", 1
 "cap_transfer", "Capacitive transfer factor", "1", 0, p.coupling.capacitive.pathTransferLinear, 1, "linear", "response", "coupling.capacitive.pathTransferLinear", 1
 "ind_transfer", "Inductive transfer factor", "1", 0, p.coupling.inductive.pathTransferLinear, 1, "linear", "response", "coupling.inductive.pathTransferLinear", 1
 "return_resistance", "Shared-return resistance", "mOhm", 5, p.coupling.shared.returnResistance_Ohm*1e3, 100, "log", "response", "coupling.shared.returnResistance_Ohm", 1e-3
 "return_inductance", "Shared-return inductance", "nH", 2, p.coupling.shared.returnInductance_H*1e9, 100, "log", "response", "coupling.shared.returnInductance_H", 1e-9
 "shared_conversion", "Shared-return CM-to-DM factor", "1", 0, p.coupling.shared.commonModeToDifferential, 0.5, "linear", "response", "coupling.shared.commonModeToDifferential", 1
 "ground_voltage", "Ground common-mode offset", "V", -0.5, p.groundOffset.voltage_V, 0.5, "linear", "response", "groundOffset.voltage_V", 1
 "ground_conversion", "Ground CM-to-DM factor", "1", 0, p.groundOffset.commonModeToDifferential, 0.5, "linear", "response", "groundOffset.commonModeToDifferential", 1
 "termination", "Differential termination", "Ohm", 60, p.receiver.differentialTermination_Ohm, 240, "log", "response", "receiver.differentialTermination_Ohm", 1
 "bandwidth", "Equivalent baseband bandwidth", "Hz", 30, p.receiver.bandwidth_Hz, 1e7, "log", "response", "receiver.bandwidth_Hz", 1
 "angle_sensitivity", "Equivalent voltage-to-angle gain", "deg/V", 1, rad2deg(p.receiver.systemLevelEquivalentSensitivity_rad_V), 50, "log", "response", "receiver.systemLevelEquivalentSensitivity_rad_V", pi/180
 "envelope_frequency", "Receiver-equivalent envelope frequency", "Hz", 5, p.source.observedBasebandFrequency_Hz, 400, "log", "response", "source.observedBasebandFrequency_Hz", 1
 "noise_margin", "Differential diagnostic margin", "V", 0.025, p.receiver.differentialNoiseMargin_V, 0.4, "log", "diagnostic", "receiver.differentialNoiseMargin_V", 1
 "common_mode_limit", "Common-mode diagnostic limit", "V", 0.025, p.receiver.commonModeLimit_V, 15, "log", "diagnostic", "receiver.commonModeLimit_V", 1
 "receiver_capacitance", "Receiver differential capacitance", "pF", 10, p.receiver.differentialCapacitance_F*1e12, 1000, "log", "derived_only", "receiver.differentialCapacitance_F", 1e-12
 "pwm_frequency", "PWM frequency (context only)", "kHz", 5, p.source.pwmFrequency_Hz*1e-3, 100, "log", "inactive", "source.pwmFrequency_Hz", 1e3
 "voltage_fall", "Voltage fall time (reserved)", "ns", 25, p.source.voltageFallTime_s*1e9, 400, "log", "inactive", "source.voltageFallTime_s", 1e-9
 "minimum_pulse", "Minimum pulse width (reserved)", "ns", 10, p.receiver.minimumPulseWidth_s*1e9, 500, "log", "inactive", "receiver.minimumPulseWidth_s", 1e-9
 "count_cap", "Spurious count cap (reserved)", "counts/sample", 1, p.receiver.maxSpuriousCountsPerSample, 16, "integer", "inactive", "receiver.maxSpuriousCountsPerSample", 1
 "cap_mean", "Mean paired capacitance", "pF", 5, mean([p.coupling.capacitive.linePositive_F p.coupling.capacitive.lineNegative_F])*1e12, 30, "log", "inactive", "virtual.cap_mean", 1e-12
 "ind_mean", "Mean paired mutual inductance", "nH", 10, mean([p.coupling.inductive.linePositive_H p.coupling.inductive.lineNegative_H])*1e9, 100, "log", "inactive", "virtual.ind_mean", 1e-9
};
catalog = cell2table(rows, 'VariableNames', {'Key','Label','Unit','Low', ...
    'Nominal','High','Scale','Role','ParameterPath','SIConversion'});
catalog.RangeProvenance = repmat("Exploratory assumed design range; not measured bounds or a probability distribution", height(catalog), 1);
end
