function plot_phase3_motion_study(study,outputFolder)
%PLOT_PHASE3_MOTION_STUDY Preserve task-delay cost alongside alarm prevention.
arguments
 study (1,1) struct
 outputFolder (1,1) string
end
if ~isfolder(outputFolder),mkdir(outputFolder);end
dark=[.13,.17,.21];gray=[.48,.51,.55];blue=[.08,.39,.66];orange=[.87,.43,.12];
raw=study.results{1,1}.fault.timeSeries;shaped=study.results{1,2}.fault.timeSeries;
requested=study.results{1,2}.fault.run.profiles.requestedReference_rad;
f=figureBase([1550,1050]);cleanup=onCleanup(@()close(f));
l=tiledlayout(f,3,1,'TileSpacing','compact','Padding','compact');l.OuterPosition=[.045,.13,.92,.76];
ax=nexttile(l);style(ax);hold(ax,'on');
h(1)=plot(ax,raw.time_s,rad2deg(requested),'--','Color',dark,'LineWidth',1.2);
h(2)=plot(ax,raw.time_s,rad2deg(raw.position_rad),'Color',gray,'LineWidth',1.8);
h(3)=plot(ax,shaped.time_s,rad2deg(shaped.position_rad),'Color',blue,'LineWidth',2);
h(4)=plot(ax,shaped.time_s,rad2deg(shaped.reference_rad),':','Color',orange,'LineWidth',1.8);
xlim(ax,[1.30,2.35]);ylabel(ax,'Position (deg)','Color',dark);
visible=raw.time_s>=1.30&raw.time_s<=2.35;
positionRange=rad2deg([raw.position_rad(visible);shaped.position_rad(visible);requested(visible)]);
padding=max(5,.08*(max(positionRange)-min(positionRange)));
ylim(ax,[min(positionRange)-padding,max(positionRange)+padding]);
title(ax,'A  Original task, shaped command and actual position','Color',dark);
leg=legend(ax,h,{'Original request','Raw-policy position','Governed position','Shaped command'}, ...
 'Color','white','TextColor',dark,'Orientation','horizontal');leg.Layout.Tile='south';
ax=nexttile(l);style(ax);hold(ax,'on');
plot(ax,raw.time_s,raw.velocity_rad_s,'Color',gray,'LineWidth',1.8);
plot(ax,shaped.time_s,shaped.velocity_rad_s,'Color',blue,'LineWidth',2);
yline(ax,-25,'--','25 rad/s: source-time measurement rate gate','Color',dark,'LabelHorizontalAlignment','left');
yline(ax,-20,':','20 rad/s magnitude: clean-case guard','Color',[.19,.52,.37],'LabelHorizontalAlignment','left');
xlim(ax,[1.30,2.35]);ylabel(ax,'Actual velocity (rad/s)','Color',dark);
title(ax,'B  Plant velocity; reference limits alone do not guarantee this bound','Color',dark);
ax=nexttile(l);style(ax);hold(ax,'on');
stairs(ax,raw.time_s,raw.mode,'Color',gray,'LineWidth',1.8);
stairs(ax,shaped.time_s,shaped.mode,'Color',blue,'LineWidth',2);
scatter(ax,raw.time_s(raw.alarm~=0),raw.mode(raw.alarm~=0),10,[.75,.19,.17],'filled');
xlim(ax,[1.30,2.35]);ylim(ax,[-.2,4.3]);yticks(ax,0:4);
yticklabels(ax,{'Normal','Suspected','Degraded','Recovery','Stop'});
xlabel(ax,'Time (s)','Color',dark);title(ax,'C  Supervisory modes; red dots show raw-policy alarms','Color',dark);
header(f,'Resolving the recorded clean-reversal rate-check conflict', ...
 'Historical gains and 25 rad/s observer threshold unchanged; optional command shaping only.');
footer(f,'The original request remains the task target. Shaping adds delay; actual plant behavior is checked separately. Existing zero-voltage stop and reset rules remain unchanged.');
export(f,outputFolder,'phase3_motion_reversal');clear cleanup

