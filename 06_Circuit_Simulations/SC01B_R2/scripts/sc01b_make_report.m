function reportFile=sc01b_make_report(study,folder)
%SC01B_MAKE_REPORT Render R2 evidence without inferring acceptance from plots.
arguments
    study (1,1) struct
    folder (1,1) string
end
if ~isfolder(folder),mkdir(folder);end
[ok,a]=fileattrib(folder);assert(ok);folder=string(a.Name);
root=fileparts(fileparts(mfilename('fullpath')));c=study.criteria;
verified=sc01b_campaign_acceptance(study,c);
for field=string(fieldnames(verified)).'
    assert(isfield(study,field) && isequaln(study.(field),verified.(field)), ...
        'SC01B:ReportStatus','Stored status %s disagrees with campaign acceptance.',field);
end
names=string(c.caseNames);n=numel(names);labels=strings(n,1);
baseline=jsondecode(fileread(fullfile(root,'references','SC01B_Baseline_Summary.json')));
oldPeak=NaN(n,1);oldChannel=oldPeak;newPeak=oldPeak;spicePeak=oldPeak;
newChannel=oldPeak;overlap=oldPeak;oldUnresolved=oldPeak;newUnresolved=oldPeak;
numeric=false(n,1);operating=numeric;channel=numeric;execution=numeric;
waveRatio=NaN(n,1);unavailable=zeros(n,1);
for k=1:n
    name=names(k);labels(k)=caseLabel(name);p=study.cases.(name).parameters;
    m=study.metrics(string(study.metrics.Case)==name,:);
    mn=m(string(m.Engine)=="native",:);ms=m(string(m.Engine)=="spice",:);
    q=study.comparisons(string(study.comparisons.Case)==name,:);
    r=study.runs(string(study.runs.Case)==name,:);
    b=study.balance(string(study.balance.Case)==name,:);
    e=study.events(string(study.events.Case)==name,:);
    nr=r(startsWith(string(r.Run),"native_"),:);
    steps=recordSteps(string(r.Run),c);
    execution(k)=all(r.Completed & r.Warnings==0 & isfinite(r.Samples) & r.Samples>=2 & ...
        isfinite(r.StopTime_s) & abs(r.StopTime_s-p.simulation.stopTime_s)<=1e-14 & ...
        isfinite(r.Step_s) & abs(r.Step_s-steps)<=1e-20);
    limits=max(c.balanceAbsoluteTolerance_J,c.balanceRelativeTolerance*b.EnergyScale_J);
    balanceOK=~b.WindowClipped & isfinite(b.Residual_J) & isfinite(b.EnergyScale_J) & b.EnergyScale_J>=0 & ...
        abs(b.Residual_J)<=limits & abs(b.WindowStart_s-p.validation.startTime_s)<=1e-14 & ...
        abs(b.WindowEnd_s-p.simulation.stopTime_s)<=1e-14;
    numeric(k)=execution(k) && all(q.Pass) && all(balanceOK);
    channel(k)=all(mn.ChannelOverlapKnown & isfinite(mn.nativeChannelOverlap_s) & mn.nativeChannelOverlap_s==0) && ...
        all(nr.ChannelOverlapKnown & isfinite(nr.NativeChannelOverlap_s) & nr.NativeChannelOverlap_s==0);
    operating(k)=channel(k) && all(m.AllFinite & ~m.ValidationRecordClipped & ...
        abs(m.ValidationStart_s-p.validation.startTime_s)<=1e-14 & abs(m.ValidationEnd_s-p.simulation.stopTime_s)<=1e-14 & ...
        m.DeviceVoltageLimitsPassed & m.GateVoltageLimitsPassed & m.UnresolvedEventCount==0 & m.VoltageRecrossingCount==0) && ...
        all(e.Resolved & ~e.Clipped & ~e.CounterpartGateClipped);
    newPeak(k)=max([mn.PeakAbsHighCurrent_A;mn.PeakAbsLowCurrent_A]);
    spicePeak(k)=max([ms.PeakAbsHighCurrent_A;ms.PeakAbsLowCurrent_A]);
    newChannel(k)=mn.PeakSharedForwardChannelCurrent_A;overlap(k)=mn.nativeChannelOverlap_s;
    newUnresolved(k)=mn.UnresolvedEventCount;
    match=baseline.cases(string({baseline.cases.Case})==name);
    assert(isscalar(match),'SC01B:BaselineShape','Expected one original baseline row per case.');
    oldPeak(k)=match.PeakNativeTerminal_A;oldChannel(k)=match.PeakSharedForwardChannelCurrent_A;
    oldUnresolved(k)=match.NativeUnresolvedEvents;
    unavailable(k)=sum(~q.ExecutionComplete);values=q.MaxWaveformLimitRatio(q.ExecutionComplete);
    values=values(isfinite(values));if ~isempty(values),waveRatio(k)=max(values);end
