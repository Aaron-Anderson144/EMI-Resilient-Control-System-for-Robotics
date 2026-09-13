classdef TestHybridForecast < matlab.unittest.TestCase
    methods (Test)
        function physicsUsesKnownFutureInput(testCase)
            config=localConfig();
            [forecast,diagnostic]=hybrid_forecast(config,[2;0;0],[],[],[1;2;0],[],"physics");
            testCase.verifyEqual(forecast,[3;5;5],'AbsTol',1e-14);
            testCase.verifyEqual(diagnostic.predictedInnovation,zeros(3,1));
            testCase.verifyTrue(diagnostic.conditionalOnSuppliedInputs);
        end
        function persistentUsesOnlyTwentyNewestInnovations(testCase)
            config=localConfig();history=[2*ones(20,1);999];
            [forecast,diagnostic]=hybrid_forecast(config,[2;0;0],history,[],[1;2;0],[],"persistent");
            testCase.verifyEqual(forecast,[5;8;9],'AbsTol',1e-14);
            testCase.verifyEqual(diagnostic.posteriorPosition,[4;7;8],'AbsTol',1e-14);
        end
        function learnedInnovationAndPosteriorAreDistinct(testCase)
            config=localConfig();model=localModel();
            [forecast,diagnostic]=hybrid_forecast(config,[2;0;0],2,[],[1;2;0],model,"learned");
            testCase.verifyEqual(diagnostic.predictedInnovation,[1.1;.75;.375],'AbsTol',1e-14);
            testCase.verifyEqual(forecast,[4.1;6.3;6.3],'AbsTol',1e-14);
            testCase.verifyEqual(diagnostic.posteriorPosition,[3.55;5.925;6.1125],'AbsTol',1e-14);
        end
        function batchedOriginsMatchSingleOriginForecasts(testCase)
            config=localConfig();model=localModel();inputs=[1,2;2,0;0,-1];
            batch=hybrid_forecast(config,[2,4;0,0;0,0],[2,3],zeros(0,2),inputs,model,"learned");
            first=hybrid_forecast(config,[2;0;0],2,[],inputs(:,1),model,"learned");
            second=hybrid_forecast(config,[4;0;0],3,[],inputs(:,2),model,"learned");
            testCase.verifyEqual(batch,[first,second],'AbsTol',1e-14);
        end
        function numericalFailureIsRetainedAcrossFutureSteps(testCase)
            config=localConfig();model=localModel();model.A(2,2)=realmax;
            [forecast,diagnostic]=hybrid_forecast(config,[2;0;0],2,[],[1;2;0],model,"learned");
            testCase.verifyTrue(all(~isfinite(forecast)));
            testCase.verifyTrue(all(diagnostic.nonfinite));
        end
        function truthDoesNotEnterForecastAndFailuresCannotDisappearFromScores(testCase)
            rec=localRecord();model=localModel();
            [~,before]=hybrid_score({[],model},["Nominal physics","EDMD hybrid"],{rec},[1,3],20,.2);
            changed=rec;changed.truth(:,1)=changed.truth(:,1)+1;
            [~,after]=hybrid_score({[],model},["Nominal physics","EDMD hybrid"],{changed},[1,3],20,.2);
            testCase.verifyEqual(after.measurementRMSE,before.measurementRMSE,'AbsTol',1e-14);
            testCase.verifyTrue(all(after.truthRMSE~=before.truthRMSE));
            broken=model;broken.A(2,2)=Inf;
            [summary,failed]=hybrid_score({broken},"EDMD hybrid",{rec},[1,3],20,.2);
            testCase.verifyTrue(all(isinf(failed.truthRMSE)));
            testCase.verifyTrue(all(failed.nonfiniteForecastCount==failed.forecastCount));
            testCase.verifyTrue(all(isinf(summary.truthRMSE)));
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

function rec=localRecord()
t=(0:500)'*.001;y=.01*sin(2*pi*t);u=.1*cos(2*pi*t);
rec=struct('y',y,'u',u,'t',t,'valid',true(size(t)),'sampleTime',.001, ...
    'domainValid',true,'truth',[y,zeros(numel(t),2)],'id',"unit",'regime',"unit",'seed',1);
end
