function reportFile=sc01b_make_report(study,folder)
%SC01B_MAKE_REPORT Render recorded evidence without changing acceptance gates.
% Run only after sc01b_main has populated the final study tables. Plots use
% stored finest native/SPICE integration samples; no simulations are launched.
arguments
    study (1,1) struct
    folder (1,1) string
end
if ~isfolder(folder),mkdir(folder);end
[ok,attributes]=fileattrib(folder);if ok,folder=string(attributes.Name);end
root=fileparts(fileparts(mfilename('fullpath')));
c=study.criteria;names=string(c.caseNames);n=numel(names);
labels=strings(size(names));for k=1:n,labels(k)=caseLabel(names(k));end
wavePass=false(n,1);numericPass=wavePass;operatingPass=wavePass;
peakNative=zeros(n,1);peakSpice=zeros(n,1);waveRatio=NaN(n,1);
nativeUnresolved=zeros(n,1);spiceUnresolved=zeros(n,1);nativeOverlap=NaN(n,1);
availableComparisons=zeros(n,1);unavailableComparisons=zeros(n,1);
runComplete=completed(study.runs,'Completed');
comparisonComplete=completed(study.comparisons,'ExecutionComplete');
for k=1:n
    q=study.comparisons(string(study.comparisons.Case)==names(k),:);
    executionComplete=completed(q,'ExecutionComplete');
    measured=q(executionComplete,:);
    availableComparisons(k)=height(measured);unavailableComparisons(k)=sum(~executionComplete);
    b=study.balance(string(study.balance.Case)==names(k),:);
    m=study.metrics(string(study.metrics.Case)==names(k),:);
    wavePass(k)=~isempty(measured) && all(measured.WaveformsPassed);
    numericPass(k)=~isempty(q) && ~isempty(b) && all(q.Pass) && all(b.Pass);
    operatingPass(k)=~isempty(m) && all(m.DeviceVoltageLimitsPassed & ...
        m.GateVoltageLimitsPassed & m.UnresolvedEventCount==0 & m.VoltageRecrossingCount==0);
    native=m(string(m.Engine)=="native",:);spice=m(string(m.Engine)=="spice",:);
    nativeUnresolved(k)=native.UnresolvedEventCount;spiceUnresolved(k)=spice.UnresolvedEventCount;
    nativeOverlap(k)=channelOverlap(study.cases.(names(k)).nativeFine,study.cases.(names(k)).parameters);
    peakNative(k)=max([native.PeakAbsHighCurrent_A;native.PeakAbsLowCurrent_A]);
    peakSpice(k)=max([spice.PeakAbsHighCurrent_A;spice.PeakAbsLowCurrent_A]);
    if ~isempty(measured)
        finiteRatios=measured.MaxWaveformLimitRatio(isfinite(measured.MaxWaveformLimitRatio));
        if ~isempty(finiteRatios),waveRatio(k)=max(finiteRatios);end
    end
end
makeOverview(study,folder,names,labels,peakNative,peakSpice,waveRatio,unavailableComparisons);
makeSwitchingOverlay(study,folder);

lines=strings(0,1);
lines(end+1)="# SC-01B switching-source verification";
lines(end+1)="";
if study.numericalCampaignPassed && study.operatingPointsPassed
    lines(end+1)="**The recorded numerical and operating-point checks pass. Physical source validation remains open.**";
else
    lines(end+1)="**The campaign is complete, with failed checks retained. The switching source is not accepted across the full test matrix.**";
end
lines(end+1)="";
lines(end+1)=sprintf('%d of %d cases pass all completed waveform comparisons; %d of %d pass the full numerical checks, and %d of %d pass the declared operating-point checks. The latter also require resolved switching events and device terminal voltages within the imposed limits.', ...
    sum(wavePass),n,sum(numericPass),n,sum(operatingPass),n);
lines(end+1)="";
if any(~comparisonComplete)
    lines(end+1)=sprintf('%d comparison check(s) are unavailable because the stricter solver attempt did not produce an accepted complete reference. These checks fail the full numerical campaign. They are not counted as measured waveform disagreement and are excluded from waveform-only summaries and ratio plots. Partial traces from rejected attempts are not accepted as reference data.',sum(~comparisonComplete));
    lines(end+1)="";
