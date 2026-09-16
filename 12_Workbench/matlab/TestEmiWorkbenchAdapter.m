classdef TestEmiWorkbenchAdapter < matlab.unittest.TestCase
    % Small boundary tests use fresh fake projects, never research outputs.
    properties
        ProjectRoot
        RunDirectory
    end

    methods (TestMethodSetup)
        function createIsolatedDirectories(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.ProjectRoot = string(fullfile(fixture.Folder, 'project'));
            testCase.RunDirectory = string(fullfile(fixture.Folder, 'run'));
            mkdir(testCase.ProjectRoot);
            mkdir(testCase.RunDirectory);
        end
    end

    methods (Test)
        function unsupportedWorkflowFailsWithReadableResult(testCase)
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, ...
                "evaluate_campaign", testCase.RunDirectory), 'EMIWorkbench:UnknownWorkflow');
            result = localResult(testCase.RunDirectory);
            testCase.verifyEqual(result.status, 'failed');
            testCase.verifyEqual(result.error.identifier, 'EMIWorkbench:UnknownWorkflow');
            testCase.verifyFalse(isfolder(fullfile(testCase.RunDirectory, 'output')));
        end

        function existingEmptyOutputIsRejected(testCase)
            mkdir(fullfile(testCase.RunDirectory, 'output'));
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, ...
                "baseline", testCase.RunDirectory), 'EMIWorkbench:OutputExists');
            result = localResult(testCase.RunDirectory);
            testCase.verifyEqual(result.status, 'failed');
            testCase.verifyEmpty(result.artifacts);
        end

        function historicalFilesAndResultAreNeverOverwritten(testCase)
            outputFolder = fullfile(testCase.RunDirectory, 'output');
            mkdir(outputFolder);
            sentinel = fullfile(outputFolder, 'preserved.txt');
            localWrite(sentinel, "retained evidence");
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, ...
                "baseline", testCase.RunDirectory), 'EMIWorkbench:OutputExists');
            originalResult = fileread(fullfile(testCase.RunDirectory, 'result.json'));
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, ...
                "baseline", testCase.RunDirectory), 'EMIWorkbench:ResultExists');
            testCase.verifyEqual(fileread(sentinel), 'retained evidence');
            testCase.verifyEqual(fileread(fullfile(testCase.RunDirectory, 'result.json')), originalResult);
        end

        function missingProjectSavesFailureBeforeReturning(testCase)
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, ...
                "baseline", testCase.RunDirectory), 'EMIWorkbench:InvalidProject');
            result = localResult(testCase.RunDirectory);
            testCase.verifyEqual(result.error.identifier, 'EMIWorkbench:InvalidProject');
            testCase.verifyFalse(isfolder(fullfile(testCase.RunDirectory, 'output')));
        end

        function baselineExportsStrictJsonAndRestoresCallerState(testCase)
            localFakeBaselineProject(testCase.ProjectRoot, false);
            oldPath = path;
            oldDirectory = pwd;
            oldVisibility = get(groot, 'DefaultFigureVisible');
            oldRandomState = rng;
            result = emi_workbench_run(testCase.ProjectRoot, "baseline", testCase.RunDirectory);
            raw = fileread(fullfile(testCase.RunDirectory, 'result.json'));
            decoded = jsondecode(raw);
            testCase.verifyEqual(result.status, "passed");
            testCase.verifyEqual(decoded.status, 'passed');
            testCase.verifyTrue(contains(raw, 'null'));
            testCase.verifyFalse(contains(raw, 'NaN'));
            testCase.verifyEqual(string(decoded.artifacts), "output/baseline_timeseries.csv");
            testCase.verifyEqual(decoded.provenance.parameter_set_id, 'WORKBENCH-TEST');
            testCase.verifyMatches(decoded.provenance.adapter_file_sha256, '^[a-f0-9]{64}$');
            testCase.verifyEqual(path, oldPath);
            testCase.verifyEqual(pwd, oldDirectory);
            testCase.verifyEqual(get(groot, 'DefaultFigureVisible'), oldVisibility);
            testCase.verifyEqual(rng, oldRandomState);
        end

        function workflowFailureRetainsPartialEvidenceAndRestoresState(testCase)
            localFakeBaselineProject(testCase.ProjectRoot, true);
            oldPath = path;
            oldDirectory = pwd;
            oldVisibility = get(groot, 'DefaultFigureVisible');
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, ...
                "baseline", testCase.RunDirectory), 'WorkbenchTest:ExpectedFailure');
            result = localResult(testCase.RunDirectory);
            testCase.verifyEqual(result.status, 'failed');
            testCase.verifyEqual(string(result.artifacts), "output/baseline_timeseries.csv");
            testCase.verifyEqual(path, oldPath);
            testCase.verifyEqual(pwd, oldDirectory);
            testCase.verifyEqual(get(groot, 'DefaultFigureVisible'), oldVisibility);
        end

        function characterizationCompletionDoesNotRequireScientificAcceptance(testCase)
            localFakeCharacterizationProject(testCase.ProjectRoot, false);
            oldPath = path;
            oldDirectory = pwd;
            result = emi_workbench_run(testCase.ProjectRoot, ...
                "receiver_characterization", testCase.RunDirectory);
            decoded = localResult(testCase.RunDirectory);
            testCase.verifyEqual(result.status, "passed");
            testCase.verifyFalse(decoded.characterization.suitableForFourWay);
            testCase.verifyEqual(decoded.metrics.totalCases, 3);
            testCase.verifyEqual(decoded.metrics.invalidCases, 1);
            testCase.verifyEqual(decoded.characterization.findings, 'No candidate established.');
            testCase.verifyTrue(contains(decoded.summary, 'Conditional simulation only'));
            testCase.verifyTrue(any(string(decoded.artifacts) == ...
                "output/receiver_characterization/cases.csv"));
            testCase.verifyTrue(any(string(decoded.artifacts) == ...
                "output/receiver_characterization/summary.json"));
            testCase.verifyMatches(decoded.provenance.receiver_characterization_file_sha256, '^[a-f0-9]{64}$');
            testCase.verifyEqual(path, oldPath);
            testCase.verifyEqual(pwd, oldDirectory);
        end

        function characterizationFailureKeepsPartialOutputs(testCase)
            localFakeCharacterizationProject(testCase.ProjectRoot, true);
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, ...
                "receiver_characterization", testCase.RunDirectory), 'WorkbenchTest:CharacterizationFailure');
            result = localResult(testCase.RunDirectory);
            testCase.verifyEqual(result.status, 'failed');
            testCase.verifyTrue(any(string(result.artifacts) == ...
                "output/receiver_characterization/cases.csv"));
        end

        function missingCharacterizationSourceFailsClearly(testCase)
            localFakeBaselineProject(testCase.ProjectRoot, false);
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, ...
                "receiver_characterization", testCase.RunDirectory), 'EMIWorkbench:MissingCharacterization');
            result = localResult(testCase.RunDirectory);
            testCase.verifyEqual(result.error.identifier, 'EMIWorkbench:MissingCharacterization');
        end

        function developmentCompletionKeepsFailedResearchGuards(testCase)
            localFakeDevelopmentProject(testCase.ProjectRoot, true, false);
            result = emi_workbench_run(testCase.ProjectRoot, "four_way_v2_development", testCase.RunDirectory);
            testCase.verifyEqual(result.status, "passed");
            decoded = localResult(testCase.RunDirectory);
            testCase.verifyFalse(decoded.development.summary.all_execution_clean_guards_pass);
            testCase.verifyEqual(decoded.development.pairs.Variant, 'V01');
            testCase.verifyEqual(decoded.development.pairs.ExecutionGuardPass, 0);
            testCase.verifyTrue(contains(decoded.summary, 'separately verified acceptance'));
            testCase.verifyMatches(decoded.provenance.development_runner_file_sha256, '^[a-f0-9]{64}$');
            testCase.verifyTrue(any(string(decoded.artifacts) == "output/four_way_v2_development/metrics.csv"));
        end

        function incompleteDevelopmentRetainsFailuresAndPairs(testCase)
            localFakeDevelopmentProject(testCase.ProjectRoot, false, false);
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, "four_way_v2_development", ...
                testCase.RunDirectory), 'EMIWorkbench:DevelopmentIncomplete');
            result = localResult(testCase.RunDirectory);
            testCase.verifyFalse(result.development.summary.complete);
            testCase.verifyEqual(result.development.pairs.Variant, 'V01');
            testCase.verifyTrue(any(string(result.artifacts) == "output/four_way_v2_development/metrics.csv"));
        end

        function developmentParserRejectsReservedEvaluation(testCase)
            localFakeDevelopmentProject(testCase.ProjectRoot, true, true);
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, "four_way_v2_development", ...
                testCase.RunDirectory), 'EMIWorkbench:DevelopmentPartition');
        end
    end
