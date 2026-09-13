classdef TestHybridCorrectionPolicy < matlab.unittest.TestCase
    methods(Test)
        function learnsFromCompletedPredictions(testCase)
            m=localModel();r=ones(400,1);u=zeros(400,1);
            [w,diagnostic]=hybrid_correction_weight(m,r,u,[110,200,300]);
            testCase.verifyEqual(w,[0,1,1]);
            testCase.verifyEqual(diagnostic.reason(1),"insufficient_history");
            testCase.verifyEqual(diagnostic.pastSelectedMSE(2),0,'AbsTol',1e-14);
        end
        function harmfulCorrectionSelectsPhysics(testCase)
            m=localModel();m.A(2,:)=[-1,0];
            w=hybrid_correction_weight(m,ones(300,1),zeros(300,1),200);
            testCase.verifyEqual(w,0);
        end
        function fractionalWeightCanWin(testCase)
            m=localModel();m.A(2,:)=[2,0];
            w=hybrid_correction_weight(m,ones(300,1),zeros(300,1),200);
            testCase.verifyEqual(w,.5);
        end
        function futureSuffixCannotAffectWeight(testCase)
            m=localModel();r=ones(400,1);u=zeros(400,1);
            [before,d1]=hybrid_correction_weight(m,r,u,[200,250]);
            r(251:end)=NaN;u(250:end)=Inf;
            [after,d2]=hybrid_correction_weight(m,r,u,[200,250]);
            testCase.verifyEqual(after,before);testCase.verifyEqual(d2,d1);
        end
        function domainAndNumericalFailuresRejectCorrection(testCase)
            m=localModel();r=ones(300,1);r(200)=10;
            [w,d]=hybrid_correction_weight(m,r,zeros(300,1),200);
            testCase.verifyEqual(w,0);testCase.verifyEqual(d.reason,"outside_training_domain");
            m.A(2,2)=Inf;r(200)=1;
            [w,d]=hybrid_correction_weight(m,r,zeros(300,1),200);
            testCase.verifyEqual(w,0);testCase.verifyTrue(d.learnedCandidateNonfinite);
        end
        function policyRequiresZeroAndBoundedWeights(testCase)
            m=localModel();m.correctionPolicy.weights=[.5,1];
            testCase.verifyError(@()hybrid_correction_weight(m,ones(300,1),zeros(300,1),200),'HybridWeight:Policy');
        end
        function delayedInputPredictionsUseOnlyCompletedIntervals(testCase)
            m=localModel();m.delay=2;
            m.historyMean=[.1;.1;.1;.2;.2];m.historyScale=[2;2;2;3;3];
            m.inputMean=.2;m.inputScale=3;m.outputMean=.1;m.outputScale=2;
            m.A=zeros(6);m.A(1,1)=1;m.A(2,:)=[.3,.4,-.2,.1,.5,-.3];
            m.B=[0;.8;0;0;0;0];m.C=[0,2,0,0,0,0];
            m.training.minimumHistory=-10*ones(5,1);m.training.maximumHistory=10*ones(5,1);
            k=(1:400)';u=.3*sin(.13*k)+.1*cos(.03*k);r=.2*ones(400,1);
            manualPrediction=NaN(size(r));
            for target=4:numel(r)
                % Independent physical-coordinate equation: input(target-1)
                % is the last completed interval, never input(target).
                manualPrediction(target)=.1+2*(.3 ...
                    +.4*(r(target-1)-.1)/2-.2*(r(target-2)-.1)/2 ...
                    +.1*(r(target-3)-.1)/2+.5*(u(target-2)-.2)/3 ...
                    -.3*(u(target-3)-.2)/3+.8*(u(target-1)-.2)/3);
                r(target)=manualPrediction(target)+.02*sin(.19*target);
            end
            origins=[123,200,275];[batch,diagnostic]=hybrid_correction_weight(m,r,u,origins);
            for j=1:numel(origins)
                origin=origins(j);indices=origin-19:origin;
                observed=r(indices);predicted=manualPrediction(indices);
                mse=mean((observed-predicted*m.correctionPolicy.weights).^2,1);
                [best,index]=min(mse);baseline=mean(observed.^2);
                gain=(baseline-best)/max(baseline,eps*m.outputScale^2);
                expected=0;
                if m.correctionPolicy.weights(index)>0 && gain>m.correctionPolicy.minRelativeImprovement
                    expected=m.correctionPolicy.weights(index);
                else,best=baseline;end
                testCase.verifyEqual(batch(j),expected);
                testCase.verifyEqual(diagnostic.pastPhysicsMSE(j),baseline,'AbsTol',1e-13);
                testCase.verifyEqual(diagnostic.pastSelectedMSE(j),best,'AbsTol',1e-13);
                testCase.verifyEqual(diagnostic.pastRelativeImprovement(j),gain,'AbsTol',1e-13);
                [single,singleDiagnostic]=hybrid_correction_weight(m,r(1:origin),u(1:origin-1),origin);
                testCase.verifyEqual(single,batch(j));
                localVerifyDiagnostic(testCase,singleDiagnostic,diagnostic(j,:));
            end
            alteredR=r;alteredU=u;
            alteredR(origins(1)+1:end)=alteredR(origins(1)+1:end)+100;
            alteredU(origins(1):end)=alteredU(origins(1):end)-100;
            [changed,changedDiagnostic]=hybrid_correction_weight(m,alteredR,alteredU,origins);
            testCase.verifyEqual(changed(1),batch(1));
            localVerifyDiagnostic(testCase,changedDiagnostic(1,:),diagnostic(1,:));
        end
        function endpointPairingRejectsDifferentOrigins(testCase)
            % Same counts and errors must not conceal different paired origins.
            e=table(["Nominal physics";"Nominal physics";"EDMD hybrid";"EDMD hybrid"], ...
                repmat("unit",4,1),repmat("run",4,1),ones(4,1),ones(4,1), ...
                [201;221;201;241],50*ones(4,1),.05*ones(4,1), ...
                [1;2;1;2],[1;2;1;2],[1;2;1;2],false(4,1),true(4,1), ...
                false(4,1),true(4,1),false(4,1), ...
                'VariableNames',{'modelName','regime','runName','runIndex','seed','originIndex', ...
                'horizonSamples','horizonSeconds','truthError','measurementError','posteriorTruthError', ...
                'nonfinite','reversalLabelAvailable','nearReversal','awayFromReversal','targetInStartup'});
            testCase.verifyError(@()hybrid_endpoint_summary(e),'HybridEndpoints:Pairing');
            e.originIndex(4)=221;
            [summary,perRun,pairs]=hybrid_endpoint_summary(e);
            [shuffledSummary,shuffledRuns,shuffledPairs]=hybrid_endpoint_summary(e([2,1,4,3],:));
            testCase.verifyEqual(shuffledSummary,summary);testCase.verifyEqual(shuffledRuns,perRun);
            testCase.verifyEqual(shuffledPairs,pairs);
            testCase.verifyEqual(pairs.truthRMSEDelta,zeros(height(pairs),1));
        end
    end
end
function localVerifyDiagnostic(testCase,actual,expected)
% Different batch widths can change the last bits of matrix products.
% The chosen action, reason, sample identity and domain/failure flags are exact.
exact={'originIndex','correctionWeight','reason','historyInTrainingDomain','learnedCandidateNonfinite'};
numeric={'pastPhysicsMSE','pastSelectedMSE','pastRelativeImprovement'};
testCase.verifyEqual(actual(:,exact),expected(:,exact));
testCase.verifyEqual(actual{:,numeric},expected{:,numeric},'RelTol',2e-14,'AbsTol',1e-18);
end
function m=localModel()
m=struct('delay',0,'degree',1,'sampleTime',.001,'historyMean',0,'historyScale',1, ...
    'A',[1,0;0,1],'B',[0;0],'C',[0,1],'inputMean',0,'inputScale',1, ...
    'outputMean',0,'outputScale',1,'training',struct('minimumHistory',-2,'maximumHistory',2), ...
    'correctionPolicy',struct('windowSamples',20,'minRelativeImprovement',.1, ...
    'weights',[0,.25,.5,1],'domainMargin',.1));
end