end
if any(nativeUnresolved>0)
    eventCounts=strings(1,n);
    for k=1:n,eventCounts(k)=sprintf('%s: %d',labels(k),nativeUnresolved(k));end
    lines(end+1)="Native unresolved-event counts are "+join(eventCounts,'; ')+". Gate-transition classification is checked separately from switch-voltage crossings, so matching first-crossing times alone cannot clear these event failures. The case-by-case flags below identify the recorded cause without changing the frozen gates.";
    lines(end+1)="";
end
gateIndex=find(names=="holdout_gate47",1);
if ~isempty(gateIndex)
    gm=study.metrics(string(study.metrics.Case)=="holdout_gate47",:);
    gn=gm(string(gm.Engine)=="native",:);
    if ~numericPass(gateIndex) || ~operatingPass(gateIndex)
        lines(end+1)=sprintf('The 47 Ω gate-resistance case reaches %.3f A peak terminal current in the native model and %.3f A in original SPICE; its native event record contains %d unresolved events and %d repeated voltage crossings. Agreement between two engines does not make that behavior acceptable. This case remains in the frozen matrix as a failed or limited operating point.', ...
            peakNative(gateIndex),peakSpice(gateIndex),gn.UnresolvedEventCount,gn.VoltageRecrossingCount);
    else
        lines(end+1)="The 47 Ω gate-resistance case is retained in the result tables and plots; its final status follows the recorded checks rather than the earlier exploratory screen.";
    end
    lines(end+1)="";
end
nominal=study.cases.nominal;
nominalOverlap=channelOverlap(nominal.nativeFine,nominal.parameters);
nominalMetrics=study.metrics(string(study.metrics.Case)=="nominal" & string(study.metrics.Engine)=="native",:);
if ismember('PeakSharedForwardChannelCurrent_A',nominalMetrics.Properties.VariableNames) && isfinite(nominalOverlap)
    lines(end+1)=sprintf('The nominal model also has %.3f ns of simultaneous forward channel conduction above the declared current floor, with %.3f A peak common forward channel current. Waveform agreement and voltage-limit checks do not establish zero channel overlap; its event-classification outcome is reported separately. This is separate evidence from the 47 Ω stress behavior.', ...
        nominalOverlap*1e9,nominalMetrics.PeakSharedForwardChannelCurrent_A);
    lines(end+1)="";
end
if all(isfinite(nativeOverlap))
    lines(end+1)=sprintf('Native internal channel currents show simultaneous forward conduction above the declared floor in %d of %d cases. These modeled-current results remain part of the driver/dead-time investigation.',sum(nativeOverlap>0),n);
    lines(end+1)="";
end
lines(end+1)="These are two realizations of the same manufacturer equations, with an assumed gate drive and circuit fixture. They do not independently validate real MOSFETs, the complete driver IC, or a robot installation.";
lines(end+1)="";
lines(end+1)="![Campaign overview](Overview.png)";
lines(end+1)="";
lines(end+1)="## Recorded outcome";
lines(end+1)="";
lines(end+1)="| Check | Recorded result |";
lines(end+1)="|---|---|";
lines(end+1)=sprintf('| Native/original-SPICE numerical campaign | %s |',status(study.numericalCampaignPassed));
lines(end+1)=sprintf('| All operating points | %s |',status(study.operatingPointsPassed));
lines(end+1)=sprintf('| Automated tests | %d / %d passed; %d failed; %d incomplete |', ...
    study.tests.Passed,study.tests.Total,study.tests.Failed,study.tests.Incomplete);
lines(end+1)=sprintf('| Recorded simulation attempts | %d |',height(study.runs));
lines(end+1)=sprintf('| Completed / rejected attempts | %d / %d |',sum(runComplete),sum(~runComplete));
if ismember('Reused',study.runs.Properties.VariableNames)
    lines(end+1)=sprintf('| Completed records reused | %d |',sum(study.runs.Reused & runComplete));
