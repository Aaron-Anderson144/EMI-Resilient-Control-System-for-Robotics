function smokeTestSummary = smoke_test_phase2_model()
%SMOKE_TEST_PHASE2_MODEL Simulate all Phase 2 scenarios in Simulink.

scriptPath = mfilename('fullpath');
matlabRoot = fileparts(fileparts(scriptPath));
run(fullfile(matlabRoot, 'startup_project.m'));

modelName = 'EMI_Resilient_Actuator_Phase2';
modelPath = fullfile(matlabRoot, 'models', [modelName, '.slx']);

if ~isfile(modelPath)
    build_phase2_model(false);
else
    load_system(modelPath);
end

scenarioNames = ["none", "gaussian", "sinusoidal", "count_jump", "dropout"];
completed = false(numel(scenarioNames), 1);
loggedSamples = zeros(numel(scenarioNames), 1);

for scenarioIndex = 1:numel(scenarioNames)
    configure_phase2_simulink_fault(scenarioNames(scenarioIndex));
    simulationOutput = sim(modelName, 'ReturnWorkspaceOutputs', 'on');
    loggedData = simulationOutput.get('phase2Simout');
    completed(scenarioIndex) = ~isempty(loggedData);
    loggedSamples(scenarioIndex) = numel(loggedData.time);
end

smokeTestSummary = table(scenarioNames.', completed, loggedSamples, ...
    'VariableNames', {'Scenario', 'Completed', 'LoggedSamples'});

if ~all(completed)
    error('EMIProject:Phase2SmokeTestFailed', ...
        'At least one Phase 2 Simulink scenario failed to log results.');
end

close_system(modelName, 0);
disp(smokeTestSummary);
end

