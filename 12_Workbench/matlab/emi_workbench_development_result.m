function study = emi_workbench_development_result(outputFolder)
% Compact view of saved development evidence; never accepts or launches evaluation.
arguments
    outputFolder (1,1) string
end
summary = jsondecode(fileread(fullfile(outputFolder, 'stage_summary.json')));
assert(strcmp(summary.partition, 'development'), 'EMIWorkbench:DevelopmentPartition', ...
    'Only development results can be displayed by this workflow.');
assert(summary.receiver_hypotheses == 16 && summary.expected_records == 256, ...
    'EMIWorkbench:DevelopmentScope', 'The declared development workflow requires 16 receiver assumptions and 256 records.');
study = struct('summary', summary, 'pairs', struct([]));
metricsPath = fullfile(outputFolder, 'metrics.csv');
if isfile(metricsPath)
    metrics = readtable(metricsPath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    columns = {'Fixture','Variant','Arm','ReceiverDomainPass','ReceiverNumericsPass', ...
        'CleanGuardPass','ExecutionGuardPass','WindowPairedRMSE_deg','WindowPairedPeak_deg', ...
        'PeakCurrent_A','EMICountPeak_counts','EMICountFinal_counts','TaskSuccess'};
    assert(all(ismember(columns, metrics.Properties.VariableNames)), ...
        'EMIWorkbench:DevelopmentMetrics', 'Development metrics are missing required per-hypothesis fields.');
    assert(height(metrics) == summary.paired_results, ...
        'EMIWorkbench:DevelopmentMetrics', 'Saved pair count differs from the metrics table.');
    study.pairs = table2struct(metrics(:, columns));
elseif summary.paired_results ~= 0
    error('EMIWorkbench:DevelopmentMetrics', 'Saved development metrics are missing.');
end
end