end
lines(end+1)=sprintf('| Available / unavailable comparison checks | %d / %d |',sum(comparisonComplete),sum(~comparisonComplete));
lines(end+1)=sprintf('| Recorded warnings | %d |',sum(study.runs.Warnings));
lines(end+1)="| Physical source validated | No |";
lines(end+1)="";
lines(end+1)="| Case | Completed waveform comparisons | Unavailable checks | Full numerical checks | Operating-point checks |";
lines(end+1)="|---|---|---:|---|---|";
for k=1:n
    waveStatus=status(wavePass(k));if availableComparisons(k)==0,waveStatus="Unavailable";end
    lines(end+1)=sprintf('| %s | %s (%d checks) | %d | %s | %s |',labels(k),waveStatus,availableComparisons(k),unavailableComparisons(k),status(numericPass(k)),status(operatingPass(k)));
end
lines(end+1)="";
lines(end+1)="A full numerical pass requires completed execution, initial-state consistency, waveform and event agreement, required resolved events, signed-energy agreement and external energy closure. Rejected execution is an unavailable check; a completed trace with an unresolved event is a different failure. Neither is silently removed from the full numerical result. Operating-point checks are a separate check of events and terminal-voltage limits; they do not certify hardware safety.";
lines(end+1)="";
lines(end+1)="### Event-resolution evidence";
lines(end+1)="";
lines(end+1)="The conservative event gate requires ordered, finite and unrepeated threshold crossings, the required endpoint states, and complete event windows. A low-side gate disturbance during high-side turn-on can cross the low gate threshold again. That makes the counterpart gate transition ambiguous under this definition even when the switch-voltage transition resolves and the engines' first-crossing times agree. The classification is retained as recorded; this response is not removed by retiming traces, widening windows or relaxing the event gate.";
lines(end+1)="";
lines(end+1)="| Case | Native unresolved events | SPICE unresolved events |";
lines(end+1)="|---|---:|---:|";
for k=1:n
    lines(end+1)=sprintf('| %s | %d | %d |',labels(k),nativeUnresolved(k),spiceUnresolved(k));
end
lines(end+1)="";
lines(end+1)="| Native case / event | Recorded Status | Unmet resolution flags | Voltage recrossings |";
lines(end+1)="|---|---|---|---:|";
nativeEvents=study.events(string(study.events.Engine)=="native",:);
for k=1:height(nativeEvents)
    event=nativeEvents(k,:);
    lines(end+1)=sprintf('| %s / %s | %s | %s | %d |', ...
        caseLabel(string(event.Case)),markdownText(event.EventId),markdownText(event.Status), ...
        eventFlags(event),event.VoltageRecrossingCount);
end
lines(end+1)="";
lines(end+1)="VoltageResolved refers to switch-node voltage; GateResolved refers to the high-side gate, and CounterpartGateResolved to the low-side gate transition associated with that commutation. A false counterpart flag must not be described as an unresolved switch-voltage event. The voltage-recrossing column counts switch-node crossings only; it does not count low-side gate recrossings. Full native/SPICE flags, clipping and grazing diagnostics are retained in events.csv.";
lines(end+1)="";
if any(~runComplete)
    lines(end+1)="### Rejected solver attempts";
    lines(end+1)="";
    lines(end+1)="The stricter tolerance check is recorded as rejected rather than accepted with partial data. Baseline records remain separate. A zero warning count does not mean a rejected attempt succeeded: its error/abort reason and completion flag remain part of the evidence.";
    lines(end+1)="";
    lines(end+1)="| Case / attempt | Status | Recorded diagnostic |";
    lines(end+1)="|---|---|---|";
    rejected=study.runs(~runComplete,:);
    for k=1:height(rejected)
        row=rejected(k,:);
        diagnostic="See retained solver log.";
        if ismember('Diagnostic',row.Properties.VariableNames),diagnostic=reportDiagnostic(row.Diagnostic);end
        lines(end+1)=sprintf('| %s / %s | Rejected; reference unavailable | %s |',caseLabel(string(row.Case)),markdownText(row.Run),diagnostic);
        logPath=retainedLog(row,folder);
        if isfile(logPath)
            logText=fileread(logPath);
            token=regexp(logText,'[Tt]imestep too small;\s*time\s*=\s*([0-9.eE+-]+)','tokens','once');
            detail="Retained solver log";
            if ~isempty(token),detail=sprintf('Retained solver log: timestep failure at %.6g µs',str2double(token{1})*1e6);end
            lines(end+1)=sprintf('| ↳ %s | No partial reference accepted | [%s](<%s>) |',caseLabel(string(row.Case)),detail,relativePath(logPath,folder));
        end
    end
    lines(end+1)="";
    lines(end+1)="The CSV diagnostic fields preserve original worker paths as provenance. Report links use the collected case/run log first, so the linked evidence remains usable after installation or copying the report with its case/run folders.";
    lines(end+1)="";
