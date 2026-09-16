function result = emi_workbench_run(projectRoot, workflow, runDir, acceptancePath)
%EMI_WORKBENCH_RUN Run one existing workflow and retain its evidence.
% The launcher creates runDir. This adapter requires a new output child and
% never reuses result.json. Failed tests remain failed and raise an error
% after the machine-readable result has been saved for the workbench.
arguments
    projectRoot (1,1) string
    workflow (1,1) string
    runDir (1,1) string
    acceptancePath (1,1) string = ""
end

projectRoot = string(java.io.File(char(projectRoot)).getCanonicalPath());
runDir = string(java.io.File(char(runDir)).getCanonicalPath());
assert(isfolder(runDir), 'EMIWorkbench:MissingRunDirectory', ...
    'The launcher must create a fresh run directory first.');
resultPath = fullfile(runDir, 'result.json');
assert(~isfile(resultPath) && ~isfolder(resultPath), ...
    'EMIWorkbench:ResultExists', 'Existing run results cannot be overwritten.');

outputFolder = fullfile(runDir, 'output');
started = tic;
ownsOutput = false;
result = struct('workflow', workflow, 'status', "failed", ...
    'summary', "Workflow did not complete.", 'metrics', struct(), ...
    'artifacts', {{}}, 'started_at', localTimestamp(), ...
    'provenance', struct('matlab_version', version, ...
    'matlab_release', version('-release'), 'platform', computer, ...
    'project_root', projectRoot));

