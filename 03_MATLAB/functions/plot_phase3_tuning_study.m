function plot_phase3_tuning_study(study, outputFolder)
%PLOT_PHASE3_TUNING_STUDY Scientific figures from the frozen numerical study.
% Exports PNG and vector PDF without changing study data, selection or policy.
% Explicit graphics colors make exports independent of MATLAB desktop theme.
arguments
    study (1,1) struct
    outputFolder (1,1) string
end
required={'plan','selection','tuningAssessment','tuningCaseAssessment', ...
    'evaluationMetrics','evaluationCaseAssessment','evaluationAssessment','limiterResults'};
assert(all(isfield(study,required)),'EMIProject:TuningPlotData', ...
    'Plotting requires the completed frozen tuning, evaluation and limiter study.');
if ~isfolder(outputFolder),mkdir(outputFolder);end
plotGrid(study,outputFolder);
plotEvaluation(study,outputFolder);
plotLimiters(study,outputFolder);
end

function plotGrid(study,folder)
p=palette();a=study.tuningAssessment;n=height(a);policies=study.plan.policies;
assert(n==numel(policies) && n>0 && all(isfinite(a.TrackingScore)) && ...
    all(a.HistoricalTrackingScore>0),'EMIProject:TuningPlotData','Tuning scores must be finite and comparable.');
labels=strings(n,1);
for j=1:n
    labels(j)=sprintf('%g%% / %g ms',100*policies(j).options.degradedBandwidthRatio, ...
        1000*policies(j).options.referenceTimeConstant_s);
end
labels(study.selection.historicalIndex)=labels(study.selection.historicalIndex)+"  [H]";
labels(study.selection.selectedIndex)=labels(study.selection.selectedIndex)+"  [S]";
gateNames={'InvariantsPass','TrackingPass','DisturbancePass','PeakErrorPass', ...
    'WindowCurrentPass','FullCurrentPass','FinalErrorPass','AlarmResponsePass', ...
    'RecoveryPass','FinalModePass','StopDurationPass'};
gateLabels={'Execution','Tracking','Disturbance','Peak error','Window I', ...
    'Full I','Final error','Alarm','Recovery','Final mode','Stop time'};
counts=zeros(n,numel(gateNames));caseCount=zeros(n,1);
for j=1:n
    cases=study.tuningCaseAssessment(study.tuningCaseAssessment.Policy==a.Policy(j),:);
    caseCount(j)=height(cases);
    counts(j,:)=sum(cases{:,gateNames},1);
end
assert(all(caseCount==caseCount(1)) && caseCount(1)>0,'EMIProject:TuningPlotData', ...
    'Every policy must have the same nonempty tuning case set.');
f=makeFigure('Frozen tuning grid',1600,850);cleanup=onCleanup(@()close(f)); %#ok<NASGU>
layout=tiledlayout(f,1,3,'TileSpacing','compact','Padding','compact');
layout.OuterPosition=[.025,.14,.95,.76];
ax=nexttile(layout,1);styleAxes(ax);
ratio=a.TrackingScore./a.HistoricalTrackingScore;
colors=repmat(p.paleBlue,n,1);colors(study.selection.historicalIndex,:)=p.gray;
colors(study.selection.selectedIndex,:)=p.blue;
b=barh(ax,1:n,ratio,.64,'FaceColor','flat','EdgeColor','none');b.CData=colors;
hold(ax,'on');
xline(ax,1,'--','Color',p.dark,'LineWidth',1.1,'HandleVisibility','off');
target=1-study.plan.criteria.requiredAggregateImprovement;
xline(ax,target,':','Color',p.green,'LineWidth',1.6,'HandleVisibility','off');
maximum=max([1;ratio]);xlim(ax,[0,maximum*1.23]);ylim(ax,[.35,n+.65]);
set(ax,'YDir','reverse','YTick',1:n,'YTickLabel',cellstr(labels),'TickLabelInterpreter','none');
for j=1:n
    text(ax,ratio(j)+.025*maximum,j,sprintf('%.3f',ratio(j)), ...
        'Color',p.dark,'FontSize',10,'VerticalAlignment','middle');