m=study.metrics;g=m(m.Policy=="GOVERNED"&m.Partition=="evaluation"&m.Kind=="clean",:);
r=m(m.Policy=="RAW"&m.Partition=="evaluation"&m.Kind=="clean",:);
assert(isequal(g.Fixture,r.Fixture));n=height(g);
labels=strings(n,1);
for k=1:n,labels(k)=sprintf('%02d  %s',k,replace(erase(g.Fixture(k),"clean_"),"_"," "));end
f=figureBase([1600,1050]);cleanup=onCleanup(@()close(f));
l=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');l.OuterPosition=[.035,.14,.93,.74];
ax=nexttile(l);style(ax);hold(ax,'on');
for k=1:n,plot(ax,[r.MaxTrueVelocity_rad_s(k),g.MaxTrueVelocity_rad_s(k)],[k,k],'Color',[.78,.81,.84],'LineWidth',2);end
h1=scatter(ax,r.MaxTrueVelocity_rad_s,1:n,50,gray,'s','filled');
h2=scatter(ax,g.MaxTrueVelocity_rad_s,1:n,50,blue,'filled');
xline(ax,25,'--','25: measured-rate gate','Color',dark,'LabelOrientation','horizontal','LabelVerticalAlignment','top');
xline(ax,20,':','20: clean-case guard','Color',[.19,.52,.37],'LabelOrientation','horizontal','LabelVerticalAlignment','bottom');
set(ax,'YDir','reverse','YTick',1:n,'YTickLabel',labels,'TickLabelInterpreter','none');ylim(ax,[.4,n+.6]);
xlim(ax,[0,max([26;r.MaxTrueVelocity_rad_s;g.MaxTrueVelocity_rad_s])*1.13]);
xlabel(ax,'Full-record peak actual speed (rad/s)','Color',dark);title(ax,'A  New clean-motion cases','Color',dark);
leg=legend(ax,[h1,h2],{'Raw reference','Governed reference'},'Color','white','TextColor',dark,'Location','southoutside','Orientation','horizontal');
ax=nexttile(l);style(ax);hold(ax,'on');
for k=1:n,plot(ax,[r.RequestedWindowRMSE_deg(k),g.RequestedWindowRMSE_deg(k)],[k,k],'Color',[.78,.81,.84],'LineWidth',2);end
h1=scatter(ax,r.RequestedWindowRMSE_deg,1:n,50,gray,'s','filled');
h2=scatter(ax,g.RequestedWindowRMSE_deg,1:n,50,blue,'filled');
set(ax,'YDir','reverse','YTick',1:n,'YTickLabel',labels,'TickLabelInterpreter','none');ylim(ax,[.4,n+.6]);
xlim(ax,[0,max([1;r.RequestedWindowRMSE_deg;g.RequestedWindowRMSE_deg])*1.12]);
xlabel(ax,'Error against ORIGINAL request, window RMSE (deg)','Color',dark);
title(ax,'B  Task tracking retains the shaping delay','Color',dark);
legend(ax,[h1,h2],{'Raw reference','Governed reference'},'Color','white','TextColor',dark,'Location','southoutside','Orientation','horizontal');
header(f,'New clean motions: rate margin and task-tracking cost', ...
 sprintf('%d/%d governed cases pass declared behavior; raw/governed alarm samples: %d / %d.', ...
 nnz(g.DeclaredBehaviorPass),n,sum(r.AlarmSamples),sum(g.AlarmSamples)));
footer(f,'The shaper bounds its own sampled reference speed at 10 rad/s and acceleration at 200 rad/s^2. Actual speed, sensor rates, task error and faults are evaluated independently.');
export(f,outputFolder,'phase3_motion_clean_evaluation');clear cleanup
end

function f=figureBase(size)
f=figure('Visible','off','Color','white','Position',[20,20,size], ...
 'DefaultAxesColor','white','DefaultAxesXColor',[.13,.17,.21], ...
 'DefaultAxesYColor',[.13,.17,.21],'DefaultTextColor',[.13,.17,.21], ...
 'DefaultAxesFontName','Arial','DefaultAxesFontSize',11,'InvertHardcopy','off');
end
function style(ax)
set(ax,'Color','white','XColor',[.13,.17,.21],'YColor',[.13,.17,.21], ...
 'GridColor',[.75,.8,.84],'GridAlpha',.45,'Box','on','FontName','Arial');grid(ax,'on');
end
function header(f,titleText,subtitle)
annotation(f,'textbox',[.04,.95,.92,.036],'String',titleText,'EdgeColor','none', ...
 'Color',[.13,.17,.21],'FontName','Arial','FontSize',18,'FontWeight','bold','Interpreter','none');
annotation(f,'textbox',[.04,.905,.92,.04],'String',subtitle,'EdgeColor','none', ...
 'Color',[.43,.48,.53],'FontName','Arial','FontSize',11,'Interpreter','none');
end
function footer(f,message)
annotation(f,'textbox',[.04,.02,.92,.06],'String',message,'EdgeColor','none', ...
 'Color',[.13,.17,.21],'FontName','Arial','FontSize',10,'Interpreter','none');
end
function export(f,folder,name)
drawnow;exportgraphics(f,fullfile(folder,string(name)+".png"),'Resolution',180,'BackgroundColor','white');
exportgraphics(f,fullfile(folder,string(name)+".pdf"),'ContentType','vector','BackgroundColor','white');
end