try
    result.provenance.adapter_file_sha256 = localHash(string(mfilename('fullpath')) + ".m");
    if workflow == "project_tests"
        result.provenance.workflow_test_folders = { ...
            '03_MATLAB/tests', ...
            '06_Circuit_Simulations/SC01A/tests', ...
            '06_Circuit_Simulations/SC01B_R2/tests', ...
            '06_Circuit_Simulations/FOUR_WAY/tests'};
    end
    assert(any(workflow == ["baseline", "receiver_characterization", "four_way_v2_development", ...
        "four_way_v2_evaluation", "four_way_v2_closure", "receiver_tests", "project_tests"]), ...
        'EMIWorkbench:UnknownWorkflow', 'Unsupported workbench workflow: %s', workflow);
    if any(workflow == ["four_way_v2_evaluation", "four_way_v2_closure"])
        assert(strlength(acceptancePath)>0 && isfile(acceptancePath), ...
            'EMIWorkbench:MissingAcceptance', 'A separately verified V2 implementation acceptance file is required.');
        acceptancePath = string(java.io.File(char(acceptancePath)).getCanonicalPath());
        result.provenance.acceptance_path = acceptancePath;
        result.provenance.acceptance_file_sha256 = localHash(acceptancePath);
    end
    assert(~isfolder(outputFolder) && ~isfile(outputFolder), ...
        'EMIWorkbench:OutputExists', ...
        'The output directory already exists. Start a new workbench run.');
    startupFile = fullfile(projectRoot, '03_MATLAB', 'startup_project.m');
    assert(isfile(startupFile), 'EMIWorkbench:InvalidProject', ...
        'Project startup file is missing: %s', startupFile);
    [created, message] = mkdir(outputFolder);
    assert(created, 'EMIWorkbench:CannotCreateOutput', '%s', message);
    ownsOutput = true;

    % Restore the caller's state, including figures that existed beforehand.
    oldPath = path;
    oldDirectory = pwd;
    oldRandomState = rng;
    oldVisibility = get(groot, 'DefaultFigureVisible');
    oldFigures = findall(groot, 'Type', 'figure');
    stateCleanup = onCleanup(@()localRestoreState(oldPath, oldDirectory, ...
        oldRandomState, oldVisibility, oldFigures)); %#ok<NASGU>
    set(groot, 'DefaultFigureVisible', 'off');
    cd(runDir);
    localStartup(startupFile);

    params = actuator_parameters();
    result.provenance.parameter_set_id = params.meta.parameterSetId;
    result.provenance.parameter_source = params.meta.provenance;
    result.provenance.parameter_file_sha256 = localHash( ...
        fullfile(projectRoot, '03_MATLAB', 'parameters', 'actuator_parameters.m'));

    switch workflow
        case {"four_way_v2_evaluation", "four_way_v2_closure"}
            v2Root = fullfile(projectRoot, '06_Circuit_Simulations', 'FOUR_WAY_V2');
            runnerName = 'run_fourway_v2_stage.m';
            if workflow == "four_way_v2_closure", runnerName = 'run_fourway_v2_closure.m'; end
            runnerFile = fullfile(v2Root, 'scripts', runnerName);
            assert(isfile(runnerFile), 'EMIWorkbench:MissingV2Runner', ...
                'The selected four-way v2 runner is missing from the verified scientific workspace.');
            addpath(fullfile(v2Root, 'functions'), fullfile(v2Root, 'scripts'));
            result.provenance.v2_runner_file_sha256 = localHash(runnerFile);
            studyFolder = fullfile(outputFolder, workflow);
            if workflow == "four_way_v2_evaluation"
                run_fourway_v2_stage("evaluation", studyFolder, acceptancePath);
                result.evaluation = emi_workbench_evaluation_result(studyFolder);
                summary = result.evaluation.summary;
                result.metrics = struct('logicalRecords', summary.logical_records, ...
                    'pairedResults', summary.paired_results, 'receiverHypotheses', summary.receiver_hypotheses, ...
                    'failedRecords', summary.failed_records, 'failedPairs', summary.failed_pairs, ...
                    'evaluationGuardsPass', summary.all_execution_clean_guards_pass);
                if isfield(summary, 'assessment')
                    result.metrics.passingHypotheses = summary.assessment.passing_hypotheses;
                    result.metrics.allHypothesesBenefitPass = summary.assessment.all_hypotheses_pass;
                end
                result.summary = string(sprintf(['Evaluation completed: %d records and %d matched comparisons under %d receiver assumptions. ' ...
                    'Execution, research guards, and each hypothesis benefit screen are separate results. Conditional simulation only.'], ...
                    summary.logical_records, summary.paired_results, summary.receiver_hypotheses));
            else
                run_fourway_v2_closure(studyFolder, acceptancePath);
                result.closure = emi_workbench_closure_result(studyFolder);
                summary = result.closure.summary;
                result.metrics = struct('logicalRecords', summary.logical_records, ...
                    'comparisonPairs', summary.comparison_pairs, 'receiverHypotheses', result.closure.receiverHypotheses, ...
                    'failedRecords', result.closure.failedRecords, ...
                    'closureDomainNumericsPass', result.closure.domainNumericsPass);
                result.summary = string(sprintf(['Return-sensitivity diagnostic completed: %d records and %d short/long-return comparisons. ' ...
                    'This conditional diagnostic is excluded from primary evaluation scoring and does not establish mitigation benefit.'], ...
                    summary.logical_records, summary.comparison_pairs));
            end
            assert(strcmp(result.provenance.acceptance_file_sha256, localHash(acceptancePath)), ...
                'EMIWorkbench:AcceptanceChanged', 'The acceptance file changed during execution; retain these outputs for review.');
            assert(summary.complete, 'EMIWorkbench:V2ExecutionIncomplete', ...
                'The selected V2 execution is incomplete; failed records and partial outputs remain available.');
            result.status = "passed";
        case "four_way_v2_development"
            v2Root = fullfile(projectRoot, '06_Circuit_Simulations', 'FOUR_WAY_V2');
            runnerFile = fullfile(v2Root, 'scripts', 'run_fourway_v2_stage.m');
            assert(isfile(runnerFile), 'EMIWorkbench:MissingDevelopment', ...
                'Four-way v2 development source is missing from this workspace.');
            addpath(fullfile(v2Root, 'functions'), fullfile(v2Root, 'scripts'));
            result.provenance.development_runner_file_sha256 = localHash(runnerFile);
            developmentFolder = fullfile(outputFolder, 'four_way_v2_development');
            run_fourway_v2_stage("development", developmentFolder);
            result.development = emi_workbench_development_result(developmentFolder);
            summary = result.development.summary;
            result.metrics = struct('logicalRecords', summary.logical_records, ...
                'pairedResults', summary.paired_results, 'receiverHypotheses', summary.receiver_hypotheses, ...
                'failedRecords', summary.failed_records, 'failedPairs', summary.failed_pairs, ...
                'developmentGuardsPass', summary.all_execution_clean_guards_pass);
            result.summary = string(sprintf(['Development completed: %d records and %d matched comparisons across %d receiver assumptions. ' ...
                'Conditional simulation only; each hypothesis retains its own results. Reserved evaluation requires separately verified acceptance.'], ...
                summary.logical_records, summary.paired_results, summary.receiver_hypotheses));
            assert(summary.complete, 'EMIWorkbench:DevelopmentIncomplete', ...
                'Development execution is incomplete; failed records and partial outputs remain available.');
            result.status = "passed";
        case "receiver_characterization"
            receiverRoot = fullfile(projectRoot, '06_Circuit_Simulations', 'RECEIVER_V2');
            runnerFile = fullfile(receiverRoot, 'scripts', 'run_receiver_characterization.m');
            assert(isfile(runnerFile), 'EMIWorkbench:MissingCharacterization', ...
                'Receiver v2 characterization source is missing from this workspace.');
            addpath(fullfile(receiverRoot, 'functions'), fullfile(receiverRoot, 'scripts'));
            result.provenance.receiver_characterization_file_sha256 = localHash(runnerFile);
            study = run_receiver_characterization(fullfile(outputFolder, 'receiver_characterization'));
            result.characterization = study;
            result.metrics = struct('totalCases', study.totalCases, ...
                'validCases', study.validCases, 'invalidCases', study.invalidCases, ...
                'unresolvedCases', study.unresolvedCases, 'cleanErrorCases', study.cleanErrorCases, ...
                'exposedErrorCases', study.exposedErrorCases, ...
                'pulseLawDependentCases', study.pulseLawDependentCases);
            result.status = "passed";
            result.summary = string(sprintf(['Receiver characterization completed: %d cases; ' ...
                '%d within the model domain with converged numerics, %d outside, %d unresolved. ' ...
                'Conditional simulation only; inspect domain and timing findings before interpreting control comparisons.'], ...
                study.totalCases, study.validCases, study.invalidCases, study.unresolvedCases));
        case "baseline"
            study = run_baseline(outputFolder);
            result.metrics = study.metrics;
            result.status = "passed";
            result.summary = "Clean baseline completed with the existing project parameters.";
        case "receiver_tests"
            % Preserve the runner's own acceptance checks and diagnostic files.
            report = run_fourway_receiver_tests(outputFolder);
            result.metrics = localReadTestMetrics(outputFolder);
            result.provenance.receiver_engine = report.engine_function;
            result.provenance.receiver_source = report.source;
            assert(report.accepted && result.metrics.tests > 0, ...
                'EMIWorkbench:ReceiverTestsFailed', ...
                'Focused receiver tests did not all pass.');
            result.status = "passed";
            result.summary = localTestSummary("Receiver tests", result.metrics);
            localWriteTestSummary(outputFolder, result);
        case "project_tests"
            % Keep generated Simulink caches and guard-test scratch with this run.
            % Some existing test fixtures also create and remove unique scratch
            % folders in 03_MATLAB/work; their source and gates stay unchanged.
            scratchFolder = fullfile(runDir, 'scratch');
            mkdir(scratchFolder);
            oldGuardRoot = getenv('EMI_OUTPUT_GUARD_TEST_ROOT');
            guardCleanup = onCleanup(@()setenv('EMI_OUTPUT_GUARD_TEST_ROOT', oldGuardRoot)); %#ok<NASGU>
            setenv('EMI_OUTPUT_GUARD_TEST_ROOT', char(scratchFolder));
            if exist('Simulink.fileGenControl', 'file') ~= 0
                oldConfig = Simulink.fileGenControl('getConfig');
                cacheCleanup = onCleanup(@()Simulink.fileGenControl( ...
                    'setConfig', 'config', oldConfig)); %#ok<NASGU>
                Simulink.fileGenControl('set', ...
                    'CacheFolder', char(fullfile(scratchFolder, 'simulink_cache')), ...
                    'CodeGenFolder', char(fullfile(scratchFolder, 'simulink_codegen')), ...
                    'createDir', true);
            end
            % Match the published main robotics regression scope. The original
            % SC01B implementation and the EDMD study have separate suites.
            circuitA = fullfile(projectRoot, '06_Circuit_Simulations', 'SC01A');
            circuitB = fullfile(projectRoot, '06_Circuit_Simulations', 'SC01B_R2');
            fourWay = fullfile(projectRoot, '06_Circuit_Simulations', 'FOUR_WAY');
            addpath(fullfile(circuitA, 'functions'), fullfile(circuitA, 'scripts'), ...
                fullfile(circuitB, 'functions'), fullfile(circuitB, 'scripts'), circuitB);
            suite = [ ...
                matlab.unittest.TestSuite.fromFolder(fullfile(projectRoot, '03_MATLAB', 'tests')), ...
                matlab.unittest.TestSuite.fromFolder(fullfile(circuitA, 'tests')), ...
                matlab.unittest.TestSuite.fromFolder(fullfile(circuitB, 'tests')), ...
                matlab.unittest.TestSuite.fromFolder(fullfile(fourWay, 'tests'))];
            tests = run(suite);
            testTable = table(string({tests.Name}).', [tests.Passed].', ...
                [tests.Failed].', [tests.Incomplete].', [tests.Duration].', ...
                'VariableNames', {'Name', 'Passed', 'Failed', 'Incomplete', 'Duration_s'});
            writetable(testTable, fullfile(outputFolder, 'test_results.csv'));
            save(fullfile(outputFolder, 'test_results.mat'), 'tests');
            result.metrics = localTestMetrics(testTable);
            result.summary = localTestSummary("Project tests", result.metrics);
            assert(result.metrics.tests > 0 && result.metrics.passed == result.metrics.tests ...
                && result.metrics.failed == 0 && result.metrics.incomplete == 0, ...
                'EMIWorkbench:ProjectTestsFailed', '%s', result.summary);
            result.status = "passed";
            localWriteTestSummary(outputFolder, result);
    end

    result.artifacts = localArtifacts(outputFolder, runDir, workflow);
    result.finished_at = localTimestamp();
    result.duration_s = toc(started);
    localWriteJson(resultPath, result);