end
xlabel(ax,'Tracking score / historical score','Color',p.dark);
ylabel(ax,'Degraded tuning target / reference filter','Color',p.dark);
title(ax,'A  Aggregate tracking score','Color',p.dark,'FontSize',12,'FontWeight','bold');
grid(ax,'on');ax.YGrid='off';
ax=nexttile(layout,2,[1,2]);styleAxes(ax);
imagesc(ax,counts,[0,caseCount(1)]);
map=interp1([0,.6,1],[.84,.39,.33; .99,.96,.82; .24,.57,.44], ...
    linspace(0,1,caseCount(1)+1));colormap(ax,map);
set(ax,'YDir','reverse','YTick',1:n,'YTickLabel',cellstr(labels), ...
    'XTick',1:numel(gateNames),'XTickLabel',gateLabels,'TickLabelInterpreter','none','XTickLabelRotation',35);
ylim(ax,[.5,n+.5]);xlim(ax,[.5,numel(gateNames)+.5]);
for j=1:n
    for k=1:numel(gateNames)
        color=p.dark;
        if counts(j,k)==caseCount(1),color=[1,1,1];end
        text(ax,k,j,sprintf('%d',counts(j,k)),'Color',color, ...
            'HorizontalAlignment','center','FontWeight','bold','FontSize',11);
    end
end
title(ax,sprintf('B  Cases passing each comparative gate (of %d)',caseCount(1)), ...
    'Color',p.dark,'FontSize',12,'FontWeight','bold');
bar=colorbar(ax);bar.Color=p.dark;bar.Ticks=0:caseCount(1);bar.Label.String='Cases passing';bar.Label.Color=p.dark;
status="Selection is eligible on the tuning set";
if study.selection.diagnosticOnly,status="Selection is diagnostic only: no tuning candidate was eligible";end
header(f,'Frozen tuning grid: tracking and comparative gates', ...
    sprintf('%d policies; %d tuning fixtures. %s.',n,caseCount(1),status));
footer(f,sprintf(['[H] historical; [S] selected before separate evaluation. Dashed line: historical = 1; green dotted line: required %.0f%% improvement.\n' ...
    'Score = mean window RMSE / max(historical window RMSE, %.2f deg), then divided by the historical score. Every gate must pass every case. Defaults unchanged.'], ...
    100*study.plan.criteria.requiredAggregateImprovement,study.plan.criteria.normalizationFloor_deg));
exportFigure(f,folder,'phase3_tuning_grid');
end

function plotEvaluation(study,folder)
p=palette();historical=string(study.plan.historicalPolicy);selected=string(study.selection.policy.id);
a=study.evaluationMetrics(study.evaluationMetrics.Policy==selected,:);
b=study.evaluationMetrics(study.evaluationMetrics.Policy==historical,:);
assert(height(a)>0 && isequal(a.Fixture,b.Fixture),'EMIProject:TuningPlotData', ...
    'Evaluation figures require ordered selected/historical pairs.');
n=height(a);comparison=study.evaluationCaseAssessment;
assert(isequal(comparison.Fixture,a.Fixture),'EMIProject:TuningPlotData','Evaluation gates must match plotted cases.');
labels=fixtureLabels(a.Fixture);
f=makeFigure('Separate candidate evaluation',1600,1050);cleanup=onCleanup(@()close(f)); %#ok<NASGU>
layout=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
layout.OuterPosition=[.025,.15,.95,.75];
ax=nexttile(layout);styleAxes(ax);hold(ax,'on');
for j=1:n
    plot(ax,[b.WindowTrackingRMSE_deg(j),a.WindowTrackingRMSE_deg(j)],[j,j], ...
        '-','Color',p.lightGray,'LineWidth',2,'HandleVisibility','off');
