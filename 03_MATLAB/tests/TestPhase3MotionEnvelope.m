classdef TestPhase3MotionEnvelope < matlab.unittest.TestCase
    methods (Test)
        function rampPrefixMatchesIndependentClosedForm(testCase)
            [~,cfg,motion]=configuration(); %#ok<ASGLU>
            state=phase3_reference_governor_initialize(motion);
            n=50;position=zeros(n,1);velocity=position;
            for k=1:n
                [state,sample]=phase3_reference_governor_step(state,1.5);
                position(k)=sample.shapedReference_rad;velocity(k)=sample.velocity_rad_s;
            end
            k=(1:n)';b=motion.beta;h=motion.sampleTime_s;v=motion.maxVelocity_rad_s;
            expectedV=v*(1-(1-b).^k);
            expectedR=h*v*(k-(1-b)*(1-(1-b).^k)/b);
            testCase.verifyEqual(velocity,expectedV,'AbsTol',1e-10);
            testCase.verifyEqual(position,expectedR,'AbsTol',1e-12);
            testCase.verifyEqual(state.slewReference_rad,n*h*v,'AbsTol',1e-12);
        end

        function unitBetaBoundaryPreservesWorstCaseReversalBound(testCase)
            [p,cfg]=configuration();
            motion=phase3_motion_configuration(p,cfg.observer, ...
                struct('maxVelocity_rad_s',1,'maxAcceleration_rad_s2',2000));
            testCase.verifyEqual(motion.beta,1);
            state=phase3_reference_governor_initialize(motion);
            for k=1:10,[state,sample]=phase3_reference_governor_step(state,1);end
            testCase.verifyEqual(sample.velocity_rad_s,1,'AbsTol',1e-12);
            [state,sample]=phase3_reference_governor_step(state,-1);
            testCase.verifyEqual(sample.velocity_rad_s,-1,'AbsTol',1e-12);
            testCase.verifyEqual(sample.acceleration_rad_s2,-2000,'AbsTol',1e-8);
            testCase.verifyEqual(state.shapedReference_rad,state.slewReference_rad);
        end

        function retargetingIsCausalAndPreservesBoundsAndGlobalEnvelope(testCase)
            [~,~,motion]=configuration();
            targets=repelem([2;-2;.4;-1.1;1.7;0],40);
            a=govern(targets,motion);b=govern(-targets,motion);
            testCase.verifyLessThanOrEqual(max(abs(a(:,2))),motion.maxVelocity_rad_s+1e-10);
            testCase.verifyLessThanOrEqual(max(abs(a(:,3))),motion.maxAcceleration_rad_s2+1e-7);
            testCase.verifyEqual(b,-a,'AbsTol',1e-12);
            for k=1:numel(targets)
                testCase.verifyGreaterThanOrEqual(a(k,1),min([0;targets(1:k)])-1e-12);
                testCase.verifyLessThanOrEqual(a(k,1),max([0;targets(1:k)])+1e-12);
            end
            later=targets;later(101:end)=.1;
            changed=govern(later,motion);
            testCase.verifyEqual(changed(1:100,:),a(1:100,:));
        end

        function wrapperPreservesExogenousProfilesAndInitialSample(testCase)
            [p,cfg]=configuration();s=phase3_scenario("motion_wrapper_test",p);
            s.referenceValues_rad=[.5;1];s.benignNoiseStandardDeviation_rad=1e-4;
            before=rng;raw=phase3_fault_profiles(p,s);
            [f,trace]=phase3_motion_profiles(p,s,cfg);
            testCase.verifyEqual(rng,before);
            restored=rmfield(f,{'requestedReference_rad','motionConfiguration','motionTrace','motionGoverned'});
            restored.reference_rad=f.requestedReference_rad;
            testCase.verifyTrue(isequaln(restored,raw));
            testCase.verifyEqual(trace.Requested_rad,raw.reference_rad);
            testCase.verifyEqual(trace{1,{'SlewReference_rad','ShapedReference_rad', ...
                'Velocity_rad_s','Acceleration_rad_s2'}},[0,0,0,0]);
            testCase.verifyEqual(trace.Requested_rad(1),.5);
            testCase.verifyEqual(f.reference_rad,trace.ShapedReference_rad);
            [~,names]=phase3_logged_values();testCase.verifyEqual(numel(names),31);
        end

        function invalidContractsCannotSilentlyJumpOrFreezeGovernor(testCase)
            [p,cfg,motion]=configuration();
            for options={struct('maxVelocity_rad_s',0),struct('maxVelocity_rad_s',13), ...
                    struct('maxAcceleration_rad_s2',eps(0)),struct('positionLimit_rad',pi), ...
                    struct('unknown',1),struct('maxVelocity_rad_s',true)}
                testCase.verifyError(@()phase3_motion_configuration(p,cfg.observer,options{1}), ...
                    'EMIProject:InvalidPhase3MotionConfiguration');
            end
            state=phase3_reference_governor_initialize(motion);
            for value={NaN,Inf,1i,true,pi,[0,1]}
                testCase.verifyError(@()phase3_reference_governor_step(state,value{1}), ...
                    'EMIProject:InvalidReferenceGovernorRequest');
            end
            bad=state;bad.shapedReference_rad=.1;
            testCase.verifyError(@()phase3_reference_governor_step(bad,0), ...
                'EMIProject:InvalidReferenceGovernorState');
            testCase.verifyEqual(state,phase3_reference_governor_initialize(motion));
        end

        function fixedWindowSeparatesTaskTrackingFromCommandAndShapingError(testCase)
            [r,fixture]=metricRecord();clean=r;
            r.run.profiles.requestedReference_rad(21:end)=deg2rad(1);
            r.timeSeries.reference_rad(21:end)=deg2rad(.25);
            r.timeSeries.position_rad(21:80)=deg2rad(.5);
            r.timeSeries.position_rad(81:100)=deg2rad(5);
            r.timeSeries.position_rad(101:end)=deg2rad(1);
            r=refreshTrace(r);clean.run.profiles=r.run.profiles;
            clean.timeSeries.reference_rad=r.timeSeries.reference_rad;
            clean.timeSeries.position_rad(21:end)=deg2rad(.25);
            row=phase3_motion_metrics(r,clean,fixture,"synthetic");
            testCase.verifyEqual(row.WindowSamples,60);
            testCase.verifyEqual([row.RequestedWindowRMSE_deg,row.CommandWindowRMSE_deg, ...
                row.ShapingWindowRMSE_deg,row.WindowDisturbanceRMSE_deg],[.5,.25,.75,.25],'AbsTol',1e-12);
            testCase.verifyEqual([row.FinalRequestedError_deg,row.FinalRequestedTailRMSE_deg],[0,0]);
            bad=clean;bad.time_s(2)=bad.time_s(2)+1e-9;
            testCase.verifyError(@()phase3_motion_metrics(r,bad,fixture,"bad"),'EMIProject:MotionAlignment');
            bad=clean;bad.run.profiles.requestedReference_rad(21)=0;
            testCase.verifyError(@()phase3_motion_metrics(r,bad,fixture,"bad"),'EMIProject:MotionAlignment');
            badFixture=fixture;badFixture.window_s=[.02,.0205];
            testCase.verifyError(@()phase3_motion_metrics(r,clean,badFixture,"bad"),'EMIProject:InvalidMotionWindow');
        end

        function candidateRateUsesTrustedSourceTimeAndReanchorHistory(testCase)
            [r,fixture]=metricRecord();clean=r;
            r.timeSeries.sampleReceived(:)=0;r.timeSeries.measurementAccepted(:)=0;
            indices=[1,2,10,11,12,14,15,16];
            r.timeSeries.sampleReceived(indices)=1;
            r.timeSeries.sourceIndex(indices)=[1,2,3,3,200,14,4,16];
            r.timeSeries.receivedMeasurement_rad(indices)=[0,0,.02,.5,.8,.021,.8,.022];
            r.timeSeries.measurementAccepted([1,10,14,16])=1;
            r.timeSeries.reacquisitionCommitted(14)=1;
            row=phase3_motion_metrics(r,clean,fixture,"source_time");
            testCase.verifyEqual(row.MaxCandidateMeasurementRate_rad_s,10,'AbsTol',1e-12);
            testCase.verifyEqual(row.CandidateMeasurementRateSamples,4);
            r.timeSeries.sampleReceived(:)=0;r.timeSeries.measurementAccepted(:)=0;
            row=phase3_motion_metrics(r,clean,fixture,"missing");
            testCase.verifyTrue(isnan(row.MaxCandidateMeasurementRate_rad_s));
            testCase.verifyEqual(row.CandidateMeasurementRateSamples,0);
            testCase.verifyFalse(row.CandidateMeasurementRatePass);
        end

        function faultTimingAndResetReleaseRequireFreshIndependentEvidence(testCase)
            [r,fixture]=metricRecord();clean=r;
            fixture.kind="fault";fixture.responseKind="stop";fixture.alarmDeadline_s=.015;
            fixture.requireStop=true;fixture.requireResetRelease=true;
            r.run.profiles.receiverFault(11:20)=true;
            r.timeSeries.mode(11:70)=4;r.timeSeries.commandLimit_V(11:70)=0;
            r.timeSeries.reacquisitionCommitted(20)=1;r.timeSeries.credibleFresh(20)=0;
            r.timeSeries.resetRequest(71)=1;
            row=phase3_motion_metrics(r,clean,fixture,"valid_release");
            testCase.verifyTrue(row.CommandInvariantsPass&&row.DeclaredBehaviorPass);
            testCase.verifyTrue(isnan(row.FirstPostExposureAlarm_s));
            testCase.verifyEqual(row.FirstPostExposureStop_s,.01,'AbsTol',1e-12);
            testCase.verifyTrue(row.ResetReleaseOccurred);
            bad=r;bad.timeSeries.resetRequest(71)=0;
            row=phase3_motion_metrics(bad,clean,fixture,"missing_reset");
            testCase.verifyFalse(row.ReleaseEvidencePass||row.DeclaredBehaviorPass);
            bad=r;bad.timeSeries.credibleFresh(20)=1;
            row=phase3_motion_metrics(bad,clean,fixture,"invented_trust");
            testCase.verifyFalse(row.CommitsRemainStopped||row.CommandInvariantsPass);
            bad=r;bad.timeSeries.mode(5)=1;
            row=phase3_motion_metrics(bad,clean,fixture,"preexisting");
            testCase.verifyTrue(row.PreexistingResponse);
            testCase.verifyFalse(row.AlarmDeadlinePass||row.DeclaredBehaviorPass);
            fixture.responseKind="alarm";
            row=phase3_motion_metrics(r,clean,fixture,"wrong_response");
            testCase.verifyFalse(row.AlarmDeadlinePass);
            fixture.kind="diagnostic";fixture.responseKind="none";
            row=phase3_motion_metrics(r,clean,fixture,"diagnostic");
            testCase.verifyFalse(row.BehaviorApplicable);
            testCase.verifyTrue(row.DeclaredBehaviorPass);
        end
    end
