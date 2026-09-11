classdef TestPhase3Simulink < matlab.unittest.TestCase
    %TESTPHASE3SIMULINK Identity, applied configuration and actual execution.
    % Build the current Phase 3 model explicitly before running this suite.
    % Tests mutate only loaded copies/workspaces and preserve the saved file.
    properties (Access = private)
        ModelPath
        OriginalModelBytes
        ScratchFolder
    end

    methods (TestClassSetup)
        function requireSavedModelAndIsolateEvidence(testCase)
            matlabRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.ModelPath = fullfile(matlabRoot, 'models', ...
                'EMI_Resilient_Actuator_Phase3.slx');
            testCase.assertTrue(isfile(testCase.ModelPath), ...
                'Build the current Phase 3 model explicitly before running this suite.');
            testCase.OriginalModelBytes = localReadBytes(testCase.ModelPath);
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.ScratchFolder = fixture.Folder;
        end
    end

    methods (TestMethodTeardown)
        function discardOnlyInMemoryTestChanges(~)
            localCloseModel();
        end
    end

    methods (TestClassTeardown)
        function savedModelRemainsByteIdentical(testCase)
            localCloseModel();
            testCase.verifyEqual(localReadBytes(testCase.ModelPath), ...
                testCase.OriginalModelBytes, 'The generated model must not be saved by these tests.');
        end
    end

    methods (Test)
        function preloadedOtherProjectIsRejectedBeforeAnyMutation(testCase)
            localCloseModel();
            copyPath = fullfile(testCase.ScratchFolder, ...
                'EMI_Resilient_Actuator_Phase3.slx');
            copyfile(testCase.ModelPath, copyPath);
            load_system(copyPath);
            model = 'EMI_Resilient_Actuator_Phase3';
            workspace = get_param(model, 'ModelWorkspace');
            oldData = workspace.getVariable('EMIPhase3ModelSchema');
            oldDirty = get_param(model, 'Dirty');
            p = actuator_parameters();
            record = localRunRecord(p, phase3_scenario("path_guard", p));
            testCase.verifyError(@() build_phase3_simulink_model(record, false), ...
                'EMIProject:ActuatorModelPathMismatch');
            % Even explicit permission to rebuild this project's model does
            % not authorize closing or editing a different project's model.
            testCase.verifyError(@() build_phase3_simulink_model(record, true), ...
                'EMIProject:ActuatorModelPathMismatch');
            testCase.verifyEqual(get_param(model, 'FileName'), copyPath);
            testCase.verifyEqual(workspace.getVariable('EMIPhase3ModelSchema'), oldData);
            testCase.verifyEqual(get_param(model, 'Dirty'), oldDirty);
            % The campaign saves the rejection then raises its failed gate.
            % Its cleanup must preserve the foreign model as well.
            analytical = simulate_phase3_actuator(p, record.scenario, true);
            folder = fullfile(testCase.ScratchFolder, 'foreign_model_rejection');
            testCase.verifyError(@() validate_phase3_simulink({analytical}, folder), ...
                'EMIProject:Phase3SimulinkCrossValidationFailed');
            testCase.verifyTrue(bdIsLoaded(model));
            testCase.verifyEqual(get_param(model, 'FileName'), copyPath);
            testCase.verifyEqual(workspace.getVariable('EMIPhase3ModelSchema'), oldData);
            testCase.verifyEqual(get_param(model, 'Dirty'), oldDirty);
            saved = load(fullfile(folder, 'phase3_simulink_validation.mat'), 'validationTable');
            testCase.verifyFalse(saved.validationTable.Passed);
            testCase.verifyTrue(contains(saved.validationTable.Diagnostic, ...
                'EMIProject:ActuatorModelPathMismatch'));
        end

        function staleSchemaFailsWithoutOverwritingSavedModel(testCase)
            localCloseModel();
            load_system(testCase.ModelPath);
            model = 'EMI_Resilient_Actuator_Phase3';
            workspace = get_param(model, 'ModelWorkspace');
            workspace.assignin('EMIPhase3ModelSchema', struct('schema', 'obsolete-test-schema'));
            p = actuator_parameters();
            record = localRunRecord(p, phase3_scenario("schema_guard", p));
            testCase.verifyError(@() build_phase3_simulink_model(record, false), ...
                'EMIProject:StalePhase3Model');
            testCase.verifyEqual(workspace.getVariable('EMIPhase3ModelSchema'), ...
                struct('schema', 'obsolete-test-schema'));
            testCase.verifyEqual(localReadBytes(testCase.ModelPath), testCase.OriginalModelBytes);
        end

        function actualPlantInitialStateLoadAndSampleTimeReachModel(testCase)
            [p, scenario] = localChangedFixture();
            record = localRunRecord(p, scenario);
            % Vary the applied exogenous load as well as the actual plant.
            record.profiles.loadTorque_Nm(record.profiles.time_s >= .7) = -.008;
            build_phase3_simulink_model(record, false);
            model = 'EMI_Resilient_Actuator_Phase3';
            workspace = get_param(model, 'ModelWorkspace');
            actualPlant = c2d(actuator_state_space(scenario.actualParameters), ...
                p.control.sampleTime_s, 'zoh');
            [expectedA, expectedB] = ssdata(actualPlant);
            testCase.verifyEqual(workspace.getVariable('phase3PlantA'), expectedA, 'AbsTol', 0);
            testCase.verifyEqual(workspace.getVariable('phase3PlantB'), expectedB, 'AbsTol', 0);
            testCase.verifyEqual(workspace.getVariable('phase3InitialPlantState'), scenario.initialPlantState);
            testCase.verifyEqual(workspace.getVariable('phase3LoadProfile'), ...
                [record.profiles.time_s, record.profiles.loadTorque_Nm]);
            testCase.verifyEqual(workspace.getVariable('phase3SampleTime_s'), p.control.sampleTime_s);
            testCase.verifyEqual(workspace.getVariable('phase3Run'), record);
            testCase.verifyEqual(str2double(get_param(model, 'FixedStep')), p.control.sampleTime_s);
            testCase.verifyEqual(str2double(get_param(model, 'StopTime')), p.simulation.stopTime_s);
            testCase.verifyEqual(get_param([model, '/Independent Actual Actuator'], 'BlockType'), 'DiscreteStateSpace');
            testCase.verifyEqual(get_param([model, '/Independent Actual Actuator'], 'A'), 'phase3PlantA');
            testCase.verifyEqual(get_param([model, '/Independent Actual Actuator'], 'SampleTime'), 'phase3SampleTime_s');
            testCase.verifyEqual(get_param([model, '/Applied Load'], 'VariableName'), 'phase3LoadProfile');
            testCase.verifyEqual(get_param([model, '/Causal Sensor and Protection Loop'], 'Parameters'), 'phase3Run');
            % A fresh nominal run must replace every changed workspace value.
            nominal = actuator_parameters();
            clean = localRunRecord(nominal, phase3_scenario("nominal_after_changed", nominal));
            build_phase3_simulink_model(clean, false);
            testCase.verifyEqual(workspace.getVariable('phase3Run'), clean);
            testCase.verifyEqual(workspace.getVariable('phase3InitialPlantState'), zeros(3,1));
            testCase.verifyEqual(workspace.getVariable('phase3SampleTime_s'), nominal.control.sampleTime_s);
            testCase.verifyEqual(workspace.getVariable('phase3LoadProfile'), ...
                [clean.profiles.time_s, clean.profiles.loadTorque_Nm]);
        end

        function changedParameterClosedLoopRunsAgainstIndependentPlant(testCase)
            p = actuator_parameters();
            normal = simulate_phase3_actuator(p, phase3_scenario("simulink_nominal", p), true);
            [changed, scenario] = localChangedFixture();
            profiles = phase3_fault_profiles(changed, scenario);
            profiles.loadTorque_Nm(profiles.time_s >= .7) = -.008;
            modified = simulate_phase3_actuator(changed, scenario, true, ...
                phase3_configuration(changed), profiles);
            folder = fullfile(testCase.ScratchFolder, 'changed_parameters');
            comparison = validate_phase3_simulink({normal; modified}, folder);
            testCase.verifyTrue(all(comparison.Passed));
            testCase.verifyEqual(comparison.ExpectedSamples, [1501; 751]);
            testCase.verifyTrue(all(comparison.DiscreteProfilesExact));
            testCase.verifyEqual(comparison.SimulationWarnings, [0;0]);
            saved = load(fullfile(folder, 'phase3_simulink_validation.mat'), 'evidence', 'channelTable');
            testCase.verifyEqual(height(saved.channelTable), 2*(3+31));
            testCase.verifyEqual(saved.evidence{2}.plantValues(1,:).', scenario.initialPlantState, 'AbsTol', 1e-12);
            testCase.verifyEqual(saved.evidence{2}.plantValues, modified.state, 'AbsTol', 1e-9);
            % Prevent an inactive override or nominal-response replay from
            % passing merely because two implementations share metadata.
            nominalAtChangedTimes = interp1(normal.time_s, normal.state(:,1), modified.time_s);
            testCase.verifyGreaterThan(max(abs(saved.evidence{2}.plantValues(:,1)-nominalAtChangedTimes)), .01);
            testCase.verifyGreaterThan(max(abs(saved.evidence{2}.loopValues(:,1))), .01);
        end

        function innovationMaskMismatchIsSavedAsFailure(testCase)
            p = actuator_parameters();
            expected = simulate_phase3_actuator(p, phase3_scenario("invalid_innovation_log", p), true);
            index = find(isfinite(expected.loopValues(:,8)), 1, 'first');
            testCase.assertNotEmpty(index);
            expected.loopValues(index,8) = NaN;
            folder = fullfile(testCase.ScratchFolder, 'mismatched_nan_mask');
            testCase.verifyError(@() validate_phase3_simulink({expected}, folder), ...
                'EMIProject:Phase3SimulinkCrossValidationFailed');
            saved = load(fullfile(folder, 'phase3_simulink_validation.mat'), ...
                'validationTable', 'channelTable');
            testCase.verifyFalse(saved.validationTable.Passed);
            testCase.verifyFalse(saved.validationTable.InnovationNaNMaskMatched);
            innovation = saved.channelTable.Domain == "loop" & ...
                saved.channelTable.Channel == "innovation_rad";
            testCase.verifyEqual(nnz(innovation), 1);
            testCase.verifyFalse(saved.channelTable.ChannelPassed(innovation));
            testCase.verifyTrue(contains(saved.validationTable.Diagnostic, "innovation_missing_mask_mismatch"));
        end
    end
end

function record = localRunRecord(p, scenario)
cfg = phase3_configuration(p);
cfg.observer.assumedLoadTorque_Nm = scenario.assumedLoadTorque_Nm;
record = struct('params', p, 'scenario', scenario, ...
    'profiles', phase3_fault_profiles(p, scenario), ...
    'configuration', cfg, 'protectionEnabled', true);
end

function [p, scenario] = localChangedFixture()
p = actuator_parameters();
p.control.sampleTime_s = .002;
p.electrical.resistance_Ohm = 1.65;
p.mechanical.inertia_kg_m2 = 1.15*p.mechanical.inertia_kg_m2;
p.control.targetBandwidth_rad_s = 15;
scenario = phase3_scenario("simulink_changed_parameters", p);
scenario.actualParameters.electrical.resistance_Ohm = 1.9;
scenario.actualParameters.mechanical.inertia_kg_m2 = 1.4*p.mechanical.inertia_kg_m2;
scenario.initialPlantState = [.001; -.05; .02];
scenario.loadTorque_Nm = .005;
scenario.assumedLoadTorque_Nm = .002;
scenario.referenceTimes_s = [0; .17; .85];
scenario.referenceValues_rad = [0; .35; .2];
end

function bytes = localReadBytes(path)
file = fopen(path, 'rb');
assert(file >= 0, 'EMIProject:TestModelReadFailed', 'Could not read saved model.');
cleanup = onCleanup(@() fclose(file)); %#ok<NASGU>
bytes = fread(file, Inf, '*uint8');
end

function localCloseModel()
model = 'EMI_Resilient_Actuator_Phase3';
if bdIsLoaded(model), close_system(model, 0); end
end