catch failure
    result.status = "failed";
    result.summary = string(failure.message);
    result.error = struct('identifier', failure.identifier, 'message', failure.message);
    if ownsOutput
        % The receiver runner saves diagnostics before asserting acceptance.
        % Recover counts so a failed run still has useful, accurate results.
        if any(workflow == ["receiver_tests", "project_tests"])
            try
                result.metrics = localReadTestMetrics(outputFolder);
                result.summary = localTestSummary("Tests", result.metrics);
            catch
                % An earlier setup error can leave no test-results table.
            end
            try
                localWriteTestSummary(outputFolder, result);
            catch summaryFailure
                warning('EMIWorkbench:SummaryWriteFailed', '%s', summaryFailure.message);
            end
        end
        result.artifacts = localArtifacts(outputFolder, runDir, workflow);
    end
    result.finished_at = localTimestamp();
    result.duration_s = toc(started);
    try
        localWriteJson(resultPath, result);
    catch writeFailure
        warning('EMIWorkbench:ResultWriteFailed', '%s', writeFailure.message);
    end
    rethrow(failure);
end
end

function localStartup(startupFile)
% Isolate script-local variables from the adapter workspace.
run(startupFile);
end

function localRestoreState(oldPath, oldDirectory, oldRandomState, oldVisibility, oldFigures)
set(groot, 'DefaultFigureVisible', oldVisibility);
newFigures = setdiff(findall(groot, 'Type', 'figure'), oldFigures);
delete(newFigures(isgraphics(newFigures)));
rng(oldRandomState);
cd(oldDirectory);
path(oldPath);
end

