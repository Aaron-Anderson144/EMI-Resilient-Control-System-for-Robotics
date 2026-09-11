function plot_phase3_study(study,outputFolder)
%PLOT_PHASE3_STUDY Traceable response examples and retained limitations.
if ~isfolder(outputFolder),mkdir(outputFolder);end
selected=["out_of_range_measurement","freeze_during_motion"];
fig=figure('Visible','off','Position',[100 100 1450 1150]);theme(fig,'light');
layout=tiledlayout(fig,4,2,'TileSpacing','compact','Padding','compact');
for col=1:2
 idx=find(string({study.scenarios.name})==selected(col),1);
 a=study.protected{idx}.timeSeries;b=study.baseline{idx}.timeSeries;
 for row=1:4
  ax=nexttile(layout,(row-1)*2+col);hold(ax,'on');grid(ax,'on');
  switch row
   case 1
    plot(ax,a.time_s,rad2deg(a.reference_rad),'k:');
    plot(ax,b.time_s,rad2deg(b.position_rad),'Color',[.75 .3 .12]);
    plot(ax,a.time_s,rad2deg(a.position_rad),'Color',[.1 .35 .75]);
    ylabel(ax,'Position (deg)');legend(ax,{'Reference','Baseline','Protected'},'Location','best');
    title(ax,strrep(selected(col),'_',' '));
   case 2
    plot(ax,a.time_s,rad2deg(a.innovation_rad),'Color',[.1 .35 .75]);
    yline(ax,rad2deg(study.configuration.observer.residualTrip_rad),'r--');
    yline(ax,-rad2deg(study.configuration.observer.residualTrip_rad),'r--');ylabel(ax,'Innovation (deg)');
   case 3
    plot(ax,b.time_s,b.command_V,'Color',[.75 .3 .12]);plot(ax,a.time_s,a.command_V,'Color',[.1 .35 .75]);ylabel(ax,'Applied voltage (V)');
   case 4
    stairs(ax,a.time_s,a.mode,'Color',[.1 .35 .75]);ylim(ax,[-.2 4.2]);yticks(ax,0:4);
    yticklabels(ax,{'Normal','Suspected','Degraded','Recovery','Stop'});xlabel(ax,'Time (s)');
  end
  if col==1,xlim(ax,[.35 .8]);else,xlim(ax,[0 3]);end
 end
end
title(layout,'Phase 3 numerical prototype | online detection and supervised response');
exportgraphics(fig,fullfile(outputFolder,'phase3_response_examples.png'),'Resolution',150,'BackgroundColor','white');close(fig);
fig=figure('Visible','off','Position',[100 100 1450 800]);theme(fig,'light');
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
selected=["encoder_dropout","loaded_supply_interruption"];
for col=1:2
 idx=find(string({study.scenarios.name})==selected(col),1);a=study.protected{idx}.timeSeries;b=study.baseline{idx}.timeSeries;
 ax=nexttile(layout,col);hold(ax,'on');grid(ax,'on');
 plot(ax,a.time_s,rad2deg(a.reference_rad),'k:');plot(ax,b.time_s,rad2deg(b.position_rad),'Color',[.75 .3 .12]);
 plot(ax,a.time_s,rad2deg(a.position_rad),'Color',[.1 .35 .75]);
 plot(ax,a.time_s,rad2deg(a.estimatedPosition_rad),'--','Color',[.2 .6 .3]);
 title(ax,strrep(selected(col),'_',' '));ylabel(ax,'Position (deg)');legend(ax,{'Reference','Baseline','Protected true','Observer'},'Location','best');
 ax=nexttile(layout,2+col);stairs(ax,a.time_s,a.mode,'Color',[.1 .35 .75]);grid(ax,'on');ylim(ax,[-.2 4.2]);yticks(ax,0:4);
 yticklabels(ax,{'Normal','Suspected','Degraded','Recovery','Stop'});xlabel(ax,'Time (s)');
end
title(layout,'Retained limitations | observer cannot always reacquire; zero voltage permits load-driven drift');
exportgraphics(fig,fullfile(outputFolder,'phase3_retained_limitations.png'),'Resolution',150,'BackgroundColor','white');close(fig);
end
