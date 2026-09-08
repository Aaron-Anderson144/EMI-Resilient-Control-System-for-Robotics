classdef TestBaseline < matlab.unittest.TestCase
    %TESTBASELINE Structural and reproducibility tests for Phase 1.

    methods (Test)
        function parametersAreValid(testCase)
            params = actuator_parameters();
            testCase.verifyWarningFree(@() validate_parameters(params));
        end

        function plantDimensionsAreCorrect(testCase)
            params = actuator_parameters();
            plant = actuator_state_space(params);
            [A, B, C, D] = ssdata(plant);

            testCase.verifySize(A, [3, 3]);
            testCase.verifySize(B, [3, 2]);
            testCase.verifySize(C, [3, 3]);
            testCase.verifySize(D, [3, 2]);
        end

        function cleanClosedLoopIsStable(testCase)
            params = actuator_parameters();
            model = baseline_closed_loop(params);
            closedLoopPoles = pole(model.referenceToPosition);

            testCase.verifyLessThan(max(abs(closedLoopPoles)), 1);
        end

        function baselineResponseIsFinite(testCase)
            params = actuator_parameters();
            model = baseline_closed_loop(params);
            time_s = (0:params.control.sampleTime_s: ...
                params.simulation.stopTime_s).';
            reference = zeros(size(time_s));
            reference(time_s >= params.simulation.stepTime_s) = ...
                params.simulation.stepAmplitude_rad;

            response = lsim(model.referenceToPosition, reference, time_s);
            testCase.verifyTrue(all(isfinite(response)));
        end

        function baselineResponseIsRepeatable(testCase)
            params = actuator_parameters();
            model = baseline_closed_loop(params);
            time_s = (0:params.control.sampleTime_s: ...
                params.simulation.stopTime_s).';
            reference = zeros(size(time_s));
            reference(time_s >= params.simulation.stepTime_s) = ...
                params.simulation.stepAmplitude_rad;

            responseOne = lsim(model.referenceToPosition, reference, time_s);
            responseTwo = lsim(model.referenceToPosition, reference, time_s);

            testCase.verifyEqual(responseOne, responseTwo, 'AbsTol', 1e-12);
        end
    end
end

