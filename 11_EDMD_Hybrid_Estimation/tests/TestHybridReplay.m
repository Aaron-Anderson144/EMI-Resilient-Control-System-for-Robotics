classdef TestHybridReplay < matlab.unittest.TestCase
    properties
        BundleRoot
        WorkFolder
        ModelFile
        ControllerTable
    end
    methods (TestClassSetup)
        function prepareReplayFixture(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.BundleRoot = root;
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'code')));
            parent = fullfile(root,'results','replay_test_work');
            if ~isfolder(parent), mkdir(parent); end
            folder = tempname(parent); mkdir(folder);
            testCase.WorkFolder = folder;
            testCase.addTeardown(@() TestHybridReplay.removeOwnFolder(folder,parent));
            training = study_generate_records(fullfile(root,'reference_project'), ...
                [930101,930102,930103],["nominal","nominal","nominal"],0.30);
            residuals = hybrid_prepare_records(training);
            linear = edmd_fit(residuals,degree=1,delay=2,ridge=1e-6);
            nonlinear = edmd_fit(residuals,degree=2,delay=2,ridge=1e-6);
            models = {[],[],linear,nonlinear}; %#ok<NASGU>
            testCase.ModelFile = fullfile(folder,'unit_selected_models.mat');
            save(testCase.ModelFile,'models');
            rec = training{1}; n = numel(rec.t);
            testCase.ControllerTable = table(rec.t,rec.y,rec.u,ones(n,1),(1:n)',zeros(n,1), ...
                'VariableNames',{'time_s','receivedMeasurement_rad','command_V', ...
                'sampleReceived','sourceIndex','receiverDomainFailed'});
        end
    end
    methods (Test)
        function replayNeedsNoTruthAndRetainsWarmup(testCase)
            csvPath = fullfile(testCase.WorkFolder,'healthy_without_truth.csv');
            writetable(testCase.ControllerTable,csvPath);
            log = replay_controller(csvPath,testCase.ModelFile,fullfile(testCase.WorkFolder,'basic'));
            testCase.verifyEqual(height(log),height(testCase.ControllerTable));
            testCase.verifyFalse(any(log.eligible(1:201)));
            testCase.verifyTrue(all(log.eligible(202:end)));
            testCase.verifyTrue(all(isnan(log.edmdPrediction_rad(1:201))));
            testCase.verifyTrue(all(isfinite(log.edmdPrediction_rad(202:end))));
            testCase.verifyEqual(log.edmdError_rad, ...
                log.edmdPrediction_rad-log.measurement_rad);
            outputs = dir(fullfile(testCase.WorkFolder,'basic','*','replay_metadata.json'));
            testCase.verifyEqual(numel(outputs),1);
        end
        function hiddenTruthCannotChangeReplay(testCase)
            plain = testCase.ControllerTable;
            firstPath = fullfile(testCase.WorkFolder,'truth_absent.csv');
            writetable(plain,firstPath);
            baseline = replay_controller(firstPath,testCase.ModelFile,fullfile(testCase.WorkFolder,'truth'));
            plain.position_rad = 1e9*ones(height(plain),1);
            plain.velocity_rad_s = NaN(height(plain),1);
            plain.current_A = Inf(height(plain),1);
            changedPath = fullfile(testCase.WorkFolder,'truth_changed.csv');
            writetable(plain,changedPath);
            changed = replay_controller(changedPath,testCase.ModelFile,fullfile(testCase.WorkFolder,'truth'));
            testCase.verifyEqual(changed,baseline);
        end
        function futureMeasurementsCannotChangeEarlierPredictions(testCase)
            base = testCase.ControllerTable;
            firstPath = fullfile(testCase.WorkFolder,'causal_original.csv');
            writetable(base,firstPath);
            original = replay_controller(firstPath,testCase.ModelFile,fullfile(testCase.WorkFolder,'causal'));
            base.receivedMeasurement_rad(251:end) = base.receivedMeasurement_rad(251:end)+0.05;
            changedPath = fullfile(testCase.WorkFolder,'causal_changed.csv');
            writetable(base,changedPath);
            changed = replay_controller(changedPath,testCase.ModelFile,fullfile(testCase.WorkFolder,'causal'));
            testCase.verifyEqual(changed.linearPrediction_rad(1:251),original.linearPrediction_rad(1:251));
            testCase.verifyEqual(changed.edmdPrediction_rad(1:251),original.edmdPrediction_rad(1:251));
            testCase.verifyEqual(changed.nominalPrior_rad(1:251),original.nominalPrior_rad(1:251));
        end
        function appliedCommandFirstAffectsFollowingSample(testCase)
            base = testCase.ControllerTable;
            firstPath = fullfile(testCase.WorkFolder,'command_original.csv');
            writetable(base,firstPath);
            original = replay_controller(firstPath,testCase.ModelFile,fullfile(testCase.WorkFolder,'command'));
            % Row 250's applied voltage drives [t(250),t(251)). The reading
            % at row 250 and its predictions must be independent of it.
            deltaVoltage = 0.5;
            base.command_V(250:end) = base.command_V(250:end)+deltaVoltage;
            changedPath = fullfile(testCase.WorkFolder,'command_changed.csv');
            writetable(base,changedPath);
            changed = replay_controller(changedPath,testCase.ModelFile,fullfile(testCase.WorkFolder,'command'));
            testCase.verifyEqual(changed.linearPrediction_rad(1:250),original.linearPrediction_rad(1:250));
            testCase.verifyEqual(changed.edmdPrediction_rad(1:250),original.edmdPrediction_rad(1:250));
            testCase.verifyEqual(changed.nominalPrior_rad(1:250),original.nominalPrior_rad(1:250));
            config = hybrid_reference_observer();
            testCase.verifyEqual(changed.nominalPrior_rad(251)-original.nominalPrior_rad(251), ...
                config.C*config.B*deltaVoltage,'AbsTol',1e-14);
            testCase.verifyNotEqual(changed.linearPrediction_rad(251),original.linearPrediction_rad(251));
            testCase.verifyNotEqual(changed.edmdPrediction_rad(251),original.edmdPrediction_rad(251));
        end
        function malformedTimingAndEligibilityFailClosed(testCase)
            original = testCase.ControllerTable;
            candidates = cell(1,8);
            candidates{1} = original; candidates{1}.time_s(220) = candidates{1}.time_s(219);
            candidates{2} = original; candidates{2}.time_s(220) = candidates{2}.time_s(218);
            candidates{3} = original; candidates{3}.time_s(220:end) = candidates{3}.time_s(220:end)+.001;
            candidates{4} = original; candidates{4}.time_s = candidates{4}.time_s+1;
            candidates{5} = original; candidates{5}.sampleReceived(220) = NaN;
            candidates{6} = original; candidates{6}.sampleReceived(220) = 2;
            candidates{7} = original; candidates{7}.sourceIndex(220) = 220.5;
            candidates{8} = original; candidates{8}.receiverDomainFailed(220) = NaN;
            identifiers = ["EDMD:Time","EDMD:Time","EDMD:Time","EDMDHybrid:Timestamp", ...
                "EDMDHybrid:InvalidObservation","EDMDHybrid:InvalidObservation", ...
                "EDMDHybrid:InvalidObservation","EDMD:ReceiverDomain"];
            for k = 1:numel(candidates)
                csvPath = fullfile(testCase.WorkFolder,"malformed_"+k+".csv");
                writetable(candidates{k},csvPath);
                testCase.verifyError(@() replay_controller(csvPath,testCase.ModelFile, ...
                    fullfile(testCase.WorkFolder,'malformed')),char(identifiers(k)));
            end
        end
        function longDelayDoesNotReintroduceObserverWarmup(testCase)
            saved = load(testCase.ModelFile,'models'); models = saved.models;
            model = models{3}; model.delay = 101;
            count = 2*model.delay+1;
            model.historyMean = [repmat(model.outputMean,model.delay+1,1); ...
                repmat(model.inputMean,model.delay,1)];
            model.historyScale = [repmat(model.outputScale,model.delay+1,1); ...
                repmat(model.inputScale,model.delay,1)];
            model.A = eye(count+1); model.B = zeros(count+1,1);
            model.C = zeros(1,count+1); model.C(model.delay+2) = model.outputScale;
            models{3} = model; %#ok<NASGU>
            modelFile = fullfile(testCase.WorkFolder,'long_delay_models.mat');
            save(modelFile,'models');
            csvPath = fullfile(testCase.WorkFolder,'long_delay.csv');
            writetable(testCase.ControllerTable,csvPath);
            log = replay_controller(csvPath,modelFile,fullfile(testCase.WorkFolder,'long_delay'));
            % Earliest history is innovation(101), at origin 202, target 203.
            testCase.verifyFalse(any(log.eligible(1:202)));
            testCase.verifyTrue(all(log.eligible(203:end)));
            testCase.verifyTrue(all(isnan(log.linearPrediction_rad(1:202))));
            testCase.verifyTrue(all(isfinite(log.linearPrediction_rad(203:end))));
        end
        function optionalCorrectionPoliciesCannotBeSilentlyDiscarded(testCase)
            saved = load(testCase.ModelFile,'models');
            csvPath = fullfile(testCase.WorkFolder,'unweighted_contract.csv');
            writetable(testCase.ControllerTable,csvPath);
            models = [saved.models,saved.models(3:4)]; %#ok<NASGU>
            bundleFile = fullfile(testCase.WorkFolder,'six_model_bundle.mat');
            save(bundleFile,'models');
            testCase.verifyError(@() replay_controller(csvPath,bundleFile, ...
                fullfile(testCase.WorkFolder,'unsupported')),'HybridReplay:Models');
            models = saved.models;
            models{4}.correctionPolicy = struct('windowSamples',20, ...
                'minRelativeImprovement',0,'weights',0,'domainMargin',.1); %#ok<NASGU>
            policyFile = fullfile(testCase.WorkFolder,'attached_policy.mat');
            save(policyFile,'models');
            testCase.verifyError(@() replay_controller(csvPath,policyFile, ...
                fullfile(testCase.WorkFolder,'unsupported')),'HybridReplay:Models');
        end
        function invalidPacketOrDomainRejected(testCase)
            invalid = testCase.ControllerTable;
            invalid.sampleReceived(220) = 0;
            csvPath = fullfile(testCase.WorkFolder,'missing_packet.csv');
            writetable(invalid,csvPath);
            testCase.verifyError(@() replay_controller(csvPath,testCase.ModelFile, ...
                fullfile(testCase.WorkFolder,'invalid')),'EDMDHybrid:InvalidObservation');
            invalid = testCase.ControllerTable; invalid.sourceIndex(220) = 219;
            csvPath = fullfile(testCase.WorkFolder,'delayed_packet.csv');
            writetable(invalid,csvPath);
            testCase.verifyError(@() replay_controller(csvPath,testCase.ModelFile, ...
                fullfile(testCase.WorkFolder,'invalid')),'EDMDHybrid:InvalidObservation');
            invalid = testCase.ControllerTable; invalid.receiverDomainFailed(220) = 1;
            csvPath = fullfile(testCase.WorkFolder,'failed_domain.csv');
            writetable(invalid,csvPath);
            testCase.verifyError(@() replay_controller(csvPath,testCase.ModelFile, ...
                fullfile(testCase.WorkFolder,'invalid')),'EDMD:ReceiverDomain');
        end
    end
    methods (Static, Access=private)
        function removeOwnFolder(folder,parent)
            folder = char(string(folder)); parent = char(string(parent));
            assert(startsWith(folder,[parent,filesep]) && ~strcmp(folder,parent), ...
                'HybridReplayTest:Cleanup','Cleanup target must remain inside the test workspace.');
            if isfolder(folder), rmdir(folder,'s'); end
        end
    end
end
