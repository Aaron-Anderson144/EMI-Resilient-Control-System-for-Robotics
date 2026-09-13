classdef TestHybridCorrectionWeight < matlab.unittest.TestCase
    methods (Test)
        function zeroWeightIsExactlyPhysicsWithNonfiniteLearnedOperator(testCase)
            config=localConfig();model=localModel();inputs=[1;2;0];origin=[2;0;0];
            [physics,physicsDiagnostic]=hybrid_forecast(config,origin,[],[],inputs,[],"physics");
            for corruptValue=[Inf,NaN,realmax]
                broken=model;broken.A(2,2)=corruptValue;
                [forecast,diagnostic]=hybrid_forecast(config,origin,2,[],inputs,broken,"learned",0);
                testCase.verifyEqual(forecast,physics);
                testCase.verifyEqual(diagnostic.posteriorPosition,physicsDiagnostic.posteriorPosition);
                testCase.verifyEqual(diagnostic.predictedInnovation,zeros(3,1));
                testCase.verifyFalse(any(diagnostic.nonfinite,'all'));
                testCase.verifyTrue(all(diagnostic.learnedCandidateNonfinite,'all'));
                testCase.verifyTrue(all(~isfinite(diagnostic.rawPredictedInnovation),'all'));
                testCase.verifyEqual(diagnostic.correctionWeight,0);
            end
        end
        function unitWeightPreservesKnownOriginalRecursion(testCase)
            config=localConfig();model=localModel();inputs=[1;2;0];
            [default,defaultDiagnostic]=hybrid_forecast(config,[2;0;0],2,[],inputs,model,"learned");
            [weighted,diagnostic]=hybrid_forecast(config,[2;0;0],2,[],inputs,model,"learned",1);
            testCase.verifyEqual(weighted,[4.1;6.3;6.3],'AbsTol',1e-14);
            testCase.verifyEqual(diagnostic.posteriorPosition,[3.55;5.925;6.1125],'AbsTol',1e-14);
            testCase.verifyEqual(diagnostic.predictedInnovation,[1.1;.75;.375],'AbsTol',1e-14);
            testCase.verifyEqual(diagnostic.rawPredictedInnovation,diagnostic.predictedInnovation);
            testCase.verifyEqual(weighted,default);
            testCase.verifyEqual(diagnostic,defaultDiagnostic);
        end
        function intermediateWeightUsesAppliedCorrectionInBothRecursions(testCase)
            config=localConfig();model=localModel();inputs=[1;2;0];
            [forecast,diagnostic]=hybrid_forecast(config,[2;0;0],2,[],inputs,model,"learned",.25);
            % Raw residuals follow r_next=.5*r+.1*u independently of the
            % corrected observer; output adds .25*r and posterior adds .125*r.
            testCase.verifyEqual(diagnostic.rawPredictedInnovation,[1.1;.75;.375],'AbsTol',1e-14);
            testCase.verifyEqual(diagnostic.predictedInnovation,[.275;.1875;.09375],'AbsTol',1e-14);
            testCase.verifyEqual(forecast,[3.275;5.325;5.325],'AbsTol',1e-14);
            testCase.verifyEqual(diagnostic.posteriorPosition,[3.1375;5.23125;5.278125],'AbsTol',1e-14);
            testCase.verifyFalse(any(diagnostic.learnedCandidateNonfinite,'all'));
        end
        function batchedWeightsAreFixedAndIndependentPerOrigin(testCase)
            config=localConfig();model=localModel();inputs=[1,2,-1;2,0,1;0,-1,2];
            origins=[2,4,-1;0,0,0;0,0,0];histories=[2,3,4];weights=[0,.25,1];
            [batch,diagnostic]=hybrid_forecast(config,origins,histories,zeros(0,3),inputs,model,"learned",weights);
            for j=1:3
                [single,singleDiagnostic]=hybrid_forecast(config,origins(:,j),histories(j),[],inputs(:,j),model,"learned",weights(j));
                testCase.verifyEqual(batch(:,j),single);
                testCase.verifyEqual(diagnostic.predictedInnovation(:,j),singleDiagnostic.predictedInnovation);
                testCase.verifyEqual(diagnostic.rawPredictedInnovation(:,j),singleDiagnostic.rawPredictedInnovation);
            end
            testCase.verifyEqual(diagnostic.correctionWeight,weights);
            [scalar,scalarDiagnostic]=hybrid_forecast(config,origins,histories,zeros(0,3),inputs,model,"learned",.25);
            row=hybrid_forecast(config,origins,histories,zeros(0,3),inputs,model,"learned",[.25,.25,.25]);
            testCase.verifyEqual(scalar,row);
            testCase.verifyEqual(scalarDiagnostic.correctionWeight,[.25,.25,.25]);
        end
        function zeroWeightIsolatesFailureWithinBatch(testCase)
            config=localConfig();model=localModel();model.A(2,2)=Inf;
            inputs=[1,2;2,0;0,-1];origins=[2,4;0,0;0,0];
            [forecast,diagnostic]=hybrid_forecast(config,origins,[2,3],zeros(0,2),inputs,model,"learned",[0,.5]);
            physics=hybrid_forecast(config,origins(:,1),[],[],inputs(:,1),[],"physics");
            testCase.verifyEqual(forecast(:,1),physics);
            testCase.verifyTrue(all(isnan(forecast(:,2))));
            testCase.verifyEqual(diagnostic.nonfinite,[false(3,1),true(3,1)]);
            testCase.verifyTrue(all(diagnostic.learnedCandidateNonfinite,'all'));
        end
        function invalidWeightsAndNonlearnedWeightsAreRejected(testCase)
            config=localConfig();model=localModel();origins=zeros(3,2);
            badWeights={-.01,1.01,NaN,Inf,1i,[],[0;1],[0,.5,1],ones(2)};
            for j=1:numel(badWeights)
                testCase.verifyError(@()hybrid_forecast(config,origins,[2,3],zeros(0,2),ones(3,2),model,"learned",badWeights{j}), ...
                    'HybridForecast:CorrectionWeight');
            end
            testCase.verifyError(@()hybrid_forecast(config,[2;0;0],[],[],ones(3,1),[],"physics",0), ...
                'HybridForecast:CorrectionWeight');
            testCase.verifyError(@()hybrid_forecast(config,[2;0;0],ones(20,1),[],ones(3,1),[],"persistent",.5), ...
                'HybridForecast:CorrectionWeight');
        end
        function futureSuffixCannotAlterPrefixAndInputsAreUnchanged(testCase)
            config=localConfig();model=localModel();origin=[2;0;0];history=2;
            inputs=[1;2;0;3];originalInputs=inputs;originalModel=model;originalConfig=config;
            [first,firstDiagnostic]=hybrid_forecast(config,origin,history,[],inputs,model,"learned",.25);
            changed=inputs;changed(3:4)=[-9;8];
            [second,secondDiagnostic]=hybrid_forecast(config,origin,history,[],changed,model,"learned",.25);
            testCase.verifyEqual(first(1:2),second(1:2));
            testCase.verifyEqual(firstDiagnostic.predictedInnovation(1:2),secondDiagnostic.predictedInnovation(1:2));
            testCase.verifyNotEqual(first(3:4),second(3:4));
            fullWeight=hybrid_forecast(config,origin,history,[],inputs,model,"learned",1);
            repeated=hybrid_forecast(config,origin,history,[],inputs,model,"learned",.25);
            testCase.verifyEqual(repeated,first);
            testCase.verifyNotEqual(fullWeight,first);
            testCase.verifyEqual(inputs,originalInputs);testCase.verifyEqual(model,originalModel);
            testCase.verifyEqual(config,originalConfig);testCase.verifyEqual(origin,[2;0;0]);
            testCase.verifyEqual(history,2);
        end
    end
end

function config=localConfig()
config=struct('A',eye(3),'B',[1;0;0],'C',[1,0,0],'L',[.5;0;0], ...
    'dt',.001,'quantum',2*pi/4096);
end

function model=localModel()
model=struct('delay',0,'degree',1,'sampleTime',.001,'historyMean',0,'historyScale',1, ...
    'A',[1,0;0,.5],'B',[0;.1],'C',[0,1],'inputMean',0,'inputScale',1,'outputMean',0);
end