end

function localFakeDevelopmentProject(projectRoot, complete, wrongPartition)
localFakeBaselineProject(projectRoot, false);
v2Root = fullfile(projectRoot, '06_Circuit_Simulations', 'FOUR_WAY_V2');
mkdir(fullfile(v2Root, 'functions')); mkdir(fullfile(v2Root, 'scripts'));
partition = "development"; if wrongPartition, partition = "evaluation"; end
summary = struct('partition', partition, 'receiver_hypotheses', 16, 'expected_records', 256, ...
    'logical_records', 256, 'paired_results', 1, 'failed_records', double(~complete), ...
    'failed_pairs', 0, 'complete', complete, 'all_execution_clean_guards_pass', false);
lines = [
    "function study = run_fourway_v2_stage(partition, outputFolder)"
    "assert(partition == ""development""); assert(~isfolder(outputFolder)); mkdir(outputFolder);"
    "study = jsondecode('" + string(jsonencode(summary)) + "');"
    "fid=fopen(fullfile(outputFolder,'stage_summary.json'),'w'); fprintf(fid,'%s',jsonencode(study)); fclose(fid);"
    "row=struct('Fixture','D01','Variant','V01','Arm','BASELINE','ReceiverDomainPass',true,'ReceiverNumericsPass',true,'CleanGuardPass',false,'ExecutionGuardPass',false,'WindowPairedRMSE_deg',0.2,'WindowPairedPeak_deg',0.3,'PeakCurrent_A',0.4,'EMICountPeak_counts',2,'EMICountFinal_counts',1,'TaskSuccess',false);"
    "writetable(struct2table(row),fullfile(outputFolder,'metrics.csv'));"
    "end"
    ];
