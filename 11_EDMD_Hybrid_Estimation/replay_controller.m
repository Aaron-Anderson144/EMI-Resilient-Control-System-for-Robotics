function log = replay_controller(csvPath, modelFile, outputFolder)
%REPLAY_CONTROLLER Causal one-step shadow replay of a healthy controller CSV.
% log = replay_controller(csvPath,modelFile,outputFolder) loads selected linear
% and EDMD innovation models. Omitted modelFile uses results/latest_run.json;
% omitted outputFolder uses results/replays. Each invocation writes a new
% subfolder containing replay.csv and replay_metadata.json.
%
% Assumes known zero initial position/velocity/current at time zero. Only
% receivedMeasurement_rad, applied command_V, and sampling/domain eligibility
% enter the observer/predictors. Sample j is forecast from histories ending at
% j-1 and already-applied command u(j-1); no future measurement, reference,
% hidden load, or plant truth is used. This is healthy synchronous shadow
% replay only. It changes no control command and supplies no EMI detector or
% protection decision. Domain-failed, delayed, missing, or gapped records fail.
% Error columns use prediction minus received measurement. Warmup forecasts
% remain NaN. This adapter does not establish model performance on hardware.
% The model file must contain exactly the original four unweighted benchmark
% entries. Correction-study bundles and attached policies are rejected rather
% than silently selecting or discarding an optional weighting rule.

root = fileparts(mfilename('fullpath'));
oldPath = path;
restorePath = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(fullfile(root,'code'),'-begin');
if nargin < 2 || isempty(modelFile)
    pointerFile = fullfile(root,'results','latest_run.json');
    assert(isfile(pointerFile),'HybridReplay:ModelFile', ...
        'No completed run pointer exists; pass an explicit selected_models.mat file.');
    pointer = jsondecode(fileread(pointerFile));
    assert(isfield(pointer,'folder') && ...
        (ischar(pointer.folder) || (isstring(pointer.folder) && isscalar(pointer.folder))), ...
        'HybridReplay:ModelFile','The latest-run pointer has no valid folder name.');
    folder = char(string(pointer.folder));
    [parent,name,extension] = fileparts(folder);
    assert(isempty(parent) && strcmp(folder,[name,extension]) && ...
        ~ismember(string(folder),["",".",".."]), ...
        'HybridReplay:ModelFile','The latest-run folder must be a local directory name.');
    modelFile = fullfile(root,'results',folder,'selected_models.mat');
end
if nargin < 3 || isempty(outputFolder), outputFolder = fullfile(root,'results','replays'); end
modelFile = char(string(modelFile)); outputFolder = char(string(outputFolder));
assert(isfile(modelFile),'HybridReplay:ModelFile','The selected-model MAT file does not exist.');
saved = load(modelFile,'models');
assert(isfield(saved,'models') && iscell(saved.models) && numel(saved.models) == 4 && ...
    isstruct(saved.models{3}) && isstruct(saved.models{4}) && ...
    isfield(saved.models{3},'degree') && isfield(saved.models{4},'degree') && ...
    saved.models{3}.degree == 1 && saved.models{4}.degree == 2 && ...
    ~isfield(saved.models{3},'correctionPolicy') && ~isfield(saved.models{4},'correctionPolicy'), ...
    'HybridReplay:Models', ...
    'Expected exactly four original unweighted benchmark models, with 3=linear and 4=EDMD; correction-study bundles and policies are unsupported.');

record = edmd_load_controller(csvPath);
[trace,config] = hybrid_reference_observer(record);
n = numel(record.y);
models = saved.models(3:4);
maximumDelay = max(cellfun(@(m) m.delay,models));
warmupSeconds = 0.2;
% The preparation contract invalidates samples 1:100. The oldest learned
% history sample at every replay origin must therefore be at least 101.
firstOrigin = max([ceil(warmupSeconds/config.sampleTime)+1,101+maximumDelay]);
origins = firstOrigin:n-1;
assert(~isempty(origins),'HybridReplay:ShortRecord', ...
    'The record contains no one-step targets after the observer warmup.');
eligible = false(n,1); eligible(origins+1) = true;
predictions = NaN(n,2); numericalFailures = zeros(1,2);
posteriorAtOrigins = trace.posterior(origins,:)';
knownAppliedInputs = reshape(record.u(origins),1,[]);
for a = 1:2
    model = models{a}; d = model.delay;
    innovationHistory = reshape(trace.innovation(origins-(0:d)'),d+1,numel(origins));
    inputHistory = zeros(d,numel(origins));
    if d > 0, inputHistory = reshape(record.u(origins-(1:d)'),d,numel(origins)); end
    [forecast,diagnostic] = hybrid_forecast(config,posteriorAtOrigins, ...
        innovationHistory,inputHistory,knownAppliedInputs,model,"learned");
    predictions(origins+1,a) = forecast(:);
    numericalFailures(a) = sum(~isfinite(forecast(:)) | diagnostic.nonfinite(:));
end
time_s = record.t;
measurement_rad = record.y;
nominalPrior_rad = trace.prior(:,1);
linearPrediction_rad = predictions(:,1);
edmdPrediction_rad = predictions(:,2);
linearError_rad = linearPrediction_rad-measurement_rad;
edmdError_rad = edmdPrediction_rad-measurement_rad;
log = table(time_s,measurement_rad,nominalPrior_rad,linearPrediction_rad, ...
    edmdPrediction_rad,linearError_rad,edmdError_rad,eligible);

if ~isfolder(outputFolder), mkdir(outputFolder); end
runDir = tempname(outputFolder); mkdir(runDir);
writetable(log,fullfile(runDir,'replay.csv'));
metadata = struct('scope',"Healthy synchronous one-step shadow replay; no control intervention or detector", ...
    'sourceCSV',string(csvPath),'selectedModelsFile',string(modelFile), ...
    'outputDirectory',string(runDir),'sampleTime_s',config.sampleTime, ...
    'warmupSeconds',warmupSeconds,'firstEligibleTargetTime_s',time_s(origins(1)+1), ...
    'sampleCount',n,'eligibleForecastCount',numel(origins), ...
    'models',struct('linearDelay',models{1}.delay,'edmdDelay',models{2}.delay), ...
    'linearNonfiniteForecastCount',numericalFailures(1), ...
    'edmdNonfiniteForecastCount',numericalFailures(2), ...
    'initialStateAssumption',config.initialStateAssumption, ...
    'causalInputs',"Target j uses measured history through j-1 and already-applied voltage u(j-1)", ...
    'errorDefinition',"Prediction minus received encoder measurement; no truth-state error is calculated", ...
    'eligibilityMeaning',"Input/history eligibility only; nonfinite forecasts remain failures and are counted separately", ...
    'limitations',"Model generalization, EMI fault detection, packet recovery, receiver validity beyond the input gate, and hardware safety are not established");
hybrid_write_json(fullfile(runDir,'replay_metadata.json'),metadata);
fprintf('HYBRID_REPLAY %s\n',runDir);
end
