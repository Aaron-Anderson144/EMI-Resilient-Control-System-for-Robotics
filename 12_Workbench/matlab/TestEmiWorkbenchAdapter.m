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
    end
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
