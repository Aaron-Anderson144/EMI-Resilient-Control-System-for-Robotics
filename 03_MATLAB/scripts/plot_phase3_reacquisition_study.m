function plot_phase3_reacquisition_study(study,outputFolder)
%PLOT_PHASE3_REACQUISITION_STUDY Inspect recovery and retained loaded motion.
if ~isfolder(outputFolder),mkdir(outputFolder);end
names=string(study.summary.Scenario);
old=study.runs{find(names=="original_no_reference",1)}.timeSeries;
recovered=study.runs{find(names=="qualified_reference",1)}.timeSeries;
loaded=study.runs{find(names=="loaded_moving_reference",1)}.timeSeries;
fig=figure('Visible','off','Color','w','Position',[80,80,1350,850]);
set(fig,'DefaultAxesColor','w','DefaultAxesXColor',[.15,.15,.15], ...
 'DefaultAxesYColor',[.15,.15,.15],'DefaultTextColor',[.15,.15,.15], ...
 'DefaultLegendColor','w','DefaultLegendTextColor',[.15,.15,.15]);
cleanup=onCleanup(@()close(fig));
tiledlayout(fig,2,2,'TileSpacing','loose','Padding','loose');
ax=nexttile;plot(ax,old.time_s,rad2deg(old.position_rad),'Color',[.65,.25,.2],'LineWidth',1.4);hold(ax,'on');
plot(ax,recovered.time_s,rad2deg(recovered.position_rad),'Color',[0,.4,.55],'LineWidth',1.6);
plot(ax,recovered.time_s,rad2deg(recovered.reference_rad),'k--');
title(ax,'Original dropout: recovery with independent reference');ylabel(ax,'Position (deg)');
legend(ax,{'Original stopped response','Reference-assisted recovery','Commanded position'},'Location','best');
ax=nexttile;plot(ax,old.time_s,rad2deg(old.estimatedPosition_rad-old.position_rad),'Color',[.65,.25,.2],'LineWidth',1.4);hold(ax,'on');
plot(ax,recovered.time_s,rad2deg(recovered.estimatedPosition_rad-recovered.position_rad),'Color',[0,.4,.55],'LineWidth',1.5);
xline(ax,1.5,'--','Re-anchor','LabelVerticalAlignment','bottom','Color',[.35,.35,.35]);
title(ax,'Observer error: reference re-anchor at 1.5 s');ylabel(ax,'Estimated minus actual position (deg)');
legend(ax,{'Original observer','Reference-assisted observer'},'Location','best');
ax=nexttile;stairs(ax,recovered.time_s,recovered.mode,'Color',[0,.4,.55],'LineWidth',1.6);hold(ax,'on');
xline(ax,1.5,'--','Re-anchor','LabelVerticalAlignment','bottom','Color',[.35,.35,.35]);xline(ax,2,':','Separate reset','LabelVerticalAlignment','bottom','Color',[.35,.35,.35]);
ylim(ax,[-.25,4.4]);yticks(ax,0:4);yticklabels(ax,{'Normal','Suspected','Degraded','Recovery','Latched stop'});
title(ax,'Re-anchor preserves stop; reset follows primary qualification');
ax=nexttile;plot(ax,loaded.time_s,loaded.velocity_rad_s,'Color',[.65,.25,.2],'LineWidth',1.5);hold(ax,'on');
plot(ax,loaded.time_s,loaded.estimatedVelocity_rad_s,'--','Color',[0,.4,.55],'LineWidth',1.3);
xline(ax,1.5,'--','Re-anchor','LabelVerticalAlignment','bottom','Color',[.35,.35,.35]);xlim(ax,[1.2,1.8]);
ylim(ax,[-2.1,.1]);yline(ax,0,':','Color',[.4,.4,.4]);
title(ax,'Loaded actuator moves while motor voltage is zero');ylabel(ax,'Velocity (rad/s)');
legend(ax,{'Actual moving state','Estimated moving state'},'Location','best');
for ax=findall(fig,'Type','axes')'
 grid(ax,'on');xlabel(ax,'Time (s)');ax.FontSize=11;ax.Title.FontSize=12;
end
sgtitle(fig,{'Phase 3 independent-reference recovery — numerical fixtures', ...
 'Synthetic reference and exact assumed model; hardware sensing and stop/hold remain unvalidated'},'FontSize',15,'Color',[.15,.15,.15]);
exportgraphics(fig,fullfile(outputFolder,'reacquisition_results.png'),'Resolution',160);
exportgraphics(fig,fullfile(outputFolder,'reacquisition_results.pdf'),'ContentType','vector');
end
