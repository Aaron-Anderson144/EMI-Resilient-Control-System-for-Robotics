function scenario = configure_phase2_simulink_fault(scenarioName)
%CONFIGURE_PHASE2_SIMULINK_FAULT Load a fault profile into the base workspace.

params = actuator_parameters();
scenario = encoder_fault_scenario(scenarioName, params);
time_s = (0:params.control.sampleTime_s:params.simulation.stopTime_s).';
profile = encoder_fault_profile(time_s, params, scenario);

encoderAdditiveFault = timeseries(profile.additive_rad, time_s);
encoderDropoutMask = timeseries(double(profile.dropoutActive), time_s);

assignin('base', 'encoderAdditiveFault', encoderAdditiveFault);
assignin('base', 'encoderDropoutMask', encoderDropoutMask);
assignin('base', 'phase2FaultScenario', scenario);

fprintf('Configured Phase 2 Simulink fault: %s\n', scenario.name);
end

