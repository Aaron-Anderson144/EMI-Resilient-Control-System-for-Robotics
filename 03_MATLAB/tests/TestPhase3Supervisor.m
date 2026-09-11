classdef TestPhase3Supervisor < matlab.unittest.TestCase
    methods (Test)
        function thresholdsRepresentElapsedTimeAndRoundUp(testCase)
            c = phase3_supervisor_configuration(0.001);
            testCase.verifyEqual([c.badPersistence_samples,c.recoveryQualification_samples, ...
                c.recoveryDwell_samples,c.maxNonNormalTime_samples,c.safeStopRelease_samples], ...
                [6,11,51,501,51]);
            c = phase3_supervisor_configuration(0.001,struct('badPersistence_s',0.0051));
            testCase.verifyEqual(c.badPersistence_samples,7);
            c = phase3_supervisor_configuration(0.01,struct('badPersistence_s',0.1));
            testCase.verifyEqual(c.badPersistence_samples,11);
        end

        function persistentAlarmChangesModeOnExactBoundary(testCase)
            c = phase3_supervisor_configuration(0.001);
            s = phase3_supervisor_initialize(); in = healthyInput();
            in.alarm = true; in.credibleFresh = false;
            modes = zeros(1,6); counts = zeros(1,6);
            for k = 1:6
                [s,out] = phase3_supervisor_step(s,in,c);
                modes(k) = s.mode; counts(k) = s.badCount;
                testCase.verifyEqual(out.mode,s.mode);
            end
            testCase.verifyEqual(modes,[1,1,1,1,1,2]);
            testCase.verifyEqual(counts,1:6);
            testCase.verifyEqual(s.nonNormalCount,6);
        end

        function noFreshSampleWithinGraceIsNeutralAndBreaksBadRun(testCase)
            c = shortConfiguration(); s = phase3_supervisor_initialize();
            neutral = healthyInput(); neutral.credibleFresh = false;
            for k = 1:3
                s = phase3_supervisor_step(s,neutral,c);
                testCase.verifyEqual(s,phase3_supervisor_initialize());
            end
            bad = neutral; bad.alarm = true;
            s = phase3_supervisor_step(s,bad,c);
            s = phase3_supervisor_step(s,neutral,c);
            testCase.verifyEqual([s.mode,s.badCount,s.goodCount],[1,0,0]);
            s = phase3_supervisor_step(s,bad,c);
            testCase.verifyEqual([s.mode,s.badCount],[1,1]);
        end

        function qualificationAndRecoveryHaveIndependentDwell(testCase)
            c = shortConfiguration(); s = phase3_supervisor_initialize();
            in = healthyInput(); alarms = logical([1,1,0,0,0,0,0,0]);
            modes = zeros(size(alarms)); good = modes; episode = modes;
            for k = 1:numel(alarms)
                in.alarm = alarms(k);
                s = phase3_supervisor_step(s,in,c);
                modes(k) = s.mode; good(k) = s.goodCount; episode(k) = s.nonNormalCount;
            end
            testCase.verifyEqual(modes,[1,2,2,2,3,3,3,0]);
            testCase.verifyEqual(good,[0,0,1,2,1,2,3,0]);
            testCase.verifyEqual(episode,[1,2,3,4,5,6,7,0]);
        end

        function missingCredibleSampleRestartsRecoveryEvidence(testCase)
            c = shortConfiguration(); s = recoveryState(); in = healthyInput();
            s = phase3_supervisor_step(s,in,c);
            testCase.verifyEqual(s.goodCount,2);
            in.credibleFresh = false;
            s = phase3_supervisor_step(s,in,c);
            testCase.verifyEqual([s.mode,s.goodCount],[3,0]);
            in.credibleFresh = true; modes = zeros(1,4);
            for k = 1:4
                s = phase3_supervisor_step(s,in,c); modes(k) = s.mode;
            end
            testCase.verifyEqual(modes,[3,3,3,0]);
        end

        function recoveryAlarmImmediatelyReturnsToDegraded(testCase)
            c = phase3_supervisor_configuration(0.001);
            in = healthyInput(); in.alarm = true;
            [s,out] = phase3_supervisor_step(recoveryState(),in,c);
            testCase.verifyEqual([s.mode,s.badCount,s.goodCount],[2,1,0]);
            testCase.verifyTrue(out.useDegradedGains);
            testCase.verifyTrue(out.rebaseController);
            testCase.verifyEqual(out.transitionReason,"alarm");
        end

        function safeStopRequiresCurrentResetAndFullCredibleDuration(testCase)
            c = shortConfiguration(); s = phase3_supervisor_initialize();
            in = healthyInput(); in.supplyHealthy = false;
            s = phase3_supervisor_step(s,in,c);
            in.supplyHealthy = true;
            for k = 1:4
                s = phase3_supervisor_step(s,in,c);
            end
            testCase.verifyEqual([s.mode,s.goodCount],[4,3]);
            in.resetRequest = true; in.credibleFresh = false;
            s = phase3_supervisor_step(s,in,c);
            testCase.verifyEqual([s.mode,s.goodCount],[4,0]);
            in.credibleFresh = true;
            s = phase3_supervisor_step(s,in,c);
            s = phase3_supervisor_step(s,in,c);
            testCase.verifyEqual([s.mode,s.goodCount],[4,2]);
            [s,out] = phase3_supervisor_step(s,in,c);
            testCase.verifyEqual([s.mode,s.goodCount,s.nonNormalCount],[3,1,1]);
            testCase.verifyTrue(out.driveEnabled);
            testCase.verifyTrue(out.rebaseController);
            testCase.verifyEqual(out.transitionReason,"qualified_reset");
        end

        function unhealthySupplyOrUnusableEstimateStopsImmediately(testCase)
            c = shortConfiguration(); in = healthyInput();
            for field = ["supplyHealthy","estimateUsable"]
                bad = in; bad.(field) = false; bad.resetRequest = true;
                [s,out] = phase3_supervisor_step(recoveryState(),bad,c);
                testCase.verifyEqual([s.mode,s.goodCount,s.nonNormalCount],[4,0,0]);
                testCase.verifyFalse(out.driveEnabled);
                testCase.verifyEqual(out.voltageLimitScale,0);
            end
        end

        function timeoutWinsOverFinalRecoverySampleAndCannotBeEvaded(testCase)
            c = shortConfiguration();
            c = phase3_supervisor_configuration(c.sampleTime_s, ...
                struct('recoveryDwell_s',0.003,'maxNonNormalTime_s',0.004));
            s = recoveryState(); s.goodCount = 3; s.nonNormalCount = 4;
            [s,out] = phase3_supervisor_step(s,healthyInput(),c);
            testCase.verifyEqual(s.mode,4);
            testCase.verifyFalse(out.driveEnabled);
            testCase.verifyEqual(out.transitionReason,"qualification_timeout");
            c = phase3_supervisor_configuration(0.001, ...
                struct('badPersistence_s',0.001,'recoveryQualification_s',0.001, ...
                'recoveryDwell_s',0.003,'maxNonNormalTime_s',0.006));
            s = phase3_supervisor_initialize(); in = healthyInput();
            alarms = logical([1,1,0,0,1,0,0]); modes = zeros(1,7);
            for k = 1:7
                in.alarm = alarms(k); s = phase3_supervisor_step(s,in,c); modes(k) = s.mode;
            end
            testCase.verifyEqual(modes,[1,2,2,3,2,2,4]);
        end

        function transitionReasonsFollowModeChangeAndPriority(testCase)
            c = shortConfiguration(); s = phase3_supervisor_initialize(); in = healthyInput();
            [s,out] = phase3_supervisor_step(s,in,c);
            testCase.verifyEqual(out.transitionReason,"none");
            in.alarm = true;
            [s,out] = phase3_supervisor_step(s,in,c);
            testCase.verifyEqual(out.transitionReason,"alarm");
            in.supplyHealthy = false; in.estimateUsable = false;
            [s,out] = phase3_supervisor_step(s,in,c);
            testCase.verifyEqual(out.transitionReason,"supply_low");
            [~,out] = phase3_supervisor_step(s,in,c);
            testCase.verifyEqual(out.transitionReason,"none");
            in = healthyInput(); in.estimateUsable = false;
            [~,out] = phase3_supervisor_step(phase3_supervisor_initialize(),in,c);
            testCase.verifyEqual(out.transitionReason,"estimate_unusable");
            s = recoveryState(); s.goodCount = 3;
            [~,out] = phase3_supervisor_step(s,healthyInput(),c);
            testCase.verifyEqual(out.transitionReason,"credible_dwell");
        end

        function invalidInputsAndMutatedDerivedCountsAreRejected(testCase)
            c = shortConfiguration(); s = phase3_supervisor_initialize(); in = healthyInput();
            bad = in; bad.alarm = 1;
            testCase.verifyError(@()phase3_supervisor_step(s,bad,c), ...
                'EMIProject:InvalidPhase3SupervisorInput');
            bad = in; bad.resetRequest = [true,false];
            testCase.verifyError(@()phase3_supervisor_step(s,bad,c), ...
                'EMIProject:InvalidPhase3SupervisorInput');
            bad = s; bad.badCount = NaN;
            testCase.verifyError(@()phase3_supervisor_step(bad,in,c), ...
                'EMIProject:InvalidPhase3SupervisorState');
            bad = c; bad.badPersistence_samples = 1;
            testCase.verifyError(@()phase3_supervisor_step(s,in,bad), ...
                'EMIProject:InvalidPhase3SupervisorConfiguration');
            for value = {NaN,Inf,1i,[1,2],true,"1",0,-1}
                testCase.verifyError(@()phase3_supervisor_configuration(value{1}), ...
                    'EMIProject:InvalidPhase3SupervisorConfiguration');
            end
            testCase.verifyError(@()phase3_supervisor_configuration(.001,struct('unknown',1)), ...
                'EMIProject:InvalidPhase3SupervisorConfiguration');
        end

        function integerClassesCannotSilentlyChangeCounterArithmetic(testCase)
            c = shortConfiguration(); s = phase3_supervisor_initialize(); in = healthyInput();
            testCase.verifyError(@()phase3_supervisor_configuration(uint32(1)), ...
                'EMIProject:InvalidPhase3SupervisorConfiguration');
            testCase.verifyError(@()phase3_supervisor_configuration(.001, ...
                struct('normalVoltageLimitScale',uint8(1))), ...
                'EMIProject:InvalidPhase3SupervisorConfiguration');
            s.badCount = uint8(0);
            testCase.verifyError(@()phase3_supervisor_step(s,in,c), ...
                'EMIProject:InvalidPhase3SupervisorState');
        end
    end
end

function input = healthyInput()
input = struct('alarm',false,'credibleFresh',true,'supplyHealthy',true, ...
    'estimateUsable',true,'resetRequest',false);
end

function cfg = shortConfiguration()
cfg = phase3_supervisor_configuration(0.001,struct('badPersistence_s',0.001, ...
    'recoveryQualification_s',0.002,'recoveryDwell_s',0.003,'safeStopRelease_s',0.002));
end

function state = recoveryState()
state = phase3_supervisor_initialize();
state.mode = 3; state.goodCount = 1; state.nonNormalCount = 1;
end
