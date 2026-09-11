classdef TestPhase3TuningTools < matlab.unittest.TestCase
    %TESTPHASE3TUNINGTOOLS Policy isolation and exact activity attribution.
    methods (Test)
        function defaultPolicyExactlyPreservesExistingConfiguration(testCase)
            p=actuator_parameters();before=p;base=phase3_configuration(p);
            [cfg,policy]=phase3_tuning_configuration(p);
            testCase.verifyEqual(cfg,base);testCase.verifyEqual(p,before);
            explicit=rmfield(policy,'id');names=fieldnames(explicit);
            reversed=orderfields(explicit,flipud(names));
            [same,again]=phase3_tuning_configuration(p,reversed);
            testCase.verifyEqual(same,base);testCase.verifyEqual(again,policy);
        end

        function candidatesRetuneDegradedPidAndPreserveEveryOtherPolicy(testCase)
            p=actuator_parameters();base=phase3_configuration(p);
            options=struct('degradedBandwidthRatio',.75,'referenceTimeConstant_s',.075, ...
                'suspectedVoltageLimitScale',.7,'degradedVoltageLimitScale',.4,'nonNormalSlewRate_V_s',100);
            [cfg,policy]=phase3_tuning_configuration(p,options);
            low=p;low.control.targetBandwidth_rad_s=.75*p.control.targetBandwidth_rad_s;
            expected=design_baseline_controller(low);
            testCase.verifyEqual([cfg.control.degraded.Kp,cfg.control.degraded.Ki, ...
                cfg.control.degraded.Kd,cfg.control.degraded.Tf], ...
                [expected.continuous.Kp,expected.continuous.Ki,expected.continuous.Kd,expected.continuous.Tf]);
            restored=cfg;restored.control.degraded=base.control.degraded;
            for name={'referenceTimeConstant_s','suspectedVoltageLimitScale','degradedVoltageLimitScale','nonNormalSlewRate_V_s'}
                testCase.verifyEqual(cfg.supervisor.(name{1}),options.(name{1}));
                restored.supervisor.(name{1})=base.supervisor.(name{1});
            end
            % Whole-configuration equality includes observer/reacquisition,
            % normal gains, anti-windup, supply threshold and all dwell counts.
            testCase.verifyEqual(restored,base);testCase.verifyEqual(rmfield(policy,'id'),options);
            [~,other]=phase3_tuning_configuration(p,struct('degradedBandwidthRatio',.75));
            testCase.verifyNotEqual(policy.id,other.id);
        end

        function fullBandwidthCopiesNormalCoefficientsExactly(testCase)
            [cfg,policy]=phase3_tuning_configuration(actuator_parameters(),struct('degradedBandwidthRatio',1));
            testCase.verifyEqual(cfg.control.degraded,cfg.control.normal);
            testCase.verifyEqual(policy.degradedBandwidthRatio,1);
        end

        function invalidOptionsFailBeforeAnyPlantDesign(testCase)
            id='EMIProject:InvalidPhase3TuningConfiguration';
            invalid={struct('unknown',1),struct('degradedBandwidthRatio',.249), ...
                struct('degradedBandwidthRatio',1.001),struct('referenceTimeConstant_s',-.01), ...
                struct('referenceTimeConstant_s',.101),struct('suspectedVoltageLimitScale',.2), ...
                struct('degradedVoltageLimitScale',-.1),struct('suspectedVoltageLimitScale',1.1), ...
                struct('nonNormalSlewRate_V_s',0),struct('nonNormalSlewRate_V_s',Inf), ...
                struct('degradedBandwidthRatio',NaN),struct('degradedBandwidthRatio',[.5,.6]), ...
                struct('degradedBandwidthRatio',".5"),struct('nonNormalSlewRate_V_s',uint16(200)), ...
                struct('referenceTimeConstant_s',1i),[]};
            % Empty parameters would fail plant validation if design started.
            for k=1:numel(invalid)
                testCase.verifyError(@()phase3_tuning_configuration(struct(),invalid{k}),id);
            end
        end

        function declaredTuningBoundariesAreInclusive(testCase)
            p=actuator_parameters();
            [cfg,policy]=phase3_tuning_configuration(p,struct('degradedBandwidthRatio',.25, ...
                'referenceTimeConstant_s',0,'suspectedVoltageLimitScale',0, ...
                'degradedVoltageLimitScale',0,'nonNormalSlewRate_V_s',1));
            testCase.verifyEqual(policy.degradedBandwidthRatio,.25);
            testCase.verifyEqual(cfg.supervisor.degradedVoltageLimitScale,0);
            [cfg,~]=phase3_tuning_configuration(p,struct('referenceTimeConstant_s',.1, ...
                'suspectedVoltageLimitScale',1,'degradedVoltageLimitScale',1));
            testCase.verifyEqual(cfg.supervisor.referenceTimeConstant_s,.1);
            testCase.verifyEqual(cfg.supervisor.degradedVoltageLimitScale,1);
        end

        function touchingABoundDoesNotEarnConstraintCredit(testCase)
            cfg=localConfiguration();result=localTrace([1;1],[0;0],[1;1],cfg);
            activity=phase3_control_activity(result);
            testCase.verifyFalse(any(activity.SlewClipped | activity.AmplitudeClipped | ...
                activity.ModeCapClipped | activity.BusCapClipped | activity.CoincidentCapClipped));
            testCase.verifyEqual(activity.AmplitudeCorrection_V,zeros(2,1));
            testCase.verifyEqual(activity.AntiWindupCorrection_V,zeros(2,1));
        end

        function positiveAndNegativeSlewAreDistinctFromAmplitude(testCase)
            cfg=localConfiguration();cfg.supervisor.normalSlewRate_V_s=2;
            [result,expected]=localTrace([10;-10;10],[0;0;0],10*ones(3,1),cfg);
            activity=phase3_control_activity(result);
            testCase.verifyTrue(all(activity.SlewClipped));testCase.verifyFalse(any(activity.AmplitudeClipped));
            testCase.verifyEqual(activity.SlewCommand_V,[.2;0;.2],'AbsTol',1e-14);
            testCase.verifyEqual(activity.SlewClipped,[expected.slewLimited]');
        end

        function fallingBusCanOverrideTheOrdinarySlewBound(testCase)
            cfg=localConfiguration();cfg.supervisor.normalSlewRate_V_s=2;
            result=localTrace(10*ones(4,1),zeros(4,1),[10;10;10;.05],cfg);
            activity=phase3_control_activity(result);
            testCase.verifyTrue(activity.SlewClipped(4) && activity.AmplitudeClipped(4));
            testCase.verifyTrue(activity.BusCapClipped(4));testCase.verifyFalse(activity.ModeCapClipped(4));
            testCase.verifyEqual(activity.SlewCommand_V(4),.8,'AbsTol',1e-14);
            testCase.verifyEqual(activity.AmplitudeCorrection_V(4),-.75,'AbsTol',1e-14);
            testCase.verifyGreaterThan(abs(diff(result.timeSeries.command_V(3:4))), ...
                cfg.supervisor.normalSlewRate_V_s*cfg.control.sampleTime_s);
        end

        function activeTransferCanClipToANewModeCapWithoutSlew(testCase)
            cfg=localConfiguration();
            for direction=[-1,1]
                result=localTrace(direction*[10;10],[0;2],[10;10],cfg);
                activity=phase3_control_activity(result);
                testCase.verifyTrue(activity.Rebased(2) && activity.AmplitudeClipped(2));
                testCase.verifyFalse(activity.SlewClipped(2) || activity.BusCapClipped(2));
                testCase.verifyTrue(activity.ModeCapClipped(2));
                testCase.verifyEqual(activity.SlewCommand_V(2),direction*10);
                testCase.verifyEqual(result.timeSeries.command_V(2),direction*2.5);
            end
        end

        function busOnlyAmplitudeClippingGetsOnlyBusCredit(testCase)
            cfg=localConfiguration();
            for direction=[-1,1]
                result=localTrace(direction*20,0,2,cfg);activity=phase3_control_activity(result);
                testCase.verifyTrue(activity.AmplitudeClipped && activity.BusCapClipped);
                testCase.verifyFalse(activity.SlewClipped || activity.ModeCapClipped || activity.CoincidentCapClipped);
                testCase.verifyEqual(activity.AmplitudeCorrection_V,-direction*18);
            end
        end

        function coincidentModeAndBusCapsRemainExplicitlyAmbiguous(testCase)
            cfg=localConfiguration();result=localTrace(20,0,10,cfg);
            activity=phase3_control_activity(result);
            testCase.verifyTrue(activity.AmplitudeClipped && activity.CoincidentCapClipped);
            testCase.verifyFalse(activity.ModeCapClipped || activity.BusCapClipped);
        end

        function stopAndReleaseDoNotInventUnloggedCounterfactualDemand(testCase)
            cfg=localConfiguration();result=localTrace(5*ones(5,1),[0;4;4;3;3],10*ones(5,1),cfg);
            activity=phase3_control_activity(result);
            testCase.verifyEqual(activity.HardStop,[false;true;true;false;false]);
            testCase.verifyTrue(all(activity.Rebased(2:4)));
            testCase.verifyEqual(activity.SlewCommand_V(2:4),zeros(3,1));
            testCase.verifyEqual(activity.AntiWindupCorrection_V(2:4),zeros(3,1));
            testCase.verifyFalse(any(activity.SlewClipped(2:4) | activity.AmplitudeClipped(2:4)));
            testCase.verifyEqual(result.timeSeries.command_V(2:4),zeros(3,1));
        end

        function zeroBusIsAHardStopEvenWithoutAModeTransition(testCase)
            cfg=localConfiguration();result=localTrace([5;5;5],[0;0;0],[10;0;0],cfg);
            activity=phase3_control_activity(result);
            testCase.verifyEqual(activity.HardStop,[false;true;true]);
            testCase.verifyEqual(activity.Rebased,[false;true;true]);
            testCase.verifyFalse(any(activity.AmplitudeClipped));
        end

        function antiWindupAndActivityMatchProductionControllerDiagnostics(testCase)
            cfg=localConfiguration();cfg.supervisor.normalSlewRate_V_s=2;
            [result,expected]=localTrace([10;-10;10;10;10;10;10], ...
                [0;0;0;2;2;4;3],[10;10;.05;10;10;10;10],cfg);
            activity=phase3_control_activity(result);
            testCase.verifyEqual(activity.SlewClipped,[expected.slewLimited]');
            testCase.verifyEqual(activity.AmplitudeClipped,[expected.amplitudeLimited]');
            testCase.verifyEqual(activity.HardStop,[expected.hardStop]');
            testCase.verifyEqual(activity.Rebased,[expected.rebased]');
            testCase.verifyEqual(activity.AntiWindupCorrection_V,[expected.antiWindupCorrection_V]','AbsTol',1e-14);
            signedSlew=activity.SlewCommand_V-result.timeSeries.unsaturatedCommand_V;
            testCase.verifyEqual(activity.AntiWindupCorrection_V, ...
                cfg.control.antiWindupGain*(signedSlew+activity.AmplitudeCorrection_V),'AbsTol',1e-14);
        end

        function legacyAndMalformedTracesCannotBecomeFalseActivityCounts(testCase)
            cfg=localConfiguration();result=localTrace([1;1],[0;0],[10;10],cfg);
            legacy=result;legacy.run.protectionEnabled=false;
            testCase.verifyError(@()phase3_control_activity(legacy),'EMIProject:Phase3ControlActivityNotApplicable');
            id='EMIProject:InvalidPhase3ControlActivity';invalid={};
            bad=result;bad.timeSeries.mode(2)=.5;invalid{end+1}=bad;
            bad=result;bad.timeSeries.unsaturatedCommand_V(2)=NaN;invalid{end+1}=bad;
            bad=result;bad.run.profiles.supply.commandLimit_V=[10,10];invalid{end+1}=bad;
            bad=result;bad.timeSeries.time_s(2)=.11;invalid{end+1}=bad;
            bad=result;bad.timeSeries.command_V=[];invalid{end+1}=bad;
            bad=result;bad.run.configuration.control.antiWindupGain=0;invalid{end+1}=bad;
            bad=result;bad.run.configuration.supervisor.recoveryDwell_samples=3;invalid{end+1}=bad;
            bad=result;bad.run.protectionEnabled=1;invalid{end+1}=bad;
            for k=1:numel(invalid)
                testCase.verifyError(@()phase3_control_activity(invalid{k}),id,sprintf('Malformed case %d',k));
            end
        end

        function inconsistentLimitsTransfersAndStopCommandsAreRejected(testCase)
            cfg=localConfiguration();id='EMIProject:InvalidPhase3ControlActivity';
            result=localTrace([1;1],[0;0],[10;10],cfg);
            bad=result;bad.timeSeries.command_V(2)=2;
            testCase.verifyError(@()phase3_control_activity(bad),id);
            bad=result;bad.timeSeries.commandLimit_V(2)=2;
            testCase.verifyError(@()phase3_control_activity(bad),id);
            bad=localTrace([5;5],[0;2],[10;10],cfg);bad.timeSeries.unsaturatedCommand_V(2)=4;
            testCase.verifyError(@()phase3_control_activity(bad),id);
            bad=localTrace([5;5],[0;4],[10;10],cfg);bad.timeSeries.unsaturatedCommand_V(2)=1;
            testCase.verifyError(@()phase3_control_activity(bad),id);
            bad=localTrace([5;5],[0;4],[10;10],cfg);bad.timeSeries.command_V(2)=1e-12;
            testCase.verifyError(@()phase3_control_activity(bad),id);
        end

        function activityToleranceDoesNotPromoteNumericalSlackToClipping(testCase)
            cfg=localConfiguration();result=localTrace(1,0,10,cfg);
            result.timeSeries.command_V=1+5e-11;
            activity=phase3_control_activity(result);
            testCase.verifyFalse(activity.AmplitudeClipped || activity.SlewClipped);
            result.timeSeries.command_V=1+2e-10;
            testCase.verifyError(@()phase3_control_activity(result),'EMIProject:InvalidPhase3ControlActivity');
        end
    end
end

function cfg=localConfiguration()
cfg.supervisor=phase3_supervisor_configuration(.1);
cfg.supervisor.nonNormalSlewRate_V_s=2;
cfg.control=struct('sampleTime_s',.1,'nominalCommandLimit_V',10, ...
    'antiWindupTrackingTime_s',.2,'antiWindupGain',-expm1(-.5), ...
    'normal',struct('Kp',1,'Ki',0,'Kd',0,'Tf',0), ...
    'degraded',struct('Kp',1,'Ki',0,'Kd',0,'Tf',0));
end

function [result,diagnostics]=localTrace(reference,modes,bus,cfg)
n=numel(reference);state=phase3_control_initialize();command=zeros(n,1);raw=command;limit=command;
for k=1:n
    mode=modes(k);settings=struct('mode',double(mode),'driveEnabled',mode~=4, ...
        'useDegradedGains',any(mode==[2,3]),'rebaseController',mode~=state.previousMode, ...
        'voltageLimitScale',cfg.supervisor.degradedVoltageLimitScale, ...
        'referenceTimeConstant_s',0,'commandSlewRate_V_s',cfg.supervisor.nonNormalSlewRate_V_s);
    if mode==0
        settings.voltageLimitScale=cfg.supervisor.normalVoltageLimitScale;
        settings.commandSlewRate_V_s=cfg.supervisor.normalSlewRate_V_s;
    elseif mode==1
        settings.voltageLimitScale=cfg.supervisor.suspectedVoltageLimitScale;
    elseif mode==4
        settings.voltageLimitScale=0;
    end
    if settings.useDegradedGains,settings.referenceTimeConstant_s=cfg.supervisor.referenceTimeConstant_s;end
    input=struct('reference_rad',double(reference(k)),'feedback_rad',0,'availableLimit_V',double(bus(k)));
    [state,command(k),d]=phase3_control_step(state,input,settings,cfg.control);
    raw(k)=d.rawCommand_V;limit(k)=d.commandLimit_V;diagnostics(k,1)=d; %#ok<AGROW>
end
time=(0:n-1)'*cfg.control.sampleTime_s;
result.timeSeries=table(time,double(modes(:)),command,raw,limit, ...
    'VariableNames',{'time_s','mode','command_V','unsaturatedCommand_V','commandLimit_V'});
result.run=struct('protectionEnabled',true,'configuration',cfg, ...
    'profiles',struct('supply',struct('commandLimit_V',double(bus(:)))));
end