end
makeOverview(study,folder,names,labels,oldPeak,newPeak,waveRatio,unavailable);
makeSwitchingOverlay(study,folder);
p=study.cases.nominal.parameters;
lines=["# SC-01B R2 switching-model review";""; ...
    "This separately identified revision preserves the original SC01B campaign and MOSFET equations. Its outcome is computed from the recorded campaign, including rejected attempts.";""];
if verified.switchingFailuresResolved
    lines(end+1)="**The declared R2 numerical and operating-point checks pass, including modeled channel overlap. Physical source validation remains open.**";
else
    lines(end+1)="**R2 has remaining failed acceptance checks. The complete switching-model failure set is not yet marked resolved.**";
end
lines(end+1)="";
lines(end+1)=sprintf('The revised behavioral drive commands +%.4g V on and %.4g V off, retains the original turn-on gate-resistance cases, and uses %.4g Ω total discharge resistance. The %.4g ns dead time, %.4g ns linear ramps and %.4g/%.4g ns delays are retained. The negative rail and directional impedance are new design assumptions; this is not an unchanged UCC27211A implementation.', ...
    p.driver.voltage_V,p.driver.offVoltage_V,p.driver.turnOffResistance_Ohm,p.control.deadTime_s*1e9, ...
    p.driver.commandRamp_s*1e9,p.driver.riseDelay_s*1e9,p.driver.fallDelay_s*1e9);
lines=[lines;"";"## Recorded acceptance";"";"| Gate | Result |";"|---|---|"];
fields=["executionPassed","numericalCampaignPassed","modeledChannelOverlapPassed","operatingPointsPassed","switchingFailuresResolved"];
descriptions=["Required simulation execution","Full numerical campaign","Modeled channel overlap, all native runs","All operating points, including channel overlap","Switching-model failures resolved"];
for k=1:numel(fields),lines(end+1)=sprintf('| %s | %s |',descriptions(k),status(verified.(fields(k))));end
lines(end+1)=sprintf('| Automated tests | %d / %d passed; %d failed; %d incomplete |',study.tests.Passed,study.tests.Total,study.tests.Failed,study.tests.Incomplete);
lines(end+1)="| Physical source validated | No |";
lines(end+1)="";
lines(end+1)=sprintf('%d required attempts were recorded: %d complete, %d rejected. %d of %d numerical comparisons have an accepted complete reference. Rejected references fail acceptance and are excluded from measured comparison-ratio plots.', ...
    height(study.runs),sum(study.runs.Completed),sum(~study.runs.Completed),sum(study.comparisons.ExecutionComplete),height(study.comparisons));
lines=[lines;"";"| Case | Execution | Numerical | Channel overlap | Operating point |";"|---|---|---|---|---|"];
for k=1:n
    lines(end+1)=sprintf('| %s | %s | %s | %s | %s |',labels(k),status(execution(k)),status(numeric(k)),status(channel(k)),status(operating(k)));