end

function [p,cfg,motion]=configuration()
persistent params fullCfg motionCfg
if isempty(params)
 params=actuator_parameters();fullCfg=phase3_configuration(params);
 motionCfg=phase3_motion_configuration(params,fullCfg.observer);
end
p=params;cfg=fullCfg;motion=motionCfg;
end

function values=govern(targets,motion)
state=phase3_reference_governor_initialize(motion);values=zeros(numel(targets),3);
for k=1:numel(targets)
 [state,s]=phase3_reference_governor_step(state,targets(k));
 values(k,:)=[s.shapedReference_rad,s.velocity_rad_s,s.acceleration_rad_s2];
end
end

function [r,fixture]=metricRecord()
[p,cfg,motion]=configuration();n=201;t=(0:n-1)'*.001;z=zeros(n,1);one=ones(n,1);
r.time_s=t;r.state=zeros(n,3);r.run.params=p;r.run.configuration=cfg;r.run.protectionEnabled=true;
r.timeSeries=table(t,z,z,z,z,z,z,24*one,z,z,z,z,one,one,(1:n)',one,z,one, ...
 'VariableNames',{'time_s','position_rad','velocity_rad_s','current_A','reference_rad', ...
 'command_V','unsaturatedCommand_V','commandLimit_V','mode','alarm','reacquisitionCommitted', ...
 'resetRequest','credibleFresh','supplyHealthy','sourceIndex','sampleReceived', ...
 'receivedMeasurement_rad','measurementAccepted'});
r.run.profiles=struct('time_s',t,'reference_rad',z,'requestedReference_rad',z, ...
 'motionGoverned',true,'motionConfiguration',motion,'receiverFault',false(n,1), ...
 'supply',struct('commandLimit_V',24*one));
r=refreshTrace(r);
fixture=struct('id',"synthetic",'partition',"development",'kind',"clean", ...
 'window_s',[.02,.08],'alarmDeadline_s',NaN,'requireStop',false, ...
 'requireResetRelease',false,'responseKind',"none");
end

function r=refreshTrace(r)
t=r.time_s;requested=r.run.profiles.requestedReference_rad;shaped=r.timeSeries.reference_rad;
velocity=[0;diff(shaped)/.001];acceleration=[0;diff(velocity)/.001];
r.run.profiles.reference_rad=shaped;
r.run.profiles.motionTrace=table(t,requested,shaped,shaped,velocity,acceleration, ...
 'VariableNames',{'Time_s','Requested_rad','SlewReference_rad','ShapedReference_rad','Velocity_rad_s','Acceleration_rad_s2'});
end
