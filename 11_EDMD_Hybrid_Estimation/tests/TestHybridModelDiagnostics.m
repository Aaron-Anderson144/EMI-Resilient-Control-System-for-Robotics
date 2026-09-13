classdef TestHybridModelDiagnostics < matlab.unittest.TestCase
    % Diagnostic outputs must not alter the production recursion or fit.
    methods (Test)
        function storedSpectrumRidgeAndConstantMode(testCase)
            model=localModel(.5,1);rec=localRecord(model,140,"closed");
            [description,spectrum,rollout]=hybrid_model_diagnostics( ...
                {[],model,[]},["Nominal physics","linear","Persistent innovation"], ...
                {rec},[1,3],20,0);
            testCase.verifyEqual(height(description),1);
            testCase.verifyEqual(description.modelName,"linear");
            testCase.verifyEqual(description.storedRegressorRank,2);
            testCase.verifyEqual(description.recomputedRetainedRank,2);
            testCase.verifyTrue(description.storedRankMatchesThreshold);
            testCase.verifyEqual(description.retainedSpectrumCondition,2);
            testCase.verifyEqual(description.smallestSingularValue,0);
            testCase.verifyEqual(description.smallestPositiveSingularValue,2);
            testCase.verifyEqual(description.fullSpectralRadius,1,'AbsTol',1e-14);
            testCase.verifyEqual(description.affineSpectralRadius,.5,'AbsTol',1e-14);
            testCase.verifyTrue(description.constantCoordinateIsExact);
            testCase.verifyEqual(description.knownConstantEigenvalue,1);
            testCase.verifyEqual(spectrum.retained,[true;true;false]);
            testCase.verifyEqual(spectrum.ridgeFilterFactor,[16/16.25;4/4.25;0], ...
                'AbsTol',1e-14);
            testCase.verifyEqual(spectrum.inverseGain,[4/16.25;2/4.25;0], ...
                'AbsTol',1e-14);
            testCase.verifyEqual(unique(rollout.modelName),"linear");
            testCase.verifyTrue(contains(description.coupledSensitivityStatus,"no raw augmented norm"));
        end

        function exactlyClosedLinearAndQuadraticModels(testCase)
            linear=localModel(-1,1);quadratic=localModel(-1,2);
            rec=localRecord(linear,170,"closed");
            [description,spectrum,rows]=hybrid_model_diagnostics( ...
                {linear,quadratic},["linear","quadratic"],{rec},[1,3,7],20,0);
            testCase.verifyLessThan(max(rows.oneStepLiftedRelativeError),1e-10);
            testCase.verifyLessThan(max(rows.oneStepInnovationRMSE),1e-12);
            testCase.verifyLessThan(max(rows.quadraticConsistencyRMSE),1e-12);
            testCase.verifyLessThan(max(rows.quadraticConsistencyRelativeError),1e-10);
            testCase.verifyEqual(rows.nonfiniteForecastCount,zeros(height(rows),1));
            testCase.verifyEqual(description.constantCoordinateResidual,[0;0]);
            q=spectrum(spectrum.modelName=="quadratic",:);
            testCase.verifyEqual(q.retained,[true;true;false;false]);
            testCase.verifyEqual(q.ridgeFilterFactor(3:4),[0;0]);
            testCase.verifyEqual(description.retainedSpectrumCondition,[2;2]);
            testCase.verifyEqual(description.positiveSpectrumCondition(2),4e10, ...
                'RelTol',1e-12);
            % The quadratic learned block has its own unit eigenvalue: only
            % the known constant coordinate is excluded from the affine block.
            testCase.verifyEqual(description.affineSpectralRadius,[1;1],'AbsTol',1e-14);
        end

        function inconsistentQuadraticCoordinateIsDiagnosticOnly(testCase)
            exact=localModel(-1,2);inconsistent=exact;
            inconsistent.A(3,1)=inconsistent.A(3,1)+.2;
            rec=localRecord(exact,140,"inconsistent");
            [~,~,rows]=hybrid_model_diagnostics({inconsistent},"quadratic",{rec},[1,3],20,0);
            run=rows(rows.rowScope=="run",:);
            testCase.verifyEqual(run.quadraticConsistencyRMSE,[.2;.6],'AbsTol',1e-10);
            testCase.verifyGreaterThan(min(run.oneStepLiftedRelativeError),0);
            % Accurate decoded innovation can coexist with an inconsistent
            % redundant quadratic state. Re-lifting during prediction would
            % reset this drift, contrary to the production recursion.
            testCase.verifyLessThan(max(run.oneStepInnovationRMSE),1e-12);
            testCase.verifyEqual(inconsistent.A(3,1),.21,'AbsTol',1e-14);
        end

        function futureObservationOnlyChangesHeldOutTarget(testCase)
            model=localModel(-1,2);rec=localRecord(model,110,"causal");
            [~,~,before]=hybrid_model_diagnostics({model},"quadratic",{rec},[1,5],1000,0);
            changed=rec;changed.y(102:end)=changed.y(102:end)+.04;
            changed.truth=NaN(numel(changed.y),3); % Never read by diagnostics.
            [~,~,after]=hybrid_model_diagnostics({model},"quadratic",{changed},[1,5],1000,0);
            testCase.verifyEqual(after.forecastCount,before.forecastCount);
            testCase.verifyEqual(after.quadraticConsistencyRMSE,before.quadraticConsistencyRMSE, ...
                'AbsTol',1e-14);
            testCase.verifyEqual(after.constantCoordinateRMSE,before.constantCoordinateRMSE);
            testCase.verifyEqual(after.nonfiniteForecastCount,before.nonfiniteForecastCount);
            testCase.verifyGreaterThan(min(after.oneStepInnovationRMSE),.03);
            testCase.verifyLessThan(max(before.oneStepInnovationRMSE),1e-12);
        end

        function trajectoryMeansDoNotPoolOrigins(testCase)
            model=localModel(.5,1);other=localModel(-1,1);
            records={localRecord(model,140,"short"),localRecord(other,300,"long")};
            [~,~,rows]=hybrid_model_diagnostics({model},"linear",records,1,20,0);
            run=rows(rows.rowScope=="run",:);summary=rows(rows.rowScope=="trajectory_equal_weight",:);
            testCase.verifyEqual(height(run),2);testCase.verifyEqual(height(summary),1);
            testCase.verifyEqual(summary.runCount,2);
            testCase.verifyEqual(summary.forecastCount,sum(run.forecastCount));
            testCase.verifyEqual(summary.oneStepInnovationRMSE,mean(run.oneStepInnovationRMSE), ...
                'AbsTol',1e-14);
            testCase.verifyEqual(summary.oneStepLiftedRelativeError,mean(run.oneStepLiftedRelativeError), ...
                'AbsTol',1e-14);
            pooled=sqrt(sum(run.forecastCount.*run.oneStepInnovationRMSE.^2)/sum(run.forecastCount));
            testCase.verifyGreaterThan(abs(summary.oneStepInnovationRMSE-pooled),1e-3);
        end

        function failuresRemainInEveryHorizonAndSummary(testCase)
            model=localModel(.5,2);rec=localRecord(model,140,"failure");
            broken=model;broken.A(2,2)=Inf;
            [description,~,rows]=hybrid_model_diagnostics({broken},"broken",{rec},[1,3],20,0);
            testCase.verifyTrue(isinf(description.affineSpectralRadius));
            testCase.verifyTrue(all(isinf(rows.oneStepLiftedRelativeError)));
            testCase.verifyTrue(all(isinf(rows.oneStepInnovationRMSE)));
            testCase.verifyTrue(all(isinf(rows.quadraticConsistencyRMSE)));
            testCase.verifyEqual(rows.nonfiniteForecastCount,rows.forecastCount);
            testCase.verifyEqual(rows.oneStepNonfiniteCount,rows.oneStepPairCount);
            testCase.verifyEqual(rows.consistencyNonfiniteCount,rows.forecastCount);
            testCase.verifyEqual(rows.nonfiniteForecastFraction,ones(height(rows),1));
        end

        function allEmptyModelsReturnTypedEmptyTables(testCase)
            [description,spectrum,rows]=hybrid_model_diagnostics({[],[]}, ...
                ["Nominal physics","Persistent innovation"],{struct()},1,20,0);
            testCase.verifyEqual(height(description),0);testCase.verifyEqual(height(spectrum),0);
            testCase.verifyEqual(height(rows),0);
            testCase.verifyTrue(ismember('rowScope',rows.Properties.VariableNames));
        end

        function commonOriginsRespectPreparationAndPersistenceHistory(testCase)
            model=localModel(-1,1);rec=localRecord(model,140,"warmup");
            [~,~,single]=hybrid_model_diagnostics({model},"linear",{rec},1,1,0);
            testCase.verifyEqual(single.forecastCount(single.rowScope=="run"),39);
            [~,~,paired]=hybrid_model_diagnostics({[],model}, ...
                ["Persistent innovation","linear"],{rec},1,1,0);
            testCase.verifyEqual(paired.forecastCount(paired.rowScope=="run"),20);
            short=localRecord(model,101,"short");
            testCase.verifyError(@()hybrid_model_diagnostics({model},"linear",{short},1,1,0), ...
                'HybridDiagnostics:ShortRecord');
            short=localRecord(model,120,"short_persistent");
            testCase.verifyError(@()hybrid_model_diagnostics({[],model}, ...
                ["Persistent innovation","linear"],{short},1,1,0), ...
                'HybridDiagnostics:ShortRecord');
        end
    end
