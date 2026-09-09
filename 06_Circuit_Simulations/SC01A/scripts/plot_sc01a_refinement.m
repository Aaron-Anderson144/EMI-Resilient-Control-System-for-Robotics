function plot_sc01a_refinement(refinement, outputFolder)
%PLOT_SC01A_REFINEMENT Overlay retained native grids and their reference error.
arguments
    refinement (1,:) struct
    outputFolder (1,1) string
end
assert(numel(refinement)==3, 'SC01A:MissingRefinementTraces', ...
    'The waveform overlay requires coarse, middle and fine native traces.');
if ~isfolder(outputFolder), mkdir(outputFolder); end
[~,order]=sort([refinement.maxStep_s],'descend');
refinement=refinement(order);
colors=[0.06 0.31 0.57;0.83 0.36 0.09;0.04 0.45 0.34];
styles={'-','--',':'};
ink=[0.12 0.16 0.22];gray=[0.39 0.43 0.48];
fig=figure('Visible','off','Color','white','Units','pixels', ...
    'Position',[80 80 1450 780],'Name','SC-01A native waveform refinement');
cleanup=onCleanup(@() close(fig));
layout=tiledlayout(fig,1,2,'TileSpacing','loose','Padding','loose');
layout.OuterPosition=[0.02 0.10 0.96 0.80];
title(layout,'SC-01A | Native waveform overlay across solver refinements', ...
    'FontSize',20,'FontWeight','bold','Color',ink);
subtitle(layout,'Nominal combined rising edge | Each curve retains its own variable-step solver sample times', ...
    'FontSize',12,'Color',gray);
left=nexttile(layout);right=nexttile(layout);
axesList=[left right];
for ax=axesList
    set(ax,'Color','white','XColor',ink,'YColor',ink,'FontName','Arial', ...
        'FontSize',11,'LineWidth',0.8,'GridColor',[0.69 0.73 0.79], ...
        'GridAlpha',0.25,'Box','off','Layer','top');
    hold(ax,'on');grid(ax,'on');
    xlim(ax,[0.98 1.25]);
    xlabel(ax,'Time (\mus)');
end
handles=gobjects(3,1);labels=cell(3,1);
for k=1:3
    example=refinement(k);r=example.result;
    reference=sc01a_reference(example.params,example.stimulus,r.time_s);
    time_us=r.time_s*1e6;
    dm_mV=1e3*(r.differential_V-example.baseline.differential_V);
    error_uV=1e6*(r.differential_V-reference.differential_V);
    handles(k)=plot(left,time_us,dm_mV,styles{k},'Color',colors(k,:), ...
        'LineWidth',2.0);
    plot(right,time_us,error_uV,styles{k},'Color',colors(k,:),'LineWidth',1.6);
    labels{k}=sprintf('Maximum step %.2f ns',example.maxStep_s*1e9);

    % A separate file for each native grid avoids implying uniform samples.
    Time_s=r.time_s;DifferentialDisturbance_V=dm_mV*1e-3;
    NativeDifferential_V=r.differential_V;
    ReferenceDifferential_V=reference.differential_V;
    ReferenceError_V=error_uV*1e-6;
    trace=table(Time_s,DifferentialDisturbance_V,NativeDifferential_V, ...
        ReferenceDifferential_V,ReferenceError_V);
    writetable(trace,fullfile(outputFolder, ...
        sprintf('sc01a_combined_rise_refinement_%g_ns.csv',example.maxStep_s*1e9)));
end
yline(left,0,':','Color',gray,'HandleVisibility','off');
yline(right,0,':','Color',gray,'HandleVisibility','off');
ylabel(left,'Differential disturbance (mV)');
ylabel(right,'Native minus independent reference (\muV)');
title(left,'A. Coarse, middle and fine waveforms','FontSize',13,'Color',ink);
subtitle(left,'Overlapping traces show the retained waveform agreement', ...
    'FontSize',10,'Color',gray);
title(right,'B. Residuals reveal the small numerical differences','FontSize',13,'Color',ink);
subtitle(right,'Reference evaluated directly at each native sample time', ...
    'FontSize',10,'Color',gray);
legend(left,handles,labels,'Location','northeast','Box','off','FontSize',10,'TextColor',ink);
annotation(fig,'textbox',[0.055 0.015 0.90 0.045], ...
    'String','Assumed circuit parameters and prescribed sources. These traces assess numerical agreement, not hardware accuracy.', ...
    'EdgeColor','none','Color',gray,'FontSize',11,'VerticalAlignment','middle');
exportgraphics(fig,fullfile(outputFolder,'sc01a_refinement_overlay.png'), ...
    'Resolution',180,'BackgroundColor','white');
end
