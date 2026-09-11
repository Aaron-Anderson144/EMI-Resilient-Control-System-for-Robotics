function scenario = configure_phase2_simulink_fault(scenarioName, params)
%CONFIGURE_PHASE2_SIMULINK_FAULT Load a fault profile into the base workspace.
arguments
    scenarioName (1,1) string = "none"
    params (1,1) struct = actuator_parameters()
end
validate_parameters(params);
scenario = encoder_fault_scenario(scenarioName, params);
time_s = (0:round(params.simulation.stopTime_s / params.control.sampleTime_s))' ...
    .* params.control.sampleTime_s;
profile = encoder_fault_profile(time_s, params, scenario);
configure_actuator_simulink_parameters("EMI_Resilient_Actuator_Phase2",params,"phase2");

encoderAdditiveFault = timeseries(profile.additive_rad, time_s);
encoderDropoutMask = timeseries(double(profile.dropoutActive), time_s);

assignin('base', 'encoderAdditiveFault', encoderAdditiveFault);
assignin('base', 'encoderDropoutMask', encoderDropoutMask);
assignin('base', 'phase2FaultScenario', scenario);
assignin('base', 'phase2Parameters', params);

fprintf('Configured Phase 2 Simulink fault: %s\n', scenario.name);
end