end
h1=scatter(ax,b.WindowTrackingRMSE_deg,1:n,42,p.gray,'filled','Marker','s','MarkerEdgeColor',p.dark);
h2=scatter(ax,a.WindowTrackingRMSE_deg,1:n,45,p.blue,'filled','MarkerEdgeColor',p.blue);
failed=~comparison.TrackingPass;
h3=scatter(ax,a.WindowTrackingRMSE_deg(failed),find(failed),100,'o','MarkerEdgeColor',p.red,'LineWidth',1.5);
largest=max([a.WindowTrackingRMSE_deg;b.WindowTrackingRMSE_deg]);
xlim(ax,[0,max(.1,1.10*largest)]);ylim(ax,[.35,n+.65]);
set(ax,'YDir','reverse','YTick',1:n,'YTickLabel',cellstr(labels),'TickLabelInterpreter','none');
xlabel(ax,'Fixed-window tracking RMSE (deg)','Color',p.dark);
title(ax,'A  Tracking against the original reference','Color',p.dark,'FontSize',12,'FontWeight','bold');
grid(ax,'on');ax.YGrid='off';
legend(ax,[h1,h2,h3],{'Historical','Selected','Tracking gate failed'}, ...
    'Location','southoutside','Orientation','horizontal','Color','white','TextColor',p.dark,'EdgeColor',p.lightGray);