end
lines=[lines;"";"The operating-point gate requires complete finite records, resolved unclipped events, no repeated switch-voltage crossings, terminal voltage limits and zero simultaneous positive native channel conduction above max(1 mA, 0.1% of peak load current). Channel evidence is required for every native refinement and consistency run. Gate midpoint overlap and simultaneous terminal currents cannot substitute for internal channel-current evidence."; ...
    "";"## Original campaign and R2";""; ...
    "Original values come from the immutable campaign's finest native metrics, with source hashes retained in the baseline extract under references/SC01B_Baseline_Summary.json. R2 values come from this study's finest native records. These columns compare fixtures, not numerical convergence.";""; ...
    "| Case | Original peak terminal (A) | R2 peak terminal (A) | Original common channel (A) | R2 common channel (A) | Native unresolved events, original → R2 |"; ...
    "|---|---:|---:|---:|---:|---:|"];
for k=1:n
    lines(end+1)=sprintf('| %s | %.6g | %.6g | %.6g | %.6g | %d → %d |',labels(k),oldPeak(k),newPeak(k),oldChannel(k),newChannel(k),oldUnresolved(k),newUnresolved(k));
end
lines=[lines;"";"![Original and revised current peaks and numerical comparison ratios](Overview.png)";""; ...
    "A common-channel value below the declared floor is not a claim of mathematically zero current. Drain-terminal peaks also contain charge and diode contributions. Neither a low terminal peak nor waveform agreement alone proves absence of channel overlap."; ...
    "";"## Numerical evidence";""];
lines(end+1)=sprintf('Recorded native local-trapezoidal steps: %s ns. Original-equation SPICE maximum steps: %s ns. Labels below come directly from the recorded comparisons. The declared nominal and combined-extension tolerance checks are included in the full numerical gate.', ...
    join(compose("%g",c.nativeSteps_s*1e9),", "),join(compose("%g",c.spiceSteps_s*1e9),", "));
lines(end+1)=sprintf('The comparison interval is %.4g–%.4g µs, without fitted delay, filtering or a moved time origin. Waveform allowances are max(%.4g V or %.4g A, %.4g%% of reference peak absolute amplitude); signed-energy allowance is max(%.4g nJ, %.4g%% of absolute reference energy); event-time allowance is %.4g ns; closure allowance is max(%.4g nJ, %.4g%% of its recorded energy scale).', ...
    p.validation.startTime_s*1e6,p.simulation.stopTime_s*1e6,c.voltageAbsoluteTolerance_V,c.currentAbsoluteTolerance_A, ...
    100*c.relativeWaveformTolerance,c.energyAbsoluteTolerance_J*1e9,100*c.relativeMetricTolerance,c.eventTimeTolerance_s*1e9, ...
    c.balanceAbsoluteTolerance_J*1e9,100*c.balanceRelativeTolerance);
lines=[lines;"";"| Case / comparison | Waveform ratio | Energy ratio | Timing difference (ns) | Required events resolved | Result |";"|---|---:|---:|---:|---|---|"];
for k=1:height(study.comparisons)
    q=study.comparisons(k,:);
    if q.ExecutionComplete
        lines(end+1)=sprintf('| %s / %s | %s | %s | %s | %s | %s |',caseLabel(string(q.Case)),markdownText(q.Comparison), ...
            number(q.MaxWaveformLimitRatio),number(q.MaxEnergyLimitRatio),number(q.MaxEventTimeDifference_s*1e9),status(q.AllEventsResolved),status(q.Pass));
    else
        lines(end+1)=sprintf('| %s / %s | Unavailable | Unavailable | Unavailable | Unavailable | FAIL: rejected execution |',caseLabel(string(q.Case)),markdownText(q.Comparison));
    end
end
lines=[lines;"";"A ratio of 1 is the acceptance boundary. Unavailable means no accepted reference; it never means zero difference. Current-timing agreement and initial-state consistency remain separate components of the recorded composite comparison flag. Signed device terminal energy includes stored-charge transfer and is not semiconductor heat.";""; ...
    "### Solver investigation and rejected evidence";""; ...
    "The solver remedy combines two controls: algebraically equivalent clipped-linear behavioral command sources, and a fixed 1 ns TSTEP independent of the actual integration maximum TMAX. Source levels, timing, ramp durations and strict tolerances are unchanged. With wrdata and no interp command, exported times are the actual integration times; each completed SPICE record is checked against TMAX. Changing source representation alone was insufficient at finer steps. Actual completion and comparison flags above determine this campaign's result; supplemental trials cannot replace failed required checks."];
