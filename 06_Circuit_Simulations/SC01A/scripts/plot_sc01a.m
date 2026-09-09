function plot_sc01a(study, outputFolder)
%PLOT_SC01A Export a readable overview of circuit traces and reference errors.
% The plotted thresholds are voltage diagnostics, not decoded encoder events.
arguments
    study (1,1) struct
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
requiredCases = {'combined_rise', 'stress_fall'};
assert(all(isfield(study.examples, requiredCases)), ...
    'SC01A:MissingPlotExample', 'The overview requires combined_rise and stress_fall.');

nominal = study.examples.combined_rise;
stress = study.examples.stress_fall;
native = nominal.result;
reference = sc01a_reference(nominal.params, nominal.stimulus, native.time_s);
time_us = native.time_s * 1e6;
nominalWindow = [0.8 1.5];
stressWindow = [0.8 2.0];
nominalMask = time_us >= nominalWindow(1) & time_us <= nominalWindow(2);

ink = [0.12 0.16 0.22];
blue = [0.06 0.31 0.57];
orange = [0.83 0.36 0.09];
green = [0.04 0.45 0.34];
purple = [0.46 0.25 0.62];
gray = [0.39 0.43 0.48];
fig = figure('Visible', 'off', 'Color', 'white', ...
    'Units', 'pixels', 'Position', [80 80 1450 1000], ...
    'Name', 'SC-01A finite-edge circuit overview');
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'loose', 'Padding', 'loose');
layout.OuterPosition = [0.02 0.06 0.96 0.89];
title(layout, 'SC-01A | Finite switching edges at a differential receiver', ...
    'FontSize', 21, 'FontWeight', 'bold', 'Color', ink);
subtitle(layout, 'Native Simscape results and an independent circuit reference | Assumed bench parameters', ...
    'FontSize', 12, 'Color', gray);

ax = nexttile(layout);
localStyle(ax, ink);
hold(ax, 'on');
dmNative_mV = 1e3 * (native.differential_V - nominal.baseline.differential_V);
dmReference_mV = 1e3 * (reference.differential_V - nominal.baseline.differential_V);
hNative = plot(ax, time_us, dmNative_mV, '-', 'Color', blue, 'LineWidth', 2.0);
hReference = plot(ax, time_us, dmReference_mV, '--', 'Color', orange, 'LineWidth', 1.5);
yline(ax, 0, ':', 'Color', gray, 'HandleVisibility', 'off');
xlim(ax, nominalWindow);
ylim(ax, localLimits([dmNative_mV(nominalMask); dmReference_mV(nominalMask); 0], 1));
xlabel(ax, 'Time (\mus)');
ylabel(ax, 'Differential disturbance (mV)');
title(ax, 'A. Nominal combined rising edge', 'FontSize', 13, 'Color', ink);
subtitle(ax, 'Receiver voltage minus the intended baseline', 'FontSize', 10, 'Color', gray);
legend(ax, [hNative hReference], {'Native circuit', 'Independent reference'}, ...
    'Location', 'northeast', 'Box', 'off', 'FontSize', 10, 'TextColor', ink);

ax = nexttile(layout);
localStyle(ax, ink);
hold(ax, 'on');
yyaxis(ax, 'left');
hCM = plot(ax, time_us, native.commonMode_V, '-', 'Color', blue, 'LineWidth', 1.9);
ylabel(ax, 'Receiver common-mode voltage (V)');
ylim(ax, localLimits(native.commonMode_V(nominalMask), 0.02));
ax.YAxis(1).Color = ink;
yyaxis(ax, 'right');
hGround = plot(ax, time_us, native.ground_V, '-', 'Color', green, 'LineWidth', 1.8);
ylabel(ax, 'Shared-ground voltage (V)');
ylim(ax, localLimits([native.ground_V(nominalMask); 0], 0.02));
ax.YAxis(2).Color = ink;
xlim(ax, nominalWindow);
xlabel(ax, 'Time (\mus)');
title(ax, 'B. Common-mode and shared-ground transient', 'FontSize', 13, 'Color', ink);
subtitle(ax, 'Actual node voltages for the nominal combined rising edge', ...
    'FontSize', 10, 'Color', gray);
legend(ax, [hCM hGround], {'Receiver common mode (left)', 'Shared ground (right)'}, ...
    'Location', 'northeast', 'Box', 'off', 'FontSize', 10, 'TextColor', ink);

ax = nexttile(layout);
localStyle(ax, ink);
hold(ax, 'on');
stressTime_us = stress.result.time_s * 1e6;
stressMask = stressTime_us >= stressWindow(1) & stressTime_us <= stressWindow(2);
threshold = stress.params.diagnostics.receiverThreshold_V;
hBand = patch(ax, stressWindow([1 2 2 1]), threshold * [-1 -1 1 1], ...
    [0.98 0.88 0.74], 'EdgeColor', 'none', 'FaceAlpha', 0.55);
hTotal = plot(ax, stressTime_us, stress.result.differential_V, '-', ...
    'Color', purple, 'LineWidth', 2.0);
