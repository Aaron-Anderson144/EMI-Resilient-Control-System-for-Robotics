function simulationInput = apply_actuator_simulation_input(simulationInput, params, kind)
%APPLY_ACTUATOR_SIMULATION_INPUT Apply parameters without mutating workspaces.
arguments
    simulationInput (1,1) Simulink.SimulationInput
    params (1,1) struct
    kind (1,1) string
end
modelName = string(simulationInput.ModelName);
assert_actuator_model_schema(modelName,kind);
configuration = actuator_simulink_configuration(params,kind);
for k = 1:size(configuration.blocks,1)
    row = configuration.blocks(k,:);
    simulationInput = simulationInput.setBlockParameter( ...
        char(modelName + "/" + row{1}),row{2},row{3});
end
simulationInput = simulationInput.setModelParameter( ...
    'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep',configuration.sampleTimeText,'StopTime',configuration.stopTimeText);
end
