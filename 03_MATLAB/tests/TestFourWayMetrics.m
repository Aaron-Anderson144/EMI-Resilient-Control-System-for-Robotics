classdef TestFourWayMetrics < matlab.unittest.TestCase
    % Hand-computed scoring records; no controller or circuit solver needed.
    methods (Test)
        function scoringWindowsExcludeTheirRightEndpoints(testCase)
            [a,b] = syntheticPair(false);
            a.timeSeries.position_rad([241,401,1691,1851]) = deg2rad([1,50,2,70]);
            row = score(a,b);
            testCase.verifyEqual(row.WindowPairedRMSE_deg,sqrt(5/320),'AbsTol',1e-14);
            testCase.verifyEqual(row.WindowPairedPeak_deg,2,'AbsTol',1e-14);
            testCase.verifyEqual(row.FullPairedPeak_deg,70,'AbsTol',1e-12);
        end

        function originalRequestShapedCommandAndTailStaySeparate(testCase)
            [a,b] = syntheticPair(false);
            a.timeSeries.position_rad(2901:end) = deg2rad(.25);
            a.timeSeries.position_rad(end) = deg2rad(.5);
            a.timeSeries.reference_rad(:) = deg2rad(.1);
            row = score(a,b);
            testCase.verifyEqual(row.FinalRequestedError_deg,.5,'AbsTol',1e-14);
            testCase.verifyEqual(row.TailRequestedRMSE_deg,sqrt((100*.25^2+.5^2)/101),'AbsTol',1e-14);
            testCase.verifyEqual(row.TailShapedRMSE_deg,sqrt((100*.15^2+.4^2)/101),'AbsTol',1e-14);
            testCase.verifyEqual(row.FinalShapedError_deg,.4,'AbsTol',1e-14);
            testCase.verifyNotEqual(row.RequestedRMSE_deg,row.ShapedRMSE_deg);
        end

        function laterSecondRecoveryDoesNotEraseFirstFailure(testCase)
            [a,b] = syntheticPair(false);
            a.timeSeries.position_rad(301:801) = deg2rad(.6);
            [row,recovery] = score(a,b);
            testCase.verifyTrue(row.ExecutionGuardPass);
            testCase.verifyLessThan(row.WindowPairedRMSE_deg,.5);
            testCase.verifyLessThan(row.WindowPairedPeak_deg,2);
            testCase.verifyEqual(recovery.Status,["recovered";"recovered"]);
            testCase.verifyEqual(recovery.WithinLimit,[false;true]);
            testCase.verifyGreaterThan(recovery.Delay_s(1),.5);
            testCase.verifyLessThan(recovery.Delay_s(2),.001);
            testCase.verifyFalse(row.TaskSuccess);
        end

        function protectedRecoveryRequiresNormalModeForFullDwell(testCase)
            [a,b] = syntheticPair(true);
            a.timeSeries.mode(256:790) = 1;
            [~,recovery] = score(a,b);
            testCase.verifyEqual(recovery.RecoveryStart_s(1),.790,'AbsTol',1e-12);
            testCase.verifyEqual(recovery.Confirmation_s(1),.840,'AbsTol',1e-12);
            testCase.verifyFalse(recovery.WithinLimit(1));
        end

        function fortyNineMillisecondsAtRecordEndIsCensored(testCase)
            [a,b] = syntheticPair(false);
            a.timeSeries.position_rad(301:2951) = deg2rad(.6);
            [~,recovery] = score(a,b);
            testCase.verifyEqual(recovery.Status,["right_censored";"right_censored"]);
            testCase.verifyTrue(all(isnan(recovery.Delay_s)));
            a.timeSeries.position_rad(2951) = 0;
            [~,recovery] = score(a,b);
            testCase.verifyEqual(recovery.Status,["recovered";"recovered"]);
            testCase.verifyEqual(recovery.Confirmation_s,[3;3],'AbsTol',1e-12);
        end

        function cleanExecutionViolationsRejectComparison(testCase)
            [a,b] = syntheticPair(false);
            for kind = 1:4
                changed = b;
                switch kind
                    case 1, changed.timeSeries.command_V(100) = 25;
                    case 2
                        changed.timeSeries.mode(100) = 4;
                        changed.timeSeries.command_V(100) = 1;
                    case 3, changed.timeSeries.sourceIndex(100) = 99;
                    case 4, changed.timeSeries.sampleReceived(100) = false;
                end
                row = score(a,changed);
                testCase.verifyFalse(row.CleanGuardPass);
                testCase.verifyFalse(row.ExecutionGuardPass);
                testCase.verifyFalse(row.TaskSuccess);
            end
        end

        function incompleteMatchedRecordsAreStillRejected(testCase)
            [a,b] = syntheticPair(false);
            a.timeSeries(end,:) = []; b.timeSeries(end,:) = [];
            row = score(a,b);
            testCase.verifyFalse(row.CompleteFinite);
            testCase.verifyFalse(row.CleanCompleteFinite);
        end

        function missingOrFailedContinuousCleanAuditRejectsComparison(testCase)
            [a,b] = syntheticPair(false);
            changed = rmfield(b,'decoderAudit');
            row = score(a,changed);
            testCase.verifyFalse(row.CleanGuardPass);
            b.decoderAudit.cleanCountConservationPass = false;
            row = score(a,b);
            testCase.verifyFalse(row.CleanGuardPass);
            testCase.verifyFalse(row.TaskSuccess);
        end

        function detectorEpisodesAndPreexistingSecondBurstRemainDistinct(testCase)
            [a,b] = syntheticPair(true);
            a.timeSeries.emiCountError(252:254) = 1;
            a.timeSeries.emiCountError(271:281) = 1;
            a.timeSeries.emiCountError(351:1801) = 1;
            a.timeSeries.emiCountError(1911:1921) = 1;
            a.timeSeries.emiCountError(3000:3001) = 1;
            a.timeSeries.alarm(253:281) = 1;
            a.timeSeries.alarm(291:301) = 1;
            a.timeSeries.alarm(361:1901) = 1;
            [row,~,episodes,bursts] = score(a,b);
            testCase.verifyEqual(episodes.Status,["detected";"preexisting_alarm"; ...
                "detected";"missed";"right_censored"]);
            testCase.verifyEqual(episodes.DetectionDelay_s(1),.001,'AbsTol',1e-12);
            testCase.verifyEqual(episodes.OriginBurst,[1;1;1;2;2]);
            testCase.verifyEqual(row.FalseAlarmEpisodes,1);
            testCase.verifyGreaterThan(row.NoncorruptionAlarmSamples,1);
            testCase.verifyEqual(row.Burst2DetectionStatus,"preexisting_corruption");
            testCase.verifyTrue(bursts.PreexistingCorruption(2));
            testCase.verifyEqual(bursts.NewCorruptionEpisodes(2),2);
        end

        function noCorruptionIsNotCreditedAsDetection(testCase)
            [a,b] = syntheticPair(true);
            a.timeSeries.alarm(501:510) = 1;
            [row,~,episodes,bursts] = score(a,b);
            testCase.verifyEqual(row.DetectionStatus,"no_detectable_opportunity");
            testCase.verifyEmpty(episodes);
            testCase.verifyEqual(bursts.Status,repmat("no_detectable_opportunity",2,1));
            testCase.verifyEqual(row.FalseAlarmEpisodes,1);
        end

        function sharedFloorAppliesToBothAggregateSides(testCase)
            m = assessmentMatrix(.01,.02);
            m.TaskSuccess(m.Fixture=="EVAL01"&m.Arm=="BASELINE") = false;
            result = fourway_assess(m);
            testCase.verifyEqual(result.baseline_normalized_mean,.04,'AbsTol',1e-14);
            testCase.verifyEqual(result.combined_normalized_mean,.08,'AbsTol',1e-14);
            testCase.verifyLessThan(result.combined_normalized_mean,.9);
            testCase.verifyFalse(result.aggregate_gate);
            testCase.verifyFalse(result.combined_benefit_demonstrated);
        end

        function improvementWithoutRescuedFailureIsNotBenefit(testCase)
            result = fourway_assess(assessmentMatrix(.2,.1));
            testCase.verifyTrue(result.aggregate_gate);
            testCase.verifyFalse(result.rescued_failure_gate);
            testCase.verifyFalse(result.combined_benefit_demonstrated);
        end

        function oneRescueCanPassOnlyWhenEveryOtherGatePasses(testCase)
            m = assessmentMatrix(.6,.4);
            m.TaskSuccess(m.Fixture=="EVAL01"&m.Arm=="BASELINE") = false;
            result = fourway_assess(m);
            testCase.verifyTrue(result.combined_benefit_demonstrated);
            testCase.verifyEqual(result.rescued_failures,1);
            selected = m.Fixture=="EVAL02"&m.Arm=="COMBINED";
            m.PeakCurrent_A(selected) = 1.10001;
            result = fourway_assess(m);
            testCase.verifyFalse(result.current_gate);
            testCase.verifyFalse(result.combined_benefit_demonstrated);
        end

        function sameRowCountCannotHideMissingOrDuplicateArms(testCase)
            m = assessmentMatrix(.6,.4);
            m.Arm(m.Fixture=="EVAL01"&m.Arm=="EM_ONLY") = "SW_ONLY";
            testCase.verifyError(@() fourway_assess(m),'EMIProject:FourWayAssessment');
            m = assessmentMatrix(.6,.4);
            m.Fixture(m.Fixture=="EVAL12") = "EVAL11";
            testCase.verifyError(@() fourway_assess(m),'EMIProject:FourWayAssessment');
        end
    end
