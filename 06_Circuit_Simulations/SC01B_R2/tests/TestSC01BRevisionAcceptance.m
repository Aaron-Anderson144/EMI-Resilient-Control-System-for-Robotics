classdef TestSC01BRevisionAcceptance < matlab.unittest.TestCase
    % Synthetic complete manifests isolate final acceptance from simulation.
    methods (Test)
        function completeEvidencePassesNumericalAndModeledOperatingGates(testCase)
            [s,c]=campaign();a=sc01b_campaign_acceptance(s,c);
            testCase.verifyTrue(a.switchingFailuresResolved);
            testCase.verifyFalse(a.physicalSourceValidated);
        end
        function missingWaveformCannotHideBehindComparisonPass(testCase)
            [s,c]=campaign();s.waveforms(1,:)=[];
            testCase.verifyError(@()sc01b_campaign_acceptance(s,c),'SC01B:CampaignShape');
        end
        function duplicateRunCannotReplaceAnotherRequiredRun(testCase)
            [s,c]=campaign();s.runs(2,:)=s.runs(1,:);
            testCase.verifyError(@()sc01b_campaign_acceptance(s,c),'SC01B:CampaignShape');
        end
        function staleWaveformPassIsRejected(testCase)
            [s,c]=campaign();s.waveforms.MaxAbsoluteDifference(1)=2*s.waveforms.Limit(1);
            testCase.verifyError(@()sc01b_campaign_acceptance(s,c),'SC01B:InconsistentEvidence');
        end
        function nativeChannelOverlapFailsEvenWhenWaveformsAndEventsPass(testCase)
            [s,c]=campaign();s.metrics.nativeChannelOverlap_s(1)=1e-12;
            a=sc01b_campaign_acceptance(s,c);
            testCase.verifyTrue(a.numericalCampaignPassed);
            testCase.verifyFalse(a.modeledChannelOverlapPassed);
            testCase.verifyFalse(a.switchingFailuresResolved);
        end
        function unknownNativeChannelStateCannotPass(testCase)
            [s,c]=campaign();s.metrics.ChannelOverlapKnown(1)=false;
            a=sc01b_campaign_acceptance(s,c);testCase.verifyFalse(a.operatingPointsPassed);
        end
        function incompleteOrWarningBearingRunFails(testCase)
            [s,c]=campaign();s.runs.StopTime_s(1)=s.runs.StopTime_s(1)-1e-7;
            a=sc01b_campaign_acceptance(s,c);testCase.verifyFalse(a.executionPassed);
            [s,c]=campaign();s.runs.Warnings(1)=1;
            a=sc01b_campaign_acceptance(s,c);testCase.verifyFalse(a.numericalCampaignPassed);
        end
        function clippedBalanceFailsDespiteStaleStoredPass(testCase)
            [s,c]=campaign();s.balance.WindowClipped(1)=true;
            a=sc01b_campaign_acceptance(s,c);testCase.verifyFalse(a.energyBalancePassed);
        end
        function clippedEventFailsDespiteStaleResolvedFlag(testCase)
            [s,c]=campaign();s.events.Clipped(1)=true;
            a=sc01b_campaign_acceptance(s,c);testCase.verifyFalse(a.operatingPointsPassed);
        end
        function incompleteStrictAttemptRemainsAReportableFailure(testCase)
            [s,c]=campaign();row=find(s.runs.Run=="spice_tight_tolerance",1);
            name=s.runs.Case(row);s.runs.Completed(row)=false;s.runs.Samples(row)=0;s.runs.StopTime_s(row)=NaN;
            index=find(s.comparisons.Case==name & s.comparisons.Comparison=="spice_tolerances_10x");
            flags=["WaveformsPassed","InitialStatePassed","EventTimingPassed","CurrentTimingPassed", ...
                "EventClassificationMatched","AllEventsResolved","EnergyPassed","ExecutionComplete","Pass"];
            s.comparisons{index,flags}=false;
            s.waveforms(s.waveforms.Case==name & s.waveforms.Comparison=="spice_tolerances_10x",:)=[];
            a=sc01b_campaign_acceptance(s,c);testCase.verifyFalse(a.numericalCampaignPassed);
        end
        function refinementMatrixUsesDeclaredStepSizes(testCase)
            c=sc01b_criteria();c.nativeSteps_s=[0.25 0.125 0.0625]*1e-9;c.spiceSteps_s=[0.125 0.0625]*1e-9;
            [s,c]=campaign(c);a=sc01b_campaign_acceptance(s,c);
            testCase.verifyTrue(a.switchingFailuresResolved);
            s.runs.Run(1)="native_0.5_ns";
            testCase.verifyError(@()sc01b_campaign_acceptance(s,c),'SC01B:CampaignShape');
        end
        function channelOverlapInAnyRecordedNativeRefinementFails(testCase)
            [s,c]=campaign();native=startsWith(s.runs.Run,"native_");
            s.runs.ChannelOverlapKnown=native;s.runs.NativeChannelOverlap_s=NaN(height(s.runs),1);
            s.runs.NativeChannelOverlap_s(native)=0;s.runs.NativeChannelOverlap_s(find(native,1))=1e-12;
            a=sc01b_campaign_acceptance(s,c);testCase.verifyFalse(a.modeledChannelOverlapPassed);
        end
    end