ax=nexttile(layout);styleAxes(ax);hold(ax,'on');
windowRatio=ratioOrMissing(a.WindowPeakCurrent_A,b.WindowPeakCurrent_A);
fullRatio=ratioOrMissing(a.FullPeakCurrent_A,b.FullPeakCurrent_A);
allRatios=[windowRatio;fullRatio];finite=allRatios(isfinite(allRatios));
assert(~isempty(finite),'EMIProject:TuningPlotData','Current ratios require a positive historical denominator.');
low=max(0,min([.85;finite])-.07);high=max([1.18;finite])*1.09;
xline(ax,1,'--','Color',p.dark,'LineWidth',1.1,'HandleVisibility','off');
xline(ax,1+study.plan.criteria.currentRelativeAllowance,':','Color',p.brown,'LineWidth',1.4,'HandleVisibility','off');
h1=scatter(ax,windowRatio,(1:n)'-.12,42,p.blue,'filled','MarkerEdgeColor',p.blue);
h2=scatter(ax,fullRatio,(1:n)'+.12,45,p.orange,'filled','Marker','^','MarkerEdgeColor',p.orange);
failedWindow=~comparison.WindowCurrentPass;failedFull=~comparison.FullCurrentPass;
scatter(ax,windowRatio(failedWindow),find(failedWindow)-.12,100,'o','MarkerEdgeColor',p.red,'LineWidth',1.5,'HandleVisibility','off');
scatter(ax,fullRatio(failedFull),find(failedFull)+.12,100,'o','MarkerEdgeColor',p.red,'LineWidth',1.5,'HandleVisibility','off');
h3=scatter(ax,NaN,NaN,90,'o','MarkerEdgeColor',p.red,'LineWidth',1.5);
undefined=~isfinite(windowRatio)|~isfinite(fullRatio);
for j=reshape(find(undefined),1,[])
    text(ax,low+.025*(high-low),j,'Undefined ratio: historical peak = 0', ...
        'Color',p.gray,'FontSize',8,'Interpreter','none');
end
xlim(ax,[low,high]);ylim(ax,[.35,n+.65]);
set(ax,'YDir','reverse','YTick',1:n,'YTickLabel',cellstr(labels),'TickLabelInterpreter','none');
xlabel(ax,'Selected / historical peak current','Color',p.dark);
title(ax,'B  Window and full-record current ratios','Color',p.dark,'FontSize',12,'FontWeight','bold');
grid(ax,'on');ax.YGrid='off';
legend(ax,[h1,h2,h3],{'Window peak','Full-record peak','Current gate failed'}, ...
    'Location','southoutside','Orientation','horizontal','Color','white','TextColor',p.dark,'EdgeColor',p.lightGray);
header(f,'Separate evaluation of the frozen selection', ...
    sprintf('%s versus %s; %d / %d cases pass every comparative gate. Defaults unchanged.', ...
    selected,historical,study.evaluationAssessment.PassedCases,n));
footer(f,sprintf(['Each row uses its predeclared calendar scoring window. Red rings identify actual gate failures; ratios alone do not determine pass/fail.\n' ...
    'Current gate permits the larger of +%.0f%% or +%.2f A. Dashed line: ratio 1; dotted line: relative allowance only. These are assumed-model numerical results.'], ...
    100*study.plan.criteria.currentRelativeAllowance,study.plan.criteria.currentAbsoluteAllowance_A));
exportFigure(f,folder,'phase3_tuning_evaluation');
end

function plotLimiters(study,folder)
p=palette();records=study.limiterResults;
assert(iscell(records) && isequal(size(records),[2,4]),'EMIProject:TuningPlotData', ...
    'Limiter figure requires both stress fixtures and all four declared policies.');
names={'Selected','Mode caps removed','Slew relaxed','Both removed'};
shortNames={'Selected','No mode cap','Relaxed slew','Both removed'};
colors=[p.blue;p.orange;p.purple;p.green];styles={'-','--','-.',':'};
f=makeFigure('Actual limiter stress responses',1660,1190);cleanup=onCleanup(@()close(f)); %#ok<NASGU>
layout=tiledlayout(f,3,2,'TileSpacing','compact','Padding','compact');
layout.OuterPosition=[.035,.16,.93,.74];
allAxes=gobjects(3,2);responseHandles=gobjects(4,1);
for fixture=1:2
    reference=records{fixture,1};window=reference.fixture.targetWindow_s;
    range=[max(0,window(1)-.07),min(reference.fault.time_s(end),window(2)+.10)];
    ax=nexttile(layout,fixture);allAxes(1,fixture)=ax;styleAxes(ax);hold(ax,'on');
    for policy=1:4
        a=records{fixture,policy}.fault.timeSeries;
        responseHandles(policy)=plot(ax,a.time_s,rad2deg(a.position_rad),styles{policy}, ...
            'Color',colors(policy,:),'LineWidth',1.7);
    end
    a=reference.fault.timeSeries;
    plot(ax,a.time_s,rad2deg(a.reference_rad),'--','Color',p.dark,'LineWidth',1.1,'HandleVisibility','off');
    xlim(ax,range);ylabel(ax,'Position (deg)','Color',p.dark);grid(ax,'on');
    if fixture==1,caseTitle='A  +60 to -60 deg reversal';else,caseTitle='B  -60 to +60 deg reversal';end
    title(ax,caseTitle,'Color',p.dark,'FontSize',12,'FontWeight','bold');
    ax=nexttile(layout,2+fixture);allAxes(2,fixture)=ax;styleAxes(ax);hold(ax,'on');
    for policy=1:4
        a=records{fixture,policy}.fault.timeSeries;
        plot(ax,a.time_s,a.command_V,styles{policy},'Color',colors(policy,:),'LineWidth',1.7);
    end
    a=reference.fault.timeSeries;
    plot(ax,a.time_s,a.commandLimit_V,'--','Color',p.dark,'LineWidth',.9,'HandleVisibility','off');
    plot(ax,a.time_s,-a.commandLimit_V,'--','Color',p.dark,'LineWidth',.9,'HandleVisibility','off');
    yline(ax,0,':','Color',p.lightGray,'LineWidth',.8,'HandleVisibility','off');
    xlim(ax,range);ylabel(ax,'Applied command (V)','Color',p.dark);grid(ax,'on');
    title(ax,'Applied voltage and selected command limits','Color',p.dark,'FontSize',11,'FontWeight','normal');
    ax=nexttile(layout,4+fixture);allAxes(3,fixture)=ax;styleAxes(ax);
    codes=zeros(4,height(a));
    for policy=1:4
        record=records{fixture,policy};activity=record.activity;
        assert(isequal(record.fault.time_s,reference.fault.time_s),'EMIProject:TuningPlotData', ...
            'Limiter policies must share an exact time grid.');
        codes(policy,:)=double(activity.SlewClipped)'+2*double(activity.AmplitudeClipped)';
    end
    imagesc(ax,a.time_s,1:4,codes,[-.5,3.5]);
    colormap(ax,[.98,.98,.98;p.blue;p.orange;p.purple]);
    xlim(ax,range);ylim(ax,[.5,4.5]);
    set(ax,'YDir','reverse','YTick',1:4,'YTickLabel',shortNames,'TickLabelInterpreter','none');
    xlabel(ax,'Time (s)','Color',p.dark);
    title(ax,'Actual constraint activity (1 ms samples)','Color',p.dark,'FontSize',11,'FontWeight','normal');
    bar=colorbar(ax,'southoutside');bar.Color=p.dark;bar.Ticks=0:3;
    bar.TickLabels={'None','Slew','Amplitude','Both'};
    linkaxes(allAxes(:,fixture),'x');
end
leg=legend(allAxes(1,2),responseHandles,names,'Orientation','horizontal', ...
    'Color','white','TextColor',p.dark,'EdgeColor',p.lightGray,'FontSize',10);
leg.Layout.Tile='south';
header(f,'Limiter ablation: actual motion, voltage and clipping', ...
    'Identical selected gains and reference filter; two predeclared 2 V command-limit stress fixtures. Diagnostic comparisons only.');
footer(f,['Black dashed curves: commanded position (top) and selected effective voltage limits (middle). ' ...
    'Removing mode caps retains the 2 V software/bus bound.' newline ...
    'Activity strips count actual interventions; merely touching a bound and zero-voltage hard stop are not clipping. No hardware operating-point qualification.']);
exportFigure(f,folder,'phase3_tuning_limiter_stress');
end

function labels=fixtureLabels(ids)
known=["eval_negative_freeze","eval_short_freeze","eval_reversed_burst", ...
    "eval_known_positive_load","eval_known_negative_load","eval_unknown_load_freeze", ...
    "eval_model_mismatch_burst","eval_permitted_delay_jitter","eval_benign_noise_reversal", ...
    "eval_opposite_capped_reversal","eval_independent_reference_recovery","eval_independent_reference_no_reset"];
short=["Negative freeze","Short freeze","Reversal + packet burst", ...
    "Known positive load","Known negative load","Unknown load + freeze", ...
    "Model mismatch + burst","Permitted delay / jitter","Benign noise + reversal", ...
    "Opposite capped reversal","Independent ref. + reset","Independent ref., no reset"];
labels=strings(numel(ids),1);
for k=1:numel(ids)
    index=find(known==string(ids(k)),1);
    name=replace(erase(string(ids(k)),"eval_"),"_"," ");
    if ~isempty(index),name=short(index);end
    labels(k)=sprintf('%02d  %s',k,name);
end
end

function ratio=ratioOrMissing(numerator,denominator)
ratio=NaN(size(numerator));valid=denominator>0;
ratio(valid)=numerator(valid)./denominator(valid);
end

function f=makeFigure(name,width,height)
p=palette();
f=figure('Name',name,'Visible','off','Color','white','Position',[30,30,width,height], ...
    'InvertHardcopy','off','DefaultAxesColor','white','DefaultAxesXColor',p.dark, ...
    'DefaultAxesYColor',p.dark,'DefaultTextColor',p.dark,'DefaultAxesFontName','Arial', ...
    'DefaultAxesFontSize',10,'DefaultLegendColor','white','DefaultLegendTextColor',p.dark);
end

function styleAxes(ax)
p=palette();set(ax,'Color','white','XColor',p.dark,'YColor',p.dark,'ZColor',p.dark, ...
    'GridColor',p.lightGray,'MinorGridColor',p.lightGray,'GridAlpha',.55, ...
    'FontName','Arial','FontSize',10,'Box','on','Layer','top');
end

function header(f,titleText,subtitle)
p=palette();
annotation(f,'textbox',[.04,.95,.92,.036],'String',titleText,'EdgeColor','none', ...
    'Color',p.dark,'FontName','Arial','FontSize',18,'FontWeight','bold','Interpreter','none');
annotation(f,'textbox',[.04,.915,.92,.036],'String',subtitle,'EdgeColor','none', ...
    'Color',p.gray,'FontName','Arial','FontSize',10,'Interpreter','none');
end

function footer(f,caption)
p=palette();annotation(f,'textbox',[.04,.018,.92,.059],'String',caption, ...
    'EdgeColor','none','Color',p.dark,'FontName','Arial','FontSize',9,'Interpreter','none');
end

function exportFigure(f,folder,name)
drawnow;
exportgraphics(f,fullfile(folder,string(name)+".png"),'Resolution',200,'BackgroundColor','white');
exportgraphics(f,fullfile(folder,string(name)+".pdf"),'ContentType','vector','BackgroundColor','white');
end

function p=palette()
p.dark=[.12,.16,.20];p.gray=[.41,.46,.50];p.lightGray=[.76,.80,.83];
p.blue=[.08,.38,.64];p.paleBlue=[.69,.79,.88];p.orange=[.84,.43,.13];
p.green=[.16,.53,.40];p.purple=[.47,.31,.64];p.red=[.72,.15,.16];p.brown=[.61,.43,.14];
end
