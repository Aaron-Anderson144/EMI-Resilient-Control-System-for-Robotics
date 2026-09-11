function simulationInput = create_baseline_simulation_input(modelName, params)
%CREATE_BASELINE_SIMULATION_INPUT Configure reference, plant, load and limits.
arguments
    modelName (1,1) string = "EMI_Resilient_Actuator_Baseline"
    params (1,1) struct = actuator_parameters()
end
simulationInput = Simulink.SimulationInput(char(modelName));
simulationInput = apply_actuator_simulation_input(simulationInput,params,"baseline");
simulationInput = simulationInput.setVariable('baselineParameters',params);
end
