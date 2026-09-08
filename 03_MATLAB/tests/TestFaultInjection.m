classdef TestFaultInjection < matlab.unittest.TestCase
    %TESTFAULTINJECTION Verify independent and deterministic Phase 2 faults.

    methods (Test)
        function defaultScenarioHasNoFault(testCase)
            params = actuator_parameters();
            scenario = encoder_fault_scenario([], params);
            time_s = (0:params.control.sampleTime_s: ...
                params.simulation.stopTime_s).';
            profile = encoder_fault_profile(time_s, params, scenario);

            testCase.verifyEqual(scenario.name, "none");
            testCase.verifyEqual(profile.additive_rad, zeros(size(time_s)));
            testCase.verifyFalse(any(profile.dropoutActive));
        end

        function gaussianNoiseIsDeterministic(testCase)
            params = actuator_parameters();
            scenario = encoder_fault_scenario("gaussian", params);
            time_s = (0:params.control.sampleTime_s: ...
                params.simulation.stopTime_s).';

            profileOne = encoder_fault_profile(time_s, params, scenario);
            profileTwo = encoder_fault_profile(time_s, params, scenario);

            testCase.verifyEqual( ...
                profileOne.gaussian_rad, profileTwo.gaussian_rad);
            testCase.verifyGreaterThan(nnz(profileOne.gaussian_rad), 0);
        end

        function sinusoidIsLimitedToWindow(testCase)
            params = actuator_parameters();
            scenario = encoder_fault_scenario("sinusoidal", params);
            time_s = (0:params.control.sampleTime_s: ...
                params.simulation.stopTime_s).';
            profile = encoder_fault_profile(time_s, params, scenario);
            outsideWindow = time_s < scenario.sinusoid.startTime_s | ...
                time_s >= scenario.sinusoid.stopTime_s;

            testCase.verifyEqual( ...
                profile.sinusoidal_rad(outsideWindow), ...
                zeros(nnz(outsideWindow), 1));
            testCase.verifyLessThanOrEqual( ...
                max(abs(profile.sinusoidal_rad)), ...
                scenario.sinusoid.amplitude_rad + eps);
        end

        function countJumpOccupiesOneSample(testCase)
            params = actuator_parameters();
            scenario = encoder_fault_scenario("count_jump", params);
            time_s = (0:params.control.sampleTime_s: ...
                params.simulation.stopTime_s).';
            profile = encoder_fault_profile(time_s, params, scenario);
            expectedJump_rad = scenario.countJump.magnitude_counts * ...
                2 * pi / params.sensor.encoderCountsPerRevolution;

            testCase.verifyEqual(nnz(profile.countJump_rad), 1);
            testCase.verifyEqual( ...
                max(profile.countJump_rad), expectedJump_rad, ...
                'AbsTol', 10 * eps(expectedJump_rad));
        end

        function dropoutHoldsLastMeasurement(testCase)
            params = actuator_parameters();
            scenario = encoder_fault_scenario("dropout", params);
            result = simulate_faulted_actuator(params, scenario);
            dropoutValues = result.timeSeries.theta_measured_rad( ...
                result.timeSeries.measurement_stale);

            testCase.verifyGreaterThan(numel(dropoutValues), 1);
            testCase.verifyEqual( ...
                dropoutValues, repmat(dropoutValues(1), size(dropoutValues)), ...
                'AbsTol', 1e-12);
        end

        function noFaultMeasurementEqualsTruePosition(testCase)
            params = actuator_parameters();
            scenario = encoder_fault_scenario("none", params);
            result = simulate_faulted_actuator(params, scenario);

            testCase.verifyEqual( ...
                result.timeSeries.theta_measured_rad, ...
                result.timeSeries.theta_rad, ...
                'AbsTol', 1e-12);
        end

        function unknownScenarioIsRejected(testCase)
            params = actuator_parameters();
            testCase.verifyError( ...
                @() encoder_fault_scenario("not_a_scenario", params), ...
                'EMIProject:UnknownFaultScenario');
        end
    end
end

