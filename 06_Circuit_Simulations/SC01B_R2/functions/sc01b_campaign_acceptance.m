function status=sc01b_campaign_acceptance(study,c)
%SC01B_CAMPAIGN_ACCEPTANCE Check the complete declared matrix and its gates.
% Structural omissions are errors. Recorded numerical or operating failures
% remain reportable failures, including failed strict-tolerance attempts.
assert(isequaln(study.criteria,c),'SC01B:CriteriaMismatch','Frozen criteria differ.');
assert(isequal(sort(string(fieldnames(study.cases))).',sort(c.caseNames)), ...
    'SC01B:IncompleteCampaign','All declared cases must be present.');
assert(numel(c.nativeSteps_s)>=2 && numel(c.spiceSteps_s)>=2 && ...
    all(diff(c.nativeSteps_s)<0) && all(diff(c.spiceSteps_s)<0), ...
    'SC01B:CriteriaShape','Each engine needs a strictly decreasing refinement sequence.');
runKeys=strings(0,1);comparisonKeys=runKeys;engineKeys=runKeys;eventKeys=runKeys;
expectedStep=zeros(0,1);expectedStop=zeros(0,1);expectedStart=zeros(0,1);engineStop=zeros(0,1);
for name=c.caseNames
    p=sc01b_case(name);
    assert(isequaln(study.cases.(name).parameters,p), ...
        'SC01B:CaseParameters','Stored parameters differ from frozen case %s.',name);
    tags=[compose("native_%g_ns",c.nativeSteps_s*1e9),compose("spice_%g_ns",c.spiceSteps_s*1e9)];
    steps=[c.nativeSteps_s,c.spiceSteps_s];
    labels=[compose("native_%g_to_",c.nativeSteps_s(1:end-1)*1e9)+compose("%gns",c.nativeSteps_s(end)*1e9), ...
        compose("spice_%g_to_",c.spiceSteps_s(1:end-1)*1e9)+compose("%gns",c.spiceSteps_s(end)*1e9), ...
        compose("native_to_original_spice_%gns",c.spiceSteps_s(end)*1e9)];
    if ismember(name,c.consistencyCases)
        tags=[tags,"native_tight_consistency","spice_tight_tolerance"];
        steps=[steps,c.nativeSteps_s(end),c.spiceSteps_s(end)];
        labels=[labels,"native_consistency_10x","spice_tolerances_10x"];
    end
    runKeys=[runKeys;reshape(name+"|"+tags,[],1)];
    expectedStep=[expectedStep;steps(:)];expectedStop=[expectedStop;repmat(p.simulation.stopTime_s,numel(tags),1)];
    comparisonKeys=[comparisonKeys;reshape(name+"|"+labels,[],1)];
    for engine=["native","spice"]
        engineKeys(end+1,1)=name+"|"+engine;
        expectedStart(end+1,1)=p.validation.startTime_s;engineStop(end+1,1)=p.simulation.stopTime_s;
        for pulse=1:numel(p.control.highOn_s)
            for kind=["high_on","high_off"]
                eventKeys(end+1,1)=name+"|"+engine+"|pulse_"+pulse+"_"+kind;
            end
        end
    end
end
runOrder=exactKeys(study.runs,["Case","Run"],runKeys,'runs');
exactKeys(study.comparisons,["Case","Comparison"],comparisonKeys,'comparisons');
metricOrder=exactKeys(study.metrics,["Case","Engine"],engineKeys,'metrics');
balanceOrder=exactKeys(study.balance,["Case","Engine"],engineKeys,'balance');
exactKeys(study.events,["Case","Engine","EventId"],eventKeys,'events');

signals=["switch_V","bus_V","highVgs_V","lowVgs_V","highVds_V","lowVds_V", ...
    "highCurrent_A","lowCurrent_A","highGateCurrent_A","lowGateCurrent_A","loadCurrent_A","feedCurrent_A"];
waveKeys=strings(0,1);wavePass=true;
for k=1:height(study.comparisons)
    s=study.comparisons(k,:);
    if s.ExecutionComplete
        waveKeys=[waveKeys;reshape(string(s.Case)+"|"+string(s.Comparison)+"|"+signals,[],1)];
    end
end
exactKeys(study.waveforms,["Case","Comparison","Signal"],waveKeys,'waveforms');
w=study.waveforms;
if height(w)>0
    limits=max(c.currentAbsoluteTolerance_A,c.relativeWaveformTolerance*w.ReferencePeakAbsolute);
    isVoltage=endsWith(string(w.Signal),"_V");
    limits(isVoltage)=max(c.voltageAbsoluteTolerance_V,c.relativeWaveformTolerance*w.ReferencePeakAbsolute(isVoltage));
    valid=isfinite(w.MaxAbsoluteDifference) & w.MaxAbsoluteDifference>=0 & ...
        isfinite(w.ReferencePeakAbsolute) & w.ReferencePeakAbsolute>=0 & isfinite(w.Limit) & w.Limit>0;
    consistent=valid & abs(w.Limit-limits)<=8*eps(max(1,limits));
    actual=consistent & w.MaxAbsoluteDifference<=limits;
    assert(all(logical(w.Pass)==actual),'SC01B:InconsistentEvidence','Waveform Pass does not match its values and frozen limit.');
    wavePass=all(actual);
end
for k=1:height(study.comparisons)
    s=study.comparisons(k,:);mask=string(w.Case)==string(s.Case) & string(w.Comparison)==string(s.Comparison);
    if s.ExecutionComplete
        assert(s.WaveformsPassed==all(w.Pass(mask)),'SC01B:InconsistentEvidence','Comparison disagrees with waveform rows.');
    end
end

r=study.runs(runOrder,:);
status.executionPassed=all(r.Completed & r.Warnings==0 & isfinite(r.Samples) & r.Samples>=2 & ...
    isfinite(r.StopTime_s) & abs(r.StopTime_s-expectedStop)<=1e-14 & ...
    isfinite(r.Step_s) & abs(r.Step_s-expectedStep)<=1e-20);
comparisonFields=["WaveformsPassed","InitialStatePassed","EventTimingPassed","CurrentTimingPassed", ...
    "EventClassificationMatched","AllEventsResolved","EnergyPassed","ExecutionComplete"];
actualComparison=all(study.comparisons{:,comparisonFields},2);
assert(all(logical(study.comparisons.Pass)==actualComparison),'SC01B:InconsistentEvidence','Composite comparison Pass contradicts its component gates.');
b=study.balance(balanceOrder,:);
balanceLimit=max(c.balanceAbsoluteTolerance_J,c.balanceRelativeTolerance*b.EnergyScale_J);
actualBalance=~b.WindowClipped & isfinite(b.Residual_J) & isfinite(b.EnergyScale_J) & b.EnergyScale_J>=0 & ...
    abs(b.Residual_J)<=balanceLimit & abs(b.WindowStart_s-expectedStart)<=1e-14 & abs(b.WindowEnd_s-engineStop)<=1e-14;
status.energyBalancePassed=all(actualBalance);
status.numericalCampaignPassed=status.executionPassed && all(actualComparison) && wavePass && status.energyBalancePassed;

m=study.metrics(metricOrder,:);
native=string(m.Engine)=="native";
% Zero simultaneous positive channel conduction is required above the
% existing numerical floor (max(1 mA, 0.1% of peak load current)). A gate
% midpoint or terminal-current proxy cannot satisfy this gate.
status.modeledChannelOverlapPassed=all(m.ChannelOverlapKnown(native) & ...
    isfinite(m.nativeChannelOverlap_s(native)) & m.nativeChannelOverlap_s(native)==0);
assert(all(ismember(["ChannelOverlapKnown","NativeChannelOverlap_s"],string(r.Properties.VariableNames))), ...
    'SC01B:CampaignShape','Every native run must include modeled channel-overlap evidence.');
nativeRuns=startsWith(string(r.Run),"native_");
status.modeledChannelOverlapPassed=status.modeledChannelOverlapPassed && ...
    all(r.ChannelOverlapKnown(nativeRuns) & isfinite(r.NativeChannelOverlap_s(nativeRuns)) & r.NativeChannelOverlap_s(nativeRuns)==0);
status.operatingPointsPassed=all(m.AllFinite & ~m.ValidationRecordClipped & ...
    abs(m.ValidationStart_s-expectedStart)<=1e-14 & abs(m.ValidationEnd_s-engineStop)<=1e-14 & ...
    m.DeviceVoltageLimitsPassed & m.GateVoltageLimitsPassed & ...
    m.UnresolvedEventCount==0 & m.VoltageRecrossingCount==0) && ...
    all(study.events.Resolved & ~study.events.Clipped & ~study.events.CounterpartGateClipped) && status.modeledChannelOverlapPassed;
status.switchingFailuresResolved=status.numericalCampaignPassed && status.operatingPointsPassed;
status.physicalSourceValidated=false;
end

function order=exactKeys(rows,fields,expected,label)
assert(istable(rows) && all(ismember(fields,string(rows.Properties.VariableNames))), ...
    'SC01B:CampaignShape','Missing %s key columns.',label);
keys=string(rows.(fields(1)));
for field=fields(2:end),keys=keys+"|"+string(rows.(field));end
assert(numel(unique(keys))==numel(keys) && isequal(sort(keys(:)),sort(expected(:))), ...
    'SC01B:CampaignShape','The %s rows do not contain the exact unique frozen keyset.',label);
[~,order]=ismember(expected(:),keys(:));
end
