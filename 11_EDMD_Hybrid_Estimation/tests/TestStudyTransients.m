classdef TestStudyTransients < matlab.unittest.TestCase
    properties
        ProjectRoot
    end
    methods (TestMethodSetup)
        function locateProject(testCase)
            testCase.ProjectRoot=fullfile(fileparts(fileparts(mfilename('fullpath'))),'reference_project');
        end
    end
    methods (Test)
        function explicitDefaultsPreserveGeneratedDataExactly(testCase)
            seeds=[3101,3102];regimes=["nominal","nonlinear"];
            options=struct('motionScenario',"multisine",'loadScenario',"smooth",'controllerGainScale',1);
            rngBefore=rng;
            [implicit,implicitMeta]=study_generate_records(testCase.ProjectRoot,seeds,regimes,.15);
            [explicit,explicitMeta]=study_generate_records(testCase.ProjectRoot,seeds,regimes,.15,options);
            testCase.verifyEqual(explicit,implicit);
            testCase.verifyEqual(explicitMeta,implicitMeta);
            testCase.verifyEqual(rng,rngBefore);
            for k=1:numel(seeds)
                testCase.verifyEqual(explicit{k}.y,implicit{k}.y);
                testCase.verifyEqual(explicit{k}.u,implicit{k}.u);
                testCase.verifyEqual(explicit{k}.truth,implicit{k}.truth);
            end
        end
        function stepLoadHasExactTimesAndRespectsEachRegimeBound(testCase)
            options=struct('loadScenario',"step");
            records=study_generate_records(testCase.ProjectRoot,[3201,3202], ...
                ["nominal","stress"],2.1,options);
            for k=1:numel(records)
                record=records{k};bound=record.parameters.loadBound_Nm;
                expected=zeros(size(record.t));expected(record.t>=1)=bound;expected(record.t>=2)=-bound;
                testCase.verifyEqual(record.offlineLoadTorque_Nm,expected);
                testCase.verifyLessThanOrEqual(max(abs(record.offlineLoadTorque_Nm)),bound);
                testCase.verifyEqual(record.scenarioSpecification.load.levels_Nm,[0,bound,-bound]);
                testCase.verifyTrue(record.domainValid);
                testCase.verifyTrue(all(record.valid));
                testCase.verifyFalse(isfield(record,'receiverDomainFailed'));
            end
            testCase.verifyEmpty(records{1}.offlineEventTimes.loadTransition_s);
            testCase.verifyEqual(records{2}.offlineEventTimes.loadTransition_s,[1,2]);
            first=study_generate_records(testCase.ProjectRoot,3202,"stress",1,options);
            testCase.verifyEqual(first{1}.offlineEventTimes.loadTransition_s,1);
            testCase.verifyEqual(first{1}.offlineLoadTorque_Nm(end),first{1}.parameters.loadBound_Nm);
            testCase.verifyEqual(first{1}.offlineLoadTorque_Nm(1:end-1),zeros(1000,1));
        end
        function reversalProfileIsSmoothBoundedAndPreciselySpecified(testCase)
            options=struct('motionScenario',"smooth_reversal");
            records=study_generate_records(testCase.ProjectRoot,3301,"varied",2.5,options);
            record=records{1};spec=record.referenceSpecification;amplitude=deg2rad(40);
            testCase.verifyEqual(record.offlineEventTimes.commandedReversal_s,[.75,1.5,2.25]);
            testCase.verifyEqual(record.reference([1,751,1501,2251]),[0;amplitude;-amplitude;amplitude],'AbsTol',1e-14);
            testCase.verifyEqual(record.referenceRate([1,751,1501,2251]),zeros(4,1),'AbsTol',1e-14);
            testCase.verifyGreaterThan(record.referenceRate(750),0);
            testCase.verifyLessThan(record.referenceRate(752),0);
            testCase.verifyLessThan(record.referenceRate(1500),0);
            testCase.verifyGreaterThan(record.referenceRate(1502),0);
            testCase.verifyLessThanOrEqual(max(abs(record.reference)),amplitude+eps);
            testCase.verifyLessThanOrEqual(max(abs(record.referenceRate)),spec.maximumRate_rad_s+eps(10));
            testCase.verifyLessThanOrEqual(spec.maximumRate_rad_s,10);
            testCase.verifyEqual(record.referenceRate(376),1.875*amplitude/.75,'AbsTol',1e-14);
            testCase.verifyEqual(record.referenceRate(1126),-1.875*2*amplitude/.75,'AbsTol',1e-14);
            testCase.verifyEqual(spec.normalizedPolynomialCoefficients,[0,0,0,10,-15,6]);
            testCase.verifyLessThan(max(abs(diff(record.referenceRate))),.02);
        end
        function changedControllerUsesReportedActualGains(testCase)
            options=struct('motionScenario',"smooth_reversal",'loadScenario',"step",'controllerGainScale',.6);
            [changed,meta]=study_generate_records(testCase.ProjectRoot,3401,"nonlinear",.2,options);
            options.controllerGainScale=1;
            baseline=study_generate_records(testCase.ProjectRoot,3401,"nonlinear",.2,options);
            record=changed{1};c=meta.controller;
            testCase.verifyEqual(c.Kp_V_rad,12*.6);testCase.verifyEqual(c.Kd_V_s_rad,.25*.6);
            testCase.verifyEqual(c.gainScale,.6);
            testCase.verifyEqual(record.scenarioSpecification.controllerGainScale,.6);
            testCase.verifyNotEqual(record.u,baseline{1}.u);
            testCase.verifyNotEqual(record.truth,baseline{1}.truth);
            testCase.verifyEqual(record.reference,baseline{1}.reference);
            testCase.verifyEqual(record.parameters,baseline{1}.parameters);
            velocity=0;decay=exp(-record.sampleTime/c.derivativeFilterTime_s);expected=zeros(size(record.u));
            for k=1:numel(record.y)
                if k>1,velocity=decay*velocity+(1-decay)*(record.y(k)-record.y(k-1))/record.sampleTime;end
                raw=c.Kp_V_rad*(record.reference(k)-record.y(k))-c.Kd_V_s_rad*velocity;
                expected(k)=max(-c.voltageLimit_V,min(c.voltageLimit_V,raw));
            end
            testCase.verifyEqual(record.u,expected,'AbsTol',1e-13);
        end
        function alternativeScenariosAreSeededWithoutChangingGlobalRandomState(testCase)
            options=struct('motionScenario',"smooth_reversal",'loadScenario',"step");rngBefore=rng;
            first=study_generate_records(testCase.ProjectRoot,3501,"stress",.1,options);
            second=study_generate_records(testCase.ProjectRoot,3501,"stress",.1,options);
            testCase.verifyEqual(first,second);testCase.verifyEqual(rng,rngBefore);
            testCase.verifyEmpty(first{1}.offlineEventTimes.loadTransition_s);
            testCase.verifyEmpty(first{1}.offlineEventTimes.commandedReversal_s);
            testCase.verifyTrue(contains(first{1}.scenarioSpecification.scope,'no receiver faults'));
        end
        function invalidScenarioOptionsAreRejected(testCase)
            invalid={[],"step",struct('unknown',1),struct('motionScenario',"abrupt"), ...
                struct('motionScenario',["multisine","smooth_reversal"]),struct('motionScenario',1), ...
                struct('loadScenario',"impulse"),struct('controllerGainScale',0), ...
                struct('controllerGainScale',-1),struct('controllerGainScale',NaN), ...
                struct('controllerGainScale',Inf),struct('controllerGainScale',1i), ...
                struct('controllerGainScale',[1,2]),struct('controllerGainScale',"1")};
            for k=1:numel(invalid)
                testCase.verifyError(@()study_generate_records(testCase.ProjectRoot,1,"nominal",.1,invalid{k}), ...
                    'EDMDStudy:Options');
            end
        end
    end
end
