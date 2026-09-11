classdef TestPhase3TuningAssessment < matlab.unittest.TestCase
    methods (Test)
        function calendarWindowDoesNotFollowChangedModeDuration(testCase)
            [short,fixture] = metricRecord(); clean = short;
            short.timeSeries.position_rad(:) = deg2rad(1);
            short.timeSeries.position_rad(81:end) = deg2rad(50);
            short.timeSeries.mode(11:20) = 1;
            short.timeSeries.commandLimit_V(11:20) = 12;
            long = short;
            long.timeSeries.mode(11:40) = 1;
            long.timeSeries.commandLimit_V(11:40) = 12;
            a = phase3_tuning_metrics(short,clean,fixture,"short_response");
            b = phase3_tuning_metrics(long,clean,fixture,"long_response");
            testCase.verifyEqual([a.WindowStart_s,a.WindowStop_s,a.WindowSamples],[.02,.08,60]);
            testCase.verifyEqual(a.WindowTrackingRMSE_deg,1,'AbsTol',1e-12);
            testCase.verifyEqual(a.WindowTrackingRMSE_deg,b.WindowTrackingRMSE_deg);
            testCase.verifyTrue(a.RecoveryConfirmed && b.RecoveryConfirmed);
            testCase.verifyEqual([a.FirstConfirmedNormal_s,b.FirstConfirmedNormal_s],[.02,.04],'AbsTol',1e-12);
            testCase.verifyTrue(a.InvariantsPass && b.InvariantsPass);
        end

        function effortUsesHeldIntervalsAndExcludesWindowStopSample(testCase)
            [r,fixture] = metricRecord(); clean = r;
            r.timeSeries.current_A(21:80) = 2;
            r.timeSeries.current_A(81:end) = 100;
            r.timeSeries.command_V(21:80) = 3;
            r.timeSeries.command_V(81:end) = 12;
            r.timeSeries.unsaturatedCommand_V = r.timeSeries.command_V;
            a = phase3_tuning_metrics(r,clean,fixture,"effort");
            testCase.verifyEqual(a.WindowCurrentSquared_A2s,4*.060,'AbsTol',1e-12);
            testCase.verifyEqual(a.WindowVoltageSquared_V2s,9*.060,'AbsTol',1e-12);
            testCase.verifyEqual(a.WindowCommandVariation_V,3,'AbsTol',1e-12);
            testCase.verifyEqual(a.WindowPeakCurrent_A,2);
            testCase.verifyEqual(a.FullPeakCurrent_A,100);
            testCase.verifyTrue(a.InvariantsPass);
        end

        function offlineCleanDeltaIsSeparateFromReferenceTracking(testCase)
            [r,fixture] = metricRecord(); clean = r;
            r.timeSeries.position_rad(:) = deg2rad(3);
            r.timeSeries.reference_rad(:) = deg2rad(1);
            clean.timeSeries.position_rad(:) = deg2rad(2.5);
            a = phase3_tuning_metrics(r,clean,fixture,"delta");
            testCase.verifyEqual(a.WindowTrackingRMSE_deg,2,'AbsTol',1e-12);
            testCase.verifyEqual(a.WindowDisturbanceRMSE_deg,.5,'AbsTol',1e-12);
            testCase.verifyEqual(a.WindowPeakError_deg,2,'AbsTol',1e-12);
            clean.timeSeries.reference_rad(:) = -100;
            b = phase3_tuning_metrics(r,clean,fixture,"delta");
            testCase.verifyEqual(b.WindowDisturbanceRMSE_deg,a.WindowDisturbanceRMSE_deg);
        end

        function unalignedRecordsAndInvalidCalendarWindowsAreRejected(testCase)
            [r,fixture] = metricRecord(); clean = r;
            clean.time_s(21) = clean.time_s(21)+1e-9;
            testCase.verifyError(@()phase3_tuning_metrics(r,clean,fixture,"bad"), ...
                'EMIProject:TuningAlignment');
            for window = {[-.001,.08],[.02,.101],[.08,.02],[.02,.0205],[.02,NaN]}
                bad = fixture; bad.targetWindow_s = window{1};
                testCase.verifyError(@()phase3_tuning_metrics(r,r,bad,"bad"), ...
                    'EMIProject:InvalidTuningWindow');
            end
        end

        function aggregateImprovementMustReachDeclaredTenPercent(testCase)
            b = assessmentRows(); a = b; a.Policy(:) = "candidate";
            a.WindowTrackingRMSE_deg = .90*b.WindowTrackingRMSE_deg;
            [s,g] = phase3_tuning_assess(a,b);
            testCase.verifyTrue(all(g.Passed));
            testCase.verifyTrue(s.Eligible);
            testCase.verifyEqual(s.AggregateImprovementFraction,.10,'AbsTol',1e-12);
            a.WindowTrackingRMSE_deg = .9001*b.WindowTrackingRMSE_deg;
            s = phase3_tuning_assess(a,b);
            testCase.verifyTrue(s.AllComparativeGatesPass);
            testCase.verifyFalse(s.MeaningfulImprovement || s.Eligible);
        end

        function smallHistoricalErrorsUseAbsoluteAllowancesAndScoreFloor(testCase)
            b = assessmentRows(); a = b;
            b.WindowTrackingRMSE_deg = [.01;1];
            a.WindowTrackingRMSE_deg = [.02;.8];
            b.WindowDisturbanceRMSE_deg(:) = .01;
            a.WindowDisturbanceRMSE_deg(:) = .26;
            b.WindowPeakError_deg(1) = .01; a.WindowPeakError_deg(1) = .51;
            b.WindowPeakCurrent_A(:) = .001; a.WindowPeakCurrent_A(:) = .051;
            b.FullPeakCurrent_A(:) = .001; a.FullPeakCurrent_A(:) = .051;
            b.FinalTrackingError_deg(:) = .01; a.FinalTrackingError_deg(:) = .51;
            [s,g] = phase3_tuning_assess(a,b);
            testCase.verifyTrue(all(g.Passed));
            testCase.verifyTrue(s.Eligible);
            testCase.verifyEqual(s.HistoricalTrackingScore,.52,'AbsTol',1e-12);
            testCase.verifyEqual(s.TrackingScore,.44,'AbsTol',1e-12);
            a.WindowDisturbanceRMSE_deg(1) = .2601;
            [s,g] = phase3_tuning_assess(a,b);
            testCase.verifyFalse(g.DisturbancePass(1) || s.Eligible);
        end

        function goodTrackingCannotExcuseLostRecoveryNewStopOrCurrentRegression(testCase)
            b = assessmentRows(); base = b;
            base.WindowTrackingRMSE_deg = .5*b.WindowTrackingRMSE_deg;
            fields = {'RecoveryConfirmed','FinalMode','SafeStopDuration_s', ...
                'WindowPeakCurrent_A','FullPeakCurrent_A','InvariantsPass','FirstAlarm_s'};
            values = {false,2,.001,1.1001,1.1001,false,.052};
            gates = {'RecoveryPass','FinalModePass','StopDurationPass', ...
                'WindowCurrentPass','FullCurrentPass','InvariantsPass','AlarmResponsePass'};
            for k = 1:numel(fields)
                a = base; a.(fields{k})(1) = values{k};
                if strcmp(fields{k},'RecoveryConfirmed'), a.FirstConfirmedNormal_s(1) = NaN; end
                [s,g] = phase3_tuning_assess(a,b);
                testCase.verifyFalse(g.(gates{k})(1),fields{k});
                testCase.verifyTrue(s.MeaningfulImprovement);
                testCase.verifyFalse(s.Eligible,fields{k});
            end
        end

        function lowerEffortCannotEarnEligibilityThroughStopping(testCase)
            b = assessmentRows(); a = b;
            a.WindowCurrentSquared_A2s(:) = 0;
            a.WindowVoltageSquared_V2s(:) = 0;
            s = phase3_tuning_assess(a,b);
            testCase.verifyFalse(s.MeaningfulImprovement || s.Eligible);
            a.WindowTrackingRMSE_deg = .5*b.WindowTrackingRMSE_deg;
            a.SafeStopDuration_s(1) = .01; a.FinalMode(1) = 4;
            a.RecoveryConfirmed(1) = false;
            a.FirstConfirmedNormal_s(1) = NaN;
            [s,g] = phase3_tuning_assess(a,b);
            testCase.verifyFalse(s.Eligible);
            testCase.verifyFalse(g.StopDurationPass(1));
            testCase.verifyFalse(g.RecoveryPass(1));
            testCase.verifyFalse(g.FinalModePass(1));
        end

        function comparisonRejectsRenamedReorderedOrDifferentWindows(testCase)
            b = assessmentRows(); a = b; a.Fixture(1) = "different";
            testCase.verifyError(@()phase3_tuning_assess(a,b),'EMIProject:TuningPairMismatch');
            testCase.verifyError(@()phase3_tuning_assess(b([2,1],:),b),'EMIProject:TuningPairMismatch');
            for field = ["WindowStart_s","WindowStop_s","WindowSamples"]
                a = b; a.(field)(1) = a.(field)(1)+.001;
                if field=="WindowSamples", a.(field)(1) = b.(field)(1)+1; end
                testCase.verifyError(@()phase3_tuning_assess(a,b),'EMIProject:TuningPairMismatch');
            end
            a = b; a.Partition(1) = "evaluation";
            testCase.verifyError(@()phase3_tuning_assess(a,b),'EMIProject:TuningPairMismatch');
            a = b; a.ExpectClean(1) = true;
            testCase.verifyError(@()phase3_tuning_assess(a,b),'EMIProject:TuningPairMismatch');
        end

        function nonfiniteAndNegativeEvidenceCannotBecomeEligible(testCase)
            baseline = assessmentRows(); candidate = baseline;
            candidate.WindowTrackingRMSE_deg = .8*baseline.WindowTrackingRMSE_deg;
            fields = {'FullPeakCurrent_A','WindowCurrentSquared_A2s','WindowVoltageSquared_V2s'};
            values = {Inf,NaN,-1};
            for k = 1:numel(fields)
                a = candidate; b = baseline;
                a.(fields{k})(1) = values{k};
                if isinf(values{k}), b.(fields{k})(1) = values{k}; end
                testCase.verifyError(@()phase3_tuning_assess(a,b),'EMIProject:InvalidTuningMetrics');
            end
            a = candidate; a.Policy(2) = "different_policy";
            testCase.verifyError(@()phase3_tuning_assess(a,baseline),'EMIProject:InvalidTuningMetrics');
            for field = ["ExpectClean","RecoveryConfirmed","InvariantsPass","CommandBoundsPass"]
                for value = [.5,2]
                    a = candidate; a.(field) = double(a.(field)); a.(field)(1) = value;
                    testCase.verifyError(@()phase3_tuning_assess(a,baseline),'EMIProject:InvalidTuningMetrics');
                end
            end
            a = candidate; a.InvariantsPass = double(a.InvariantsPass);
            s = phase3_tuning_assess(a,baseline);
            testCase.verifyTrue(s.Eligible); % Imported numeric 0/1 flags remain valid.
            c = phase3_tuning_criteria();
            badFields = ["normalizationFloor_deg","requiredAggregateImprovement", ...
                "requiredAggregateImprovement","rmseRelativeAllowance","peakErrorRelativeAllowance", ...
                "currentAbsoluteAllowance_A","extraStopAllowance_s","alarmDelayAllowance_s", ...
                "finalErrorRelativeAllowance","rmseAbsoluteAllowance_deg","currentRelativeAllowance"];
            badValues = {0,0,1.01,-.01,1.01,-.01,Inf,NaN,[.1,.2],1i,true};
            for k = 1:numel(badFields)
                bad = c; bad.(badFields(k)) = badValues{k};
                testCase.verifyError(@()phase3_tuning_assess(candidate,baseline,bad), ...
                    'EMIProject:InvalidTuningCriteria');
            end
            for bad = {[],[c,c],rmfield(c,'normalizationFloor_deg')}
                testCase.verifyError(@()phase3_tuning_assess(candidate,baseline,bad{1}), ...
                    'EMIProject:InvalidTuningCriteria');
            end
            c.requiredAggregateImprovement = .25;
            s = phase3_tuning_assess(candidate,baseline,c);
            testCase.verifyFalse(s.Eligible);
            c.requiredAggregateImprovement = .15;
            s = phase3_tuning_assess(candidate,baseline,c);
            testCase.verifyTrue(s.Eligible);
        end
    end
