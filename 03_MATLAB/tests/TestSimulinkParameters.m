classdef TestSimulinkParameters < matlab.unittest.TestCase
    %TESTSIMULINKPARAMETERS Execute changed inputs rather than trust metadata.
    % Build all three current-schema models explicitly before running this suite.
    methods (TestClassSetup)
        function requireCurrentModels(testCase)
            models = ["EMI_Resilient_Actuator_Baseline", ...
                "EMI_Resilient_Actuator_Phase2","EMI_Resilient_Actuator_Phase2B"];
            kinds = ["baseline","phase2","phase2b"];
            for k=1:numel(models)
                testCase.assertWarningFree(@() assert_actuator_model_schema(models(k),kinds(k)));
            end
        end
    end

    methods (Test)
        function changedReferenceIsActuallyExecuted(testCase)
            p = actuator_parameters();
            p.simulation.stepAmplitude_rad = deg2rad(60);
            p.simulation.stepTime_s = 0.15;
            [actual,expected] = localRunPhase2B(p,"none");
            testCase.verifyEqual(actual(:,1),expected.reference_rad,'AbsTol',1e-12);
            testCase.verifyEqual(actual(end,1),deg2rad(60),'AbsTol',1e-12);
            localVerifyCore(testCase,actual,expected);
        end

        function changedPlantAndControllerAreActuallyExecuted(testCase)
            p = actuator_parameters();
            p.electrical.resistance_Ohm = 1.7;
            p.mechanical.inertia_kg_m2 = 2*p.mechanical.inertia_kg_m2;
            p.control.targetBandwidth_rad_s = 15;
            [actual,expected] = localRunPhase2B(p,"none");
            localVerifyCore(testCase,actual,expected);
            nominal = actuator_parameters();
            original = simulate_phase2b_actuator(nominal,phase2b_scenario("none",nominal));
            testCase.verifyGreaterThan(max(abs(actual(:,2)-original.position_rad)),1e-3);
        end

        function loadChangesAllThreeModels(testCase)
            p = actuator_parameters();
            p.mechanical.nominalLoadTorque_Nm = 0.1;
            encoderScenario = encoder_fault_scenario("none",p);
            expected = simulate_faulted_actuator(p,encoderScenario);
            baselineInput = create_baseline_simulation_input("EMI_Resilient_Actuator_Baseline",p);
            baselineOutput = sim(baselineInput);
            baseline = baselineOutput.get('baselineSimout');
            testCase.verifyEqual(baseline.signals.values(:,2), ...
                expected.timeSeries.theta_rad,'AbsTol',1e-9);
            phase2Input = create_phase2_simulation_input("EMI_Resilient_Actuator_Phase2",p,encoderScenario);
            phase2Output = sim(phase2Input);
            phase2 = phase2Output.get('phase2Simout');
            testCase.verifyEqual(phase2.signals.values(:,2), ...
                expected.timeSeries.theta_rad,'AbsTol',1e-9);
            [actual,phase2bExpected] = localRunPhase2B(p,"none");
            localVerifyCore(testCase,actual,phase2bExpected);
            testCase.verifyLessThan(actual(2,2),0); % Load already acts before the step.
            testCase.verifyGreaterThan(max(abs(actual(:,4))),0.1);
        end

        function sampleTimeAppliesToPlantControllerAndChannel(testCase)
            p = actuator_parameters();
            p.control.sampleTime_s = 0.0005;
            [actual,expected,output] = localRunPhase2B(p,"combined_phase2b");
            log = output.get('phase2bSimout');
            testCase.verifySize(actual,[3001,29]);
            testCase.verifyEqual(log.time,expected.time_s,'AbsTol',1e-12);
            localVerifyCore(testCase,actual,expected);
        end

        function changedVoltageLimitActuallySaturates(testCase)
            p = actuator_parameters();
            p.control.voltageLimit_V = 0.25;
            [actual,expected] = localRunPhase2B(p,"none");
            localVerifyCore(testCase,actual,expected);
            testCase.verifyLessThanOrEqual(max(abs(actual(:,9))),0.25);
            testCase.verifyGreaterThan(nnz(abs(actual(:,8))>0.25),0);
            testCase.verifyEqual(max(abs(actual(:,9))),0.25,'AbsTol',1e-12);
        end

        function lowNominalBusLimitsAllThreeModelsConsistently(testCase)
            p = actuator_parameters();
            p.electrical.nominalVoltage_V = 0.5;
            p.control.voltageLimit_V = 24;
            p.supply.sagVoltage_V = 0.5;
            encoderScenario = encoder_fault_scenario("none",p);
            expectedA = simulate_faulted_actuator(p,encoderScenario);
            baselineInput = create_baseline_simulation_input("EMI_Resilient_Actuator_Baseline",p);
            baselineOutput = sim(baselineInput);
            baseline = baselineOutput.get('baselineSimout');
            phase2Input = create_phase2_simulation_input("EMI_Resilient_Actuator_Phase2",p,encoderScenario);
            phase2Output = sim(phase2Input);
            phase2 = phase2Output.get('phase2Simout');
            [actualB,expectedB] = localRunPhase2B(p,"none");
            localVerifyCore(testCase,actualB,expectedB);
            expectedStatesA = [expectedA.timeSeries.theta_rad, ...
                expectedA.timeSeries.omega_rad_s,expectedA.timeSeries.current_A];
            testCase.verifyEqual(actualB(:,2:4),expectedStatesA,'AbsTol',1e-9);
            testCase.verifyEqual(actualB(:,9),expectedA.timeSeries.voltage_cmd_V,'AbsTol',1e-9);
            testCase.verifyTrue(all(isfinite(baseline.signals.values(:))));
            testCase.verifyTrue(all(isfinite(phase2.signals.values(:))));
            testCase.verifyEqual(baseline.signals.values(:,2),expectedB.position_rad,'AbsTol',1e-9);
            testCase.verifyEqual(phase2.signals.values(:,2),expectedB.position_rad,'AbsTol',1e-9);
            testCase.verifyLessThanOrEqual(max(abs(actualB(:,9))),0.5);
            testCase.verifyLessThanOrEqual(max(abs(expectedA.timeSeries.voltage_cmd_V)),0.5);
            testCase.verifyEqual(max(abs(actualB(:,9))),0.5,'AbsTol',1e-12);
            testCase.verifyGreaterThan(nnz(abs(actualB(:,8))>0.5),0);
            % All three bounded trajectories must differ from the unlimited
            % linear response, rather than merely agreeing at an inactive cap.
            linearModel = baseline_closed_loop(p);
            unlimitedPosition = lsim(linearModel.referenceToPosition, ...
                expectedB.reference_rad,expectedB.time_s);
            positions = [baseline.signals.values(:,2), ...
                phase2.signals.values(:,2),actualB(:,2)];
            testCase.verifyGreaterThan(min(max(abs(positions-unlimitedPosition),[],1)),1e-3);
        end

        function supplyPoliciesMatchStateAndSeparateSupplyLogs(testCase)
            p = actuator_parameters();
            for name = ["supply_sag","supply_interruption", ...
                    "supply_interruption_reset","combined_supply"]
                [actual,expected,output] = localRunPhase2B(p,name);
                localVerifyCore(testCase,actual,expected);
                supplyLog = output.get('supplySimout');
                stateLog = output.get('controllerStateSimout');
                expectedSupply = [expected.supply.voltage_V,expected.supply.commandLimit_V, ...
                    double(expected.supply.driveAvailable), ...
                    double(expected.supply.configuredWindowActive)];
                testCase.verifyEqual(supplyLog.signals.values,expectedSupply,'AbsTol',0);
                testCase.verifyEqual(supplyLog.time,expected.time_s,'AbsTol',1e-12);
                testCase.verifyEqual(stateLog.signals.values, ...
                    expected.controllerState_log,'AbsTol',1e-9);
            end
        end

        function inputConstructionDoesNotMutateModelOrBaseMetadata(testCase)
            model = 'EMI_Resilient_Actuator_Phase2B';
            localLoadModel(model);
            beforeReference = get_param([model,'/Position Reference'],'After');
            hadMetadata = evalin('base','exist(''phase2bParameters'',''var'') == 1');
            if hadMetadata, beforeMetadata = evalin('base','phase2bParameters'); end
            p = actuator_parameters();p.simulation.stepAmplitude_rad = deg2rad(60);
            create_phase2b_simulation_input(string(model),p,phase2b_scenario("none",p));
            testCase.verifyEqual(get_param([model,'/Position Reference'],'After'),beforeReference);
            testCase.verifyEqual(evalin('base','exist(''phase2bParameters'',''var'') == 1'),hadMetadata);
            if hadMetadata
                testCase.verifyEqual(evalin('base','phase2bParameters'),beforeMetadata);
            end
        end

        function staleSchemaIsRejectedBeforeSimulation(testCase)
            model = 'EMI_Resilient_Actuator_Phase2B';
            localLoadModel(model);
            workspace = get_param(model,'ModelWorkspace');
            beforeSchema = workspace.getVariable('EMIActuatorModelSchema');
            beforeDirty = get_param(model,'Dirty');
            cleanup = onCleanup(@() localRestoreSchema(model,beforeSchema,beforeDirty)); %#ok<NASGU>
            workspace.assignin('EMIActuatorModelSchema',struct('id','legacy'));
            p = actuator_parameters();
            testCase.verifyError(@() create_phase2b_simulation_input( ...
                string(model),p,phase2b_scenario("none",p)), ...
                'EMIProject:StaleActuatorModel');
        end

        function preloadedOtherProjectModelIsRejected(testCase)
            model = 'EMI_Resilient_Actuator_Phase2B';
            if bdIsLoaded(model),close_system(model,0);end
            matlabRoot = fileparts(fileparts(mfilename('fullpath')));
            scratch = tempname;mkdir(scratch);
            copyPath = fullfile(scratch,[model,'.slx']);
            cleanup = onCleanup(@() localRemoveModelCopy(model,copyPath,scratch)); %#ok<NASGU>
            copyfile(fullfile(matlabRoot,'models',[model,'.slx']),copyPath);
            load_system(copyPath);
            p = actuator_parameters();
            testCase.verifyError(@() create_phase2b_simulation_input( ...
                string(model),p,phase2b_scenario("none",p)), ...
                'EMIProject:ActuatorModelPathMismatch');
        end
    end
