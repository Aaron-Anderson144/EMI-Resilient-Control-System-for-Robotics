classdef TestSC01AThresholds < matlab.unittest.TestCase
    %TESTSC01ATHRESHOLDS Analytic signals guard diagnostic event semantics.
    methods (Test)
        function triangularPulseHasExactDurationAndCrossings(testCase)
            [events, duration, grazing] = sc01a_threshold_events( ...
                [0; 1; 2], [0; 2; 0], 1, 0);
            testCase.verifyEqual(events{:,:}, [0.5 1 1; 1.5 1 -1], 'AbsTol', 1e-14);
            testCase.verifyEqual(duration, 1, 'AbsTol', 1e-14);
            testCase.verifyFalse(grazing);
        end

        function negativePulsePreservesVoltageDirection(testCase)
            [events, duration, grazing] = sc01a_threshold_events( ...
                [0; 1; 2], [0; -2; 0], 1, 0);
            testCase.verifyEqual(events{:,:}, [0.5 -1 -1; 1.5 -1 1], 'AbsTol', 1e-14);
            testCase.verifyEqual(duration, 1, 'AbsTol', 1e-14);
            testCase.verifyFalse(grazing);
        end

        function oneSegmentCanCrossBothLevels(testCase)
            [events, duration] = sc01a_threshold_events([4; 8], [-2; 2], 1, 0);
            testCase.verifyEqual(events{:,:}, [5 -1 1; 7 1 1], 'AbsTol', 1e-14);
            testCase.verifyEqual(duration, 2, 'AbsTol', 1e-14);
        end

        function exactSampleCrossingIsCountedOnlyOnce(testCase)
            [events, duration, grazing] = sc01a_threshold_events( ...
                [0; 1; 2; 3; 4], [0; 1; 2; 1; 0], 1, 0);
            testCase.verifyEqual(events{:,:}, [1 1 1; 3 1 -1]);
            testCase.verifyEqual(duration, 2, 'AbsTol', 1e-14);
            testCase.verifyFalse(grazing);
        end

        function thresholdTangencyIsNotACrossing(testCase)
            [events, duration, grazing] = sc01a_threshold_events( ...
                [0; 1; 2], [0; 1; 0], 1, 0);
            testCase.verifyEmpty(events);
            testCase.verifyEqual(duration, 0);
            testCase.verifyTrue(grazing);
            [events, duration, grazing] = sc01a_threshold_events( ...
                [0; 1; 2], [-2; -1; -2], 1, 0);
            testCase.verifyEmpty(events);
            testCase.verifyEqual(duration, 2);
            testCase.verifyTrue(grazing);
        end

        function crossingPlateauUsesItsFirstSample(testCase)
            [events, duration, grazing] = sc01a_threshold_events( ...
                [0; 1; 3; 4], [0; 1; 1; 2], 1, 0);
            testCase.verifyEqual(events{:,:}, [1 1 1]);
            testCase.verifyEqual(duration, 1);
            testCase.verifyTrue(grazing);
        end

        function touchingPlateauHasNoCrossingOrExposure(testCase)
            [events, duration, grazing] = sc01a_threshold_events( ...
                [0; 1; 3; 4], [0; 1; 1; 0], 1, 0);
            testCase.verifyEmpty(events);
            testCase.verifyEqual(duration, 0);
            testCase.verifyTrue(grazing);
        end

        function allThresholdPlateauHasZeroExposure(testCase)
            [events, duration, grazing] = sc01a_threshold_events( ...
                [2; 5; 9], [-1; -1; -1], 1, 0);
            testCase.verifyEmpty(events);
            testCase.verifyEqual(events.Properties.VariableNames, ...
                {'Time_s', 'Level_V', 'Direction'});
            testCase.verifyEqual(duration, 0);
            testCase.verifyTrue(grazing);
        end

        function nearExtremumOnlyChangesGrazingWarning(testCase)
            [events, duration, grazing] = sc01a_threshold_events( ...
                [0; 1; 2], [0; 0.999; 0], 1, 0.002);
            testCase.verifyEmpty(events);
            testCase.verifyEqual(duration, 0);
            testCase.verifyTrue(grazing);
            [~, ~, grazing] = sc01a_threshold_events( ...
                [0; 1; 2], [0; 0.999; 0], 1, 0.0001);
            testCase.verifyFalse(grazing);
        end

        function initialExposureIsClippedToRecord(testCase)
            [events, duration, grazing] = sc01a_threshold_events( ...
                [5; 7], [3; 0], 1, 0);
            testCase.verifyEqual(events{:,:}, [19/3 1 -1], 'AbsTol', 1e-14);
            testCase.verifyEqual(duration, 4/3, 'AbsTol', 1e-14);
            testCase.verifyFalse(grazing);
        end

        function boundaryEqualitiesDoNotCreateInteriorEvents(testCase)
            [events, duration, grazing] = sc01a_threshold_events( ...
                [0; 1; 2], [1; 2; 1], 1, 0);
            testCase.verifyEmpty(events);
            testCase.verifyEqual(duration, 2);
            testCase.verifyFalse(grazing);
            [events, duration, grazing] = sc01a_threshold_events( ...
                [0; 1; 2; 3], [1; 1; 2; 2], 1, 0);
            testCase.verifyEmpty(events);
            testCase.verifyEqual(duration, 2);
            testCase.verifyTrue(grazing);
        end

        function nonuniformGridHasAnalyticTimesAndDuration(testCase)
            [events, duration] = sc01a_threshold_events( ...
                [0; 0.2; 1.7; 4], [0; 2; -2; 0], 1, 0);
            expected = [0.1 1 1; 0.575 1 -1; 1.325 -1 -1; 2.85 -1 1];
            testCase.verifyEqual(events{:,:}, expected, 'AbsTol', 1e-13);
            testCase.verifyEqual(duration, 2, 'AbsTol', 1e-13);
        end

        function invalidTimesAreRejected(testCase)
            invalid = {[0; 0; 1], [0; 2; 1], [0; NaN; 1], [0; Inf; 1]};
            for k = 1:numel(invalid)
                testCase.verifyError(@() sc01a_threshold_events( ...
                    invalid{k}, [0; 1; 0], 1, 0), 'SC01A:ThresholdInput');
            end
        end

        function invalidShapesValuesAndThresholdsAreRejected(testCase)
            testCase.verifyError(@() sc01a_threshold_events( ...
                [0 1], [0 2], 1, 0), 'SC01A:ThresholdInput');
            testCase.verifyError(@() sc01a_threshold_events( ...
                [0; 1], [0; 1; 2], 1, 0), 'SC01A:ThresholdInput');
            testCase.verifyError(@() sc01a_threshold_events( ...
                [0; 1], [0; NaN], 1, 0), 'SC01A:ThresholdInput');
            testCase.verifyError(@() sc01a_threshold_events( ...
                0, 2, 1, 0), 'SC01A:ThresholdInput');
            testCase.verifyError(@() sc01a_threshold_events( ...
                [0; 1], [0; 2], 0, 0), 'SC01A:ThresholdInput');
            testCase.verifyError(@() sc01a_threshold_events( ...
                [0; 1], [0; 2], 1, -0.1), 'SC01A:ThresholdInput');
        end
    end
end