end

function [result,fixture] = metricRecord()
persistent params configuration
if isempty(params)
    params = actuator_parameters();
    configuration = phase3_configuration(params);
end
n = 101; t = (0:n-1)'*.001; zero = zeros(n,1); one = ones(n,1);
result.time_s = t; result.state = zeros(n,3);
result.timeSeries = table(t,zero,zero,zero,zero,24*one,zero,zero,zero,zero,zero,one,one, ...
    'VariableNames',{'time_s','position_rad','reference_rad','command_V', ...
    'unsaturatedCommand_V','commandLimit_V','current_A','mode','alarm', ...
    'reacquisitionCommitted','resetRequest','credibleFresh','supplyHealthy'});
result.run.params = params; result.run.configuration = configuration;
result.run.protectionEnabled = true;
result.run.profiles.supply.commandLimit_V = 24*one;
fixture = struct('id',"synthetic_a",'partition',"tuning", ...
    'expectClean',false,'targetWindow_s',[.02,.08]);
end

function rows = assessmentRows()
[r,fixture] = metricRecord();
row = phase3_tuning_metrics(r,r,fixture,"historical");
rows = struct2table([row;row]); rows.Fixture = ["synthetic_a";"synthetic_b"];
rows.WindowTrackingRMSE_deg = [10;1];
rows.WindowDisturbanceRMSE_deg(:) = 1; rows.WindowPeakError_deg(:) = 1;
rows.WindowPeakCurrent_A(:) = 1; rows.FullPeakCurrent_A(:) = 1;
rows.FinalTrackingError_deg(:) = 1;
rows.WindowCurrentSquared_A2s(:) = 1; rows.WindowVoltageSquared_V2s(:) = 1;
rows.RecoveryConfirmed(:) = true; rows.FirstConfirmedNormal_s(:) = .06;
rows.FirstAlarm_s(:) = .05; rows.AlarmSamples(:) = 1;
end
