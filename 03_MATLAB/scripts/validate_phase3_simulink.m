function validationTable = validate_phase3_simulink(study, outputFolder)
%VALIDATE_PHASE3_SIMULINK Compare numerical runs with an independent plant.
% study is a nonempty cell vector of simulate_phase3_actuator results. Each
% contains time_s, state (N-by-3), loopValues (N-by-31), and the complete run.
% All states and loop channels are checked. Only innovation_rad can be NaN,
% and its missing-value mask must match exactly. Modes/flags/source indices
% are exact. The numerical and Simulink implementations share decision logic;
% this evidence checks independent plant and scheduler integration, not an
% independent FDI implementation or physical hardware validation.

matlabRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(matlabRoot, 'functions'), fullfile(matlabRoot, 'parameters'));
validateattributes(study, {'cell'}, {'vector','nonempty'});
if nargin < 2 || strlength(string(outputFolder)) == 0
    outputFolder = fullfile(matlabRoot, 'results', 'development', 'phase3', ...
        ['simulink_', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))]);
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
[~, loopNames] = phase3_logged_values();
loopNames = reshape(string(loopNames), 1, []);
plantNames = ["position_rad", "velocity_rad_s", "current_A"];
assert(numel(loopNames) == 31 && loopNames(8) == "innovation_rad", ...
    'EMIProject:InvalidPhase3LogSchema', 'Expected the Phase 3 31-channel log schema.');
modelName = 'EMI_Resilient_Actuator_Phase3';
modelPath = fullfile(matlabRoot, 'models', [modelName, '.slx']);
modelCleanup = onCleanup(@() localClose(modelName, modelPath));
tolerance = 1e-9;
rows = cell(numel(study), 1);
details = cell(2*numel(study), 1);
evidence = cell(numel(study), 1);
for index = 1:numel(study)
    analytical = study{index};
    assert(isstruct(analytical) && isscalar(analytical) && ...
        all(isfield(analytical, {'time_s','state','loopValues','run'})), ...
        'EMIProject:InvalidPhase3Study', 'Each study cell must contain a complete numerical result.');
    runRecord = analytical.run;
    sampleTime = runRecord.params.control.sampleTime_s;
    expectedTime = (0:round(runRecord.params.simulation.stopTime_s/sampleTime)).' * sampleTime;
    sampleCount = numel(expectedTime);
    scenarioName = string(runRecord.scenario.name);
    protectionEnabled = logical(runRecord.protectionEnabled);
    simulationError = "";
    warningCount = Inf;
    completed = false;
    plantTime = zeros(0,1); plantValues = zeros(0,3);
    loopTime = zeros(0,1); loopValues = zeros(0,31);
    warningDiagnostics = [];
    try
        % The builder applies this run in memory, preserving an existing
        % saved model. Only exogenous load is supplied as a time series.
        build_phase3_simulink_model(runRecord, false);
        simulationOutput = sim(modelName, 'ReturnWorkspaceOutputs', 'on');
        plantLog = simulationOutput.get('phase3PlantSimout');
        loopLog = simulationOutput.get('phase3LoopSimout');
        plantTime = plantLog.time;
        plantValues = plantLog.signals.values;
        loopTime = loopLog.time;
        loopValues = loopLog.signals.values;
        execution = simulationOutput.SimulationMetadata.ExecutionInfo;
        warningDiagnostics = execution.WarningDiagnostics;
        warningCount = numel(warningDiagnostics);
        completed = strcmp(execution.StopEvent, 'ReachedStopTime');
    catch exception
        simulationError = string(exception.identifier) + ": " + string(exception.message);
    end
    [plantCheck, plantChannels] = compare_logged_arrays(plantTime, plantValues, ...
        analytical.time_s, analytical.state, plantNames, tolerance, [], sampleCount);
    [loopCheck, loopChannels, innovationNaNsMatch] = localCompareLoop( ...
        loopTime, loopValues, analytical.time_s, analytical.loopValues, ...
        loopNames, tolerance, sampleCount);
    expectedGridValid = isnumeric(analytical.time_s) && isreal(analytical.time_s) && ...
        isequal(size(analytical.time_s), size(expectedTime)) && ...
        all(isfinite(analytical.time_s)) && ...
        max(abs(analytical.time_s-expectedTime)) <= 32*eps(max(1, expectedTime(end)));
    passed = plantCheck.Passed && loopCheck.Passed && innovationNaNsMatch && ...
        expectedGridValid && completed && warningCount == 0 && strlength(simulationError) == 0;
    diagnostic = strjoin(["plant: " + plantCheck.Diagnostic, ...
        "loop: " + loopCheck.Diagnostic, simulationError], "; ");
    rows{index} = struct('RunIndex', index, 'Scenario', scenarioName, ...
        'ProtectionEnabled', protectionEnabled, 'ExpectedSamples', sampleCount, ...
        'LoggedPlantSamples', plantCheck.LoggedSamples, ...
        'LoggedLoopSamples', loopCheck.LoggedSamples, ...
        'ExpectedTimeGridValid', expectedGridValid, ...
        'DimensionsValid', plantCheck.DimensionsValid && loopCheck.DimensionsValid, ...
        'RecordValuesValid', plantCheck.AllFinite && loopCheck.AllFinite && innovationNaNsMatch, ...
        'TimeStrictlyIncreasing', plantCheck.TimeStrictlyIncreasing && loopCheck.TimeStrictlyIncreasing, ...
        'MaxTimeDifference_s', max(plantCheck.MaxTimeDifference_s, loopCheck.MaxTimeDifference_s), ...
        'MaxPositionDifference_rad', plantCheck.MaxDifferences(1), ...
        'MaxVelocityDifference_rad_s', plantCheck.MaxDifferences(2), ...
        'MaxCurrentDifference_A', plantCheck.MaxDifferences(3), ...
        'MaxLoopDifference', max(loopCheck.MaxDifferences), ...
        'DiscreteProfilesExact', loopCheck.DiscreteProfilesExact, ...
        'InnovationNaNMaskMatched', innovationNaNsMatch, ...
        'SimulationWarnings', warningCount, 'Completed', completed, ...
        'Passed', passed, 'Diagnostic', diagnostic);
    details{2*index-1} = localLabel(plantChannels, index, scenarioName, protectionEnabled, "plant");
    details{2*index} = localLabel(loopChannels, index, scenarioName, protectionEnabled, "loop");
    evidence{index} = struct('run', runRecord, 'plantTime_s', plantTime, ...
        'plantValues', plantValues, 'loopTime_s', loopTime, 'loopValues', loopValues, ...
        'plantCheck', plantCheck, 'loopCheck', loopCheck, ...
        'innovationNaNMaskMatched', innovationNaNsMatch, ...
        'warningDiagnostics', warningDiagnostics, 'simulationError', simulationError);
    % Keep partial/failing campaign evidence reviewable even if a later run
    % cannot be configured or MATLAB execution is interrupted.
    validationTable = struct2table(vertcat(rows{1:index}));
    channelTable = vertcat(details{1:2*index});
    writetable(validationTable, fullfile(outputFolder, 'phase3_simulink_validation.csv'));
    writetable(channelTable, fullfile(outputFolder, 'phase3_simulink_validation_channels.csv'));
    save(fullfile(outputFolder, 'phase3_simulink_validation.mat'), ...
        'validationTable', 'channelTable', 'evidence', 'loopNames', 'plantNames', 'tolerance');
