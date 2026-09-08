function params = actuator_parameters()
%ACTUATOR_PARAMETERS Return the representative Phase 1 parameter set.
%
% These values are engineering assumptions for software development. They
% are not measurements and must be replaced or identified before the model
% is treated as a representation of physical hardware.

params.meta.parameterSetId = "REPRESENTATIVE-ACTUATOR-V0.1";
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
end
