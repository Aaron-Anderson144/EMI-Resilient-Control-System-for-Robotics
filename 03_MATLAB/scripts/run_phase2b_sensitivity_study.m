function study = run_phase2b_sensitivity_study(outputFolder, options)
%RUN_PHASE2B_SENSITIVITY_STUDY Reproducible reduced-order parameter screening.
% Requires startup_project. Writes new artifacts only inside outputFolder.
% Ranges and stratification are exploratory, not physical probability bounds.
arguments
    outputFolder (1,1) string = ""
    options.GlobalSamples (1,1) double {mustBeInteger,mustBePositive} = 512
    options.Levels (1,1) double {mustBeInteger,mustBePositive} = 9
    options.GridLevels (1,1) double {mustBeInteger,mustBePositive} = 11
    options.Seed (1,1) double {mustBeInteger,mustBeNonnegative} = 260909
    options.CreateFigures (1,1) logical = true
end
assert(options.Levels >= 3 && options.GridLevels >= 3, ...
    'EMIProject:TooFewSensitivityLevels', 'At least three levels are required.');
matlabRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(matlabRoot,'functions'));
outputFolder=prepare_fresh_output_folder(outputFolder, ...
    fullfile(matlabRoot,'results','development'),"phase2b_sensitivity");
startClock = tic;
params = actuator_parameters();
catalog = phase2b_sensitivity_catalog(params);
contexts = ["physical_only", "combined_phase2b"];
baseline = simulate_phase2b_actuator(params, phase2b_scenario("none", params));
nominalResults = cell(2,1);
for c = 1:2
    nominalResults{c} = simulate_phase2b_actuator(params, localScenario(params, contexts(c)));