end

function [actual,expected,output] = localRunPhase2B(p,name)
scenario = phase2b_scenario(name,p);
expected = simulate_phase2b_actuator(p,scenario);
input = create_phase2b_simulation_input("EMI_Resilient_Actuator_Phase2B",p,scenario);
output = sim(input);
logged = output.get('phase2bSimout');
actual = logged.signals.values;
end

function localVerifyCore(testCase,actual,expected)
testCase.verifyTrue(all(isfinite(actual(:))));
reference = [expected.reference_rad,expected.position_rad,expected.velocity_rad_s, ...
    expected.current_A,expected.sensorSideMeasurement_rad,expected.receivedMeasurement_rad, ...
    expected.trackingError_rad,expected.unsaturatedCommand_V,expected.command_V];
testCase.verifyEqual(actual(:,1:9),reference,'AbsTol',1e-9);
end

function localLoadModel(model)
if ~bdIsLoaded(model)
    matlabRoot = fileparts(fileparts(mfilename('fullpath')));
    load_system(fullfile(matlabRoot,'models',[model,'.slx']));
end
end

function localRestoreSchema(model,schema,dirty)
if bdIsLoaded(model)
    workspace = get_param(model,'ModelWorkspace');
    workspace.assignin('EMIActuatorModelSchema',schema);
    set_param(model,'Dirty',dirty);
end
end

function localRemoveModelCopy(model,copyPath,folder)
if bdIsLoaded(model),close_system(model,0);end
if isfile(copyPath),delete(copyPath);end
if isfolder(folder),rmdir(folder);end
end