hBaseline = plot(ax, stressTime_us, stress.baseline.differential_V, '--', ...
    'Color', gray, 'LineWidth', 1.6);
yline(ax, threshold, ':', 'Color', orange, 'HandleVisibility', 'off');
yline(ax, -threshold, ':', 'Color', orange, 'HandleVisibility', 'off');
xlim(ax, stressWindow);
ylim(ax, localLimits([stress.result.differential_V(stressMask); ...
    stress.baseline.differential_V(stressMask); -threshold; threshold], 0.02));
xlabel(ax, 'Time (\mus)');
ylabel(ax, 'Total receiver differential input (V)');
title(ax, 'C. Asymmetric-coupling stress: falling edge', 'FontSize', 13, 'Color', ink);
subtitle(ax, 'A prescribed stress case; the shaded band is a voltage diagnostic', ...
    'FontSize', 10, 'Color', gray);
legend(ax, [hTotal hBaseline hBand], {'Native receiver input', 'Intended baseline', ...
    sprintf('+/- %.2f V diagnostic band', threshold)}, ...
    'Location', 'southeast', 'Box', 'off', 'FontSize', 10, 'TextColor', ink);

ax = nexttile(layout);
localStyle(ax, ink);
hold(ax, 'on');
caseNames = ["combined_rise", "stress_fall"];
displayNames = {'Nominal combined rise', 'Asymmetric-coupling stress fall'};
colors = [blue; purple];
markers = {'o', 's'};
handles = gobjects(2, 1);
steps_ns = [];
allErrors_mV = [];
clippedZero = false;
for k = 1:numel(caseNames)
    rows = study.metrics(string(study.metrics.Case) == caseNames(k), :);
    assert(~isempty(rows), 'SC01A:MissingPlotMetrics', ...
        'No step-refinement metrics for %s.', caseNames(k));
    [step_s, order] = sort(rows.MaxStep_s);
    error_mV = 1e3 * max([rows.ReferenceDMError_V, rows.ReferenceCMError_V, ...
        rows.ReferenceGroundError_V], [], 2);
    error_mV = error_mV(order);
    assert(all(isfinite(error_mV) & error_mV >= 0) && all(step_s > 0), ...
        'SC01A:InvalidPlotMetrics', 'Reference errors and time steps must be finite and valid.');
    clippedZero = clippedZero || any(error_mV == 0);
    error_mV(error_mV == 0) = 1e-12;
    handles(k) = loglog(ax, step_s * 1e9, error_mV, ...
        'Color', colors(k,:), 'LineStyle', '-', 'LineWidth', 1.8, ...
        'Marker', markers{k}, 'MarkerSize', 7, 'MarkerFaceColor', 'white');
    steps_ns = [steps_ns; step_s * 1e9]; %#ok<AGROW>
    allErrors_mV = [allErrors_mV; error_mV]; %#ok<AGROW>
end
set(ax, 'XScale', 'log', 'YScale', 'log');
steps_ns = unique(steps_ns);
xticks(ax, steps_ns);
xticklabels(ax, compose('%.3g', steps_ns));
xlim(ax, [min(steps_ns) / 1.18, max(steps_ns) * 1.18]);
ylim(ax, [min(allErrors_mV) / 1.08, max(allErrors_mV) * 1.08]);
xlabel(ax, 'Maximum solver step (ns)');
ylabel(ax, 'Maximum absolute reference error (mV)');
title(ax, 'D. Reference agreement across solver refinements', 'FontSize', 13, 'Color', ink);
subtitle(ax, 'Worst of differential, common-mode and ground voltage errors', ...
    'FontSize', 10, 'Color', gray);
legend(ax, handles, displayNames, 'Location', 'best', 'Box', 'off', ...
    'FontSize', 10, 'TextColor', ink);

note = ['Circuit voltages and diagnostic bands do not establish encoder faults. ', ...
    'Ground reference error excludes exact source-corner timestamps.'];
if clippedZero, note = [note ' Zero errors are shown at 10^{-12} mV.']; end
annotation(fig, 'textbox', [0.055 0.005 0.90 0.032], 'String', note, ...
    'EdgeColor', 'none', 'Color', gray, 'FontSize', 10, ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
exportgraphics(fig, fullfile(outputFolder, 'sc01a_overview.png'), ...
    'Resolution', 180, 'BackgroundColor', 'white');
end

function localStyle(ax, ink)
set(ax, 'Color', 'white', 'XColor', ink, 'YColor', ink, ...
    'FontName', 'Arial', 'FontSize', 10.5, 'LineWidth', 0.8, ...
    'GridColor', [0.69 0.73 0.79], 'GridAlpha', 0.25, ...
    'MinorGridAlpha', 0.12, 'Box', 'off', 'Layer', 'top');
grid(ax, 'on');
end

function limits = localLimits(values, minimumSpan)
lo = min(values);
hi = max(values);
span = max(hi - lo, minimumSpan);
limits = [(lo + hi - span) / 2, (lo + hi + span) / 2] + [-0.15 0.15] * span;
end
