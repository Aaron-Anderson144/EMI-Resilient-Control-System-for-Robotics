function validationTable = validate_phase2_simulink()
%VALIDATE_PHASE2_SIMULINK Compare Simulink against the analytical model.

scriptPath = mfilename('fullpath');
matlabRoot = fileparts(fileparts(scriptPath));
run(fullfile(matlabRoot, 'startup_project.m'));

params = actuator_parameters();
modelName = 'EMI_Resilient_Actuator_Phase2';
modelPath = fullfile(matlabRoot, 'models', [modelName, '.slx']);

if ~isfile(modelPath)
    build_phase2_model(false);
else
    load_system(modelPath);
end

modelCleanup = onCleanup(@() close_system(modelName, 0));
scenarioNames = ["none", "gaussian", "sinusoidal", "count_jump", "dropout"];
scenarioCount = numel(scenarioNames);

maximumReferenceDifference = zeros(scenarioCount, 1);
maximumTruePositionDifference = zeros(scenarioCount, 1);
maximumMeasuredPositionDifference = zeros(scenarioCount, 1);
maximumAdditiveFaultDifference = zeros(scenarioCount, 1);
maximumDropoutMaskDifference = zeros(scenarioCount, 1);

for scenarioIndex = 1:scenarioCount
    scenario = encoder_fault_scenario(scenarioNames(scenarioIndex), params);
    analyticalResult = simulate_faulted_actuator(params, scenario);

    configure_phase2_simulink_fault(scenarioNames(scenarioIndex));
    simulationOutput = sim(modelName, 'ReturnWorkspaceOutputs', 'on');
    loggedData = simulationOutput.get('phase2Simout');
    values = loggedData.signals.values;

    maximumReferenceDifference(scenarioIndex) = max(abs( ...
        values(:, 1) - analyticalResult.timeSeries.theta_ref_rad));
    maximumTruePositionDifference(scenarioIndex) = max(abs( ...
        values(:, 2) - analyticalResult.timeSeries.theta_rad));
    maximumMeasuredPositionDifference(scenarioIndex) = max(abs( ...
        values(:, 3) - analyticalResult.timeSeries.theta_measured_rad));
    maximumAdditiveFaultDifference(scenarioIndex) = max(abs( ...
        values(:, 4) - analyticalResult.profile.additive_rad));
    maximumDropoutMaskDifference(scenarioIndex) = max(abs( ...
        values(:, 5) - double(analyticalResult.profile.dropoutActive)));
end

validationTable = table( ...
    scenarioNames.', ...
    maximumReferenceDifference, ...
    maximumTruePositionDifference, ...
    maximumMeasuredPositionDifference, ...
    maximumAdditiveFaultDifference, ...
    maximumDropoutMaskDifference, ...
    'VariableNames', { ...
        'Scenario', ...
        'MaxReferenceDifference', ...
        'MaxTruePositionDifference', ...
        'MaxMeasuredPositionDifference', ...
        'MaxAdditiveFaultDifference', ...
        'MaxDropoutMaskDifference'});

tolerance = 1e-9;
numericDifferences = validationTable{:, 2:end};
if any(numericDifferences > tolerance, 'all')
    error('EMIProject:Phase2CrossValidationFailed', ...
        'Analytical and Simulink Phase 2 results differ by more than %.3g.', ...
        tolerance);
end

writetable(validationTable, ...
    fullfile(matlabRoot, 'results', 'phase2_simulink_validation.csv'));
disp(validationTable);
fprintf('Phase 2 analytical/Simulink cross-validation passed.\n');
clear modelCleanup
end

