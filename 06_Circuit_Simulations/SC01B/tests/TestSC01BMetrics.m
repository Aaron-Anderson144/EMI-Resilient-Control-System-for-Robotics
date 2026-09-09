classdef TestSC01BMetrics < matlab.unittest.TestCase
    %TESTSC01BMETRICS Analytic traces test event definitions and energy signs.
    methods (Test)
        function analyticRisingAndFallingEdgesResolve(testCase)
            [r,p,g]=fixture();[m,e]=sc01b_metrics(r,p);
            testCase.verifyEqual(m.EventCount,2);
            testCase.verifyEqual(m.UnresolvedEventCount,0);
            testCase.verifyEqual(m.UnresolvedCurrentTimingCount,0);
            testCase.verifyEqual(e.EdgeTime_s,[80;80]*1e-9,'AbsTol',1e-14);
            testCase.verifyEqual(e.SwitchT10_s(1),g.highOn_s+60e-9,'AbsTol',1e-14);
            testCase.verifyEqual(e.SwitchT90_s(1),g.highOn_s+140e-9,'AbsTol',1e-14);
            testCase.verifyEqual(e.SwitchT90_s(2),g.highOff_s+60e-9,'AbsTol',1e-14);
            testCase.verifyEqual(e.HighGateT50_s,[g.highOn_s;g.highOff_s]+60e-9,'AbsTol',1e-14);
            testCase.verifyEqual(e.HighCurrentT50_s,[g.highOn_s;g.highOff_s]+80e-9,'AbsTol',1e-14);
            testCase.verifyEqual(e.Ipre_A,[3;3]);
            testCase.verifyEqual(e.GateMidpointDeadTime_s,e.DriverCommandDeadTime_s,'AbsTol',1e-14);
            testCase.verifyFalse(m.ChannelOverlapKnown);
            testCase.verifyFalse(m.DissipatedEnergyKnown);
        end

        function thresholdsFollowActualBusRatherThanNominalParameter(testCase)
            [r,p,g]=fixture();
            r.bus_V(:)=18;r.switch_V=r.switch_V*18/24;
            [~,e]=sc01b_metrics(r,p);
            testCase.verifyTrue(all(e.VoltageResolved));
            testCase.verifyEqual(e.SwitchT90_s(1),g.highOn_s+140e-9,'AbsTol',1e-14);
            testCase.verifyEqual(e.EdgeTime_s,[80;80]*1e-9,'AbsTol',1e-14);
        end

        function endpointChecksRejectAnIncompleteSwing(testCase)
            [r,p]=fixture();r.switch_V=r.switch_V*0.8;
            [m,e]=sc01b_metrics(r,p);
            testCase.verifyEqual(m.UnresolvedEventCount,2);
            testCase.verifyFalse(any(e.VoltageResolved));
            testCase.verifyTrue(isnan(e.SwitchT90_s(1)));
        end

        function signedTerminalEnergyUsesExactProductIntegration(testCase)
            [r,p]=fixture();
            r.highVds_V=r.time_s*1e6;r.highCurrent_A=-r.time_s*1e6;
            r.highGateCurrent_A(:)=0;
            [~,e]=sc01b_metrics(r,p);
            a=e.WindowStart_s(1);b=e.WindowEnd_s(1);
            expected=-(b^3-a^3)/3*1e12;
            testCase.verifyEqual(e.HighDrainTerminalEnergy_J(1),expected,'AbsTol',1e-18);
            testCase.verifyEqual(e.HighTerminalEnergy_J(1),expected,'AbsTol',1e-18);
            testCase.verifyLessThan(e.HighTerminalEnergy_J(1),0);
        end

        function gateTerminalEnergyIsIncludedSeparately(testCase)
            [r,p]=fixture();r.highCurrent_A(:)=0;r.highGateCurrent_A(:)=0.1;
            [~,e]=sc01b_metrics(r,p);
            % 80 ns gate ramp plus 400 ns plateau inside the rising window.
            expected=0.1*(0.5*80e-9*12+400e-9*12);
            testCase.verifyEqual(e.HighDrainTerminalEnergy_J(1),0);
            testCase.verifyEqual(e.HighGateTerminalEnergy_J(1),expected,'AbsTol',1e-18);
            testCase.verifyEqual(e.HighTerminalEnergy_J(1),expected,'AbsTol',1e-18);
        end

        function preambleIsExcludedFromExtrema(testCase)
            [r,p]=fixture();r.highVds_V(r.time_s<0.5e-6)=100;
            r.loadCurrent_A(r.time_s<0.5e-6)=9;
            [m,e]=sc01b_metrics(r,p);
            testCase.verifyEqual(m.InitialLoadCurrent_A,9);
            testCase.verifyEqual(m.ValidationInitialLoadCurrent_A,3);
            testCase.verifyEqual(m.PeakHighVds_V,24);
            testCase.verifyTrue(m.DeviceVoltageLimitsPassed);
            testCase.verifyEqual(e.Ipre_A,[3;3]);
        end

        function clippingIsReportedInsteadOfPassing(testCase)
            [r,p,g]=fixture();r=subset(r,r.time_s<=g.highOff_s+100e-9);
            [m,e]=sc01b_metrics(r,p);
            testCase.verifyGreaterThanOrEqual(m.ClippedEventCount,1);
            testCase.verifyFalse(e.Resolved(2));
            testCase.verifyEqual(e.Status(2),"clipped");
        end

        function zeroLoadCurrentTimingIsExplicitlyUnavailable(testCase)
            [r,p]=fixture();r.loadCurrent_A(:)=0;r.highCurrent_A(:)=0;
            [m,e]=sc01b_metrics(r,p);
            testCase.verifyEqual(m.UnavailableCurrentTimingCount,2);
            testCase.verifyEqual(m.UnresolvedCurrentTimingCount,0);
            testCase.verifyTrue(all(isnan(e.HighCurrentT50_s)));
            testCase.verifyTrue(all(e.VoltageResolved));
        end

        function reverseCurrentKeepsDirectionalCommutationTiming(testCase)
            [r,p,g]=fixture();r.loadCurrent_A=-r.loadCurrent_A;r.highCurrent_A=-r.highCurrent_A;
            [~,e]=sc01b_metrics(r,p);
            testCase.verifyTrue(all(e.CurrentResolved));
            testCase.verifyEqual(e.Ipre_A,[-3;-3]);
            testCase.verifyEqual(e.HighCurrentT50_s(1),g.highOn_s+80e-9,'AbsTol',1e-14);
        end

        function terminalCoincidenceIsNotCalledChannelOverlap(testCase)
            [r,p]=fixture();r.highCurrent_A(:)=0.5;r.lowCurrent_A(:)=0.5;
            r.highVgs_V(:)=0;r.lowVgs_V(:)=0;
            [m,~]=sc01b_metrics(r,p);
            testCase.verifyEqual(m.ForwardTerminalCurrentCoincidence_s, ...
                r.time_s(end)-p.validation.startTime_s,'AbsTol',1e-14);
            testCase.verifyEqual(m.GateMidpointOverlap_s,0);
            testCase.verifyFalse(m.ChannelOverlapKnown);
        end

        function ratingsUsePostPreambleLocalTerminalVoltages(testCase)
            [r,p]=fixture();r.highVds_V(r.time_s>2e-6 & r.time_s<2.1e-6)=45;
            r.lowVgs_V(r.time_s>3e-6 & r.time_s<3.1e-6)=-18;
            [m,~]=sc01b_metrics(r,p);
            testCase.verifyEqual(m.HighVdsOverRating_V,5);
            testCase.verifyEqual(m.LowGateOverRating_V,2);
            testCase.verifyFalse(m.DeviceVoltageLimitsPassed);
            testCase.verifyFalse(m.GateVoltageLimitsPassed);
        end

        function requiredSignalsAndTimeAreValidated(testCase)
            [r,p]=fixture();bad=rmfield(r,'highGateCurrent_A');
            testCase.verifyError(@() sc01b_metrics(bad,p),'SC01B:MissingSignal');
            bad=r;bad.time_s(3)=bad.time_s(2);
            testCase.verifyError(@() sc01b_metrics(bad,p),'SC01B:InvalidTrace');
            bad=r;bad.lowCurrent_A(2)=NaN;
            testCase.verifyError(@() sc01b_metrics(bad,p),'SC01B:InvalidTrace');
            bad=r;bad.bus_V(2)=0;
            testCase.verifyError(@() sc01b_metrics(bad,p),'SC01B:InvalidBus');
        end

        function identicalResolvedTracesPassTheCompositeComparison(testCase)
            [r,p]=fixture();c=sc01b_criteria();
            [waves,summary]=sc01b_compare(r,r,p,c,"analytic_identical");
            testCase.verifyTrue(all(waves.Pass));
            testCase.verifyTrue(summary.InitialStatePassed);
            testCase.verifyTrue(summary.EventTimingPassed);
            testCase.verifyTrue(summary.CurrentTimingPassed);
            testCase.verifyTrue(summary.AllEventsResolved);
            testCase.verifyTrue(summary.Pass);
            testCase.verifyEqual(summary.MaxEventTimeDifference_s,0);
        end

        function delayedTraceFailsTimingDespiteGenerousWaveformAllowance(testCase)
            [reference,p]=fixture();candidate=reference;c=sc01b_criteria();
            delay=20e-9;query=max(reference.time_s-delay,reference.time_s(1));
            names=fieldnames(reference);
            for k=1:numel(names)
                if ~strcmp(names{k},'time_s')
                    candidate.(names{k})=interp1(reference.time_s,reference.(names{k}),query,'linear');
                end
            end
            % Keep the command schedule fixed. Broad waveform/energy bounds
            % isolate the event-timing gate; no alignment removes the delay.
            c.relativeWaveformTolerance=10;c.voltageAbsoluteTolerance_V=100;
            c.currentAbsoluteTolerance_A=100;c.energyAbsoluteTolerance_J=1;
            [~,summary]=sc01b_compare(candidate,reference,p,c,"analytic_delayed");
            testCase.verifyTrue(summary.WaveformsPassed);
            testCase.verifyTrue(summary.EnergyPassed);
            testCase.verifyTrue(summary.InitialStatePassed);
            testCase.verifyTrue(summary.AllEventsResolved);
            testCase.verifyGreaterThan(summary.MaxEventTimeDifference_s,c.eventTimeTolerance_s);
            testCase.verifyFalse(summary.EventTimingPassed);
            testCase.verifyFalse(summary.Pass);
        end

        function identicalUnresolvedTracesStillFailAndClassificationChangesAreDetected(testCase)
            [valid,p]=fixture();unresolved=valid;unresolved.switch_V=0.8*valid.switch_V;
            c=sc01b_criteria();
            [~,same]=sc01b_compare(unresolved,unresolved,p,c,"analytic_same_unresolved");
            testCase.verifyTrue(same.WaveformsPassed);
            testCase.verifyTrue(same.EventClassificationMatched);
            testCase.verifyFalse(same.AllEventsResolved);
            testCase.verifyFalse(same.Pass);
            [~,changed]=sc01b_compare(unresolved,valid,p,c,"analytic_classification_change");
            testCase.verifyFalse(changed.EventClassificationMatched);
            testCase.verifyFalse(changed.AllEventsResolved);
            testCase.verifyFalse(changed.Pass);
        end
    end