end
lines(end+1)="## What was modeled";
lines(end+1)="";
p=study.cases.(names(1)).parameters;
lines(end+1)=sprintf('The nominal fixture uses a %.3g V source, %.3g Ω / %.3g mH series load, and a preloaded high-side-on DC state. It records a %.3g µs off/on commutation pair. The isothermal IAUC100N04S6L014 model uses %.3g °C junction/case inputs. The UCC27211A-informed drive uses %.3g V, an assumed %.3g Ω fixed output resistance, an external %.3g Ω gate resistor, a %.3g ns internal ramp, and %.3g / %.3g ns rising/falling delays.', ...
    p.bus.voltage_V,p.load.resistance_Ohm,p.load.inductance_H*1e3,p.simulation.stopTime_s*1e6, ...
    p.device.temperature_C,p.driver.voltage_V,p.driver.outputResistance_Ohm,p.driver.externalResistance_Ohm, ...
    p.driver.commandRamp_s*1e9,p.driver.riseDelay_s*1e9,p.driver.fallDelay_s*1e9);
lines(end+1)="";
lines(end+1)="The floating high-side supply is regulated; bootstrap dynamics, full driver output behavior, self-heating, motor back-EMF and physical layout characterization are outside the fixture. Internal vendor charge, diode and package behavior remain in the device model. No manufacturer-model tuning was performed for these comparisons.";
lines(end+1)="";
lines(end+1)="| Case | Supply (V) | Load (Ω) | External gate (Ω) | Native initial current (A) | Native peak terminal current (A) | SPICE peak terminal current (A) |";
lines(end+1)="|---|---:|---:|---:|---:|---:|---:|";
for k=1:n
    entry=study.cases.(names(k));pp=entry.parameters;
    mn=study.metrics(string(study.metrics.Case)==names(k) & string(study.metrics.Engine)=="native",:);
    lines(end+1)=sprintf('| %s | %.4g | %.4g | %.4g | %.8f | %.5f | %.5f |', ...
        labels(k),pp.bus.voltage_V,pp.load.resistance_Ohm,pp.driver.externalResistance_Ohm, ...
        mn.InitialLoadCurrent_A,peakNative(k),peakSpice(k));
end
lines(end+1)="";
lines(end+1)="## Numerical method and frozen criteria";
lines(end+1)="";
lines(end+1)=sprintf('Native physical-network integration uses local trapezoidal steps of %s ns. Original SPICE uses maximum steps of %s ns. Completed comparisons use the unchanged time origin and the union of integration knots, with linear interpolation and no fitted delay or filtering. The nominal and combined-extension cases also have declared tenfold consistency/tolerance checks; their actual completion and acceptance are reported separately.', ...
    join(compose("%g",c.nativeSteps_s*1e9),", "),join(compose("%g",c.spiceSteps_s*1e9),", "));
