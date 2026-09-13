classdef TestEDMDPrototype < matlab.unittest.TestCase
    % Tests numerical prediction, causal timing and information boundaries.
    methods(Test)
        function linearInputTimingAndRollout(testCase)
            training=localLinear(1:5,180);
            model=edmd_fit(training,delay=2,degree=1,ridge=0,svdTolerance=1e-12);
            heldOut=localLinear(91,180); rec=heldOut{1}; k=20; H=60;
            predicted=edmd_predict(model,rec.y(k:-1:k-2),rec.u(k-1:-1:k-2),rec.u(k:k+H-1));
            testCase.verifyEqual(predicted,rec.y(k+1:k+H),'AbsTol',1e-10);
        end
        function quadraticOneStep(testCase)
            training=localQuadratic(11:16,200);
            model=edmd_fit(training,delay=0,degree=2,ridge=0,svdTolerance=1e-12);
            predicted=edmd_predict(model,.3,[],.4);
            testCase.verifyEqual(predicted,.72*.3+.10*.3^2+.14*.4,'AbsTol',1e-10);
        end
        function positiveRidgeMatchesIndependentNormalEquation(testCase)
            training=localQuadratic(31:36,160);ridge=.07;
            model=edmd_fit(training,delay=0,degree=2,ridge=ridge,svdTolerance=1e-12);
            pairs=edmd_snapshot_pairs(training,0);count=numel(pairs.U);
            % Construct the normalized scalar quadratic dictionary directly.
            % This oracle solves the regularized normal equation, independently
            % of the fitter's SVD/filter implementation and its sqrt(N) scaling.
            current=(pairs.H-model.outputMean)/model.outputScale;
            next=(pairs.Hnext-model.outputMean)/model.outputScale;
            regressor=[ones(1,count);current;current.^2; ...
                (pairs.U-model.inputMean)/model.inputScale];
            target=[ones(1,count);next;next.^2];
            gram=regressor*regressor'/count;
            testCase.verifyLessThan(cond(gram),1e4);
            expected=(target*regressor'/count)/(gram+ridge*eye(4));
            actual=[model.A,model.B];
            testCase.verifyEqual(actual(2:3,:),expected(2:3,:),'AbsTol',2e-12);
            testCase.verifyEqual(actual(1,:),[1,0,0,0]);
            testCase.verifyEqual(model.training.regressorRank,4);
            % Duplicating whole trajectories leaves a mean-loss ridge fit
            % unchanged; a mistaken sum-loss normalization would change it.
            repeated=edmd_fit([training,training],delay=0,degree=2,ridge=ridge,svdTolerance=1e-12);
            testCase.verifyEqual(repeated.A,model.A,'AbsTol',2e-12);
            testCase.verifyEqual(repeated.B,model.B,'AbsTol',2e-12);
        end
        function exactBookkeeping(testCase)
            model=edmd_fit(localLinear(1:5,100),delay=2,degree=2);
            h=[.2;-.1;.4;.7;-.3]; currentInput=.6;
            z=edmd_lift(model,h);
            next=model.A*z+model.B*((currentInput-model.inputMean)/model.inputScale);
            raw=model.historyMean+model.historyScale.*next(2:6);
            testCase.verifyEqual(next(1),1,'AbsTol',1e-14);
            testCase.verifyEqual(raw(2:5),[h(1:2);currentInput;h(4)],'AbsTol',1e-13);
        end
        function invalidSampleExcludesWholeHistory(testCase)
            records=localLinear(1,20); records{1}.valid(10)=false;
            p=edmd_snapshot_pairs(records,2);
            testCase.verifyEqual(numel(p.U),13);
            testCase.verifyFalse(any(ismember(p.sampleIndex,9:12)));
        end
        function noCrossRunPairs(testCase)
            records=localLinear(1:2,20); records{2}.y=records{2}.y+100;
            p=edmd_snapshot_pairs(records,2);
            testCase.verifyEqual(size(p.H,2),34);
            testCase.verifyLessThan(max(abs(p.Hnext(1,p.runIndex==1))),10);
            testCase.verifyGreaterThan(min(p.Hnext(1,p.runIndex==2)),90);
        end
        function rejectTimestampGap(testCase)
            records=localLinear(1,20); records{1}.t(10:end)=records{1}.t(10:end)+.001;
            testCase.verifyError(@()edmd_snapshot_pairs(records,2),'EDMD:Timestamps');
        end
        function rejectReceiverDomain(testCase)
            records=localLinear(1,20); records{1}.domainValid=false;
            testCase.verifyError(@()edmd_snapshot_pairs(records,2),'EDMD:ReceiverDomain');
        end
        function rejectUnexcitedInput(testCase)
            records=localLinear(1,100); records{1}.u(:)=0;
            testCase.verifyError(@()edmd_fit(records),'EDMD:Excitation');
        end
        function rejectChangedSampleTime(testCase)
            model=edmd_fit(localLinear(1:3,100),degree=1);
            records=localLinear(7,100); records{1}.t=2*records{1}.t;
            records{1}.sampleTime=.002;
            testCase.verifyError(@()edmd_score(model,records,1),'EDMD:SampleTime');
        end
        function loaderTruthExcludedAndDomainFailsClosed(testCase)
            tempFolder=tempname; mkdir(tempFolder);
            cleanup=onCleanup(@()rmdir(tempFolder)); %#ok<NASGU>
            t=table((0:19)'*.001,(1:20)'*.01,ones(20,1),(1:20)', ...
                ones(20,1),zeros(20,1),rand(20,1), ...
                'VariableNames',{'time_s','receivedMeasurement_rad','command_V', ...
                'sourceIndex','sampleReceived','receiverDomainFailed','position_rad'});
            file=fullfile(tempFolder,'controller.csv'); writetable(t,file);
            r1=edmd_load_controller(file);
            t.position_rad=t.position_rad+1000; writetable(t,file);
            r2=edmd_load_controller(file);
            testCase.verifyEqual(r1.y,r2.y); testCase.verifyEqual(r1.u,r2.u);
            t.sourceIndex(10)=9; writetable(t,file); r3=edmd_load_controller(file);
            testCase.verifyFalse(r3.valid(10));
            t.receiverDomainFailed(15)=1; writetable(t,file);
            testCase.verifyError(@()edmd_load_controller(file),'EDMD:ReceiverDomain');
            delete(file);
        end
        function divergentForecastIsCounted(testCase)
            records=localLinear(1:3,100); model=edmd_fit(records,degree=1);
            model.A(2,:)=realmax;
            metrics=edmd_score(model,records,20);
            testCase.verifyGreaterThan(metrics.unusableForecastCount,0);
            testCase.verifyTrue(isinf(metrics.outputRMSE));
        end
    end
end

function records=localLinear(seeds,n)
previous=rng; cleanup=onCleanup(@()rng(previous)); %#ok<NASGU>
records=cell(1,numel(seeds));
for j=1:numel(seeds)
    rng(seeds(j)); u=randn(n,1); y=zeros(n,1); y(1)=randn;
    for k=1:n-1, y(k+1)=.8*y(k)+.2*u(k)+.1; end
    records{j}=struct('y',y,'u',u,'t',(0:n-1)'*.001, ...
        'valid',true(n,1),'sampleTime',.001,'domainValid',true);
end
end

function records=localQuadratic(seeds,n)
records=localLinear(seeds,n);
for j=1:numel(records)
    rec=records{j}; rec.u=tanh(rec.u); rec.y(1)=tanh(rec.y(1));
    for k=1:n-1, rec.y(k+1)=.72*rec.y(k)+.10*rec.y(k)^2+.14*rec.u(k); end
    records{j}=rec;
end
end