end

function [s,c]=campaign(c)
if nargin==0,c=sc01b_criteria();end
s=struct('criteria',c,'cases',struct());runs={};comparisons={};waves={};metrics={};balance={};events={};
signals=["switch_V","bus_V","highVgs_V","lowVgs_V","highVds_V","lowVds_V", ...
    "highCurrent_A","lowCurrent_A","highGateCurrent_A","lowGateCurrent_A","loadCurrent_A","feedCurrent_A"];
for name=c.caseNames
    p=sc01b_case(name);s.cases.(name)=struct('parameters',p);
    tags=[compose("native_%g_ns",c.nativeSteps_s*1e9),compose("spice_%g_ns",c.spiceSteps_s*1e9)];
    steps=[c.nativeSteps_s,c.spiceSteps_s];
    labels=[compose("native_%g_to_",c.nativeSteps_s(1:end-1)*1e9)+compose("%gns",c.nativeSteps_s(end)*1e9), ...
        compose("spice_%g_to_",c.spiceSteps_s(1:end-1)*1e9)+compose("%gns",c.spiceSteps_s(end)*1e9), ...
        compose("native_to_original_spice_%gns",c.spiceSteps_s(end)*1e9)];
    if ismember(name,c.consistencyCases)
        tags=[tags,"native_tight_consistency","spice_tight_tolerance"];
        steps=[steps,c.nativeSteps_s(end),c.spiceSteps_s(end)];labels=[labels,"native_consistency_10x","spice_tolerances_10x"];
    end
    for k=1:numel(tags)
        isNative=startsWith(tags(k),"native_");overlap=NaN;if isNative,overlap=0;end
        runs{end+1}=struct('Case',name,'Run',tags(k),'Step_s',steps(k),'Completed',true,'Warnings',0, ...
            'Samples',100,'StopTime_s',p.simulation.stopTime_s,'ChannelOverlapKnown',isNative,'NativeChannelOverlap_s',overlap);
    end
    for label=labels
        comparisons{end+1}=struct('Case',name,'Comparison',label,'WaveformsPassed',true,'InitialStatePassed',true, ...
            'EventTimingPassed',true,'CurrentTimingPassed',true,'EventClassificationMatched',true, ...
            'AllEventsResolved',true,'EnergyPassed',true,'ExecutionComplete',true,'Pass',true);
        for signal=signals
            if endsWith(signal,"_V"),floor=c.voltageAbsoluteTolerance_V;else,floor=c.currentAbsoluteTolerance_A;end
            waves{end+1}=struct('Case',name,'Comparison',label,'Signal',signal,'MaxAbsoluteDifference',0, ...
                'ReferencePeakAbsolute',1,'Limit',max(floor,c.relativeWaveformTolerance),'Pass',true);
        end
    end
    for engine=["native","spice"]
        channel=NaN;if engine=="native",channel=0;end
        metrics{end+1}=struct('Case',name,'Engine',engine,'AllFinite',true,'ValidationRecordClipped',false, ...
            'ValidationStart_s',p.validation.startTime_s,'ValidationEnd_s',p.simulation.stopTime_s, ...
            'DeviceVoltageLimitsPassed',true,'GateVoltageLimitsPassed',true,'UnresolvedEventCount',0, ...
            'VoltageRecrossingCount',0,'ChannelOverlapKnown',engine=="native",'nativeChannelOverlap_s',channel);
        balance{end+1}=struct('Case',name,'Engine',engine,'WindowClipped',false,'Residual_J',0,'EnergyScale_J',1e-6, ...
            'WindowStart_s',p.validation.startTime_s,'WindowEnd_s',p.simulation.stopTime_s,'Pass',true);
        for pulse=1:numel(p.control.highOn_s)
            for kind=["high_on","high_off"]
                events{end+1}=struct('Case',name,'Engine',engine,'EventId',"pulse_"+pulse+"_"+kind, ...
                    'Resolved',true,'Clipped',false,'CounterpartGateClipped',false);
            end
        end
    end
end
s.runs=struct2table(vertcat(runs{:}));s.comparisons=struct2table(vertcat(comparisons{:}));
s.waveforms=struct2table(vertcat(waves{:}));s.metrics=struct2table(vertcat(metrics{:}));
s.balance=struct2table(vertcat(balance{:}));s.events=struct2table(vertcat(events{:}));
end
