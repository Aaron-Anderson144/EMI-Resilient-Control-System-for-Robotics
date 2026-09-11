function configure_actuator_simulink_parameters(modelName, params, kind)
%CONFIGURE_ACTUATOR_SIMULINK_PARAMETERS Apply an interactive run explicitly.
% This is the intentionally stateful companion to SimulationInput helpers.
arguments
    modelName (1,1) string
    params (1,1) struct
    kind (1,1) string
end
assert_actuator_model_schema(modelName,kind);
matlabRoot = fileparts(fileparts(mfilename('fullpath')));
if ~bdIsLoaded(char(modelName))
    load_system(fullfile(matlabRoot,'models',char(modelName + ".slx")));
end
configuration = actuator_simulink_configuration(params,kind);
for k = 1:size(configuration.blocks,1)
    row = configuration.blocks(k,:);
    set_param(char(modelName + "/" + row{1}),row{2},row{3});
end
set_param(char(modelName),'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep',configuration.sampleTimeText,'StopTime',configuration.stopTimeText);
end