end

function varargout = score(a,b)
[varargout{1:nargout}] = fourway_metrics(a,b,[.255;1.705],[.250;1.700]);
end

function [a,b] = syntheticPair(protected)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
c = jsondecode(fileread(fullfile(root,'04_EMI_Models','four_way_emi_configuration.json')));
t = (0:3000)'*.001; n = numel(t);
trace = table(t,'VariableNames',{'time_s'});
zeroNames = ["position_rad","velocity_rad_s","current_A","command_V", ...
    "requestedReference_rad","reference_rad","mode","alarm", ...
    "idealMinusDecodedCount","emiCountError","continuousQuantizationError_rad"];
for field = zeroNames, trace.(field) = zeros(n,1); end
trace.commandLimit_V = 24*ones(n,1);
trace.sourceIndex = (1:n)';trace.sampleReceived = true(n,1);
trace.receiverDomainFailed = false(n,1);
trace.commandSlewLimited = false(n,1);trace.commandAmplitudeLimited = false(n,1);
run = struct('protectionEnabled',protected,'params', ...
    struct('control',struct('sampleTime_s',.001)));
f = struct('id',"DEV01",'partition',"development",'arm',"BASELINE", ...
    'Ccp_pF',10,'Ccn_pF',9,'Cdiff_pF',100,'task_sign',1,'phase_s',0, ...
    'closure_s',1e-7,'exposed',true,'run',run,'design',c);
if protected, f.arm = "SW_ONLY"; end
audit = struct('observedTransitions',0,'shadowTransitions',0,'extraTransitions',0, ...
    'missingTransitions',0,'invalidTransitions',0,'eventMatchingAllowance_s',1e-6, ...
    'cleanSequencePass',true,'cleanDelayPass',true,'cleanMaximumDelay_s',0, ...
    'cleanCountConservationPass',true);
a = struct('timeSeries',trace,'fixture',f,'run',run,'decoderAudit',audit);
b = a;b.fixture.exposed = false;
end

function m = assessmentMatrix(baseline,combined)
ids = compose("EVAL%02d",(1:12)');arms = ["BASELINE";"EM_ONLY";"SW_ONLY";"COMBINED"];
m = table(repelem(ids,4),repmat("evaluation",48,1),repmat(arms,12,1), ...
    true(48,1),baseline*ones(48,1),ones(48,1),ones(48,1),true(48,1), ...
    'VariableNames',{'Fixture','Partition','Arm','ExecutionGuardPass', ...
    'WindowPairedRMSE_deg','WindowPairedPeak_deg','PeakCurrent_A','TaskSuccess'});
m.WindowPairedRMSE_deg(m.Arm=="COMBINED") = combined;
end
