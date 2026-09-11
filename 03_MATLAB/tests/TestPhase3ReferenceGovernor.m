classdef TestPhase3ReferenceGovernor < matlab.unittest.TestCase
    %TESTPHASE3REFERENCEGOVERNOR Causal reference bounds and opt-in isolation.
    methods (Test)
        function nominalConfigurationAndInitialStateAreDeclared(testCase)
            [p,o,c]=localConfiguration();s=phase3_reference_governor_initialize(c);
            testCase.verifyEqual(c.sampleTime_s,p.control.sampleTime_s);
            testCase.verifyEqual([c.maxVelocity_rad_s,c.maxAcceleration_rad_s2,c.positionLimit_rad], ...
                [10,200,deg2rad(120)]);
            testCase.verifyEqual(c.beta,.01,'AbsTol',1e-16);
            testCase.verifyEqual([s.slewReference_rad,s.shapedReference_rad,s.velocity_rad_s], ...
                [o.initialEstimate(1),o.initialEstimate(1),0]);
            testCase.verifyEqual(s.sampleIndex,0);
        end

        function initialPositionComesFromObserverDeclaration(testCase)
            p=actuator_parameters();o=phase3_observer_configuration(p,struct('initialEstimate',[.3;2;-.2]));
            c=phase3_motion_configuration(p,o);s=phase3_reference_governor_initialize(c);
            testCase.verifyEqual([s.slewReference_rad,s.shapedReference_rad,s.velocity_rad_s],[.3,.3,0]);
            [~,d]=phase3_reference_governor_step(s,0);
            testCase.verifyEqual(d.slewReference_rad,.29,'AbsTol',1e-14);
            testCase.verifyEqual(d.shapedReference_rad,.2999,'AbsTol',1e-14);
            testCase.verifyEqual(d.velocity_rad_s,-.1,'AbsTol',1e-12);
        end

        function stepConvergesWithoutPositionOvershoot(testCase)
            [~,~,c]=localConfiguration();s=phase3_reference_governor_initialize(c);
            values=zeros(2000,3);
            for k=1:2000
                [s,d]=phase3_reference_governor_step(s,1.5);
                values(k,:)=[d.shapedReference_rad,d.velocity_rad_s,d.acceleration_rad_s2];
            end
            testCase.verifyGreaterThanOrEqual(min(values(:,1)),0);
            testCase.verifyLessThanOrEqual(max(values(:,1)),1.5);
            testCase.verifyGreaterThanOrEqual(min(diff(values(:,1))),0);
            testCase.verifyLessThan(abs(values(end,1)-1.5),1e-7);
            testCase.verifyLessThanOrEqual(max(abs(values(:,2))),c.maxVelocity_rad_s+1e-10);
            testCase.verifyLessThanOrEqual(max(abs(values(:,3))),c.maxAcceleration_rad_s2+1e-8);
        end

        function arbitraryRetargetingPreservesVelocityAccelerationAndPastExtrema(testCase)
            [~,~,c]=localConfiguration();s=phase3_reference_governor_initialize(c);
            random=RandStream('mt19937ar','Seed',91731);
            requests=c.positionLimit_rad*(2*rand(random,1500,1)-1);low=c.initialPosition_rad;high=low;
            for k=1:numel(requests)
                low=min(low,requests(k));high=max(high,requests(k));
                [s,d]=phase3_reference_governor_step(s,requests(k));
                testCase.verifyGreaterThanOrEqual(min([d.slewReference_rad,d.shapedReference_rad]),low-1e-13);
                testCase.verifyLessThanOrEqual(max([d.slewReference_rad,d.shapedReference_rad]),high+1e-13);
                testCase.verifyLessThanOrEqual(abs(d.velocity_rad_s),c.maxVelocity_rad_s+1e-10);
                testCase.verifyLessThanOrEqual(abs(d.acceleration_rad_s2),c.maxAcceleration_rad_s2+1e-8);
            end
        end

        function generatedVelocityObeysTheConvexRecurrence(testCase)
            [~,~,c]=localConfiguration();s=phase3_reference_governor_initialize(c);
            for k=1:1000
                previous=s;request=1.8*sin(k/31);
                [s,d]=phase3_reference_governor_step(s,request);
                w=(s.slewReference_rad-previous.slewReference_rad)/c.sampleTime_s;
                expected=(1-c.beta)*previous.velocity_rad_s+c.beta*w;
                testCase.verifyEqual(d.velocity_rad_s,expected,'AbsTol',1e-10);
                testCase.verifyEqual(d.acceleration_rad_s2, ...
                    (d.velocity_rad_s-previous.velocity_rad_s)/c.sampleTime_s,'AbsTol',1e-12);
            end
        end

        function betaOneCanReachTheWorstCaseReversalAcceleration(testCase)
            [p,o,~]=localConfiguration();c=phase3_motion_configuration(p,o,struct('maxAcceleration_rad_s2',20000));
            testCase.verifyEqual(c.beta,1);s=phase3_reference_governor_initialize(c);
            [s,positive]=phase3_reference_governor_step(s,1);
            [~,negative]=phase3_reference_governor_step(s,-1);
            testCase.verifyEqual(positive.velocity_rad_s,10,'AbsTol',1e-12);
            testCase.verifyEqual(negative.velocity_rad_s,-10,'AbsTol',1e-12);
            testCase.verifyEqual(negative.acceleration_rad_s2,-20000,'AbsTol',1e-9);
            testCase.verifyEqual(negative.slewReference_rad,negative.shapedReference_rad);
        end

        function boundsUseElapsedTimeAtBothSupportedSamplePeriods(testCase)
            for Ts=[.001,.0005]
                p=actuator_parameters();p.control.sampleTime_s=Ts;o=phase3_observer_configuration(p);
                c=phase3_motion_configuration(p,o);s=phase3_reference_governor_initialize(c);
                [s,d]=phase3_reference_governor_step(s,1);
                testCase.verifyEqual(d.acceleration_rad_s2,c.maxAcceleration_rad_s2/2,'AbsTol',1e-10);
                for k=2:300
                    [s,d]=phase3_reference_governor_step(s,sign(sin(k/7)));
                    testCase.verifyLessThanOrEqual(abs(d.velocity_rad_s),c.maxVelocity_rad_s+1e-10);
                    testCase.verifyLessThanOrEqual(abs(d.acceleration_rad_s2),c.maxAcceleration_rad_s2+1e-8);
                end
            end
        end

        function malformedOptionsFailBeforeModelValidation(testCase)
            id='EMIProject:InvalidPhase3MotionConfiguration';
            invalid={struct('unknown',1),struct('sampleTime_s',.001), ...
                struct('maxVelocity_rad_s',0),struct('maxAcceleration_rad_s2',-1), ...
                struct('positionLimit_rad',NaN),struct('maxVelocity_rad_s',Inf), ...
                struct('maxVelocity_rad_s',[1,2]),struct('maxVelocity_rad_s',uint8(10)), ...
                struct('positionLimit_rad',1i),struct('maxAcceleration_rad_s2',"200"),[]};
            for k=1:numel(invalid)
                testCase.verifyError(@()phase3_motion_configuration(struct(),struct(),invalid{k}),id);
            end
        end

        function observerMarginsInitialRangeAndSampleTimeAreEnforced(testCase)
            [p,o,~]=localConfiguration();id='EMIProject:InvalidPhase3MotionConfiguration';
            testCase.verifyError(@()phase3_motion_configuration(p,o,struct('maxVelocity_rad_s',12.6)),id);
            testCase.verifyError(@()phase3_motion_configuration(p,o,struct('positionLimit_rad',.81*pi)),id);
            different=p;different.control.sampleTime_s=.0005;
            testCase.verifyError(@()phase3_motion_configuration(different,o),id);
            outside=phase3_observer_configuration(p,struct('initialEstimate',[2.2;0;0]));
            testCase.verifyError(@()phase3_motion_configuration(p,outside),id);
            testCase.verifyError(@()phase3_motion_configuration(p,o,struct('maxAcceleration_rad_s2',eps(0))),id);
        end

        function declaredObserverMarginsAndRequestBoundsAreInclusive(testCase)
            [p,o,~]=localConfiguration();c=phase3_motion_configuration(p,o, ...
                struct('maxVelocity_rad_s',.5*o.rateLimit_rad_s,'positionLimit_rad',.8*o.positionLimit_rad));
            testCase.verifyEqual(c.maxVelocity_rad_s,12.5);
            s=phase3_reference_governor_initialize(c);
            [s,a]=phase3_reference_governor_step(s,c.positionLimit_rad);
            [~,b]=phase3_reference_governor_step(s,-c.positionLimit_rad);
            testCase.verifyEqual([a.request_rad,b.request_rad],[c.positionLimit_rad,-c.positionLimit_rad]);
        end

        function invalidRequestsCannotAdvanceTheSavedState(testCase)
            [~,~,c]=localConfiguration();s=phase3_reference_governor_initialize(c);
            [s,~]=phase3_reference_governor_step(s,.5);before=s;
            invalid={NaN,Inf,1i,[0,1],"0",[],true,int16(1),c.positionLimit_rad+1e-6};
            for k=1:numel(invalid)
                testCase.verifyError(@()phase3_reference_governor_step(s,invalid{k}), ...
                    'EMIProject:InvalidReferenceGovernorRequest');
            end
            [after,d]=phase3_reference_governor_step(s,.5);
            [expected,e]=phase3_reference_governor_step(before,.5);
            testCase.verifyEqual(after,expected);testCase.verifyEqual(d,e);
        end

        function malformedSavedConfigurationIsRejected(testCase)
            [~,~,c]=localConfiguration();id='EMIProject:InvalidPhase3MotionConfiguration';
            invalid={};bad=c;bad.beta=.02;invalid{end+1}=bad;
            bad=c;bad.initialPosition_rad=NaN;invalid{end+1}=bad;
            bad=c;bad.positionLimit_rad=pi;invalid{end+1}=bad;
            bad=c;bad.sampleTime_s=0;invalid{end+1}=bad;
            for k=1:numel(invalid)
                testCase.verifyError(@()phase3_reference_governor_initialize(invalid{k}),id);
            end
        end

        function inconsistentSavedStateCannotBypassTheAccelerationProof(testCase)
            [~,~,c]=localConfiguration();s=phase3_reference_governor_initialize(c);id='EMIProject:InvalidReferenceGovernorState';
            invalid={};bad=s;bad.slewReference_rad=NaN;invalid{end+1}=bad;
            bad=s;bad.shapedReference_rad=[0,0];invalid{end+1}=bad;
            bad=s;bad.sampleIndex=1.5;invalid{end+1}=bad;
            bad=s;bad.sampleIndex=1;bad.slewReference_rad=1;invalid{end+1}=bad;
            bad=s;bad.sampleIndex=1;bad.velocity_rad_s=20;invalid{end+1}=bad;
            for k=1:numel(invalid),testCase.verifyError(@()phase3_reference_governor_step(invalid{k},0),id);end
            [p,o,~]=localConfiguration();tiny=phase3_motion_configuration(p,o,struct('maxAcceleration_rad_s2',1e-8));
            bad=phase3_reference_governor_initialize(tiny);bad.sampleIndex=1;bad.slewReference_rad=.5;
            testCase.verifyError(@()phase3_reference_governor_step(bad,0),id);
        end

        function stepIsCausalUnderArbitraryFutureRetargeting(testCase)
            [~,~,c]=localConfiguration();a=phase3_reference_governor_initialize(c);b=a;
            for k=1:250
                first=.8;second=.8;if k>150,second=-.8;end
                [a,da]=phase3_reference_governor_step(a,first);
                [b,db]=phase3_reference_governor_step(b,second);
                if k<=150,testCase.verifyEqual(da,db);end
            end
            testCase.verifyNotEqual(da.shapedReference_rad,db.shapedReference_rad);
        end

        function profileTimeZeroHasNoElapsedGovernorAdvance(testCase)
            p=actuator_parameters();cfg=phase3_configuration(p);s=phase3_scenario("motion_initial_request",p);
            s.referenceTimes_s=[0;.1];s.referenceValues_rad=[.5;.5];
            [f,t]=phase3_motion_profiles(p,s,cfg);
            testCase.verifyTrue(f.motionGoverned);
            testCase.verifyEqual(t.Requested_rad(1),.5);
            testCase.verifyEqual(t{1,{'Time_s','SlewReference_rad','ShapedReference_rad','Velocity_rad_s','Acceleration_rad_s2'}},zeros(1,5));
            testCase.verifyEqual(t.ShapedReference_rad(2),.0001,'AbsTol',1e-14);
            testCase.verifyEqual(t.Velocity_rad_s(2),.1,'AbsTol',1e-12);
            testCase.verifyEqual(f.reference_rad,t.ShapedReference_rad);
            s.referenceValues_rad(1)=3;
            testCase.verifyError(@()phase3_motion_profiles(p,s,cfg),'EMIProject:InvalidReferenceGovernorRequest');
        end

        function everyNonreferenceFaultAndSupplyFieldIsPreserved(testCase)
            p=actuator_parameters();cfg=phase3_configuration(p);s=phase3_scenario("motion_preservation",p);
            s.phase2b=phase2b_scenario("communication_delay",p);
            s.phase2b.communication.jitterEnabled=true;s.packetDropStartTime_s=.25;s.packetDropStopTime_s=.34;
            s.benignNoiseStandardDeviation_rad=.001;s.biasStartTime_s=.4;s.biasStopTime_s=.42;s.bias_rad=.1;
            before=phase3_fault_profiles(p,s);[after,t]=phase3_motion_profiles(p,s,cfg);
            testCase.verifyEqual(after.requestedReference_rad,before.reference_rad);
            testCase.verifyEqual(after.motionTrace,t);
            restored=rmfield(after,{'requestedReference_rad','motionConfiguration','motionTrace','motionGoverned'});
            restored.reference_rad=before.reference_rad;
            testCase.verifyEqual(restored,before);
        end

        function governorTraceDoesNotDependOnPlantTruthOrFaultMasks(testCase)
            p=actuator_parameters();cfg=phase3_configuration(p);a=phase3_scenario("motion_truth_a",p);b=a;
            b.initialPlantState=[.7;3;-.2];b.bias_rad=4;b.biasStartTime_s=.2;b.biasStopTime_s=.3;
            b.packetDropStartTime_s=.4;b.packetDropStopTime_s=.5;
            [~,ta]=phase3_motion_profiles(p,a,cfg);[~,tb]=phase3_motion_profiles(p,b,cfg);
            testCase.verifyEqual(ta,tb);
        end

        function profilePrefixDoesNotUseFutureReferenceKnots(testCase)
            p=actuator_parameters();cfg=phase3_configuration(p);a=phase3_scenario("motion_prefix",p);
            a.referenceTimes_s=[0;.1;.5];a.referenceValues_rad=deg2rad([0;30;60]);b=a;
            b.referenceValues_rad(3)=deg2rad(-60);
            [~,ta]=phase3_motion_profiles(p,a,cfg);[~,tb]=phase3_motion_profiles(p,b,cfg);
            testCase.verifyEqual(ta(ta.Time_s<.5,:),tb(tb.Time_s<.5,:));
            testCase.verifyNotEqual(ta.ShapedReference_rad(end),tb.ShapedReference_rad(end));
        end

        function wrapperRemainsOptInAndLeavesAllControllerSettingsUntouched(testCase)
            p=actuator_parameters();cfg=phase3_configuration(p);s=phase3_scenario("motion_opt_in",p);
            beforeCfg=cfg;beforeParams=p;beforeScenario=s;
            [f,~]=phase3_motion_profiles(p,s,cfg,struct('maxVelocity_rad_s',8,'maxAcceleration_rad_s2',100));
            testCase.verifyEqual(cfg,beforeCfg);testCase.verifyEqual(p,beforeParams);testCase.verifyEqual(s,beforeScenario);
            testCase.verifyEqual(f.motionConfiguration.maxVelocity_rad_s,8);
            original=phase3_fault_profiles(p,s);
            testCase.verifyFalse(isfield(original,'motionConfiguration') || isfield(original,'motionGoverned'));
            testCase.verifyNotEqual(f.reference_rad,original.reference_rad);
        end
    end
end

function [p,o,c]=localConfiguration()
p=actuator_parameters();o=phase3_observer_configuration(p);c=phase3_motion_configuration(p,o);
end
