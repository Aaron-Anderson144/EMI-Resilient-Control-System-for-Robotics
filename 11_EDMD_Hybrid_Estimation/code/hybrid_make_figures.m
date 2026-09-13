function hybrid_make_figures(summary,records,models,names,runDir)
%HYBRID_MAKE_FIGURES Export readable research figures with fixed selections.
regimes=["nominal","varied","nonlinear","stress"];
colors=[.25,.31,.39;.9,.55,.13;.15,.53,.68;.24,.60,.38];
f=figure('Visible','off','Color','w','Position',[60,60,1400,920]);
cleanup=onCleanup(@()close(f)); %#ok<NASGU>
layout=tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
for j=1:4
    ax=nexttile(layout);values=zeros(1,4);
    for m=1:4
        row=summary(summary.regime==regimes(j) & summary.modelName==names(m) & summary.horizonSamples==50,:);
        values(m)=row.meanTruthRMSE_deg;
    end
    plotted=values;plotted(~isfinite(plotted))=0;
    labels=string(round(values,4));labels(~isfinite(values))="FAILED";
    b=bar(ax,plotted,'FaceColor','flat');b.CData=colors;
    set(ax,'Color','w','XColor','k','YColor','k','FontSize',11,'XTick',1:4, ...
        'XTickLabel',{'Physics','Persistent','Linear hybrid','EDMD hybrid'});
    ylabel(ax,'Mean trajectory RMSE (degrees)','Color','k');
    title(ax,upper(regimes(j)),'Color','k');grid(ax,'on');
    text(ax,1:4,plotted,labels, ...
        'HorizontalAlignment','center','VerticalAlignment','bottom','Color','k');
    ylim(ax,[0,max(plotted)*1.2+eps]);
end
title(layout,'Physics plus learned correction: 50 ms position forecasts','Color','k','FontSize',18);
subtitle(layout,'10 unseen simulated trajectories per condition | lower is better | recorded future voltages supplied','Color','k');
exportgraphics(f,fullfile(runDir,'forecast_comparison.png'),'Resolution',150);
clear cleanup;

% Fixed illustrative example: first nonlinear test record, origin at 1.2s.
idx=find(cellfun(@(r) string(r.regime)=="nonlinear",records),1);record=records{idx};
[trace,config]=hybrid_reference_observer(record);k=1201;H=250;
pred=zeros(H,4);future=record.u(k:k+H-1);
for m=1:4
    if m==1
        pred(:,m)=hybrid_forecast(config,trace.posterior(k,:)',[],[],future,[],"physics");
    elseif m==2
        pred(:,m)=hybrid_forecast(config,trace.posterior(k,:)',trace.innovation(k:-1:k-19),[],future,[],"persistent");
    else
        d=models{m}.delay;
        pred(:,m)=hybrid_forecast(config,trace.posterior(k,:)',trace.innovation(k:-1:k-d), ...
            record.u(k-1:-1:k-d),future,models{m},"learned");
    end
end
f=figure('Visible','off','Color','w','Position',[60,60,1250,650]);
cleanup=onCleanup(@()close(f)); %#ok<NASGU>
ax=axes(f);hold(ax,'on');elapsed=(1:H)*record.sampleTime*1000;
plot(ax,elapsed,rad2deg(record.truth(k+1:k+H,1)),'k','LineWidth',2.5,'DisplayName','Simulated true position');
for m=1:4,plot(ax,elapsed,rad2deg(pred(:,m)),'Color',colors(m,:),'LineWidth',1.7,'DisplayName',names(m));end
set(ax,'Color','w','XColor','k','YColor','k','FontSize',12);
xlabel(ax,'Forecast horizon (ms)','Color','k');ylabel(ax,'Position (degrees)','Color','k');grid(ax,'on');
title(ax,'One fixed nonlinear example — illustrative, not an aggregate result','Color','k');
subtitle(ax,'Origin at 1.2 seconds; all methods receive the same future voltage sequence','Color','k');
legend(ax,'Location','best','TextColor','k','Color','w');
exportgraphics(f,fullfile(runDir,'example_forecast.png'),'Resolution',150);
end
