function plot_phase2b_sensitivity(study, outputFolder)
%PLOT_PHASE2B_SENSITIVITY Export publication-style static study figures.
arguments
    study (1,1) struct
    outputFolder (1,1) string
end
ink = [0.12 0.17 0.23];
blue = [0.05 0.38 0.60];
orange = [0.80 0.35 0.12];
fig = figure('Visible','off','Color','white','Position',[80 80 1500 900]);
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig,2,2,'Padding','loose','TileSpacing','compact');
ax = nexttile(layout);
ranked = study.ranking(study.ranking.Context=="physical_only" & study.ranking.Role=="response",:);
ranked = ranked(1:min(10,height(ranked)),:);
barh(ax,ranked.MaxTrajectoryChange_deg,'FaceColor',blue);
displayLabels = replace(ranked.Label, ...
    ["Equivalent voltage-to-angle gain","Receiver-equivalent envelope frequency", ...
    "Shared-return CM-to-DM factor","Equivalent baseband bandwidth"], ...
    ["Voltage-to-angle gain","Envelope frequency", ...
    "Shared-return conversion","Baseband bandwidth"]);
set(ax,'YTick',1:height(ranked),'YTickLabel',displayLabels,'YDir','reverse');
xlabel(ax,'Largest position change from nominal (deg)');
title(ax,'One parameter at a time: physical channels');

ax = nexttile(layout);
nominalRows = study.oat(study.oat.Parameter=="angle_sensitivity",:);
for c = 1:2
    rows = nominalRows(nominalRows.Context==study.contexts(c),:);
    plot(ax,rows.Value,rows.ActiveRMSE_deg,'-o','LineWidth',1.6,'DisplayName',strrep(study.contexts(c),'_',' '));
    hold(ax,'on');
end
xlabel(ax,'Assumed voltage-to-angle gain (deg/V)');
ylabel(ax,'Active position-delta RMSE (deg)');
title(ax,'Sensitivity to the assumed feedback mapping');
legend(ax,'Location','northwest','TextColor',ink,'Color','white');

ax = nexttile(layout);
first = study.globalMetrics(study.globalMetrics.Context=="physical_only",:);
second = study.globalMetrics(study.globalMetrics.Context=="combined_phase2b",:);
scatter(ax,first.ReceiverPeak_V,first.ActivePeak_deg,18,blue,'filled','DisplayName','physical only');
hold(ax,'on');
scatter(ax,second.ReceiverPeak_V,second.ActivePeak_deg,18,orange,'DisplayName','with fixed communication faults');
xline(ax,study.nominalParams.phase2b.receiver.differentialNoiseMargin_V,'--', ...
    'DisplayName','0.20 V diagnostic margin','Color',[0.4 0.4 0.4]);
xlabel(ax,'Peak receiver-equivalent differential voltage (V)');
ylabel(ax,'Peak active position delta (deg)');
title(ax,sprintf('%d combined-parameter samples per context',height(first)));
legend(ax,'Location','northeast','TextColor',ink,'Color','white');

ax = nexttile(layout);
rows = study.grid(study.grid.Grid==1,:);
x = unique(rows.FirstValue); y = unique(rows.SecondValue);
z = NaN(numel(y),numel(x));
for k = 1:height(rows)
    z(y==rows.SecondValue(k),x==rows.FirstValue(k)) = rows.ActiveRMSE_deg(k);
end
contourf(ax,x,y,z,12,'LineColor','none');
set(ax,'YScale','log');
cb = colorbar(ax); cb.Color = ink; cb.Label.String = 'Position-delta RMSE (deg)';
xlabel(ax,'Ground common-mode-to-differential factor');
ylabel(ax,'Voltage-to-angle gain (deg/V)');
title(ax,'Interaction: ground conversion and feedback gain');

axesList = findall(fig,'Type','axes');
for k = 1:numel(axesList)
    set(axesList(k),'Color','white','XColor',ink,'YColor',ink,'FontSize',10,'GridColor',[0.8 0.8 0.8]);
    grid(axesList(k),'on');
    axesList(k).Title.Color=ink;
    axesList(k).XLabel.Color=ink;
    axesList(k).YLabel.Color=ink;
end
title(layout,'Phase 2B sensitivity | assumed ranges, reduced-order model','Color',ink,'FontSize',18);
subtitle(layout,'Numerical sensitivity within this design; no calibrated failure probability or receiver immunity claim','Color',ink);
exportgraphics(fig,fullfile(outputFolder,'phase2b_sensitivity_overview.png'),'Resolution',180);
clear cleanup
end
