classdef TestHybridEndpointDiagnostics < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addCode(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'code')));
        end
    end
    methods (Test)
        function allHistoriesExcludePreparationWarmup(testCase)
            rec=localRecord();model=localModel();
            [~,~,plain]=hybrid_score({model},"EDMD hybrid",{rec},1,1000,0);
            testCase.verifyEqual(plain.originIndex,101);
            model.delay=2;model.historyMean=zeros(5,1);model.historyScale=ones(5,1);
            model.A=eye(6);model.B=zeros(6,1);model.C=[0,1,0,0,0,0];
            [~,~,delayed]=hybrid_score({model},"EDMD hybrid",{rec},1,1000,0);
            testCase.verifyEqual(delayed.originIndex,103);
            testCase.verifyEqual(delayed.originIndex-model.delay,101);
            [~,~,paired]=hybrid_score({[],model}, ...
                ["Persistent innovation","EDMD hybrid"],{rec},1,1000,0);
            testCase.verifyEqual(paired.originIndex,[120;120]);
            testCase.verifyEqual(paired.originIndex(1)-19,101);
            % The explicit time warmup still dominates when it is longer.
            [~,~,default]=hybrid_score({[],model}, ...
                ["Persistent innovation","EDMD hybrid"],{rec},1,1000,.2);
            testCase.verifyEqual(default.originIndex,[201;201]);
            model.delay=110;model.historyMean=zeros(221,1);model.historyScale=ones(221,1);
            model.A=eye(222);model.B=zeros(222,1);model.C=[0,1,zeros(1,220)];
            [~,~,long]=hybrid_score({model},"EDMD hybrid",{rec},1,1000,.2);
            testCase.verifyEqual(long.originIndex,211);
            testCase.verifyEqual(long.originIndex-model.delay,101);
        end

        function optionalDiagnosticsReproduceOriginalScores(testCase)
            rec=localRecord();models={[],[],localModel()};
            names=["Nominal physics","Persistent innovation","EDMD hybrid"];
            [before,beforeRuns]=hybrid_score(models,names,{rec},[1,20,50],20,.2);
            [after,runs,endpoints]=hybrid_score(models,names,{rec},[1,20,50],20,.2);
            testCase.verifyEqual(after,before);testCase.verifyEqual(runs,beforeRuns);
            [~,eventRuns]=hybrid_endpoint_summary(endpoints);
            for k=1:height(runs)
                row=runs(k,:);
                part=endpoints(endpoints.modelName==row.modelName & ...
                    endpoints.runIndex==row.runIndex & endpoints.horizonSamples==row.horizonSamples,:);
                testCase.verifyEqual(height(part),row.forecastCount);
                testCase.verifyEqual(sqrt(mean(part.truthError.^2)),row.truthRMSE);
                testCase.verifyEqual(sqrt(mean(part.measurementError.^2)),row.measurementRMSE);
                testCase.verifyEqual(sqrt(mean(part.posteriorTruthError.^2)),row.posteriorTruthRMSE);
                event=eventRuns(eventRuns.modelName==row.modelName & eventRuns.runIndex==row.runIndex & ...
                    eventRuns.horizonSamples==row.horizonSamples & eventRuns.eventGroup=="all",:);
                testCase.verifyEqual(event.truthRMSE,row.truthRMSE);
                testCase.verifyEqual(event.truthMaxAbsoluteError,row.peakAbsoluteError);
            end
            testCase.verifyFalse(any(endpoints.targetInStartup));
            testCase.verifyGreaterThanOrEqual(min(endpoints.originTimeSeconds),.2);
            testCase.verifyEqual(endpoints.targetIndex,endpoints.originIndex+endpoints.horizonSamples);
        end

        function offlineTruthAndEventsCannotChangePredictions(testCase)
            rec=localRecord();
            [~,~,before]=hybrid_score({localModel()},"EDMD hybrid",{rec},[1,20],20,.2);
            changed=rec;changed.truth(:,1)=changed.truth(:,1)+1;
            changed.truth(:,2)=ones(size(changed.y));
            [~,~,after]=hybrid_score({localModel()},"EDMD hybrid",{changed},[1,20],20,.2);
            testCase.verifyEqual(after.predictedPosition,before.predictedPosition);
            testCase.verifyEqual(after.predictedInnovation,before.predictedInnovation);
            testCase.verifyEqual(after.posteriorPosition,before.posteriorPosition);
            testCase.verifyEqual(after.measurementError,before.measurementError);
            testCase.verifyEqual(after.truthError,before.truthError-1,'AbsTol',1e-14);
            testCase.verifyTrue(any(before.nearReversal));testCase.verifyFalse(any(after.nearReversal));
        end

        function reversalWindowBoundariesAndMissingVelocity(testCase)
            rec=localRecord();rec.truth(:,2)=1;rec.truth(rec.t>=.4,2)=-1;
            [~,~,endpoints]=hybrid_score({[]},"Nominal physics",{rec},1,1,.2);
            for target=[.349,.350,.450,.451]
                selected=abs(endpoints.targetTimeSeconds-target)<1e-12;
                testCase.verifyEqual(sum(selected),1);
                testCase.verifyEqual(endpoints.nearReversal(selected),target>=.35 && target<=.45);
            end
            testCase.verifyTrue(all(endpoints.nearReversal | endpoints.awayFromReversal));
            missing=rec;missing.truth=missing.truth(:,1);
            [~,~,without]=hybrid_score({[]},"Nominal physics",{missing},1,1,.2);
            testCase.verifyEqual(without.predictedPosition,endpoints.predictedPosition);
            testCase.verifyFalse(any(without.reversalLabelAvailable));
            testCase.verifyFalse(any(without.nearReversal | without.awayFromReversal));
            [summary,perRun]=hybrid_endpoint_summary(without);
            testCase.verifyEqual(summary.runCount(summary.eventGroup~="all"),zeros(2,1));
            testCase.verifyEqual(perRun.eventGroup,"all");
            testCase.verifyEqual(perRun.unknownReversalForecastCount,height(without));
        end

        function zeroPlateauUsesFirstOppositeNonzeroSample(testCase)
            rec=localRecord();rec.truth(:,2)=1;
            rec.truth(rec.t>=.390 & rec.t<.401,2)=0;rec.truth(rec.t>=.401,2)=-1;
            [~,~,endpoints]=hybrid_score({[]},"Nominal physics",{rec},1,1,.2);
            testCase.verifyFalse(endpoints.nearReversal(abs(endpoints.targetTimeSeconds-.350)<1e-12));
            testCase.verifyTrue(endpoints.nearReversal(abs(endpoints.targetTimeSeconds-.351)<1e-12));
            rec.truth(:,2)=1;rec.truth(1:50,2)=0;
            [~,~,started]=hybrid_score({[]},"Nominal physics",{rec},1,1,.2);
            testCase.verifyFalse(any(started.nearReversal));
        end

        function failuresRemainInMetricsAndPairedRecords(testCase)
            rec=localRecord();bad=localModel();bad.A(2,2)=Inf;
            [~,runs,endpoints]=hybrid_score({[],bad,bad}, ...
                ["Nominal physics","Linear hybrid","EDMD hybrid"],{rec},[1,20],20,.2);
            [summary,eventRuns,pairs]=hybrid_endpoint_summary(endpoints);
            failed=endpoints.modelName=="EDMD hybrid";
            testCase.verifyTrue(all(endpoints.nonfinite(failed)));
            testCase.verifyEqual(sum(endpoints.nonfinite),sum(runs.nonfiniteForecastCount));
            selected=summary.modelName=="EDMD hybrid" & summary.forecastCount>0;
            testCase.verifyTrue(all(isinf(summary.truthRMSE(selected))));
            testCase.verifyTrue(all(isinf(summary.truthP95AbsoluteError(selected))));
            selected=eventRuns.modelName=="EDMD hybrid";
            testCase.verifyTrue(all(eventRuns.nonfiniteForecastCount(selected)==eventRuns.forecastCount(selected)));
            both=pairs.modelName=="EDMD hybrid" & pairs.baseline=="Linear hybrid";
            testCase.verifyTrue(any(both));testCase.verifyTrue(all(pairs.bothFailed(both)));
            testCase.verifyTrue(all(isnan(pairs.truthRMSEDelta(both))));
            testCase.verifyFalse(any(pairs.modelWins(both)));
            finiteBaseline=pairs.modelName=="EDMD hybrid" & pairs.baseline=="Nominal physics";
            testCase.verifyTrue(all(isinf(pairs.truthRMSEDelta(finiteBaseline))));
        end

        function unequalOriginCountsStillGiveEqualTrajectoryWeight(testCase)
            first=localRecord();second=first;second.id="second";second.seed=2;
            [~,~,endpoints]=hybrid_score({[]},"Nominal physics",{first,second},1,20,.2);
            keep=endpoints.runIndex==1 | (endpoints.runIndex==2 & endpoints.originTimeSeconds<.3);
            endpoints=endpoints(keep,:);
            endpoints.truthError=1+2*(endpoints.runIndex==2);
            endpoints.measurementError=endpoints.truthError;
            endpoints.posteriorTruthError=endpoints.truthError;
            [summary,perRun]=hybrid_endpoint_summary(endpoints);
            allRows=summary(summary.eventGroup=="all",:);
            testCase.verifyEqual(allRows.runCount,2);
            testCase.verifyEqual(allRows.truthBias,2);testCase.verifyEqual(allRows.truthRMSE,2);
            testCase.verifyEqual(allRows.truthStd,0);testCase.verifyEqual(allRows.truthP95AbsoluteError,2);
            testCase.verifyEqual(allRows.truthMaxAbsoluteError,3);
            testCase.verifyNotEqual(allRows.truthRMSE,sqrt(mean(endpoints.truthError.^2)));
            testCase.verifyEqual(perRun.truthRMSE(perRun.eventGroup=="all"),[1;3]);
        end
    end
end

function model=localModel()
model=struct('delay',0,'degree',1,'sampleTime',.001,'historyMean',0,'historyScale',1, ...
    'A',[1,0;0,.5],'B',[0;.1],'C',[0,1],'inputMean',0,'inputScale',1,'outputMean',0);
end

function rec=localRecord()
t=(0:600)'*.001;y=.01*sin(2*pi*t);u=.1*cos(2*pi*t);
rec=struct('y',y,'u',u,'t',t,'valid',true(size(t)),'sampleTime',.001, ...
    'domainValid',true,'truth',[y,.02*pi*cos(2*pi*t),zeros(numel(t),1)], ...
    'id',"unit",'regime',"unit",'seed',1);
end
