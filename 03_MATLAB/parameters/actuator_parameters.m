function params = actuator_parameters()
%ACTUATOR_PARAMETERS Return the representative Phase 1 parameter set.
%
% These values are engineering assumptions for software development. They
% are not measurements and must be replaced or identified before the model
% is treated as a representation of physical hardware.

params.meta.parameterSetId = "REPRESENTATIVE-ACTUATOR-V0.2";
params.meta.parentParameterSetId = "REPRESENTATIVE-ACTUATOR-V0.1";
params.meta.provenance = "Assumed values for baseline software development";
params.meta.createdDate = "2026-09-08";

params.electrical.nominalVoltage_V = 24.0;
params.electrical.resistance_Ohm = 1.20;
params.electrical.inductance_H = 2.50e-3;

params.motor.torqueConstant_Nm_A = 0.080;
params.motor.backEmfConstant_V_s_rad = 0.080;

params.mechanical.inertia_kg_m2 = 1.50e-4;
params.mechanical.viscousDamping_Nm_s_rad = 1.00e-4;
params.mechanical.nominalLoadTorque_Nm = 0.0;

params.sensor.encoderCountsPerRevolution = 4096;

params.control.sampleTime_s = 1.00e-3;
params.control.targetBandwidth_rad_s = 20.0;
params.control.voltageLimit_V = params.electrical.nominalVoltage_V;

params.simulation.stopTime_s = 1.50;
params.simulation.stepTime_s = 0.10;
params.simulation.stepAmplitude_rad = deg2rad(30.0);
params.simulation.randomSeed = 260908;
params.simulation.settlingBandFraction = 0.02;

% Phase 2 encoder-fault defaults. Each named scenario enables only the
% fault being studied; the default scenario remains "none".
params.faults.defaultScenario = "none";
params.faults.encoder.gaussian.standardDeviation_rad = deg2rad(0.25);
params.faults.encoder.gaussian.startTime_s = 0.20;
params.faults.encoder.gaussian.stopTime_s = 1.20;
params.faults.encoder.gaussian.randomSeed = 260909;

params.faults.encoder.sinusoid.amplitude_rad = deg2rad(1.00);
params.faults.encoder.sinusoid.frequency_Hz = 120.0;
params.faults.encoder.sinusoid.phase_rad = 0.0;
params.faults.encoder.sinusoid.startTime_s = 0.35;
params.faults.encoder.sinusoid.stopTime_s = 0.75;

params.faults.encoder.countJump.magnitude_counts = 128;
params.faults.encoder.countJump.time_s = 0.45;

params.faults.encoder.dropout.startTime_s = 0.50;
params.faults.encoder.dropout.stopTime_s = 0.65;
params.faults.encoder.dropout.behavior = "hold-last";

% Phase 2B source and coupling assumptions. The 1 kHz controller model
% cannot resolve individual PWM edges. These quantities therefore produce
% a receiver-equivalent baseband disturbance after front-end response.
params.phase2b.meta.provenance = ...
    "Assumed reduced-order values for sensitivity analysis";
params.phase2b.source.switchingVoltageStep_V = 24.0;
params.phase2b.source.pwmFrequency_Hz = 20.0e3;
params.phase2b.source.voltageRiseTime_s = 100e-9;
params.phase2b.source.voltageFallTime_s = 100e-9;
params.phase2b.source.currentStep_A = 3.0;
params.phase2b.source.currentRiseTime_s = 200e-9;
params.phase2b.source.observedBasebandFrequency_Hz = 120.0;
params.phase2b.source.startTime_s = 0.85;
params.phase2b.source.stopTime_s = 1.15;

params.phase2b.receiver.differentialTermination_Ohm = 120.0;
params.phase2b.receiver.differentialCapacitance_F = 100e-12;
params.phase2b.receiver.bandwidth_Hz = 5.0e6;
params.phase2b.receiver.differentialNoiseMargin_V = 0.20;
params.phase2b.receiver.commonModeLimit_V = 7.0;
params.phase2b.receiver.minimumPulseWidth_s = 50e-9;
params.phase2b.receiver.maxSpuriousCountsPerSample = 4;
params.phase2b.receiver.systemLevelEquivalentSensitivity_rad_V = ...
    deg2rad(10.0);

params.phase2b.coupling.capacitive.linePositive_F = 10.0e-12;
params.phase2b.coupling.capacitive.lineNegative_F = 9.0e-12;
params.phase2b.coupling.capacitive.pathTransferLinear = 0.20;

params.phase2b.coupling.inductive.linePositive_H = 20.0e-9;
params.phase2b.coupling.inductive.lineNegative_H = 17.0e-9;
params.phase2b.coupling.inductive.pathTransferLinear = 0.50;

params.phase2b.coupling.shared.returnResistance_Ohm = 25.0e-3;
params.phase2b.coupling.shared.returnInductance_H = 20.0e-9;
params.phase2b.coupling.shared.commonModeToDifferential = 0.10;

params.phase2b.groundOffset.voltage_V = 0.10;
params.phase2b.groundOffset.commonModeToDifferential = 0.10;
params.phase2b.groundOffset.startTime_s = 0.85;
params.phase2b.groundOffset.stopTime_s = 1.10;

params.phase2b.communication.startTime_s = 0.70;
params.phase2b.communication.stopTime_s = 1.10;
params.phase2b.communication.fixedDelay_samples = 8;
params.phase2b.communication.maximumJitter_samples = 8;
params.phase2b.communication.packetLossProbability = 0.20;
params.phase2b.communication.jitterRandomSeed = 260910;
params.phase2b.communication.packetLossRandomSeed = 260911;
params.phase2b.communication.lossBehavior = "hold-last";

params.phase2b.metrics.recoveryThreshold_rad = deg2rad(0.05);
params.phase2b.metrics.recoveryDwellSamples = 50;
params.phase2b.metrics.crossValidationTolerance_rad = 1e-9;
end
