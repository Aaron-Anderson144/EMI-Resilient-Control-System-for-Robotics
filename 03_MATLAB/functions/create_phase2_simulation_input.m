function [simulationInput, signals] = create_phase2_simulation_input(modelName, params, scenario)
%CREATE_PHASE2_SIMULATION_INPUT Own both model parameters and encoder inputs.
arguments
    modelName (1,1) string
    params (1,1) struct
    scenario (1,1) struct
end
validate_parameters(params);
time_s = (0:round(params.simulation.stopTime_s / params.control.sampleTime_s))' ...
    .* params.control.sampleTime_s;
profile = encoder_fault_profile(time_s,params,scenario);
signals.encoderAdditiveFault = timeseries(profile.additive_rad,time_s);
signals.encoderDropoutMask = timeseries(double(profile.dropoutActive),time_s);
signals.profile = profile;
signals.time_s = time_s;
simulationInput = Simulink.SimulationInput(char(modelName));
simulationInput = apply_actuator_simulation_input(simulationInput,params,"phase2");
simulationInput = simulationInput.setVariable('encoderAdditiveFault',signals.encoderAdditiveFault);
simulationInput = simulationInput.setVariable('encoderDropoutMask',signals.encoderDropoutMask);
simulationInput = simulationInput.setVariable('phase2FaultScenario',scenario);
simulationInput = simulationInput.setVariable('phase2Parameters',params);
end