if isfile(fullfile(folder,'supplemental','solver','Solver_Resolution.md'))
    lines(end+1)="The [solver resolution](supplemental/solver/Solver_Resolution.md) and [portable solver supplement](supplemental/solver/README.md) retain 19 accepted strict checks and 132 per-signal comparisons, including all five cases at 0.0625 ns TMAX and the nominal/combined cases at 0.03125 ns. TSTEP sensitivity repeats and unchanged-original-driver recovery checks separate the numerical remedy from the drive revision. This supplements the declared campaign and does not prove the underlying simulator defect or hardware validity.";
end
rejected=study.runs(~study.runs.Completed,:);
if isempty(rejected)
    lines(end+1)="No required simulation attempt in this collected campaign is recorded as rejected.";
else
    lines=[lines;"";"| Rejected attempt | Diagnostic | Retained evidence |";"|---|---|---|"];
    for k=1:height(rejected)
        r=rejected(k,:);log=retainedLog(r,folder);link="See runs.csv / rejected.json";
        if isfile(log),link="[Solver log](<"+relativePath(log,folder)+">)";end
        lines(end+1)=sprintf('| %s / %s | %s | %s |',caseLabel(string(r.Case)),markdownText(r.Run),reportDiagnostic(r.Diagnostic),link);
    end
end
lines=[lines;"";"## Switching and gate evidence";"";"![Stored native and SPICE switching and gate samples](Switching_Overlay.png)";""; ...
    "Plots use stored integration samples. Gate diagnostic levels remain 1.2, 6 and 10.8 V, referenced to the original +12 V level; they are not fractions of the bipolar excursion. The original −0.1 to +0.5 µs command windows and strict crossing rules remain. Full flags distinguish switch-voltage resolution, high-side gate resolution and counterpart low-side gate resolution.";""; ...
    "| Case | Native / SPICE unresolved events | Native above-floor channel overlap (ns) | Native / SPICE peak terminal current (A) |";"|---|---:|---:|---:|"];
for k=1:n
    ms=study.metrics(string(study.metrics.Case)==names(k) & string(study.metrics.Engine)=="spice",:);
    lines(end+1)=sprintf('| %s | %d / %d | %s | %.6g / %.6g |',labels(k),newUnresolved(k),ms.UnresolvedEventCount,number(overlap(k)*1e9),newPeak(k),spicePeak(k));
end
lines=[lines;"";"## Scope and next evidence";""; ...
    "MOSFET equations, nonlinear charge, body diode and package parasitics remain unchanged. The model is isothermal and uses an assumed supply/load fixture. The new regulated negative rail and split drive have not been tied to selected hardware. Bootstrap/negative-rail generation, UVLO, nonlinear driver limits, clamp/diode dynamics, temperature variation, layout tolerance, motor back-EMF and measured robot commutation remain outside the model.";""; ...
    "[TI SLUA618A, sections 3.4–3.5](https://www.ti.com/lit/ml/slua618a/slua618a.pdf) provides the design basis for lower discharge impedance and negative turn-off voltage. Numeric values are declared R2 assumptions selected during local remedy screens, not manufacturer guarantees or blinded validation. See Device_Source_and_Assumptions.md in the R2 source folder.";""; ...
    "After the declared switching gates pass, identify a realizable bipolar drive and characterize its commutation, parasitics and tolerances before treating this source as representative of robot hardware or integrating it with a validated EMI receiver model.";""; ...
    "## Reproducible records";""; ...
    "[Status](status.json), [criteria](criteria.json), [runs](runs.csv), [comparisons](comparisons.csv), [waveform differences](waveforms.csv), [metrics](metrics.csv), [events](events.csv), and [energy balance](balance.csv) preserve the machine-readable evidence. study.mat retains the finest traces and tables; per-case folders retain parameters, refinements and solver logs. test_results.mat retains individual test outcomes."];
if isfile(fullfile(folder,'supplemental','driver','README.md'))
    lines(end+1)="The [portable driver investigation](supplemental/driver/README.md) retains the fixed-drive selection, all 48 screen attempts, six rejected/incomplete attempts and selected fine raw samples. Its screening completion flags are separate from full campaign acceptance.";