function stamp = localTimestamp()
stamp = string(datetime('now', 'TimeZone', 'UTC', ...
    'Format', "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function digestText = localHash(filePath)
file = fopen(filePath, 'rb');
assert(file >= 0, 'EMIWorkbench:ProvenanceReadFailed', ...
    'Cannot read provenance source: %s', filePath);
cleanup = onCleanup(@()fclose(file)); %#ok<NASGU>
bytes = fread(file, Inf, '*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
digestText = lower(reshape(dec2hex(typecast(digest.digest(), 'uint8'), 2).', 1, []));
end

function metrics = localReadTestMetrics(outputFolder)
testTable = readtable(fullfile(outputFolder, 'test_results.csv'), ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
metrics = localTestMetrics(testTable);
end

function metrics = localTestMetrics(testTable)
metrics = struct('tests', height(testTable), ...
    'passed', sum(testTable.Passed), 'failed', sum(testTable.Failed), ...
    'incomplete', sum(testTable.Incomplete), 'duration_s', sum(testTable.Duration_s));
end

function summary = localTestSummary(label, metrics)
summary = string(sprintf('%s: %d of %d passed; %d failed; %d incomplete.', ...
    label, metrics.passed, metrics.tests, metrics.failed, metrics.incomplete));
end

function localWriteTestSummary(outputFolder, result)
summary = struct('workflow', result.workflow, 'status', result.status, ...
    'summary', result.summary, 'metrics', result.metrics);
if isfield(result, 'error'), summary.error = result.error; end
localWriteJson(fullfile(outputFolder, 'test_summary.json'), summary);
end

function artifacts = localArtifacts(outputFolder, runDir, workflow)
listing = dir(fullfile(outputFolder, '**', '*'));
listing = listing(~[listing.isdir]);
artifacts = cell(numel(listing), 1);
prefix = char(runDir + filesep);
for index = 1:numel(listing)
    absolutePath = fullfile(listing(index).folder, listing(index).name);
    artifacts{index} = strrep(absolutePath(numel(prefix) + 1:end), '\', '/');
end
artifacts = sort(artifacts);
if any(workflow == ["four_way_v2_evaluation", "four_way_v2_closure"])
    % Complete campaigns contain thousands of raw files. Keep the response
    % small while retaining an explicit inventory and every raw file on disk.
    indexPath = fullfile(outputFolder, 'artifact_index.csv');
    indexRelative = 'output/artifact_index.csv';
    if ~isfile(indexPath)
        paths = strings(numel(listing),1); sizes = zeros(numel(listing),1);
        for k = 1:numel(listing)
            absolutePath = fullfile(listing(k).folder, listing(k).name);
            paths(k) = string(strrep(absolutePath(numel(prefix)+1:end), '\', '/'));
            sizes(k) = listing(k).bytes;
        end
        inventory = sortrows(table(paths, sizes, 'VariableNames', {'Artifact','Bytes'}), 'Artifact');
        writetable(inventory, indexPath);
    end
    artifacts = artifacts(count(string(artifacts), '/') <= 2);
    artifacts = sort(unique([artifacts; {indexRelative}]));
end
end

function localWriteJson(destination, value)
% Stage beside the destination, then rename the completed JSON into place.
% JSON null represents NaN/Inf; consumers never receive nonstandard JSON.
assert(~isfile(destination) && ~isfolder(destination), ...
    'EMIWorkbench:EvidenceExists', 'Evidence file already exists: %s', destination);
temporaryPath = string(tempname(fileparts(destination))) + ".json.tmp";
cleanup = onCleanup(@()localDeleteTemporary(temporaryPath)); %#ok<NASGU>
encoded = jsonencode(value, 'PrettyPrint', true, 'ConvertInfAndNaN', true);
file = fopen(temporaryPath, 'w', 'n', 'UTF-8');
assert(file >= 0, 'EMIWorkbench:CannotWriteResult', 'Cannot create result file.');
fileCleanup = onCleanup(@()fclose(file));
count = fprintf(file, '%s\n', encoded);
assert(count > 0, 'EMIWorkbench:CannotWriteResult', 'Result file write failed.');
clear fileCleanup;
assert(~isfile(destination) && ~isfolder(destination), ...
    'EMIWorkbench:EvidenceExists', 'Evidence file already exists: %s', destination);
[moved, message] = movefile(temporaryPath, destination);
assert(moved, 'EMIWorkbench:CannotCommitResult', '%s', message);
end

function localDeleteTemporary(temporaryPath)
if isfile(temporaryPath), delete(temporaryPath); end
end