end

function [r,p,g]=fixture()
p=sc01b_parameters();p.control.highOn_s=2e-6;p.control.highOff_s=4e-6;
p.control.initialHigh=false;
p.simulation.stopTime_s=6e-6;g=sc01b_gate_signals(p);
commands=[g.highOn_s g.highOff_s g.lowOn_s g.lowOff_s];
knots=commands(:)+[0 20 30 50 100 130 150]*1e-9;
t=unique([(0:10e-9:6e-6).';knots(:)]);
highSwitch=ramp(t,g.highOn_s+50e-9,100e-9)-ramp(t,g.highOff_s+50e-9,100e-9);
highGate=ramp(t,g.highOn_s+20e-9,80e-9)-ramp(t,g.highOff_s+20e-9,80e-9);
lowGate=1-ramp(t,g.lowOff_s+20e-9,80e-9)+ramp(t,g.lowOn_s+20e-9,80e-9);
highCurrent=3*(ramp(t,g.highOn_s+30e-9,100e-9)-ramp(t,g.highOff_s+30e-9,100e-9));
r=struct('time_s',t,'switch_V',24*highSwitch,'bus_V',24*ones(size(t)), ...
    'highVgs_V',12*highGate,'lowVgs_V',12*lowGate, ...
    'highVds_V',24*(1-highSwitch),'lowVds_V',24*highSwitch, ...
    'highCurrent_A',highCurrent,'lowCurrent_A',highCurrent-3, ...
    'highGateCurrent_A',zeros(size(t)),'lowGateCurrent_A',zeros(size(t)), ...
    'loadCurrent_A',3*ones(size(t)),'feedCurrent_A',highCurrent);
end

function y=ramp(t,start,width)
y=min(1,max(0,(t-start)/width));
end

function r=subset(r,mask)
names=fieldnames(r);for k=1:numel(names),r.(names{k})=r.(names{k})(mask);end
end
