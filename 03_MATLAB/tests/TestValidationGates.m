classdef TestValidationGates < matlab.unittest.TestCase
    % Exercise the shared production acceptance gate without a Simulink run.
    methods (Test)
        function completeMatchingRecordsPass(testCase)
            [t, values, names] = fixture();
            [check, detail] = compare_logged_arrays(t, values, t, values, names, 1e-9, 18:29, 4);
            testCase.verifyTrue(check.Passed);
            testCase.verifyTrue(check.DimensionsValid && check.AllFinite && check.TimePassed);
            testCase.verifyEqual(height(detail), 29);
            testCase.verifyEqual(detail.ExactRequired, [false(17, 1); true(12, 1)]);
            testCase.verifyEqual(detail.Allowance(18:29), zeros(12, 1));
        end

        function everyLoggedChannelParticipatesInGate(testCase)
            [t, values, names] = fixture();
            % Includes previously omitted tracking error (7), raw command
            % (8), all physical diagnostics and all discrete profiles.
            for column = 1:29
                changed = values; changed(2, column) = changed(2, column) + 1e-5;
                [check, detail] = compare_logged_arrays(t, changed, t, values, names, 1e-9, 18:29, 4);
                testCase.verifyFalse(check.Passed, sprintf('Column %d was not checked.', column));
                testCase.verifyFalse(detail.ChannelPassed(column));
                testCase.verifyGreaterThan(check.MaxDifferences(column), 1e-9);
            end
        end

        function nonfiniteActualOrExpectedChannelAlwaysFails(testCase)
            [t, values, names] = fixture();
            for invalid = [NaN, Inf, -Inf]
                for column = 1:29
                    changed = values; changed(2, column) = invalid;
                    for side = 1:2
                        if side == 1, actual = changed; expected = values;
                        else, actual = values; expected = changed; end
                        check = compare_logged_arrays(t, actual, t, expected, names, 1e-9, 18:29, 4);
                        testCase.verifyFalse(check.Passed);
                        testCase.verifyFalse(check.AllFinite);
                        testCase.verifyEqual(check.MaxDifferences(column), Inf);
                    end
                end
            end
        end

        function matchingNonfiniteArraysDoNotCountAsAgreement(testCase)
            [t, values, names] = fixture();
            values(1, 18) = NaN;
            check = compare_logged_arrays(t, values, t, values, names, 1e-9, 18:29, 4);
            testCase.verifyFalse(check.Passed);
            testCase.verifyFalse(check.DiscreteProfilesExact);
            t(2) = Inf;
            check = compare_logged_arrays(t, zeros(4, 29), t, zeros(4, 29), names, 1e-9, 18:29, 4);
            testCase.verifyFalse(check.Passed);
            testCase.verifyFalse(check.TimePassed);
        end

        function nonfiniteTimeAlwaysFails(testCase)
            [t, values, names] = fixture();
            for invalid = [NaN, Inf, -Inf]
                changed = t; changed(2) = invalid;
                for side = 1:2
                    if side == 1, actual = changed; expected = t;
                    else, actual = t; expected = changed; end
                    check = compare_logged_arrays(actual, values, expected, values, names, 1e-9, 18:29, 4);
                    testCase.verifyFalse(check.Passed);
                    testCase.verifyFalse(check.AllFinite);
                    testCase.verifyEqual(check.MaxTimeDifference_s, Inf);
                end
            end
        end

        function shapeAndSampleCountCannotBroadcastOrTruncate(testCase)
            [t, values, names] = fixture();
            badValues = {values(1:3, :), values(:, 1:28), [values, zeros(4, 1)], ...
                values.', zeros(4, 29, 2), [], {1}};
            for k = 1:numel(badValues)
                check = compare_logged_arrays(t, badValues{k}, t, values, names, 1e-9, 18:29, 4);
                testCase.verifyFalse(check.Passed);
                testCase.verifyFalse(check.DimensionsValid);
                check = compare_logged_arrays(t, values, t, badValues{k}, names, 1e-9, 18:29, 4);
                testCase.verifyFalse(check.Passed);
                testCase.verifyFalse(check.DimensionsValid);
            end
            for badTime = {t.', t(1:3), [t; 1], []}
                check = compare_logged_arrays(badTime{1}, values, t, values, names, 1e-9, 18:29, 4);
                testCase.verifyFalse(check.Passed);
                testCase.verifyFalse(check.DimensionsValid);
            end
            check = compare_logged_arrays(t, values, t, values, names, 1e-9, 18:29, 5);
            testCase.verifyFalse(check.Passed);
            testCase.verifyFalse(check.DimensionsValid);
        end

        function discreteValuesRequireExactEquality(testCase)
            [t, values, names] = fixture();
            changed = values; changed(2, 18) = changed(2, 18) + 1e-10;
            check = compare_logged_arrays(t, changed, t, values, names, 1e-9, 18:29, 4);
            testCase.verifyFalse(check.Passed);
            testCase.verifyFalse(check.DiscreteProfilesExact);
            changed = values; changed(2, 8) = changed(2, 8) + 1e-10;
            check = compare_logged_arrays(t, changed, t, values, names, 1e-9, 18:29, 4);
            testCase.verifyTrue(check.Passed);
        end

        function timeMustBeOrderedAndAlignedEvenForEqualSignals(testCase)
            [t, values, names] = fixture();
            for badTime = {t + 1e-5, t([1, 2, 2, 4]), t([1, 3, 2, 4])}
                check = compare_logged_arrays(badTime{1}, values, t, values, names, 1e-9, 18:29, 4);
                testCase.verifyFalse(check.Passed);
                testCase.verifyFalse(check.TimePassed);
            end
            duplicate = t([1, 2, 2, 4]);
            check = compare_logged_arrays(duplicate, values, duplicate, values, names, 1e-9, 18:29, 4);
            testCase.verifyFalse(check.Passed);
            testCase.verifyEqual(check.MaxTimeDifference_s, 0);
            testCase.verifyFalse(check.TimeStrictlyIncreasing);
        end

        function complexRecordsAndOverflowFailClosed(testCase)
            [t, values, names] = fixture();
            changed = values; changed(2, 1) = changed(2, 1) + 1i;
            check = compare_logged_arrays(t, changed, t, values, names, 1e-9, 18:29, 4);
            testCase.verifyFalse(check.Passed);
            testCase.verifyFalse(check.AllFinite);
            actual = values; expected = values;
            actual(2, 1) = realmax; expected(2, 1) = -realmax;
            check = compare_logged_arrays(t, actual, t, expected, names, 1e-9, 18:29, 4);
            testCase.verifyFalse(check.Passed);
            testCase.verifyEqual(check.MaxDifferences(1), Inf);
        end

        function phase2DropoutMaskCannotUseAnalogTolerance(testCase)
            t = (0:3)'; values = zeros(4, 5); names = compose('Channel%d', 1:5);
            changed = values; changed(2, 5) = 1e-10;
            check = compare_logged_arrays(t, changed, t, values, names, 1e-9, 5, 4);
            testCase.verifyFalse(check.Passed);
            testCase.verifyFalse(check.DiscreteProfilesExact);
        end
    end
end

function [t, values, names] = fixture()
t = (0:3)' * 1e-3;
values = reshape(1:116, 4, 29) / 10;
values(:, 18:29) = round(values(:, 18:29));
names = compose('Channel%d', 1:29);
end
