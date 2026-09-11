function study = run_baseline(outputFolder)
%RUN_BASELINE Simulate the clean baseline in a new evidence directory.
arguments
    outputFolder (1,1) string = ""
end

scriptPath = mfilename('fullpath');
matlabRoot = fileparts(fileparts(scriptPath));
addpath(fullfile(matlabRoot,'functions'));
outputFolder = prepare_fresh_output_folder(outputFolder, ...
    fullfile(matlabRoot,'results','development'),"baseline");
run(fullfile(matlabRoot, 'startup_project.m'));
resultsFolder=outputFolder;

params = actuator_parameters();
validate_parameters(params);
model = baseline_closed_loop(params);

sampleTime = params.control.sampleTime_s;
time_s = (0:sampleTime:params.simulation.stopTime_s).';
theta_ref_rad = zeros(size(time_s));
theta_ref_rad(time_s >= params.simulation.stepTime_s) = ...
    params.simulation.stepAmplitude_rad;

theta_rad = lsim(model.referenceToPosition, theta_ref_rad, time_s);
voltage_cmd_V = lsim(model.referenceToCommand, theta_ref_rad, time_s);
loadTorque_Nm = repmat(params.mechanical.nominalLoadTorque_Nm,size(time_s));
theta_rad = theta_rad + lsim(model.loadToPosition,loadTorque_Nm,time_s);
voltage_cmd_V = voltage_cmd_V + lsim(model.loadToCommand,loadTorque_Nm,time_s);

theta_rad = theta_rad(:);
voltage_cmd_V = voltage_cmd_V(:);
position_error_rad = theta_ref_rad - theta_rad;

responseMask = time_s >= params.simulation.stepTime_s;
responseTime_s = time_s(responseMask) - params.simulation.stepTime_s;
responsePosition_rad = theta_rad(responseMask);
responseError_rad = position_error_rad(responseMask);
target_rad = params.simulation.stepAmplitude_rad;

closedLoopPoles = pole(model.referenceToPosition);
metrics.parameterSetId = params.meta.parameterSetId;
metrics.stable = all(abs(closedLoopPoles) < 1);
metrics.maximumPoleMagnitude = max(abs(closedLoopPoles));
metrics.trackingRMSE_rad = sqrt(mean(responseError_rad.^2));
metrics.finalError_rad = target_rad - responsePosition_rad(end);
metrics.peakVoltageCommand_V = max(abs(voltage_cmd_V));
metrics.overshoot_percent = max(0, ...
    100 * (max(responsePosition_rad) - target_rad) / abs(target_rad));

settlingBand_rad = params.simulation.settlingBandFraction * abs(target_rad);
lastOutsideBand = find(abs(responseError_rad) > settlingBand_rad, 1, 'last');

if isempty(lastOutsideBand)
    metrics.settlingTime_s = 0;
elseif lastOutsideBand < numel(responseTime_s)
    metrics.settlingTime_s = responseTime_s(lastOutsideBand + 1);
else
    metrics.settlingTime_s = NaN;
end

metrics.linearCommandExceedsNominalVoltage = ...
    metrics.peakVoltageCommand_V > min(params.control.voltageLimit_V,params.electrical.nominalVoltage_V);

timeSeries = table( ...
    time_s, theta_ref_rad, theta_rad, position_error_rad, voltage_cmd_V);

writetable(timeSeries, fullfile(resultsFolder, 'baseline_timeseries.csv'));
save(fullfile(resultsFolder, 'baseline_metrics.mat'), ...
    'params', 'metrics', 'closedLoopPoles');

figureHandle = figure('Color', 'white', 'Name', 'Clean Baseline Response');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

positionAxes = nexttile(layout);
plot(time_s, rad2deg(theta_ref_rad), '--', 'LineWidth', 1.2);
hold on;
plot(time_s, rad2deg(theta_rad), 'LineWidth', 1.5);
grid on;
ylabel('Position (deg)');
legendHandle = legend(["Reference", "Position"], 'Location', 'best');
titleHandle = title('Phase 1 Clean Position-Control Baseline');
set(positionAxes, ...
    'Color', 'white', ...
    'XColor', [0.1, 0.1, 0.1], ...
    'YColor', [0.1, 0.1, 0.1], ...
    'GridColor', [0.72, 0.72, 0.72]);
set(titleHandle, 'Color', [0.1, 0.1, 0.1]);
set(legendHandle, ...
    'Color', 'white', ...
    'TextColor', [0.1, 0.1, 0.1], ...
    'EdgeColor', [0.3, 0.3, 0.3]);

commandAxes = nexttile(layout);
plot(time_s, voltage_cmd_V, 'LineWidth', 1.2);
hold on;
yline(params.control.voltageLimit_V, '--');
yline(-params.control.voltageLimit_V, '--');
grid on;
xlabel('Time (s)');
ylabel('Linear command (V)');
set(commandAxes, ...
    'Color', 'white', ...
    'XColor', [0.1, 0.1, 0.1], ...
    'YColor', [0.1, 0.1, 0.1], ...
    'GridColor', [0.72, 0.72, 0.72]);

exportgraphics(figureHandle, ...
    fullfile(resultsFolder, 'baseline_response.png'), 'Resolution', 180);

fprintf('\nBaseline metrics\n');
fprintf('  Stable: %s\n', string(metrics.stable));
fprintf('  Maximum pole magnitude: %.6f\n', metrics.maximumPoleMagnitude);
fprintf('  Tracking RMSE: %.6g rad\n', metrics.trackingRMSE_rad);
fprintf('  Final error: %.6g rad\n', metrics.finalError_rad);
fprintf('  Overshoot: %.3f %%\n', metrics.overshoot_percent);
fprintf('  Settling time: %.6g s\n', metrics.settlingTime_s);
fprintf('  Peak linear command: %.3f V\n', metrics.peakVoltageCommand_V);
fprintf('  Results folder: %s\n', resultsFolder);
study=struct('outputFolder',resultsFolder,'parameters',params, ...
    'metrics',metrics,'timeSeries',timeSeries,'closedLoopPoles',closedLoopPoles);
end