lines(end+1)="";
lines(end+1)=sprintf('The default comparison interval is %.3g–%.3g µs. Initial and pre-edge currents are recorded separately. Local consistency tolerances control nonlinear consistency; they are not adaptive integration-error tolerances. SPICE uses the declared source-stepping initialization, with all actual diagnostics preserved in its run records.',p.validation.startTime_s*1e6,p.simulation.stopTime_s*1e6);
lines(end+1)="";
lines(end+1)="| Quantity | Allowed absolute difference or residual |";
lines(end+1)="|---|---|";
lines(end+1)=sprintf('| Voltage waveform | max(%.4g V, %.4g%% × reference maximum absolute voltage) |',c.voltageAbsoluteTolerance_V,100*c.relativeWaveformTolerance);
lines(end+1)=sprintf('| Current waveform | max(%.4g A, %.4g%% × reference maximum absolute current) |',c.currentAbsoluteTolerance_A,100*c.relativeWaveformTolerance);
lines(end+1)=sprintf('| Matched event timing | %.4g ns; required events must be finite, resolved and classification-compatible |',c.eventTimeTolerance_s*1e9);
lines(end+1)=sprintf('| Signed terminal energy | max(%.4g nJ, %.4g%% × absolute reference energy) |',c.energyAbsoluteTolerance_J*1e9,100*c.relativeMetricTolerance);
lines(end+1)=sprintf('| External energy closure | max(%.4g nJ, %.4g%% × recorded energy scale) |',c.balanceAbsoluteTolerance_J*1e9,100*c.balanceRelativeTolerance);
lines(end+1)="";
lines(end+1)="These are absolute allowances combined with relative allowances using the maximum. They are not denominator floors. The reference amplitude is the maximum absolute value over the comparison window. Frozen criteria followed exploratory solver selection and the first SPICE screen; the alternate points were unfitted, not blinded physical validation data.";
lines(end+1)="";
lines(end+1)="| Case / comparison | Waveform limit ratio | Timing difference (ns) | Energy limit ratio | Events resolved | Overall |";
lines(end+1)="|---|---:|---:|---:|---|---|";
for k=1:height(study.comparisons)
    q=study.comparisons(k,:);
    if completed(q,'ExecutionComplete')
        lines(end+1)=sprintf('| %s / %s | %.5g | %s | %.5g | %s | %s |', ...
            caseLabel(string(q.Case)),comparisonLabel(string(q.Comparison)),q.MaxWaveformLimitRatio, ...
            number(q.MaxEventTimeDifference_s*1e9),q.MaxEnergyLimitRatio,yesNo(q.AllEventsResolved),status(q.Pass));
    else
        lines(end+1)=sprintf('| %s / %s | Unavailable | Unavailable | Unavailable | Unavailable | FAIL: rejected execution |', ...
            caseLabel(string(q.Case)),comparisonLabel(string(q.Comparison)));
        if ismember('Diagnostic',q.Properties.VariableNames)
            lines(end+1)=sprintf('| ↳ %s | %s | — | — | — | — |',caseLabel(string(q.Case)),reportDiagnostic(q.Diagnostic));
        end
    end
end
lines(end+1)="";
lines(end+1)="A limit ratio of 1 is the acceptance boundary; smaller is better. “Unavailable” means rejected execution produced no accepted comparison reference. “Unresolved” timing means a completed trace lacks finite required timing evidence. Neither means zero error. Per-signal differences, completion flags, diagnostics, classification flags and exact criteria are retained in the CSV and JSON records.";
lines(end+1)="";
lines(end+1)="## Switching behavior and energy";
lines(end+1)="";
lines(end+1)="![Native and original-SPICE switching overlays](Switching_Overlay.png)";
lines(end+1)="";
lines(end+1)="The edge overlays use stored integration samples. Switch timing follows crossings of the actual local bus fractions. The stress panels show the 47 Ω peak region and both gate voltages; drain-terminal current includes charge transfer and body-diode behavior, so it is distinct from load current or channel current.";
lines(end+1)="";
lines(end+1)="| Case | Native high-side terminal energy (nJ) | Native low-side terminal energy (nJ) | Native modeled channel overlap (ns) |";
lines(end+1)="|---|---:|---:|---:|";
for k=1:n
    mn=study.metrics(string(study.metrics.Case)==names(k) & string(study.metrics.Engine)=="native",:);
    overlap=nativeOverlap(k);
    lines(end+1)=sprintf('| %s | %.6g | %.6g | %s |',labels(k),mn.HighTerminalEnergy_J*1e9,mn.LowTerminalEnergy_J*1e9,number(overlap*1e9));