end
if isfile(fullfile(folder,'supplemental','independent_csv_audit.json'))
    lines(end+1)="The [independent exported-data audit](supplemental/independent_csv_audit.json) checks exported waveform and energy identities with input hashes. It complements the complete MATLAB acceptance gate.";
end
lines(end+1)=sprintf('MATLAB: `%s`. Started: %s. Completed: %s.',string(study.matlabVersion),string(study.startedUTC),string(study.completedUTC));
reportFile=fullfile(folder,'SC01B_Validation_Summary.md');
fid=fopen(reportFile,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
for k=1:numel(lines),fprintf(fid,'%s\n',lines(k));end
end

function steps=recordSteps(tags,c)
steps=NaN(numel(tags),1);
for k=1:numel(tags)
    if tags(k)=="native_tight_consistency",steps(k)=c.nativeSteps_s(end);
    elseif tags(k)=="spice_tight_tolerance",steps(k)=c.spiceSteps_s(end);
    else
        token=regexp(tags(k),'^(?:native|spice)_([0-9.eE+-]+)_ns$','tokens','once');
        assert(~isempty(token),'SC01B:ReportRunTag','Unknown declared run tag.');
        steps(k)=str2double(token{1})*1e-9;
    end
end
end

function makeOverview(study,folder,names,labels,peakNative,peakSpice,ratios,unavailable)
fig=figure('Visible','off','Color','w','Position',[80 80 1500 1000]);cleanup=onCleanup(@()close(fig));
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(layout,'SC-01B R2 | original fixture and revised switching evidence','FontSize',20,'FontWeight','bold');
ax=nexttile(layout);bars=barh(ax,1:numel(names),[peakNative peakSpice]);
bars(1).FaceColor=[.12 .29 .48];bars(2).FaceColor=[.16 .63 .58];
set(ax,'YTick',1:numel(names),'YTickLabel',labels,'YDir','reverse');
xlabel(ax,'Peak absolute drain-terminal current (A)');title(ax,'Original and R2 native current peaks');
legend(ax,{'Original native','R2 native'},'Location','best');style(ax);
ax=nexttile(layout);barh(ax,1:numel(names),ratios,'FaceColor',[.12 .29 .48]);
comparisonLabels=labels;
for k=1:numel(names)
    if unavailable(k)>0,comparisonLabels(k)=labels(k)+sprintf(' (%d unavailable)',unavailable(k));end
    if ~isfinite(ratios(k)),text(ax,.02,k,'Unavailable','FontSize',9);end
end
set(ax,'YTick',1:numel(names),'YTickLabel',comparisonLabels,'YDir','reverse');
xline(ax,1,'--','Limit = 1','Color',[.72 .24 .19],'LabelOrientation','horizontal');
finiteRatios=ratios(isfinite(ratios));maximum=1;
if ~isempty(finiteRatios),maximum=max(maximum,max(finiteRatios));end
xlim(ax,[0 1.15*maximum]);xlabel(ax,'Completed waveform difference / allowed difference');
title(ax,'Available waveform comparisons only');style(ax);
entry=study.cases.nominal;p=entry.parameters;
ax=nexttile(layout);plotPair(ax,entry,'switch_V',[p.validation.startTime_s p.simulation.stopTime_s]*1e6);
title(ax,'Nominal switching record');ylabel(ax,'Switch-node voltage (V)');
entry=study.cases.holdout_gate47;p=entry.parameters;
ax=nexttile(layout);plotDevices(ax,entry,'highCurrent_A','lowCurrent_A', ...
    [p.validation.startTime_s p.simulation.stopTime_s]*1e6);
title(ax,'47 Ω gate-resistance stress record');ylabel(ax,'Drain-terminal current (A)');
lightFigure(fig,layout);exportgraphics(layout,fullfile(folder,'Overview.png'),'Resolution',160);
end

function makeSwitchingOverlay(study,folder)
fig=figure('Visible','off','Color','w','Position',[90 60 1550 1400]);cleanup=onCleanup(@()close(fig));
layout=tiledlayout(fig,3,2,'TileSpacing','compact','Padding','compact');
title(layout,'SC-01B R2 | native and original-equation SPICE overlays','FontSize',20,'FontWeight','bold');
entry=study.cases.nominal;p=entry.parameters;
off=[p.control.highOff_s-.1e-6 p.control.highOff_s+.6e-6]*1e6;
on=[p.control.highOn_s-.1e-6 p.control.highOn_s+.6e-6]*1e6;
ax=nexttile(layout);plotPair(ax,entry,'switch_V',off);title(ax,'Nominal high-side turn-off');ylabel(ax,'Switch-node voltage (V)');
ax=nexttile(layout);plotPair(ax,entry,'switch_V',on);title(ax,'Nominal high-side turn-on');ylabel(ax,'Switch-node voltage (V)');
ax=nexttile(layout);plotDevices(ax,entry,'highVgs_V','lowVgs_V',off);title(ax,'Turn-off gate transitions');ylabel(ax,'Gate-source voltage (V)');
ax=nexttile(layout);plotDevices(ax,entry,'highVgs_V','lowVgs_V',on);title(ax,'Turn-on gate transitions');ylabel(ax,'Gate-source voltage (V)');
entry=study.cases.holdout_gate47;r=entry.nativeFine;p=entry.parameters;
mask=r.time_s>=p.validation.startTime_s;
indices=find(mask);[~,at]=max(max(abs([r.highCurrent_A(mask),r.lowCurrent_A(mask)]),[],2));
peakTime=r.time_s(indices(at));window=[max(p.validation.startTime_s,peakTime-.25e-6),min(p.simulation.stopTime_s,peakTime+.25e-6)]*1e6;
ax=nexttile(layout);plotDevices(ax,entry,'highCurrent_A','lowCurrent_A',window);
title(ax,'47 Ω stress: peak-current region');ylabel(ax,'Drain-terminal current (A)');
ax=nexttile(layout);plotDevices(ax,entry,'highVgs_V','lowVgs_V',window);
title(ax,'47 Ω stress: gate-source voltages');ylabel(ax,'Gate-source voltage (V)');
lightFigure(fig,layout);exportgraphics(layout,fullfile(folder,'Switching_Overlay.png'),'Resolution',160);
end

function lightFigure(fig,layout)
% Explicit export colors remain readable regardless of desktop dark theme.
ink=[.12 .16 .20];
set(findall(fig,'Type','axes'),'Color','w','XColor',ink,'YColor',ink,'ZColor',ink,'GridColor',[.45 .5 .55]);
set(findall(fig,'Type','text'),'Color',ink);layout.Title.Color=ink;
set(findall(fig,'Type','legend'),'Color','w','TextColor',ink,'EdgeColor',[.72 .76 .8]);
end

function plotPair(ax,entry,field,window)
hold(ax,'on');r=entry.nativeFine;s=entry.spiceFine;
plot(ax,r.time_s*1e6,r.(field),'Color',[.12 .29 .48],'LineWidth',1.6);
plot(ax,s.time_s*1e6,s.(field),'--','Color',[.85 .35 .20],'LineWidth',1.2);
xlim(ax,window);xlabel(ax,'Time (µs)');legend(ax,{'Native','Original SPICE'},'Location','best');style(ax);
end

function plotDevices(ax,entry,high,low,window)
hold(ax,'on');r=entry.nativeFine;s=entry.spiceFine;
plot(ax,r.time_s*1e6,r.(high),'Color',[.12 .29 .48],'LineWidth',1.5);
plot(ax,s.time_s*1e6,s.(high),'--','Color',[.35 .60 .83],'LineWidth',1.1);
plot(ax,r.time_s*1e6,r.(low),'Color',[.78 .28 .18],'LineWidth',1.5);
plot(ax,s.time_s*1e6,s.(low),'--','Color',[.95 .63 .28],'LineWidth',1.1);
xlim(ax,window);xlabel(ax,'Time (µs)');
legend(ax,{'High native','High SPICE','Low native','Low SPICE'},'Location','best','FontSize',8);style(ax);
end

function style(ax)
set(ax,'FontName','Arial','FontSize',10,'Box','off','LineWidth',.8,'GridAlpha',.15);
grid(ax,'on');ax.TitleFontSizeMultiplier=1.2;
end

function seconds=channelOverlap(r,p)
seconds=NaN;
if ~all(isfield(r,{'highChannelCurrent_A','lowChannelCurrent_A'})),return;end
a=p.validation.startTime_s;b=p.simulation.stopTime_s;
t=[a;r.time_s(r.time_s>a & r.time_s<b);b];
h=interp1(r.time_s,r.highChannelCurrent_A,t);l=interp1(r.time_s,r.lowChannelCurrent_A,t);
load=interp1(r.time_s,r.loadCurrent_A,t);threshold=max(1e-3,1e-3*max(abs(load)));
[h0,h1]=positiveBounds(h-threshold);[l0,l1]=positiveBounds(l-threshold);
seconds=sum(diff(t).*max(0,min(h1,l1)-max(h0,l0)));
end

function [first,last]=positiveBounds(v)
left=v(1:end-1);right=v(2:end);first=zeros(size(left));last=zeros(size(left));
last(left>0 & right>0)=1;
rising=left<=0 & right>0;first(rising)=-left(rising)./(right(rising)-left(rising));last(rising)=1;
falling=left>0 & right<=0;last(falling)=-left(falling)./(right(falling)-left(falling));
end

function label=caseLabel(name)
switch string(name)
    case "nominal",label="Nominal 24 V";
    case "holdout_bus18",label="Supply 18 V";
    case "holdout_load4ohm",label="Load 4 Ω";
    case "holdout_gate47",label="Gate 47 Ω";
    case "holdout_bus30_load16_gate10",label="30 V / 16 Ω / 10 Ω";
    otherwise,label=string(name);
end
end

function label=status(pass)
if pass,label="PASS";else,label="FAIL";end
end
function label=yesNo(pass)
if pass,label="Yes";else,label="No";end
end
function label=number(value)
if isnan(value),label="Unavailable";elseif isinf(value),label="Unresolved";else,label=string(sprintf('%.6g',value));end
end

function mask=completed(rows,field)
mask=true(height(rows),1);
if ismember(field,rows.Properties.VariableNames),mask=logical(rows.(field));end
end

function value=markdownText(value)
value=regexprep(string(value),'[\r\n]+',' ');
value=replace(value,'|','\|');
end

function value=reportDiagnostic(value)
% Preserve original paths in CSV metadata; use the collected log hyperlink.
value=regexprep(string(value),'\s+Inspect\s+[A-Za-z]:[\\/][^\r\n]*?ngspice\.log', ...
    ' Retained solver log linked in the rejected-attempt table.');
value=markdownText(value);
end

function path=retainedLog(row,folder)
path=fullfile(folder,string(row.Case),string(row.Run),'ngspice.log');
if isfile(path),return;end
if ismember('Diagnostic',row.Properties.VariableNames)
    original=regexp(char(string(row.Diagnostic)),'([A-Za-z]:[\\/][^\r\n]*?ngspice\.log)','tokens','once');
    if ~isempty(original) && isfile(original{1}),path=string(original{1});end
end
end

function text=eventFlags(event)
flags=strings(0,1);
required=["VoltageResolved","GateResolved","CounterpartGateResolved"];
for field=required
    if ~event.(field),flags(end+1)=field+"=false";end
end
disqualifying=["Clipped","CounterpartGateClipped","VoltageGrazing","GateGrazing"];
for field=disqualifying
    if event.(field),flags(end+1)=field+"=true";end
end
if isempty(flags),text="None";else,text=join(flags,'; ');end
end

function path=relativePath(target,base)
target=replace(string(target),'\','/');base=replace(string(base),'\','/');
a=split(base,'/');b=split(target,'/');common=0;
for k=1:min(numel(a),numel(b))
    if ~strcmpi(a(k),b(k)),break;end
    common=k;
end
if common==0,path=target;else,path=join([repmat("..",numel(a)-common,1);b(common+1:end)],'/');end
end
