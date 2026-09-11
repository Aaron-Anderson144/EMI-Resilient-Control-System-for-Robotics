classdef TestPhase3ReacquisitionIntegration < matlab.unittest.TestCase
    % Numerical integration of an explicitly supplied independent sensor.
    % Synthetic position measurements are the only plant-dependent inputs to
    % reacquisition; these tests do not establish physical reference quality.
    methods (Test)
        function independentPositionReferenceRecoversRecordedDropout(testCase)
            [p,s,cfg,f] = dropoutFixture();
            result = simulate_phase3_actuator(p,s,true,cfg,f);
            t = result.timeSeries;
            commit = sampleAt(t.time_s,1.5);
            reset = sampleAt(t.time_s,2.0);
            testCase.verifyEqual(find(t.reacquisitionCommitted),commit);
            testCase.verifyEqual(t.mode(commit-1:reset-1), ...
                4*ones(reset-commit+1,1));
            testCase.verifyEqual(t.command_V(commit:reset-1), ...
                zeros(reset-commit,1));
            testCase.verifyFalse(logical(t.credibleFresh(commit)));
            testCase.verifyFalse(logical(t.estimateUsable(commit)));
            testCase.verifyTrue(logical(t.measurementAccepted(commit+1)));
            testCase.verifyTrue(logical(t.credibleFresh(commit+1)));
            testCase.verifyEqual(t.mode(reset),3);
            testCase.verifyEqual(t.mode(end),0);
            testCase.verifyEqual(t.transitionReason(reset),"qualified_reset");
            testCase.verifyLessThan(abs(t.estimatedPosition_rad(commit)- ...
                t.position_rad(commit)),1e-8);
        end

        function coincidentResetCannotReleaseAndIsNotRemembered(testCase)
            [p,s,cfg,f] = dropoutFixture();
            commit = sampleAt(f.time_s,1.5);
            f.resetRequest(:) = false;
            f.resetRequest(commit) = true;
            result = simulate_phase3_actuator(p,s,true,cfg,f);
            t = result.timeSeries;
            testCase.verifyTrue(logical(t.reacquisitionCommitted(commit)));
            testCase.verifyEqual(t.mode(commit:end), ...
                4*ones(height(t)-commit+1,1));
            testCase.verifyEqual(t.command_V(commit:end), ...
                zeros(height(t)-commit+1,1));
            testCase.verifyTrue(all(t.credibleFresh(commit+1:end)==1));
            testCase.verifyFalse(any(t.transitionReason=="qualified_reset"));
        end

        function primaryDwellAndRecoveryDwellHaveSeparateExactBoundaries(testCase)
            [p,s,cfg,f] = dropoutFixture();
            commit = sampleAt(f.time_s,1.5);
            % Fifty primary observations span only 49 ms. The fifty-first
            % observation may release the latch with a current reset.
            early = commit+50;
            release = commit+51;
            normal = release+50;
            f.resetRequest(:) = false;
            f.resetRequest([commit,early,release]) = true;
            result = simulate_phase3_actuator(p,s,true,cfg,f);
            t = result.timeSeries;
            testCase.verifyTrue(logical(t.reacquisitionCommitted(commit)));
            testCase.verifyEqual(t.credibleFresh(commit),0);
            testCase.verifyEqual(t.credibleFresh(commit+1:release),ones(51,1));
            testCase.verifyEqual(t.mode(early),4);
            testCase.verifyEqual(t.command_V(early),0);
            testCase.verifyEqual(t.mode(release:normal-1),3*ones(50,1));
            testCase.verifyEqual(t.mode(normal),0);
            testCase.verifyEqual(t.transitionReason(release),"qualified_reset");
            testCase.verifyEqual(t.transitionReason(normal),"credible_dwell");
        end

        function referenceObservationsWithoutRequestCannotReanchor(testCase)
            [p,s,cfg,f] = dropoutFixture();
            f.independentReference.request(:) = false;
            result = simulate_phase3_actuator(p,s,true,cfg,f);
            t = result.timeSeries;
            testCase.verifyFalse(any(t.reacquisitionCommitted));
            testCase.verifyEqual(t.mode(end),4);
            testCase.verifyFalse(any(t.transitionReason=="qualified_reset"));
        end

        function requestWithoutReceivedReferenceCannotReanchor(testCase)
            [p,s,cfg,f] = dropoutFixture();
            f.independentReference.sampleReceived(:) = false;
            result = simulate_phase3_actuator(p,s,true,cfg,f);
            t = result.timeSeries;
            testCase.verifyTrue(any(t.reacquisitionRequest));
            testCase.verifyFalse(any(t.reacquisitionCommitted));
            testCase.verifyEqual(t.mode(end),4);
            testCase.verifyFalse(any(t.transitionReason=="qualified_reset"));
        end

        function referenceRequestDuringNormalControlCannotCommit(testCase)
            [p,~,cfg,~] = dropoutFixture();
            s = phase3_scenario("clean_reference_request",p);
            f = phase3_fault_profiles(p,s);
            f.independentReference = referenceStream(f.time_s,1.2,1.6,1.5);
            result = simulate_phase3_actuator(p,s,true,cfg,f);
            t = result.timeSeries;
            testCase.verifyEqual(t.mode,zeros(height(t),1));
            testCase.verifyTrue(any(t.referenceReceived));
            testCase.verifyTrue(any(t.reacquisitionRequest));
            testCase.verifyFalse(any(t.reacquisitionCommitted));
        end

        function continuedPrimaryBiasBlocksResetAfterIndependentReanchor(testCase)
            [p,s,cfg,~] = dropoutFixture();
            s.biasStartTime_s = 1.0;
            s.biasStopTime_s = p.simulation.stopTime_s+1;
            s.bias_rad = deg2rad(5);
            f = phase3_fault_profiles(p,s);
            f.independentReference = referenceStream(f.time_s,1.2,1.6,1.5);
            result = simulate_phase3_actuator(p,s,true,cfg,f);
            t = result.timeSeries;
            commit = sampleAt(t.time_s,1.5);
            testCase.verifyTrue(logical(t.reacquisitionCommitted(commit)));
            testCase.verifyEqual(t.measurementAccepted(commit+1:end), ...
                zeros(height(t)-commit,1));
            testCase.verifyEqual(t.credibleFresh(commit+1:end), ...
                zeros(height(t)-commit,1));
            testCase.verifyEqual(t.mode(commit:end), ...
                4*ones(height(t)-commit+1,1));
            testCase.verifyEqual(t.command_V(commit:end), ...
                zeros(height(t)-commit+1,1));
            testCase.verifyFalse(any(t.transitionReason=="qualified_reset"));
        end

        function noReferenceAndDisabledFeaturePreserveOriginalControlChannels(testCase)
            [p,s,cfg,f] = dropoutFixture();
            absent = rmfield(f,'independentReference');
            disabled = cfg;
            disabled.reacquisitionEnabled = false;
            historical = simulate_phase3_actuator(p,s,true,disabled,absent);
            enabledWithoutSensor = simulate_phase3_actuator(p,s,true,cfg,absent);
            disabledWithSensor = simulate_phase3_actuator(p,s,true,disabled,f);
            for result = {enabledWithoutSensor,disabledWithSensor}
                testCase.verifyEqual(result{1}.state,historical.state);
                testCase.verifyEqual(result{1}.loopValues(:,1:20), ...
                    historical.loopValues(:,1:20));
                testCase.verifyEqual(result{1}.timeSeries.gateReason, ...
                    historical.timeSeries.gateReason);
                testCase.verifyEqual(result{1}.timeSeries.transitionReason, ...
                    historical.timeSeries.transitionReason);
                testCase.verifyFalse(any(result{1}.timeSeries.reacquisitionCommitted));
            end
        end

        function mismatchedReferenceClockOrModelIsRejectedAtInitialization(testCase)
            [p,s,cfg,f] = dropoutFixture();
            other = p;
            other.control.sampleTime_s = .002;
            bad = cfg;
            bad.reacquisition = phase3_reacquisition_configuration( ...
                phase3_observer_configuration(other));
            testCase.verifyError(@()simulate_phase3_actuator(p,s,true,bad,f), ...
                'EMIProject:Phase3SampleTime');
            other = p;
            other.electrical.resistance_Ohm = 1.01*p.electrical.resistance_Ohm;
            bad.reacquisition = phase3_reacquisition_configuration( ...
                phase3_observer_configuration(other));
            testCase.verifyError(@()simulate_phase3_actuator(p,s,true,bad,f), ...
                'EMIProject:ReacquisitionModelMismatch');
        end

        function integerReferenceErrorsAreNormalizedBeforeSensorArithmetic(testCase)
            [p,s,cfg,f] = dropoutFixture();
            floating = simulate_phase3_actuator(p,s,true,cfg,f);
            f.independentReference.error_rad = int16(f.independentReference.error_rad);
            f.independentReference.sourceIndex = uint32(f.independentReference.sourceIndex);
            integer = simulate_phase3_actuator(p,s,true,cfg,f);
            testCase.verifyTrue(any(floating.timeSeries.reacquisitionCommitted));
            testCase.verifyEqual(floating.state,integer.state);
            testCase.verifyEqual(floating.loopValues,integer.loopValues);
            testCase.verifyEqual(floating.timeSeries.reacquisitionReason, ...
                integer.timeSeries.reacquisitionReason);
        end

        function malformedReferenceRecordsAreRejectedBeforeSimulation(testCase)
            [p,s,cfg,f] = dropoutFixture();
            short = f.independentReference;
            short.sourceIndex(end) = [];
            nonfinite = f.independentReference;
            nonfinite.error_rad(sampleAt(f.time_s,1.5)) = NaN;
            invalidRequest = f.independentReference;
            invalidRequest.request = double(invalidRequest.request);
            for reference = {short,nonfinite,invalidRequest}
                bad = f;
                bad.independentReference = reference{1};
                testCase.verifyError(@()simulate_phase3_actuator(p,s,true,cfg,bad), ...
                    'EMIProject:InvalidReferenceProfile');
            end
        end

        function integerFixtureOptionsCannotEraseNoiseOrChangeTimestamps(testCase)
            [~,~,~,f] = dropoutFixture();
            options = struct('bias_rad',0,'noiseAmplitude_rad',deg2rad(.002), ...
                'noiseFrequency_Hz',37,'timestampOffset_samples',-1, ...
                'requestTime_s',Inf);
            floating = phase3_reference_profile(f.time_s,options);
            options.bias_rad = int16(0);
            options.noiseFrequency_Hz = uint8(37);
            options.timestampOffset_samples = int16(-1);
            integer = phase3_reference_profile(f.time_s,options);
            testCase.verifyGreaterThan(max(abs(floating.error_rad)),deg2rad(.001));
            testCase.verifyEqual(integer.error_rad,floating.error_rad);
            testCase.verifyEqual(integer.sourceIndex,floating.sourceIndex);
            testCase.verifyFalse(any(integer.request));
        end

        function offlineTruthAndScenarioLabelsDoNotChangeRecovery(testCase)
            [p,s,cfg,f] = dropoutFixture();
            first = simulate_phase3_actuator(p,s,true,cfg,f);
            f.sensorFaultAtSource = ~f.sensorFaultAtSource;
            f.sourceFault = ~f.sourceFault;
            f.receiverFault = ~f.receiverFault;
            s.name = "arbitrary scoring label";
            s.expectation = "unobservable";
            second = simulate_phase3_actuator(p,s,true,cfg,f);
            testCase.verifyTrue(any(first.timeSeries.reacquisitionCommitted));
            testCase.verifyEqual(first.state,second.state);
            testCase.verifyEqual(first.loopValues,second.loopValues);
            testCase.verifyEqual(first.timeSeries.reacquisitionReason, ...
                second.timeSeries.reacquisitionReason);
        end

        function unmeasuredPlantVelocityAndCurrentCannotInfluenceRecovery(testCase)
            p = actuator_parameters();
            s = phase3_scenario("measurement_boundary",p);
            s.referenceValues_rad(:) = 0;
            cfg = phase3_configuration(p);
            cfg.reacquisitionEnabled = true;
            f = phase3_fault_profiles(p,s);
            f.independentReference = referenceStream(f.time_s,0,.15,.1);
            run = struct('params',p,'scenario',s,'protectionEnabled',true, ...
                'configuration',cfg,'profiles',f);
            first = phase3_loop_initialize(run);
            first.supervisor.mode = 4;
            first.observer.estimatedState = [deg2rad(2);0;0];
            second = first;
            % Keep the valid full fixture but inspect only the 200 ms needed
            % to exercise its independent-reference commit and aftermath.
            samples = sampleAt(f.time_s,.2);
            committed = false(samples,1);
            for k = 1:samples
                [first,a] = phase3_loop_step(first,[0;0;0]);
                [second,b] = phase3_loop_step(second,[0;1e6;-1e6]);
                testCase.verifyEqual(phase3_logged_values(a),phase3_logged_values(b));
                testCase.verifyEqual(a.reacquisitionReason,b.reacquisitionReason);
                committed(k) = a.reacquisitionCommitted;
            end
            testCase.verifyEqual(find(committed),sampleAt(f.time_s,.1));
            testCase.verifyEqual(first.observer,second.observer);
        end

        function loadedStopReconstructsMotionInsteadOfAssumingZeroState(testCase)
            p = actuator_parameters();
            p.simulation.stopTime_s = 3;
            s = phase3_scenario("loaded_reference_reconstruction",p);
            s.phase2b = phase2b_scenario("supply_interruption",p);
            s.loadTorque_Nm = .01;
            s.assumedLoadTorque_Nm = .01;
            cfg = phase3_configuration(p);
            cfg.reacquisitionEnabled = true;
            f = phase3_fault_profiles(p,s);
            f.independentReference = referenceStream(f.time_s,1.2,1.6,1.5);
            result = simulate_phase3_actuator(p,s,true,cfg,f);
            t = result.timeSeries;
            commit = sampleAt(t.time_s,1.5);
            testCase.verifyTrue(logical(t.reacquisitionCommitted(commit)));
            testCase.verifyEqual(t.mode(commit),4);
            testCase.verifyEqual(t.command_V(commit),0);
            testCase.verifyGreaterThan(abs(t.velocity_rad_s(commit)),.01);
            estimate = [t.estimatedPosition_rad(commit), ...
                t.estimatedVelocity_rad_s(commit),t.estimatedCurrent_A(commit)];
            testCase.verifyEqual(estimate,result.state(commit,:),'AbsTol',1e-7);
        end
    end
end

function [p,s,cfg,f] = dropoutFixture()
p = actuator_parameters();
p.simulation.stopTime_s = 3;
s = phase3_scenario("encoder_dropout_reacquisition",p);
s.encoder = encoder_fault_scenario("dropout",p);
cfg = phase3_configuration(p);
cfg.reacquisitionEnabled = true;
f = phase3_fault_profiles(p,s);
f.independentReference = referenceStream(f.time_s,1.2,1.6,1.5);
end

function r = referenceStream(time_s,startTime_s,stopTime_s,requestTime_s)
n = numel(time_s);
r.sampleReceived = time_s>=startTime_s & time_s<stopTime_s;
r.sourceIndex = (1:n)';
r.error_rad = zeros(n,1);
r.uncertainty_rad = repmat(deg2rad(.005),n,1);
r.request = false(n,1);
r.request(sampleAt(time_s,requestTime_s)) = true;
end

function index = sampleAt(time_s,time)
[~,index] = min(abs(time_s-time));
end
