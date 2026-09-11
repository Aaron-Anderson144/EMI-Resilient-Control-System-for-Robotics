function validationTable = validate_phase2_simulink(outputFolder)
%VALIDATE_PHASE2_SIMULINK Compare every logged channel on the expected grid.
arguments
    outputFolder (1,1) string = ""
end

matlabRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(matlabRoot,'functions'));
outputFolder=prepare_fresh_output_folder(outputFolder, ...
    fullfile(matlabRoot,'results','development'),"phase2_validation");
run(fullfile(matlabRoot, 'startup_project.m'));
oldConfig=Simulink.fileGenControl('getConfig');
cacheCleanup=onCleanup(@()Simulink.fileGenControl('setConfig','config',oldConfig));
Simulink.fileGenControl('set','CacheFolder',fullfile(outputFolder,'cache'), ...
    'CodeGenFolder',fullfile(outputFolder,'codegen'),'createDir',true);
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
channelNames = ["Reference_rad", "TruePosition_rad", "MeasuredPosition_rad", ...
    "AdditiveFault_rad", "DropoutMask"];
expectedSamples = round(params.simulation.stopTime_s / params.control.sampleTime_s) + 1;
tolerance = 1e-9;
rows = cell(numel(scenarioNames), 1);
detailTables = cell(numel(scenarioNames), 1);
for scenarioIndex = 1:numel(scenarioNames)
    name = scenarioNames(scenarioIndex);
    scenario = encoder_fault_scenario(name, params);
    analytical = simulate_faulted_actuator(params, scenario);
    configure_phase2_simulink_fault(name);
    simulationOutput = sim(modelName, 'ReturnWorkspaceOutputs', 'on');
    logged = simulationOutput.get('phase2Simout');
    expected = [analytical.timeSeries.theta_ref_rad, ...
        analytical.timeSeries.theta_rad, analytical.timeSeries.theta_measured_rad, ...
        analytical.profile.additive_rad, double(analytical.profile.dropoutActive)];
    [check, channels] = compare_logged_arrays(logged.time, logged.signals.values, ...
        analytical.timeSeries.time_s, expected, channelNames, tolerance, 5, expectedSamples);
    d = check.MaxDifferences;
    row = struct('Scenario', name, ...
        'MaxReferenceDifference', d(1), 'MaxTruePositionDifference', d(2), ...
        'MaxMeasuredPositionDifference', d(3), 'MaxAdditiveFaultDifference', d(4), ...
        'MaxDropoutMaskDifference', d(5), ...
        'ExpectedSamples', check.ExpectedSamples, 'LoggedSamples', check.LoggedSamples, ...
        'DimensionsValid', check.DimensionsValid, 'AllFinite', check.AllFinite, ...
        'TimeStrictlyIncreasing', check.TimeStrictlyIncreasing, ...
        'MaxTimeDifference_s', check.MaxTimeDifference_s, ...
        'DropoutMaskExact', check.DiscreteProfilesExact, ...
        'Passed', check.Passed, 'Diagnostic', check.Diagnostic);
    rows{scenarioIndex} = row;
    detailTables{scenarioIndex} = addvars(channels, ...
        repmat(name, height(channels), 1), 'Before', 1, 'NewVariableNames', 'Scenario');
end
validationTable = struct2table(vertcat(rows{:}));
% Publish evidence before raising a failure, including invalid/partial arrays.
writetable(validationTable, fullfile(outputFolder, 'phase2_simulink_validation.csv'));
writetable(vertcat(detailTables{:}), fullfile(outputFolder, 'phase2_simulink_validation_channels.csv'));
disp(validationTable);
assert(all(validationTable.Passed), 'EMIProject:Phase2CrossValidationFailed', ...
    ['Phase 2 analytical/Simulink validation failed. Records must be finite, ', ...
    'correctly dimensioned and time aligned; all five channels must agree ', ...
    'within 1e-9 and dropout masks exactly. See validation CSVs.']);
fprintf('Phase 2 analytical/Simulink cross-validation passed.\n');
clear modelCleanup
end