end
lines(end+1)="";
lines(end+1)="Terminal energy is the signed integral of VDS×ID + VGS×IG, including stored-charge transfer; it is not reported as semiconductor heat. The overlap diagnostic uses native internal channel branches: both drain-to-source channel currents must exceed max(1 mA, 0.1% of the window peak absolute load current). Duration is integrated over their piecewise-linear positive intervals. This identifies simultaneous conduction in the model, rather than inferring it only from gate thresholds or terminal-current spikes.";
lines(end+1)="";
lines(end+1)="| Case / engine | Closure residual (nJ) | Allowed residual (nJ) | Result |";
lines(end+1)="|---|---:|---:|---|";
for k=1:height(study.balance)
    b=study.balance(k,:);
    lines(end+1)=sprintf('| %s / %s | %.6g | %.6g | %s |',caseLabel(string(b.Case)),string(b.Engine),b.Residual_J*1e9,b.AcceptanceLimit_J*1e9,status(b.Pass));
end
lines(end+1)="";
lines(end+1)="External closure includes supply and gate-source work, external resistor losses, signed device terminal energy, and changes in external inductor/capacitor storage. Its energy scale and component terms are retained in balance.csv. Matching energy and waveforms cannot override unresolved switching events or a problematic modeled operating point.";
lines(end+1)="";
lines(end+1)="## Limits and next step";
lines(end+1)="";
lines(end+1)="Resolve the rejected strict-SPICE checks or establish a separately justified independent comparison before closing full numerical acceptance. The 0.25 ns native refinement passes the waveform gates in all cases; the coarser 0.5 ns load-4-ohm low-current comparison remains failed.";
lines(end+1)="";
lines(end+1)="Keep the current five-case evidence unchanged. Investigate the driver/dead-time combination responsible for the stress behavior, then evaluate explicitly revised gate drive, dead time and clamp assumptions as a new campaign. Check modeled channel overlap, voltage peaks and convergence after each justified design change. Follow that with physical parameter identification and measured commutation waveforms before treating the source as representative of the robot hardware. The complete victim/receiver integration remains separate work.";
lines(end+1)="";
lines(end+1)="No physical validation, driver-IC equivalence, production variation coverage, thermal qualification or hardware certification follows from these results. Differentiated aggressors require their own sensitivity checks; a small waveform difference alone does not bound peak dv/dt or di/dt.";
lines(end+1)="";
lines(end+1)="## Reproduction and evidence";
lines(end+1)="";
lines(end+1)=sprintf('- [Device sources and assumptions](<%s>) and [manufacturer source manifest](<%s>).', ...
    relativePath(fullfile(root,'Device_Source_and_Assumptions.md'),folder),relativePath(fullfile(root,'references','Source_Manifest.json'),folder));
lines(end+1)=sprintf('- [SC-01B reproduction instructions](<%s>).',relativePath(fullfile(root,'README.md'),folder));
lines(end+1)="- [Status](status.json), [criteria](criteria.json), [runs](runs.csv), [comparisons](comparisons.csv), [per-signal differences](waveforms.csv), [metrics](metrics.csv), [events](events.csv), and [energy balance](balance.csv).";
if isfile(fullfile(folder,'source_identity.json'))
    lines(end+1)="- [Source identity record](source_identity.json): original run-time keys and the separately captured full vendor dependency manifest; the legacy keys omitted the core/helper package and are not backstamped.";
end
if isfile(fullfile(folder,'supplemental','gate_recrossing_diagnosis.md'))
    lines(end+1)="- [Independent gate-recrossing audit](supplemental/gate_recrossing_diagnosis.md) and [strict-tolerance diagnosis](supplemental/tight_spice/Diagnosis.md).";
end
if isfile(fullfile(folder,'supplemental','standalone_verification.json'))
    lines(end+1)="- [Standalone-model and parameter-override audit](supplemental/standalone_verification.json).";
end
if isfile(fullfile(folder,'supplemental','independent_csv_audit.json'))
    lines(end+1)="- [Independent Python audit of exported CSVs](supplemental/independent_csv_audit.json): identities, source/gate work, external energy closure, waveform differences and internal channel overlap, with input-file hashes.";
