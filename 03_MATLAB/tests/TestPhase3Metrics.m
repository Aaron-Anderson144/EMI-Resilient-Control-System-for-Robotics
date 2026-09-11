classdef TestPhase3Metrics < matlab.unittest.TestCase
    methods (Test)
        function delayUsesFirstReceiverExposureRatherThanSourceTime(testCase)
            r = syntheticRecord(101);
            r.run.profiles.sourceFault(11) = true;
            r.run.profiles.receiverFault(14) = true;
            r.timeSeries.mode(17:25) = 1;
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.DetectionStatus,"detected");
            testCase.verifyEqual(m.SourceOnset_s,.010,'AbsTol',1e-15);
            testCase.verifyEqual(m.FirstReceiverExposure_s,.013,'AbsTol',1e-15);
            testCase.verifyEqual(m.SourceToReceiver_s,.003,'AbsTol',1e-15);
            testCase.verifyEqual(m.DetectionDelay_s,.003,'AbsTol',1e-15);
            testCase.verifyEqual(m.FirstResponse_s,.016,'AbsTol',1e-15);
        end

        function exposedWithoutResponseIsMissedOnlyAfterCompleteWindow(testCase)
            r = syntheticRecord(31);
            r.run.profiles.sourceFault(11) = true;
            r.run.profiles.receiverFault(11) = true;
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.DetectionStatus,"missed"); % .010+.020=.030 end.
            testCase.verifyTrue(isnan(m.DetectionDelay_s));
            r = syntheticRecord(30);
            r.run.profiles.sourceFault(11) = true;
            r.run.profiles.receiverFault(11) = true;
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.DetectionStatus,"right_censored");
            testCase.verifyTrue(isnan(m.DetectionDelay_s));
        end

        function visibleResponseAtRecordEndRemainsDetected(testCase)
            r = syntheticRecord(30);
            r.run.profiles.sourceFault(29:30) = true;
            r.run.profiles.receiverFault(29:30) = true;
            r.timeSeries.mode(30) = 1;
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.DetectionStatus,"detected");
            testCase.verifyEqual(m.DetectionDelay_s,.001,'AbsTol',1e-15);
            testCase.verifyEqual(m.RecoveryStatus,"right_censored");
        end

        function noSourceOrNoAcceptedCorruptionIsUnexposed(testCase)
            r = syntheticRecord(101);
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.DetectionStatus,"unexposed");
            r.run.profiles.sourceFault(11:20) = true;
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.DetectionStatus,"unexposed");
            testCase.verifyEqual(m.SourceOnset_s,.010,'AbsTol',1e-15);
            testCase.verifyTrue(isnan(m.FirstReceiverExposure_s));
        end

        function ongoingPriorResponseIsNotNewFaultDetection(testCase)
            r = syntheticRecord(101);
            r.run.profiles.sourceFault(20) = true;
            r.run.profiles.receiverFault(20) = true;
            r.timeSeries.mode(10:30) = 1;
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.DetectionStatus,"preexisting_response");
            testCase.verifyTrue(isnan(m.DetectionDelay_s));
        end

        function recoveryNeedsFullFiftyMillisecondNormalSpan(testCase)
            r = syntheticRecord(71);
            r.run.profiles.sourceFault(11:20) = true;
            r.run.profiles.receiverFault(11:20) = true;
            r.timeSeries.mode(11:20) = 1;
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.RecoveryStatus,"recovered");
            testCase.verifyEqual(m.RecoveryDelay_s,.001,'AbsTol',1e-15);
            r = syntheticRecord(70);
            r.run.profiles.sourceFault(11:20) = true;
            r.run.profiles.receiverFault(11:20) = true;
            r.timeSeries.mode(11:20) = 1;
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.RecoveryStatus,"right_censored");
            testCase.verifyTrue(isnan(m.RecoveryDelay_s));
        end

        function recoveryConfirmationRestartsAfterRelapse(testCase)
            r = syntheticRecord(81);
            r.run.profiles.sourceFault(11:20) = true;
            r.run.profiles.receiverFault(11:20) = true;
            r.timeSeries.mode(11:20) = 1;
            r.timeSeries.mode(30) = 2;
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.RecoveryStatus,"recovered");
            testCase.verifyEqual(m.RecoveryDelay_s,.011,'AbsTol',1e-15);
        end

        function cleanFalseAlarmEpisodesIncludeRecoveryButNotExtraEvents(testCase)
            r = syntheticRecord(101); r.run.scenario.expectation = "clean";
            r.timeSeries.mode(11:20) = 1;
            r.timeSeries.mode(21:30) = 3;
            r.timeSeries.mode(100:101) = 4;
            m = phase3_metrics(r,r,r,r);
            testCase.verifyEqual(m.FalseAlarmEpisodes,2);
            testCase.verifyEqual(m.FalseAlarmDuration_s,.021,'AbsTol',1e-15);
            testCase.verifyEqual(m.StopDuration_s,.001,'AbsTol',1e-15);
            testCase.verifyEqual(m.DetectionStatus,"not_applicable");
        end

        function partialOutputRefusedBeforeAnyStudyWrites(testCase)
            folder = string(tempname); mkdir(folder);
            cleanup = onCleanup(@()removeTemporaryFolder(folder)); %#ok<NASGU>
            file = fullfile(folder,'partial.csv');
            fid = fopen(file,'w'); assert(fid>=0); fprintf(fid,'preserve this partial evidence'); fclose(fid);
            before = dir(folder);
            testCase.verifyError(@()run_phase3_study(folder),'EMIProject:Phase3OutputExists');
            testCase.verifyError(@()run_phase3_ablation(struct(),folder),'EMIProject:Phase3OutputExists');
            testCase.verifyEqual(fileread(file),'preserve this partial evidence');
            after = dir(folder);
            testCase.verifyEqual({after.name},{before.name});
            testCase.verifyError(@()require_empty_phase3_output_folder(file),'EMIProject:Phase3OutputExists');
            fresh = fullfile(folder,'fresh');
            require_empty_phase3_output_folder(fresh);
            testCase.verifyFalse(isfolder(fresh));
            mkdir(fresh); require_empty_phase3_output_folder(fresh);
            contents = dir(fresh);
            testCase.verifyEmpty(contents(~ismember({contents.name},{'.','..'})));
        end
    end
end

function result = syntheticRecord(n)
t = (0:n-1)'*.001; zero = zeros(n,1); limit = ones(n,1)*24;
result.timeSeries = table(t,zero,zero,zero,zero,zero,zero,zero,limit, ...
    'VariableNames',{'time_s','position_rad','reference_rad','command_V','mode', ...
    'alarm','estimatedPosition_rad','current_A','commandLimit_V'});
result.state = zeros(n,3);
result.run.params.control.sampleTime_s = .001;
result.run.scenario = struct('name',"synthetic",'expectation',"observe");
result.run.configuration.observer.maxMeasurementAge_s = .020;
result.run.profiles.sourceFault = false(n,1);
result.run.profiles.receiverFault = false(n,1);
result.run.profiles.supply.commandLimit_V = limit;
end

function removeTemporaryFolder(folder)
resolved = char(java.io.File(char(folder)).getCanonicalPath());
root = char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith(lower(resolved),[lower(root),filesep]), ...
    'EMIProject:UnsafeTestCleanup','Temporary cleanup escaped the temporary directory.');
if isfolder(folder),rmdir(folder,'s');end
end