end

function model=localModel(a,degree)
% A genuinely closed affine scalar map and (optionally) its exact square.
c=.1;A=[1,0;c,a];C=[0,.25];s=[4;2;0];
if degree==2
    A=[1,0,0;c,a,0;c^2,2*c*a,a^2];C=[0,.25,0];s=[4;2;1e-10;0];
end
model=struct('delay',0,'degree',degree,'sampleTime',.001, ...
    'historyMean',.02,'historyScale',.25,'A',A,'B',zeros(size(A,1),1),'C',C, ...
    'inputMean',0,'inputScale',1,'outputMean',.02,'outputScale',.25, ...
    'ridge',.25,'svdTolerance',1e-9, ...
    'training',struct('regressorRank',2,'singularValues',s));
end

function rec=localRecord(model,n,name)
% Construct encoder observations whose *causal nominal-observer innovations*
% follow a known scalar affine law. The generator never propagates a lifted
% square coordinate, so the quadratic-closure check is independent of it.
config=hybrid_reference_observer();t=(0:n-1)'*.001;
u=.1*cos(7*t);y=zeros(n,1);state=config.initialState;q=.3;
for k=1:n
    if k>1
        state=config.A*state+config.B*u(k-1);
        q=model.A(2,1)+model.A(2,2)*q;
    end
    innovation=model.outputMean+model.historyScale(1)*q;
    y(k)=config.C*state+innovation;
    state=state+config.L*innovation;
end
rec=struct('y',y,'u',u,'t',t,'valid',true(n,1),'sampleTime',.001, ...
    'domainValid',true,'id',name,'regime',"synthetic",'seed',1);
end
