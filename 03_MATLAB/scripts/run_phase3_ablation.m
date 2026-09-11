function ablation = run_phase3_ablation(study, outputFolder)
%RUN_PHASE3_ABLATION Separate observer/supervisor, bounds, and control changes.
% Baseline/full records are reused verbatim. Two reduced policies add six
% simulations with identical exogenous profiles. All protected policies keep
% latched zero-voltage stop. Report activity and absolute performance without
% claiming a benefit from a command bound that never becomes active.
arguments
    study (1,1) struct
    outputFolder (1,1) string
end
require_empty_phase3_output_folder(outputFolder);
names = ["out_of_range_measurement","freeze_during_motion","loaded_supply_interruption"];
policies = ["baseline_legacy","observer_supervisor","plus_command_limits","full_protection"];
indices = zeros(numel(names),1);
for k = 1:numel(names)
    match = find(string({study.scenarios.name})==names(k));
    assert(isscalar(match),'EMIProject:Phase3AblationCase', ...
        'Study must contain exactly one %s case.',names(k));
    indices(k) = match;
end
full = study.configuration;
observerSupervisor = full;
observerSupervisor.control.degraded = observerSupervisor.control.normal;
observerSupervisor.supervisor.referenceTimeConstant_s = 0;
observerSupervisor.supervisor.normalVoltageLimitScale = 1;
observerSupervisor.supervisor.suspectedVoltageLimitScale = 1;
observerSupervisor.supervisor.degradedVoltageLimitScale = 1;
observerSupervisor.supervisor.normalSlewRate_V_s = 10000;
observerSupervisor.supervisor.nonNormalSlewRate_V_s = 10000;
plusLimits = full;
plusLimits.control.degraded = plusLimits.control.normal;
plusLimits.supervisor.referenceTimeConstant_s = 0;
configurations = {full,observerSupervisor,plusLimits,full};
ablation.scenarios = names;
ablation.policies = policies;
ablation.configurations = configurations;
ablation.protectionEnabled = [false,true,true,true];
ablation.description = "Absolute matched-profile comparison; command bounds only have an effect when active. All protected variants retain latched zero-voltage stop. No hardware safety or universal improvement claim.";
ablation.newSimulations = 2*numel(names);
ablation.results = cell(numel(names),numel(policies));
rows = cell(numel(names)*numel(policies),1);
if ~isfolder(outputFolder),mkdir(outputFolder);end
rowIndex = 0;
for k = 1:numel(names)
    sourceIndex = indices(k);
    scenario = study.scenarios(sourceIndex);
    profiles = study.protected{sourceIndex}.run.profiles;
    baseline = study.baseline{sourceIndex};
    for policy = 1:numel(policies)
        if policy == 1
            result = baseline;
        elseif policy == 4
            result = study.protected{sourceIndex};
        else
            result = simulate_phase3_actuator(study.parameters,scenario,true, ...
                configurations{policy},profiles);
        end
        assert(isequal(result.time_s,baseline.time_s), ...
            'EMIProject:Phase3AblationAlignment','Ablation records must share an exact sample grid.');
        ablation.results{k,policy} = result;
        rowIndex = rowIndex+1;
        rows{rowIndex} = summarize(result,baseline,policies(policy));
        writetable(result.timeSeries,fullfile(outputFolder,names(k)+"_"+policies(policy)+".csv"));
    end
end
ablation.metrics = struct2table(vertcat(rows{:}));
writetable(ablation.metrics,fullfile(outputFolder,'phase3_ablation_metrics.csv'));
% The saved results also retain effective per-case observer/load settings.
save(fullfile(outputFolder,'phase3_ablation.mat'),'ablation','-v7');
manifest = struct('policies',policies,'configurations',{configurations}, ...
    'protectionEnabled',ablation.protectionEnabled,'scenarios',names, ...
    'newSimulations',ablation.newSimulations,'description',ablation.description);
fid = fopen(fullfile(outputFolder,'phase3_ablation_configurations.json'),'w');
assert(fid>=0,'EMIProject:Phase3AblationOutput','Cannot write ablation configuration.');
cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(manifest,'PrettyPrint',true)); clear cleanup
assert(all(ablation.metrics.FiniteStateAndCommand & ablation.metrics.CommandBoundsPass & ...
    ablation.metrics.StoppedCommandIsZero), ...
    'EMIProject:Phase3AblationFailed','Ablation finite, command-bound or zero-stop check failed.');
write_run_manifest(outputFolder,fileparts(fileparts(mfilename('fullpath'))), ...
    struct('workflow',"phase3_ablation",'newSimulations',ablation.newSimulations, ...
    'reusedSimulations',2*numel(names),'physicalValidation',false));
ablation.accepted = true;
save(fullfile(outputFolder,'phase3_ablation.mat'),'ablation','-v7');
end

function row = summarize(result,baseline,policy)
a = result.timeSeries; b = baseline.timeSeries;
Ts = result.run.params.control.sampleTime_s;
activeIntervals = 1:height(a)-1;
row.Scenario = result.run.scenario.name;
row.Policy = policy;
row.Samples = height(a);
row.FiniteStateAndCommand = all(isfinite([result.state(:);a.command_V; ...
    a.reference_rad;a.commandLimit_V;a.unsaturatedCommand_V]));
row.CommandBoundsPass = all(abs(a.command_V)<=a.commandLimit_V+1e-12) && ...
    all(abs(a.command_V)<=result.run.profiles.supply.commandLimit_V+1e-12);
row.StoppedCommandIsZero = all(a.command_V(a.mode==4)==0);
row.TrackingRMSE_deg = rad2deg(sqrt(mean((a.position_rad-a.reference_rad).^2)));
row.TrackingRMSEDeltaVsBaseline_deg = row.TrackingRMSE_deg- ...
    rad2deg(sqrt(mean((b.position_rad-b.reference_rad).^2)));
row.PeakTrackingError_deg = rad2deg(max(abs(a.position_rad-a.reference_rad)));
row.PeakCurrent_A = max(abs(a.current_A));
row.PeakCurrentDeltaVsBaseline_A = row.PeakCurrent_A-max(abs(b.current_A));
row.PeakAppliedCommand_V = max(abs(a.command_V));
row.PeakRequestedCommand_V = max(abs(a.unsaturatedCommand_V));
row.PeakCommandDeltaVsBaseline_V = max(abs(a.command_V-b.command_V));
row.CommandEnergy_V2s = sum(a.command_V(activeIntervals).^2)*Ts;
row.ControlVariation_V = sum(abs(diff(a.command_V)));
row.CommandConstraintActive_samples = sum(abs(a.command_V-a.unsaturatedCommand_V)>1e-10);
lowerModeCap = a.commandLimit_V < result.run.profiles.supply.commandLimit_V-1e-12;
row.ModeCapBinding_samples = sum(a.mode~=4 & lowerModeCap & ...
    abs(a.command_V)>=a.commandLimit_V-1e-12);
row.ModeTransitions = nnz(diff([0;a.mode]));
modeNames = ["Normal","Suspected","Degraded","Recovery","SafeStop"];
for mode = 0:4
    row.(modeNames(mode+1)+"_samples") = nnz(a.mode==mode);
    row.(modeNames(mode+1)+"_s") = nnz(a.mode(activeIntervals)==mode)*Ts;
end
end
