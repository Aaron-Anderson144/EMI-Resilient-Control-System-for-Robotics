classdef TestCommunicationEdges < matlab.unittest.TestCase
    %TESTCOMMUNICATIONEDGES Exact schedules; no random-seed searches.
    methods (Test)
        function handDeclaredSchedulesMatchAllDiagnostics(testCase)
            cases = communication_edge_cases();
            for k = 1:numel(cases)
                c = cases(k);
                actual = schedule_timestamped_packets(c.transmitDelay_samples,c.packetDropped);
                testCase.verifyEqual(actual,c.expected,char(c.name));
            end
        end

        function arrivedPacketsAreAccountedForWithoutDoubleCounting(testCase)
            cases = communication_edge_cases();
            for k = 1:numel(cases)
                c = cases(k);
                actual = schedule_timestamped_packets(c.transmitDelay_samples,c.packetDropped);
                accepted = actual.acceptedSourceIndex(actual.sampleReceived);
                testCase.verifyTrue(all(accepted<=find(actual.sampleReceived)),char(c.name));
                testCase.verifyTrue(all(diff(accepted)>0),char(c.name));
                testCase.verifyEqual(nnz(actual.arrivalIndex),nnz(actual.sampleReceived)+ ...
                    sum(actual.collisionDiscardCount)+sum(actual.outOfOrderDiscardCount),char(c.name));
            end
            % Both arrivals in this forced stale collision must be counted
            % once, with the established loser/winner diagnostic semantics.
            stale = schedule_timestamped_packets(cases(3).transmitDelay_samples,cases(3).packetDropped);
            testCase.verifyEqual(stale.collisionDiscardCount(6),1);
            testCase.verifyEqual(stale.outOfOrderDiscardCount(6),1);
            testCase.verifyFalse(stale.sampleReceived(6));
            testCase.verifyEqual(stale.lastAcceptedSourceIndex(6:7),[5;5]);
        end

        function schedulerNormalizesRowsWithoutChangingInputsOrRandomState(testCase)
            delay = [0 3 0 0 0 0 0];
            dropped = logical([0 0 0 0 1 1 0]);
            originalDelay = delay; originalDropped = dropped; originalRng = rng;
            actual = schedule_timestamped_packets(delay,dropped);
            cases = communication_edge_cases();
            testCase.verifyEqual(actual,cases(2).expected);
            testCase.verifyEqual(delay,originalDelay);
            testCase.verifyEqual(dropped,originalDropped);
            testCase.verifyEqual(rng,originalRng);
        end

        function invalidDelaysCannotScheduleNoncausalOrFractionalArrivals(testCase)
            invalid = {[],[0;NaN],[0;Inf],[-1;0],[0;0.5],[0;1+1i], ...
                [0 1;2 3],"0 1",'01',true(2,1),flintmax};
            for k = 1:numel(invalid)
                delay = invalid{k};
                testCase.verifyError(@()schedule_timestamped_packets(delay,false(numel(delay),1)), ...
                    'EMIProject:InvalidPacketSchedule');
            end
        end

        function invalidDropMasksAreRejected(testCase)
            invalid = {[],false(3,1),[0;1],[false true;false true],"false"};
            for k = 1:numel(invalid)
                testCase.verifyError(@()schedule_timestamped_packets([0;1],invalid{k}), ...
                    'EMIProject:InvalidPacketSchedule');
            end
        end

        function productionProfilesExactlyPreserveFrozenSeededEvidence(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            frozen = load(fullfile(root,'results','phase2b_fault_study.mat'),'studyResults');
            for k = 1:numel(frozen.studyResults)
                original = frozen.studyResults{k};
                actual = communication_channel_profile(original.time_s,original.params,original.scenario);
                % Counter V1 changes populations explicitly; every historical
                % scheduling/measurement field must remain exactly unchanged.
                counters={'transmittedPacketCount','droppedPacketCount','acceptedPacketCount'};
                testCase.verifyEqual(rmfield(actual,[counters,{'packetSummary'}]), ...
                    rmfield(original.communication,counters),char(original.scenario.name));
                testCase.verifyEqual(actual.packetSummary.faultWindow.transmittedPacketCount, ...
                    original.communication.transmittedPacketCount);
                testCase.verifyEqual(actual.packetSummary.faultWindow.droppedPacketCount, ...
                    original.communication.droppedPacketCount);
                testCase.verifyEqual(actual.acceptedPacketCount,original.communication.acceptedPacketCount);
            end
        end

        function constructedLossWindowHoldsRealReceivedMeasurement(testCase)
            p = actuator_parameters();
            p.phase2b.communication.startTime_s = 0.500;
            p.phase2b.communication.stopTime_s = 0.504;
            p.phase2b.communication.packetLossProbability = 1;
            scenario = phase2b_scenario("packet_loss",p);
            actual = simulate_phase2b_actuator(p,scenario);
            expectedSource = (1:numel(actual.time_s))';
            expectedSource(501:504) = 500;
            testCase.verifyEqual(actual.communication.lastAcceptedSourceIndex,expectedSource);
            testCase.verifyEqual(actual.receivedMeasurement_rad(501:504), ...
                repmat(actual.sensorSideMeasurement_rad(500),4,1));
            testCase.verifyEqual(actual.communication.measurementAge_samples(501:505),[1;2;3;4;0]);
            testCase.verifyEqual(actual.receivedMeasurement_rad(505),actual.sensorSideMeasurement_rad(505));
            testCase.verifyFalse(any(actual.communication.sampleReceived(501:504)));
            testCase.verifyTrue(actual.communication.sampleReceived(505));
        end

        function productionScenarioIsValidatedAndUnchanged(testCase)
            p = actuator_parameters();
            scenario = phase2b_scenario("combined_phase2b",p);
            before = scenario; originalParams = p;
            t = (0:p.control.sampleTime_s:p.simulation.stopTime_s)';
            communication_channel_profile(t,p,scenario);
            testCase.verifyEqual(scenario,before);
            testCase.verifyEqual(p,originalParams);
            scenario.communication.jitterEnabled = NaN;
            testCase.verifyError(@()communication_channel_profile(t,p,scenario), ...
                'EMIProject:InvalidPhase2BScenario');
        end
    end
end