localWrite(fullfile(v2Root, 'scripts', 'run_fourway_v2_stage.m'), join(lines, newline));
end

function result = localResult(runDirectory)
result = jsondecode(fileread(fullfile(runDirectory, 'result.json')));
end

function localFakeBaselineProject(projectRoot, shouldFail)
matlabRoot = fullfile(projectRoot, '03_MATLAB');
mkdir(fullfile(matlabRoot, 'parameters'));
mkdir(fullfile(matlabRoot, 'scripts'));
localWrite(fullfile(matlabRoot, 'startup_project.m'), join([
    "root = fileparts(mfilename('fullpath'));"
    "addpath(fullfile(root, 'parameters'), fullfile(root, 'scripts'));"
    "rng(9876);"
    ], newline));
localWrite(fullfile(matlabRoot, 'parameters', 'actuator_parameters.m'), join([
    "function params = actuator_parameters()"
    "params.meta = struct('parameterSetId', 'WORKBENCH-TEST', 'provenance', 'Test fixture');"
    "end"
    ], newline));
lines = [
    "function study = run_baseline(outputFolder)"
    "assert(strcmp(get(groot, 'DefaultFigureVisible'), 'off'));"
    "writetable(table([0; 1], [0; 0.5], 'VariableNames', {'time_s', 'theta_rad'}), fullfile(outputFolder, 'baseline_timeseries.csv'));"
    "study.metrics = struct('trackingRMSE_rad', 0.25, 'settlingTime_s', NaN);"
    ];
if shouldFail
    lines(end+1) = "error('WorkbenchTest:ExpectedFailure', 'Intentional workflow failure.');";
end
lines(end+1) = "end";
localWrite(fullfile(matlabRoot, 'scripts', 'run_baseline.m'), join(lines, newline));
end

function localWrite(destination, text)
file = fopen(destination, 'w', 'n', 'UTF-8');
assert(file >= 0, 'Could not create fixture.');
cleanup = onCleanup(@()fclose(file)); %#ok<NASGU>
fprintf(file, '%s', text);
end

function localFakeCharacterizationProject(projectRoot, shouldFail)
localFakeBaselineProject(projectRoot, false);
receiverRoot = fullfile(projectRoot, '06_Circuit_Simulations', 'RECEIVER_V2');
mkdir(fullfile(receiverRoot, 'functions'));
mkdir(fullfile(receiverRoot, 'scripts'));
lines = [
    "function study = run_receiver_characterization(outputFolder)"
    "assert(~isfolder(outputFolder));"
    "mkdir(outputFolder);"
    "writetable(table([1; 2; 3], 'VariableNames', {'caseId'}), fullfile(outputFolder, 'cases.csv'));"
    "study = struct('studyId', 'RECEIVER-V2-TEST', 'totalCases', 3, 'validCases', 1, 'invalidCases', 1, 'unresolvedCases', 1, 'cleanErrorCases', 0, 'exposedErrorCases', 1, 'pulseLawDependentCases', 1, 'suitableForFourWay', false, 'findings', 'No candidate established.');"
    "file = fopen(fullfile(outputFolder, 'summary.json'), 'w'); fprintf(file, '%s', jsonencode(study)); fclose(file);"
    ];
if shouldFail
    lines(end+1) = "error('WorkbenchTest:CharacterizationFailure', 'Intentional sweep failure.');";
end
lines(end+1) = "end";
localWrite(fullfile(receiverRoot, 'scripts', 'run_receiver_characterization.m'), join(lines, newline));
end