end
study.metadata.createdUTC = string(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss z'));
study.metadata.outputFolder=outputFolder;
study.metadata.matlabVersion = string(version);
study.metadata.parameterSetId = params.meta.parameterSetId;
study.metadata.options = options;
study.metadata.rangeMeaning = "Assumed exploratory ranges, not identified uncertainty or real-world failure probabilities";
study.metadata.baselineReuse = "Every swept variable is Phase2B-only; endpoint no-fault regressions verify reuse of the clean baseline";
study.metadata.communication = "Fixed nominal delay/loss settings and seeds across all combined runs; no reliability inference across seeds";
study.metadata.analysisWindow = "Both contexts use the same [0.70, 1.15) s study window; physical faults start at 0.85 s";
study.nominalParams = params;
study.catalog = catalog;
study.contexts = contexts;
writetable(catalog, fullfile(outputFolder,'phase2b_sensitivity_catalog.csv'));

records = {};
regressions = {};
for j = 1:height(catalog)
    definition = catalog(j,:);
    levels = localLevels(definition, options.Levels);
    for value = levels
        trialParams = apply_phase2b_sensitivity_value(params, definition, value);
        for c = 1:2
            record = localRun(trialParams, contexts(c), baseline, nominalResults{c});
            record.Parameter = definition.Key;
            record.Value = value;
            record.NominalValue = definition.Nominal;
            record.Unit = definition.Unit;
            record.Role = definition.Role;
            records{end+1,1} = record; %#ok<AGROW>
        end
    end
    for value = [definition.Low definition.Nominal definition.High]
        trialParams = apply_phase2b_sensitivity_value(params, definition, value);
        clean = simulate_phase2b_actuator(trialParams, phase2b_scenario("none", trialParams));
        difference = max(abs([clean.position_rad-baseline.position_rad; ...
            clean.receivedMeasurement_rad-baseline.receivedMeasurement_rad; ...
            clean.command_V-baseline.command_V]));
        assert(difference <= 1e-12, 'EMIProject:SensitivityBaselineChanged', ...
            'A swept parameter changed the no-fault trajectory.');
        regressions{end+1,1} = struct('Parameter',definition.Key, ...
            'Value',value,'MaxNoFaultDifference',difference); %#ok<AGROW>
    end
    fprintf('One-at-a-time sweep %d/%d: %s\n',j,height(catalog),definition.Key);
end
study.oat = struct2table(vertcat(records{:}));
study.noFaultRegression = struct2table(vertcat(regressions{:}));
study.ranking = localRanking(study.oat,catalog,contexts);
writetable(study.oat,fullfile(outputFolder,'phase2b_sensitivity_oat.csv'));
writetable(study.ranking,fullfile(outputFolder,'phase2b_sensitivity_ranking.csv'));
writetable(study.noFaultRegression,fullfile(outputFolder,'phase2b_sensitivity_no_fault_regression.csv'));

activeCatalog = catalog(catalog.Role == "response",:);
design = phase2b_sensitivity_design(activeCatalog,options.GlobalSamples,options.Seed);
study.globalInputs = array2table(design,'VariableNames',cellstr(activeCatalog.Key));
study.globalInputs.Sample = (1:options.GlobalSamples).';
study.globalParameters = cell(options.GlobalSamples,1);
records = cell(options.GlobalSamples*2,1);
for i = 1:options.GlobalSamples
    trialParams = params;
    for j = 1:height(activeCatalog)
        trialParams = apply_phase2b_sensitivity_value(trialParams,activeCatalog(j,:),design(i,j));
    end
    study.globalParameters{i} = trialParams;
    for c = 1:2
        record = localRun(trialParams,contexts(c),baseline,nominalResults{c});
        record.Sample = i;
        records{(i-1)*2+c} = record;
    end
    if mod(i,64) == 0 || i == options.GlobalSamples
        fprintf('Combined-parameter design %d/%d\n',i,options.GlobalSamples);
    end
end
study.globalMetrics = struct2table(vertcat(records{:}));
writetable(study.globalInputs,fullfile(outputFolder,'phase2b_sensitivity_global_inputs.csv'));
writetable(study.globalMetrics,fullfile(outputFolder,'phase2b_sensitivity_global_metrics.csv'));

% Two explicitly controlled interaction grids, with communication disabled.
pairs = ["ground_conversion","angle_sensitivity"; "return_inductance","current_rise"];
records = {};
for pairIndex = 1:size(pairs,1)
    first = catalog(catalog.Key == pairs(pairIndex,1),:);
    second = catalog(catalog.Key == pairs(pairIndex,2),:);
    firstLevels = localLevels(first,options.GridLevels);
    secondLevels = localLevels(second,options.GridLevels);
    for x = firstLevels
        for y = secondLevels
            trialParams = apply_phase2b_sensitivity_value(params,first,x);
            trialParams = apply_phase2b_sensitivity_value(trialParams,second,y);
            record = localRun(trialParams,"physical_only",baseline,nominalResults{1});
            record.Grid = pairIndex;
            record.FirstParameter = first.Key;
            record.SecondParameter = second.Key;
            record.FirstValue = x;
            record.SecondValue = y;
            records{end+1,1} = record; %#ok<AGROW>
        end
    end
    fprintf('Interaction grid %d/%d complete\n',pairIndex,size(pairs,1));
end
study.grid = struct2table(vertcat(records{:}));
writetable(study.grid,fullfile(outputFolder,'phase2b_sensitivity_interaction_grids.csv'));

% Save reproducible extreme cases, including a nominal case for each context.
cases = struct('label',{},'params',{},'scenario',{});
for c = 1:2
    cases(end+1) = localCase("nominal_"+contexts(c),params,contexts(c)); %#ok<AGROW>
    subset = study.globalMetrics(study.globalMetrics.Context == contexts(c),:);
    selectors = ["ActiveRMSE_deg","ActivePeak_deg","ReceiverPeak_V","PostPeak_deg"];
    selected = zeros(1,numel(selectors));
    for j = 1:numel(selectors)
        [~,selected(j)] = max(subset.(selectors(j)));
    end
    for index = unique(selected,'stable')
        sample = subset.Sample(index);
        cases(end+1) = localCase("global_"+sample+"_"+contexts(c), ...
            study.globalParameters{sample},contexts(c)); %#ok<AGROW>
    end
end
% Signed coupling edge and diagnostic-only case exercise additional semantics.
trialParams = apply_phase2b_sensitivity_value(params,catalog(catalog.Key=="cap_imbalance",:),-5);
trialParams = apply_phase2b_sensitivity_value(trialParams,catalog(catalog.Key=="ind_imbalance",:),-15);
cases(end+1) = localCase("negative_imbalances",trialParams,"physical_only");
trialParams = apply_phase2b_sensitivity_value(params,catalog(catalog.Key=="noise_margin",:),0.025);
cases(end+1) = localCase("diagnostic_margin_only",trialParams,"combined_phase2b");
study.validationCases = cases;
for i = 1:numel(cases)
    result = simulate_phase2b_actuator(cases(i).params,cases(i).scenario);
    [~,detail] = phase2b_metrics(result,baseline,cases(i).params);
    result.timeSeries.delta_position_rad = detail.deltaPosition_rad;
    writetable(result.timeSeries,fullfile(outputFolder, ...
        'phase2b_sensitivity_case_'+cases(i).label+'.csv'));
end
study.metadata.elapsedSeconds = toc(startClock);
study.metadata.studyClosedLoopRuns = height(study.oat)+height(study.globalMetrics)+ ...
    height(study.grid)+height(study.noFaultRegression)+3+numel(cases);
save(fullfile(outputFolder,'phase2b_sensitivity_study.mat'),'study','-v7');
if options.CreateFigures
    plot_phase2b_sensitivity(study,outputFolder);
end
fprintf('Sensitivity study complete: %d study runs, %.1f seconds.\n', ...
    study.metadata.studyClosedLoopRuns,study.metadata.elapsedSeconds);
end

function scenario = localScenario(params,context)
scenario = phase2b_scenario("combined_phase2b",params);
if context == "physical_only"
    scenario.name = "physical_only";
    scenario.description = "All physical channels; immediate loss-free communication";
    scenario.communication.fixedDelayEnabled = false;
    scenario.communication.jitterEnabled = false;
    scenario.communication.packetLossEnabled = false;
    scenario.communicationEnabled = false;
end
% Keep identical metric windows so context comparisons have the same divisor.
scenario.analysisStartTime_s = min([params.phase2b.source.startTime_s, ...
    params.phase2b.groundOffset.startTime_s,params.phase2b.communication.startTime_s]);
scenario.analysisStopTime_s = max([params.phase2b.source.stopTime_s, ...
    params.phase2b.groundOffset.stopTime_s,params.phase2b.communication.stopTime_s]);
end

function record = localRun(params,context,baseline,nominal)
result = simulate_phase2b_actuator(params,localScenario(params,context));
[m,detail] = phase2b_metrics(result,baseline,params);
signals = [result.position_rad;result.velocity_rad_s;result.current_A; ...
    result.sensorSideMeasurement_rad;result.receivedMeasurement_rad; ...
    result.command_V;result.unsaturatedCommand_V; ...
    result.physical.receiverDifferentialVoltage_V];
assert(all(isfinite(signals)), 'EMIProject:SensitivityNonfinite', 'A sensitivity run contains nonfinite signals.');
assert(m.preMaxAbsPositionDelta_rad <= 1e-12, ...
    'EMIProject:SensitivityPreOnset', 'A sensitivity run differs before onset.');
record.Context = context;
record.ActiveRMSE_deg = rad2deg(m.activePositionDeltaRMSE_rad);
record.ActivePeak_deg = rad2deg(m.activeMaxAbsPositionDelta_rad);
record.PostPeak_deg = rad2deg(m.postMaxAbsPositionDelta_rad);
record.PrePeak_rad = m.preMaxAbsPositionDelta_rad;
record.ActiveMeasurementPeak_deg = rad2deg(m.activeMaxAbsMeasurementDelta_rad);
record.ActiveCommandDelta_V = m.activeMaxAbsCommandDelta_V;
record.ReceiverPeak_V = max(abs(result.physical.receiverDifferentialVoltage_V));
record.EquivalentErrorPeak_deg = rad2deg(max(abs(result.physical.equivalentEncoderError_rad)));
record.MarginExceededSamples = nnz(result.physical.receiverMarginExceeded);
record.CommonModeExceededSamples = nnz(result.physical.commonModeLimitExceeded);
record.TerminationPole_Hz = result.physical.derived.terminationPole_Hz;
record.RecoveryTime_s = m.recoveryTime_s;
record.RecoveryCensored = m.recoveryCensored;
record.ActiveSaturatedSamples = nnz(abs(result.unsaturatedCommand_V(detail.activeMask))>params.control.voltageLimit_V);
record.PostSaturatedSamples = nnz(abs(result.unsaturatedCommand_V(detail.postMask))>params.control.voltageLimit_V);
record.MaxMeasurementAge_samples = max(result.communication.measurementAge_samples);
record.NominalTrajectoryChange_deg = rad2deg(max(abs(result.position_rad-nominal.position_rad)));
record.NominalCommandChange_V = max(abs(result.command_V-nominal.command_V));
record.NominalReceiverChange_V = max(abs(result.physical.receiverDifferentialVoltage_V-nominal.physical.receiverDifferentialVoltage_V));
end

function levels = localLevels(definition,count)
if definition.Scale == "log"
    levels = logspace(log10(definition.Low),log10(definition.High),count);
else
    levels = linspace(definition.Low,definition.High,count);
    if definition.Scale == "integer", levels = round(levels); end
end
% Explicit endpoint replacement avoids logspace floating-point overshoot.
levels(1) = definition.Low;
levels(end) = definition.High;
% Snap roundoff-close grid points to the exact nominal coordinate before
% deduplication, so CSV coordinates stay unique for downstream pivots.
nominalTolerance = 32*eps(max(1,abs(definition.Nominal)));
levels(abs(levels-definition.Nominal)<=nominalTolerance) = definition.Nominal;
levels = unique([levels definition.Nominal]);
end

function ranking = localRanking(oat,catalog,contexts)
records = {};
for c = 1:numel(contexts)
    for j = 1:height(catalog)
        rows = oat(oat.Context==contexts(c) & oat.Parameter==catalog.Key(j),:);
        record.Context = contexts(c);
        record.Parameter = catalog.Key(j);
        record.Label = catalog.Label(j);
        record.Role = catalog.Role(j);
        record.MinRMSE_deg = min(rows.ActiveRMSE_deg);
        record.MaxRMSE_deg = max(rows.ActiveRMSE_deg);
        record.RMSESpan_deg = record.MaxRMSE_deg-record.MinRMSE_deg;
        record.MaxTrajectoryChange_deg = max(rows.NominalTrajectoryChange_deg);
        record.MaxCommandChange_V = max(rows.NominalCommandChange_V);
        record.MinReceiverPeak_V = min(rows.ReceiverPeak_V);
        record.MaxReceiverPeak_V = max(rows.ReceiverPeak_V);
        record.AnyCensored = any(rows.RecoveryCensored);
        records{end+1,1} = record; %#ok<AGROW>
    end
end
ranking = struct2table(vertcat(records{:}));
ranking = sortrows(ranking,{'Context','MaxTrajectoryChange_deg'},{'ascend','descend'});
end

function c = localCase(label,params,context)
c = struct('label',label,'params',params,'scenario',localScenario(params,context));
end