end
disp(validationTable);
assert(all(validationTable.Passed), 'EMIProject:Phase3SimulinkCrossValidationFailed', ...
    ['Phase 3 integration cross-validation failed. All plant/loop samples must agree ', ...
    'within 1e-9, discrete channels and innovation NaN masks exactly, on a complete ', ...
    'uniform time grid without simulation warnings. See saved CSV/MAT evidence.']);
fprintf('Phase 3 independent-plant/shared-loop integration cross-validation passed (%d runs).\n', height(validationTable));
clear modelCleanup
end

function [check, channels, masksMatch] = localCompareLoop(actualTime, actual, ...
    expectedTime, expected, names, tolerance, sampleCount)
masksMatch = false;
if isnumeric(actual) && isreal(actual) && isnumeric(expected) && isreal(expected) && ...
        isequal(size(actual), [sampleCount, 31]) && isequal(size(expected), [sampleCount, 31])
    actualMissing = isnan(actual(:,8));
    expectedMissing = isnan(expected(:,8));
    masksMatch = isequal(actualMissing, expectedMissing);
    % Replace only paired documented missing values, retaining every other
    % nonfinite value so the ordinary finite-array gate rejects it.
    matchedMissing = actualMissing & expectedMissing;
    actual(matchedMissing,8) = 0;
    expected(matchedMissing,8) = 0;
end
[check, channels] = compare_logged_arrays(actualTime, actual, expectedTime, ...
    expected, names, tolerance, [9:13,17:20,22:26], sampleCount);
if ~masksMatch
    check.ChannelsPassed(8) = false;
    channels.ChannelPassed(8) = false;
    check.Passed = false;
    check.Diagnostic = strjoin([check.Diagnostic, "innovation_missing_mask_mismatch"], "; ");
end
end

function channels = localLabel(channels, index, name, protected, domain)
count = height(channels);
channels = addvars(channels, repmat(index,count,1), repmat(name,count,1), ...
    repmat(protected,count,1), repmat(domain,count,1), 'Before', 1, ...
    'NewVariableNames', {'RunIndex','Scenario','ProtectionEnabled','Domain'});
end

function localClose(modelName, expectedPath)
% A path-rejected preloaded model belongs to the caller. Do not close it
% while unwinding a failed validation campaign or its final assertion.
if bdIsLoaded(modelName)
    actualPath = get_param(modelName, 'FileName');
    if ~isempty(actualPath) && ...
            strcmpi(char(java.io.File(actualPath).getCanonicalPath()), ...
            char(java.io.File(expectedPath).getCanonicalPath()))
        close_system(modelName, 0);
    end
end
end
