classdef TestPacketProfileSummary < matlab.unittest.TestCase
    % Source-population accounting after every final scheduling operation.
    methods (Test)
        function cleanRecordHasFullTransmissionsAndEmptyFaultWindow(testCase)
            p=actuator_parameters();t=(0:1500)'*.001;
            c=communication_channel_profile(t,p,phase2b_scenario("none",p));
            testCase.verifyEqual(c.packetSummary.schemaVersion,"PACKET-SUMMARY-V1");
            testCase.verifyEqual([c.transmittedPacketCount,c.droppedPacketCount,c.acceptedPacketCount],[1501,0,1501]);
            testCase.verifyEqual(c.packetSummary.record,expected(1501,0,1501,1501,0,0));
            testCase.verifyEqual(c.packetSummary.faultWindow,expected(0,0,0,0,0,0));
            testCase.verifyFalse(any(c.packetSummary.faultWindowSourceActive));
        end

        function ordinarySeededLossPreservesHistoricalRateAndRandomState(testCase)
            p=actuator_parameters();before=rng;t=(0:1500)'*.001;
            c=communication_channel_profile(t,p,phase2b_scenario("packet_loss",p));
            testCase.verifyEqual(rng,before);
            % Frozen nominal seed: 91 losses from 400 enabled opportunities.
            testCase.verifyEqual(c.packetSummary.record,expected(1501,91,1410,1410,0,0));
            testCase.verifyEqual(c.packetSummary.faultWindow,expected(400,91,309,309,0,0));
            rate=c.packetSummary.faultWindow.droppedPacketCount/c.packetSummary.faultWindow.transmittedPacketCount;
            testCase.verifyEqual(rate,91/400);
            testCase.verifyEqual(c.packetSummary.faultWindowSourceActive,t>=.7&t<1.1);
        end

        function forcedGapRefreshesPreviouslyStaleCounters(testCase)
            p=actuator_parameters();s=phase3_scenario("forced_summary",p);
            s.packetDropStartTime_s=.4;s.packetDropStopTime_s=.5;
            f=phase3_fault_profiles(p,s);c=f.communication;
            testCase.verifyEqual([c.transmittedPacketCount,c.droppedPacketCount,c.acceptedPacketCount],[1501,100,1401]);
            testCase.verifyEqual(c.packetSummary.record,expected(1501,100,1401,1401,0,0));
            testCase.verifyEqual(c.packetSummary.faultWindow,expected(100,100,0,0,0,0));
            testCase.verifyEqual(c.packetSummary.faultWindowSourceActive,f.time_s>=.4&f.time_s<.5);
            testCase.verifyEqual(c.lastAcceptedSourceIndex(401:500),400*ones(100,1));
            testCase.verifyEqual(c.measurementAge_samples(401:501),[1:100,0]');
            testCase.verifyEqual(c.acceptedSourceIndex(501),501);
        end

        function overlappingLossWindowsUseUnionWithoutDoubleCounting(testCase)
            p=actuator_parameters();p.phase2b.communication.startTime_s=.45;
            p.phase2b.communication.stopTime_s=.55;p.phase2b.communication.packetLossProbability=1;
            s=phase3_scenario("overlapping_summary",p);
            s.phase2b=phase2b_scenario("packet_loss",p);
            s.packetDropStartTime_s=.4;s.packetDropStopTime_s=.5;
            f=phase3_fault_profiles(p,s);c=f.communication;
            testCase.verifyEqual(c.packetSummary.record,expected(1501,150,1351,1351,0,0));
            testCase.verifyEqual(c.packetSummary.faultWindow,expected(150,150,0,0,0,0));
            testCase.verifyEqual(c.packetDropped,f.time_s>=.4&f.time_s<.55);
            testCase.verifyEqual(c.packetSummary.faultWindowSourceActive,c.packetDropped);
            % Existing declared-window field remains the original source mask.
            testCase.verifyEqual(c.configuredWindowActive,f.time_s>=.45&f.time_s<.55);
        end

        function delayedAcceptanceBelongsToSourceWindowNotReceptionWindow(testCase)
            c=fixture([0;1;0;0;0;0],logical([0;0;1;0;0;0]));
            mask=false(6,1);mask(2)=true;
            original=c;summary=packet_profile_summary(c,mask);
            testCase.verifyEqual(summary.faultWindow,expected(1,0,1,1,0,0));
            testCase.verifyFalse(c.sampleReceived(2));
            testCase.verifyEqual(c.acceptedSourceIndex(3),2);
            testCase.verifyEqual(c,original);
        end

        function droppedDiscardedAndBeyondRecordPacketsHaveDistinctOutcomes(testCase)
            c=fixture([0;4;0;0;0;0;2],logical([0;0;0;0;1;0;0]));
            mask=logical([0;1;0;0;1;0;1]);
            summary=packet_profile_summary(c,mask);
            % Source 2 loses its arrival collision to 6; 5 drops; 7 is pending.
            testCase.verifyEqual(c.acceptedSourceIndex(c.sampleReceived),[1;3;4;6]);
            testCase.verifyEqual(summary.record,expected(7,1,5,4,1,1));
            testCase.verifyEqual(summary.faultWindow,expected(3,1,1,0,1,1));
            for name={"record","faultWindow"}
                r=summary.(name{1});
                testCase.verifyEqual(r.transmittedPacketCount,r.droppedPacketCount+ ...
                    r.acceptedPacketCount+r.discardedAfterArrivalPacketCount+r.pendingBeyondRecordPacketCount);
            end
        end

        function malformedPopulationsAndNoncausalEvidenceAreRejected(testCase)
            c=fixture(zeros(4,1),false(4,1));id='EMIProject:InvalidPacketSummary';
            testCase.verifyError(@()packet_profile_summary(c,true(3,1)),id);
            testCase.verifyError(@()packet_profile_summary(c,ones(4,1)),id);
            bad=c;bad.arrivalIndex(4)=0;
            testCase.verifyError(@()packet_profile_summary(bad,true(4,1)),id);
            bad=c;bad.acceptedSourceIndex(1)=2;
            testCase.verifyError(@()packet_profile_summary(bad,true(4,1)),id);
            bad=c;bad.packetDropped(1)=true;
            testCase.verifyError(@()packet_profile_summary(bad,true(4,1)),id);
        end

        function metadataCannotAffectObserverOrControl(testCase)
            p=actuator_parameters();s=phase3_scenario("metadata_is_offline",p);
            s.packetDropStartTime_s=.4;s.packetDropStopTime_s=.5;
            cfg=phase3_configuration(p);f=phase3_fault_profiles(p,s);changed=f;
            changed.communication.packetSummary=struct('offlineOnly',true);
            changed.communication.transmittedPacketCount=-1;
            changed.communication.droppedPacketCount=Inf;
            changed.communication.acceptedPacketCount=NaN;
            actual=simulate_phase3_actuator(p,s,true,cfg,f);
            altered=simulate_phase3_actuator(p,s,true,cfg,changed);
            testCase.verifyEqual(altered.state,actual.state);
            testCase.verifyEqual(altered.loopValues,actual.loopValues);
            testCase.verifyEqual(altered.timeSeries,actual.timeSeries);
        end
    end
end

function c=fixture(delay,dropped)
c=schedule_timestamped_packets(delay,dropped);
c.transmitDelay_samples=delay;c.packetDropped=dropped;
end

function r=expected(transmitted,dropped,arrived,accepted,discarded,pending)
r=struct('transmittedPacketCount',transmitted,'droppedPacketCount',dropped, ...
    'arrivedPacketCount',arrived,'acceptedPacketCount',accepted, ...
    'discardedAfterArrivalPacketCount',discarded,'pendingBeyondRecordPacketCount',pending);
end
