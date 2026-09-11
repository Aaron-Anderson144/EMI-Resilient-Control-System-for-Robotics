classdef TestPhase3Control < matlab.unittest.TestCase
    methods (Test)
        function normalUnconstrainedPidMatchesIndependentDiscreteBaseline(testCase)
            p = actuator_parameters(); cfg = phase3_control_configuration(p);
            baseline = design_baseline_controller(p);
            time = (0:500)'*cfg.sampleTime_s;
            error = 0.001+0.0003*sin(17*time)+0.0002*cos(31*time);
            expected = lsim(baseline.discrete,error,time);
            state = phase3_control_initialize(); settings = modeSettings(0);
            actual = zeros(size(time)); raw = actual;
            for k = 1:numel(time)
                in = struct('reference_rad',error(k),'feedback_rad',0,'availableLimit_V',24);
                [state,actual(k),d] = phase3_control_step(state,in,settings,cfg);
                raw(k) = d.rawCommand_V;
                testCase.verifyFalse(d.rebased);
                testCase.verifyFalse(d.slewLimited || d.amplitudeLimited);
            end
            testCase.verifyEqual(actual,expected,'AbsTol',1e-10);
            testCase.verifyEqual(actual,raw);
            testCase.verifyGreaterThan(abs(actual(1)),0);
        end

        function degradedGainsUseHalfBandwidthWithoutMutatingParameters(testCase)
            p = actuator_parameters(); before = p;
            cfg = phase3_control_configuration(p);
            low = p; low.control.targetBandwidth_rad_s = 10;
            expected = design_baseline_controller(low);
            testCase.verifyEqual([cfg.degraded.Kp,cfg.degraded.Ki,cfg.degraded.Kd,cfg.degraded.Tf], ...
                [expected.continuous.Kp,expected.continuous.Ki,expected.continuous.Kd,expected.continuous.Tf]);
            testCase.verifyNotEqual(cfg.normal.Kp,cfg.degraded.Kp);
            testCase.verifyEqual(p,before);
        end

        function handwrittenTustinRecurrenceIncludesCurrentSample(testCase)
            cfg = simpleConfiguration(); state = phase3_control_initialize();
            in = struct('reference_rad',1,'feedback_rad',0,'availableLimit_V',10);
            [state,u,d] = phase3_control_step(state,in,modeSettings(0),cfg);
            testCase.verifyEqual([state.integral_V,state.derivative_V,u],[0.15,1.6,3.75],'AbsTol',1e-14);
            testCase.verifyFalse(d.rebased);
            in.reference_rad = 0.5;
            [state,u] = phase3_control_step(state,in,modeSettings(0),cfg);
            testCase.verifyEqual([state.integral_V,state.derivative_V,u],[0.375,0.16,1.535],'AbsTol',1e-14);
        end

        function gainAndReferenceChangesTransferAtPriorAppliedCommand(testCase)
            cfg = simpleConfiguration(); state = phase3_control_initialize();
            state.previousCommand_V = 2; state.integral_V = 3;
            state.derivative_V = 2; state.filteredReference_rad = 0.5;
            in = struct('reference_rad',1,'feedback_rad',0.2,'availableLimit_V',10);
            settings = modeSettings(2);
            [state,u,d] = phase3_control_step(state,in,settings,cfg);
            expectedReference = 0.5+(1-exp(-2))*0.5;
            testCase.verifyEqual(d.filteredReference_rad,expectedReference,'AbsTol',1e-14);
            testCase.verifyEqual(u,2);
            testCase.verifyEqual(state.derivative_V,0);
            testCase.verifyEqual(state.integral_V,2-(expectedReference-0.2),'AbsTol',1e-14);
            testCase.verifyTrue(d.rebased);
            in.reference_rad = -4;
            [state,u,d] = phase3_control_step(state,in,modeSettings(0),cfg);
            testCase.verifyEqual(u,2);
            testCase.verifyEqual(d.filteredReference_rad,-4);
            testCase.verifyEqual(state.integral_V,2-2*(-4.2),'AbsTol',1e-14);
            testCase.verifyTrue(d.rebased);
        end

        function slewLimitAppliesInBothDirections(testCase)
            cfg = simpleConfiguration(); cfg.normal = struct('Kp',1,'Ki',0,'Kd',0,'Tf',0);
            state = phase3_control_initialize(); settings = modeSettings(0);
            settings.commandSlewRate_V_s = 2;
            in = struct('reference_rad',10,'feedback_rad',0,'availableLimit_V',10);
            [state,u,d] = phase3_control_step(state,in,settings,cfg);
            testCase.verifyEqual(u,0.2,'AbsTol',1e-14);
            testCase.verifyTrue(d.slewLimited); testCase.verifyFalse(d.amplitudeLimited);
            in.reference_rad = -10;
            [state,u,d] = phase3_control_step(state,in,settings,cfg);
            testCase.verifyEqual(u,0,'AbsTol',1e-14);
            testCase.verifyTrue(d.slewLimited);
            [~,u] = phase3_control_step(state,in,settings,cfg);
            testCase.verifyEqual(u,-0.2,'AbsTol',1e-14);
        end

        function tighterModeAndBusLimitsOverrideSlewImmediately(testCase)
            cfg = simpleConfiguration(); in = struct('reference_rad',0,'feedback_rad',0,'availableLimit_V',10);
            for sign = [-1,1]
                state = phase3_control_initialize(); state.previousCommand_V = sign*10;
                settings = modeSettings(2); settings.commandSlewRate_V_s = 2;
                [state,u,d] = phase3_control_step(state,in,settings,cfg);
                testCase.verifyEqual(u,sign*2.5);
                testCase.verifyTrue(d.amplitudeLimited);
                testCase.verifyEqual(d.commandLimit_V,2.5);
                in.availableLimit_V = 0.1;
                [~,u,d] = phase3_control_step(state,in,settings,cfg);
                testCase.verifyEqual(u,sign*0.1);
                testCase.verifyEqual(d.commandLimit_V,0.1);
                in.availableLimit_V = 10;
            end
        end

        function trackingAntiWindupBoundsPersistentSaturationState(testCase)
            cfg = simpleConfiguration(); cfg.normal = struct('Kp',0,'Ki',1,'Kd',0,'Tf',0);
            state = phase3_control_initialize(); settings = modeSettings(0);
            in = struct('reference_rad',10,'feedback_rad',0,'availableLimit_V',0.1);
            [state,u,d] = phase3_control_step(state,in,settings,cfg);
            expectedCorrection = (1-exp(-0.5))*(0.1-0.5);
            testCase.verifyEqual(u,0.1);
            testCase.verifyEqual(d.antiWindupCorrection_V,expectedCorrection,'AbsTol',1e-14);
            testCase.verifyEqual(state.integral_V,0.5+expectedCorrection,'AbsTol',1e-14);
            for k = 2:100
                [state,u] = phase3_control_step(state,in,settings,cfg);
            end
            testCase.verifyEqual(u,0.1);
            testCase.verifyLessThan(abs(state.integral_V),2);
            testCase.verifyEqual(state.integral_V,0.1+exp(-0.5)/(1-exp(-0.5)), ...
                'AbsTol',1e-12);
        end

        function hardStopAndZeroBusApplyZeroThenRestartFromZero(testCase)
            cfg = simpleConfiguration(); in = struct('reference_rad',1,'feedback_rad',0,'availableLimit_V',10);
            state = phase3_control_initialize(); state.previousCommand_V = 5;
            [stopped,u,d] = phase3_control_step(state,in,modeSettings(4),cfg);
            testCase.verifyEqual(u,0); testCase.verifyEqual(d.rawCommand_V,0);
            testCase.verifyTrue(d.hardStop);
            testCase.verifyEqual(stopped.derivative_V,0);
            testCase.verifyEqual(stopped.integral_V,-2);
            [restarted,u,d] = phase3_control_step(stopped,in,modeSettings(3),cfg);
            testCase.verifyEqual(u,0); testCase.verifyTrue(d.rebased);
            settings = modeSettings(3); settings.commandSlewRate_V_s = 2;
            [~,u] = phase3_control_step(restarted,in,settings,cfg);
            testCase.verifyLessThanOrEqual(abs(u),0.2);
            in.availableLimit_V = 0;
            [~,u,d] = phase3_control_step(state,in,modeSettings(0),cfg);
            testCase.verifyEqual(u,0); testCase.verifyTrue(d.hardStop);
        end

        function invalidNumericAndModeInputsFailBeforeStateUpdate(testCase)
            cfg = simpleConfiguration(); state = phase3_control_initialize(); settings = modeSettings(0);
            in = struct('reference_rad',1,'feedback_rad',0,'availableLimit_V',10);
            for field = ["reference_rad","feedback_rad","availableLimit_V"]
                for value = {NaN,Inf,1i,[1,2],true,"1"}
                    bad = in; bad.(field) = value{1};
                    testCase.verifyError(@()phase3_control_step(state,bad,settings,cfg), ...
                        'EMIProject:InvalidPhase3ControlInput');
                end
            end
            bad = settings; bad.mode = 4;
            testCase.verifyError(@()phase3_control_step(state,in,bad,cfg), ...
                'EMIProject:InvalidPhase3ControlSettings');
            bad = state; bad.integral_V = NaN;
            testCase.verifyError(@()phase3_control_step(bad,in,settings,cfg), ...
                'EMIProject:InvalidPhase3ControlState');
            bad = cfg; bad.degraded.Tf = -1;
            testCase.verifyError(@()phase3_control_step(state,in,settings,bad), ...
                'EMIProject:InvalidPhase3ControlConfiguration');
            bad = cfg; bad.antiWindupGain = 0;
            testCase.verifyError(@()phase3_control_step(state,in,settings,bad), ...
                'EMIProject:InvalidPhase3ControlConfiguration');
            testCase.verifyEqual(state,phase3_control_initialize());
        end

        function integerClassesCannotSilentlyRoundControlArithmetic(testCase)
            cfg = simpleConfiguration(); state = phase3_control_initialize(); settings = modeSettings(0);
            in = struct('reference_rad',1,'feedback_rad',0,'availableLimit_V',10);
            bad = in; bad.reference_rad = uint8(1);
            testCase.verifyError(@()phase3_control_step(state,bad,settings,cfg), ...
                'EMIProject:InvalidPhase3ControlInput');
            bad = state; bad.integral_V = int8(0);
            testCase.verifyError(@()phase3_control_step(bad,in,settings,cfg), ...
                'EMIProject:InvalidPhase3ControlState');
            bad = cfg; bad.sampleTime_s = uint8(1);
            testCase.verifyError(@()phase3_control_step(state,in,settings,bad), ...
                'EMIProject:InvalidPhase3ControlConfiguration');
            bad = settings; bad.mode = uint8(0);
            testCase.verifyError(@()phase3_control_step(state,in,bad,cfg), ...
                'EMIProject:InvalidPhase3ControlSettings');
            p = actuator_parameters(); p.simulation.randomSeed = uint32(p.simulation.randomSeed);
            testCase.verifyError(@()phase3_control_configuration(p), ...
                'EMIProject:InvalidPhase3ControlConfiguration');
        end
    end
end

function cfg = simpleConfiguration()
cfg.sampleTime_s = 0.1;
cfg.nominalCommandLimit_V = 10;
cfg.antiWindupTrackingTime_s = 0.2;
cfg.antiWindupGain = 1-exp(-0.5);
cfg.normal = struct('Kp',2,'Ki',3,'Kd',0.4,'Tf',0.2);
cfg.degraded = struct('Kp',1,'Ki',1,'Kd',0.2,'Tf',0.2);
end

function settings = modeSettings(mode)
settings.mode = mode;
settings.driveEnabled = mode ~= 4;
settings.useDegradedGains = mode == 2 || mode == 3;
settings.rebaseController = false;
settings.voltageLimitScale = 1;
settings.referenceTimeConstant_s = 0;
settings.commandSlewRate_V_s = 10000;
if mode == 1
    settings.voltageLimitScale = 0.5;
elseif mode == 2 || mode == 3
    settings.voltageLimitScale = 0.25;
    settings.referenceTimeConstant_s = 0.05;
elseif mode == 4
    settings.voltageLimitScale = 0;
end
end
