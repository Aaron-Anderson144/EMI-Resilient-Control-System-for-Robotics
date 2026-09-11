classdef TestSC01BNativeRecord < matlab.unittest.TestCase
    % Native worker collection must verify settings beyond the filename/step.
    methods(Test)
        function ordinaryAndTightRecordsPassWithDeclaredSettings(testCase)
            for tag=["native_0.125_ns","native_tight_consistency"]
                [r,p,row,c]=fixture(tag);
                check=sc01b_validate_native_record(r,p,p,row,c);
                testCase.verifyTrue(check.completeSettingsMatched);
                testCase.verifyTrue(check.uniformIntegrationGridPassed);
                testCase.verifyEqual(check.samples,numel(r.time_s));
            end
        end

        function ordinaryRunCannotBeLabeledTight(testCase)
            [r,p,row,c]=fixture("native_0.125_ns");
            row.Run="native_tight_consistency";
            testCase.verifyError(@()sc01b_validate_native_record(r,p,p,row,c), ...
                'SC01B:WorkerNativeSettings');
        end

        function otherSolverSettingMismatchIsRejected(testCase)
            [r,p,row,c]=fixture("native_tight_consistency");
            r.settings.consistencyToleranceFactor=0.1;
            testCase.verifyError(@()sc01b_validate_native_record(r,p,p,row,c), ...
                'SC01B:WorkerNativeSettings');
            [r,p,row,c]=fixture("native_0.125_ns");
            r.settings.localSolver='backward_euler';
            testCase.verifyError(@()sc01b_validate_native_record(r,p,p,row,c), ...
                'SC01B:WorkerNativeSettings');
        end

        function wrongRunStepCannotBeHiddenByItsManifest(testCase)
            [r,p,row,c]=fixture("native_0.125_ns");
            r.settings.maxStep_s=0.25e-9;row.Step_s=r.settings.maxStep_s;
            testCase.verifyError(@()sc01b_validate_native_record(r,p,p,row,c), ...
                'SC01B:WorkerNativeSettings');
        end

        function interiorGridDistortionIsRejected(testCase)
            [r,p,row,c]=fixture("native_0.125_ns");
            % Same count, endpoints, settings and still strictly increasing.
            r.time_s(3)=r.time_s(3)+0.1*row.Step_s;
            testCase.verifyError(@()sc01b_validate_native_record(r,p,p,row,c), ...
                'SC01B:WorkerNativeGrid');
        end

        function skippedStepFailsEvenWithMatchingSampleMetadata(testCase)
            [r,p,row,c]=fixture("native_0.125_ns");
            r.time_s(3)=[];row.Samples=numel(r.time_s);
            testCase.verifyError(@()sc01b_validate_native_record(r,p,p,row,c), ...
                'SC01B:WorkerNativeGrid');
        end

        function nonfiniteOrUnorderedGridIsRejected(testCase)
            for invalid=[NaN,Inf,0]
                [r,p,row,c]=fixture("native_0.125_ns");r.time_s(3)=invalid;
                testCase.verifyError(@()sc01b_validate_native_record(r,p,p,row,c), ...
                    'SC01B:WorkerNativeGrid');
            end
        end

        function warningOrIncompleteRecordIsRejected(testCase)
            [r,p,row,c]=fixture("native_0.125_ns");row.Warnings=1;
            testCase.verifyError(@()sc01b_validate_native_record(r,p,p,row,c), ...
                'SC01B:WorkerNativeRecord');
            [r,p,row,c]=fixture("native_0.125_ns");r.executionInfo.StopEvent="StoppedByUser";
            testCase.verifyError(@()sc01b_validate_native_record(r,p,p,row,c), ...
                'SC01B:WorkerNativeRecord');
        end

        function changedParametersOrUnknownTagAreRejected(testCase)
            [r,p,row,c]=fixture("native_0.125_ns");stored=p;stored.bus.voltage_V=18;
            testCase.verifyError(@()sc01b_validate_native_record(r,stored,p,row,c), ...
                'SC01B:WorkerNativeParameters');
            row.Run="native_unknown";
            testCase.verifyError(@()sc01b_validate_native_record(r,p,p,row,c), ...
                'SC01B:WorkerNativeTag');
        end
    end
end

function [r,p,row,c]=fixture(tag)
c=sc01b_criteria();p=sc01b_case("nominal");
% Short synthetic record with the real campaign's native timestep/settings.
p.simulation.stopTime_s=8*c.nativeSteps_s(end);
settings=p.simulation;settings.maxStep_s=c.nativeSteps_s(end);
if tag=="native_tight_consistency"
    settings.consistencyAbsoluteTolerance=1e-13;
    settings.consistencyRelativeTolerance=1e-9;
end
r=struct('params',p,'settings',sc01b_local_solver_settings(settings), ...
    'time_s',(0:8)'*settings.maxStep_s,'warningCount',0, ...
    'executionInfo',struct('StopEvent',"ReachedStopTime"));
row=struct('Case',"nominal",'Run',tag,'Step_s',settings.maxStep_s, ...
    'Samples',numel(r.time_s),'StopTime_s',p.simulation.stopTime_s, ...
    'Warnings',0,'Completed',true);
end