end
lines(end+1)="- study.mat contains the finest native/SPICE records and complete summary tables; test_results.mat retains individual automated-test results. Per-case folders retain parameters, all integration/tolerance runs, original-SPICE decks/logs, and finest exported traces.";
lines(end+1)="";
lines(end+1)=sprintf('MATLAB: `%s`. Campaign started: %s. Completed: %s.',string(study.matlabVersion),string(study.startedUTC),string(study.completedUTC));
reportFile=fullfile(folder,'SC01B_Validation_Summary.md');
fid=fopen(reportFile,'w','n','UTF-8');assert(fid>=0,'SC01B:ReportWrite','Cannot open report file.');
cleanup=onCleanup(@()fclose(fid));
for k=1:numel(lines),fprintf(fid,'%s\n',char(lines(k)));end
end

function makeOverview(study,folder,names,labels,peakNative,peakSpice,ratios,unavailable)
fig=figure('Visible','off','Color','w','Position',[80 80 1500 1000]);cleanup=onCleanup(@()close(fig));
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(layout,'SC-01B | circuit-derived switching source','FontSize',20,'FontWeight','bold');
ax=nexttile(layout);bars=barh(ax,1:numel(names),[peakNative peakSpice]);
bars(1).FaceColor=[.12 .29 .48];bars(2).FaceColor=[.16 .63 .58];
set(ax,'YTick',1:numel(names),'YTickLabel',labels,'YDir','reverse');
xlabel(ax,'Peak absolute drain-terminal current (A)');title(ax,'Stress behavior remains visible');
legend(ax,{'Native','Original SPICE'},'Location','best');style(ax);
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
title(layout,'SC-01B | native and original-SPICE switching overlays','FontSize',20,'FontWeight','bold');
entry=study.cases.nominal;p=entry.parameters;
off=[p.control.highOff_s-.1e-6 p.control.highOff_s+.6e-6]*1e6;
on=[p.control.highOn_s-.1e-6 p.control.highOn_s+.6e-6]*1e6;
ax=nexttile(layout);plotPair(ax,entry,'switch_V',off);title(ax,'Nominal high-side turn-off');ylabel(ax,'Switch-node voltage (V)');
ax=nexttile(layout);plotPair(ax,entry,'switch_V',on);title(ax,'Nominal high-side turn-on');ylabel(ax,'Switch-node voltage (V)');
ax=nexttile(layout);plotDevices(ax,entry,'highCurrent_A','lowCurrent_A',off);title(ax,'Turn-off commutation currents');ylabel(ax,'Drain-terminal current (A)');
ax=nexttile(layout);plotDevices(ax,entry,'highCurrent_A','lowCurrent_A',on);title(ax,'Turn-on commutation currents');ylabel(ax,'Drain-terminal current (A)');
entry=study.cases.holdout_gate47;r=entry.nativeFine;p=entry.parameters;
mask=r.time_s>=p.validation.startTime_s;
indices=find(mask);[~,at]=max(max(abs([r.highCurrent_A(mask),r.lowCurrent_A(mask)]),[],2));
peakTime=r.time_s(indices(at));window=[max(p.validation.startTime_s,peakTime-.25e-6),min(p.simulation.stopTime_s,peakTime+.25e-6)]*1e6;
ax=nexttile(layout);plotDevices(ax,entry,'highCurrent_A','lowCurrent_A',window);
title(ax,'47 Ω stress: peak-current region');ylabel(ax,'Drain-terminal current (A)');
ax=nexttile(layout);plotDevices(ax,entry,'highVgs_V','lowVgs_V',window);
title(ax,'47 Ω stress: simultaneous gate behavior');ylabel(ax,'Gate-source voltage (V)');
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

function label=comparisonLabel(name)
switch string(name)
    case "native_0.5_to_0.125ns",label="Native 0.5 → 0.125 ns";
    case "native_0.25_to_0.125ns",label="Native 0.25 → 0.125 ns";
    case "spice_0.25_to_0.125ns",label="SPICE 0.25 → 0.125 ns";
    case "native_to_original_spice_0.125ns",label="Native ↔ original SPICE";
    case "native_consistency_10x",label="Native consistency ×10 tighter";
    case "spice_tolerances_10x",label="SPICE tolerances ×10 tighter";
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
