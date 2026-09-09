function smokeTestSummary = smoke_test_phase2b_model()
%SMOKE_TEST_PHASE2B_MODEL Exercise every Phase 2B model scenario.

scriptPath = mfilename('fullpath');
matlabRoot = fileparts(fileparts(scriptPath));
run(fullfile(matlabRoot, 'startup_project.m'));

params = actuator_parameters();
modelName = 'EMI_Resilient_Actuator_Phase2B';
modelPath = fullfile(matlabRoot, 'models', [modelName, '.slx']);
if ~isfile(modelPath)
    build_phase2b_model(false);
end
load_system(modelPath);
modelCleanup = onCleanup(@() close_system(modelName, 0));

scenarioNames = [ ...
    "none", "capacitive_coupling", "inductive_coupling", ...
    "shared_impedance", "combined_coupling", "ground_offset", ...
    "communication_delay", "communication_jitter", ...
    "packet_loss", "combined_phase2b"];
scenarioCount = numel(scenarioNames);
completed = false(scenarioCount, 1);
finiteOutputs = false(scenarioCount, 1);
loggedSamples = zeros(scenarioCount, 1);
acceptedSourceMonotonic = false(scenarioCount, 1);
delayIntegralAndBounded = false(scenarioCount, 1);

maximumDelay = params.phase2b.communication.fixedDelay_samples + ...
    params.phase2b.communication.maximumJitter_samples;

for scenarioIndex = 1:scenarioCount
    scenario = phase2b_scenario(scenarioNames(scenarioIndex), params);
    [simulationInput, signals] = create_phase2b_simulation_input( ...
        modelName, params, scenario);
    simulationOutput = sim(simulationInput);
    logged = simulationOutput.get('phase2bSimout');
    values = logged.signals.values;

    completed(scenarioIndex) = ~isempty(logged);
    finiteOutputs(scenarioIndex) = all(isfinite(values), 'all');
    loggedSamples(scenarioIndex) = numel(logged.time);
    accepted = signals.communication.lastAcceptedSourceIndex;
    acceptedSourceMonotonic(scenarioIndex) = all(diff(accepted) >= 0);
    delays = signals.communication.transmitDelay_samples;
    delayIntegralAndBounded(scenarioIndex) = ...
        all(delays == floor(delays)) && all(delays >= 0) && ...
        all(delays <= maximumDelay);
end

smokeTestSummary = table(scenarioNames.', completed, finiteOutputs, ...
    loggedSamples, acceptedSourceMonotonic, delayIntegralAndBounded, ...
    'VariableNames', {'Scenario', 'Completed', 'FiniteOutputs', ...
    'LoggedSamples', 'AcceptedSourceMonotonic', ...
    'DelayIntegralAndBounded'});

expectedSamples = round(params.simulation.stopTime_s / ...
    params.control.sampleTime_s) + 1;
if ~all(completed & finiteOutputs & acceptedSourceMonotonic & ...
        delayIntegralAndBounded & loggedSamples == expectedSamples)
    error('EMIProject:Phase2BSmokeTestFailed', ...
        'At least one Phase 2B scenario failed its smoke-test gate.');
end

writetable(smokeTestSummary, fullfile(matlabRoot, 'results', ...
    'phase2b_simulink_smoke_test.csv'));
disp(smokeTestSummary);
clear modelCleanup
end
