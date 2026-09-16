classdef TestEmiWorkbenchReserved < matlab.unittest.TestCase
    % Dispatch boundaries use isolated stages; no scientific campaign reruns.
    properties
        ProjectRoot
        RunDirectory
        AcceptancePath
    end
    methods (TestMethodSetup)
        function createProject(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.ProjectRoot = string(fullfile(folder.Folder, 'project'));
            testCase.RunDirectory = string(fullfile(folder.Folder, 'run'));
            testCase.AcceptancePath = string(fullfile(folder.Folder, 'acceptance.json'));
            mkdir(testCase.ProjectRoot); mkdir(testCase.RunDirectory);
            localWrite(testCase.AcceptancePath, 'accepted fixture');
            matlabRoot = fullfile(testCase.ProjectRoot, '03_MATLAB');
            mkdir(fullfile(matlabRoot, 'parameters'));
            localWrite(fullfile(matlabRoot, 'startup_project.m'), ...
                "addpath(fullfile(fileparts(mfilename('fullpath')), 'parameters'));" );
            localWrite(fullfile(matlabRoot, 'parameters', 'actuator_parameters.m'), join([
                "function p=actuator_parameters()"
                "p.meta=struct('parameterSetId','RESERVED-ADAPTER-TEST','provenance','isolated fixture');"
                "end"], newline));
            v2Root = fullfile(testCase.ProjectRoot, '06_Circuit_Simulations', 'FOUR_WAY_V2');
            mkdir(fullfile(v2Root, 'functions')); mkdir(fullfile(v2Root, 'scripts'));
        end
    end
    methods (Test)
        function missingAcceptanceFailsBeforeCreatingOutput(testCase)
            for workflow = ["four_way_v2_evaluation", "four_way_v2_closure"]
                directory = fullfile(testCase.RunDirectory, workflow); mkdir(directory);
                testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, workflow, directory), ...
                    'EMIWorkbench:MissingAcceptance');
                testCase.verifyFalse(isfolder(fullfile(directory, 'output')));
                result = jsondecode(fileread(fullfile(directory, 'result.json')));
                testCase.verifyEqual(result.status, 'failed');
            end
        end

        function coreAcceptanceRejectionRemainsAWorkflowFailure(testCase)
            localRunner(testCase, "evaluation", true, true, false);
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, "four_way_v2_evaluation", ...
                testCase.RunDirectory, testCase.AcceptancePath), 'EMIProject:V2Acceptance');
            result = localResult(testCase);
            testCase.verifyEqual(result.status, 'failed');
            testCase.verifyEqual(result.error.identifier, 'EMIProject:V2Acceptance');
        end

        function evaluationCompletionKeepsNegativeBenefitScreens(testCase)
            localRunner(testCase, "evaluation", true, false, false);
            oldPath = path; oldDirectory = pwd;
            result = emi_workbench_run(testCase.ProjectRoot, "four_way_v2_evaluation", ...
                testCase.RunDirectory, testCase.AcceptancePath);
            testCase.verifyEqual(result.status, "passed");
            testCase.verifyEqual(numel(result.evaluation.pairs), 768);
            testCase.verifyEqual(numel(result.evaluation.hypotheses), 16);
            testCase.verifyTrue(result.metrics.evaluationGuardsPass);
            testCase.verifyEqual(result.metrics.passingHypotheses, 0);
            testCase.verifyFalse(result.metrics.allHypothesesBenefitPass);
            testCase.verifyMatches(result.provenance.acceptance_file_sha256, '^[a-f0-9]{64}$');
            testCase.verifyEqual(string(fileread(fullfile(testCase.RunDirectory, 'output', ...
                'four_way_v2_evaluation', 'acceptance_received.txt'))), result.provenance.acceptance_path);
            testCase.verifyTrue(any(string(result.artifacts) == "output/artifact_index.csv"));
            testCase.verifyTrue(any(endsWith(string(result.artifacts), '/stage_summary.json')));
            testCase.verifyFalse(any(endsWith(string(result.artifacts), '/raw_trace.csv')));
            inventory = readtable(fullfile(testCase.RunDirectory, 'output', 'artifact_index.csv'), 'TextType', 'string');
            raw = inventory(endsWith(inventory.Artifact, '/raw_trace.csv'),:);
            testCase.verifyEqual(height(raw), 1);
            testCase.verifyTrue(isfile(fullfile(testCase.RunDirectory, raw.Artifact)));
            testCase.verifyFalse(any(contains(inventory.Artifact, '..')));
            testCase.verifyEqual(path, oldPath); testCase.verifyEqual(pwd, oldDirectory);
        end

        function incompleteEvaluationKeepsPartialEvidence(testCase)
            localRunner(testCase, "evaluation", false, false, false);
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, "four_way_v2_evaluation", ...
                testCase.RunDirectory, testCase.AcceptancePath), 'EMIWorkbench:V2ExecutionIncomplete');
            result = localResult(testCase);
            testCase.verifyEqual(numel(result.evaluation.pairs), 1);
            testCase.verifyEmpty(result.evaluation.hypotheses);
            testCase.verifyFalse(isfield(result.metrics, 'passingHypotheses'));
            testCase.verifyTrue(any(contains(string(result.artifacts), 'metrics.csv')));
        end

        function closureCompletionKeepsFailedDomainGuards(testCase)
            localRunner(testCase, "closure", true, false, false);
            result = emi_workbench_run(testCase.ProjectRoot, "four_way_v2_closure", ...
                testCase.RunDirectory, testCase.AcceptancePath);
            testCase.verifyEqual(result.status, "passed");
            testCase.verifyEqual(numel(result.closure.comparisons), 128);
            testCase.verifyFalse(result.metrics.closureDomainNumericsPass);
            testCase.verifyTrue(result.closure.summary.excluded_from_primary_evaluation);
            testCase.verifyFalse(isfield(result.metrics, 'allHypothesesBenefitPass'));
        end

        function incompleteClosureKeepsFailureIndex(testCase)
            localRunner(testCase, "closure", false, false, false);
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, "four_way_v2_closure", ...
                testCase.RunDirectory, testCase.AcceptancePath), 'EMIWorkbench:V2ExecutionIncomplete');
            result = localResult(testCase);
            testCase.verifyEqual(result.closure.failedRecords, 1);
            testCase.verifyEqual(numel(result.closure.comparisons), 1);
            testCase.verifyTrue(any(contains(string(result.artifacts), 'record_index.csv')));
        end

        function acceptanceMutationCannotBecomeSuccessfulResult(testCase)
            localRunner(testCase, "evaluation", true, false, true);
            testCase.verifyError(@()emi_workbench_run(testCase.ProjectRoot, "four_way_v2_evaluation", ...
                testCase.RunDirectory, testCase.AcceptancePath), 'EMIWorkbench:AcceptanceChanged');
            testCase.verifyEqual(localResult(testCase).status, 'failed');
        end

        function duplicateEvaluationPairIsRejected(testCase)
            data = fullfile(testCase.ProjectRoot, 'data'); mkdir(data);
            localEvaluation(data, true);
            metrics = readtable(fullfile(data, 'metrics.csv')); metrics(2,:) = metrics(1,:);
            writetable(metrics, fullfile(data, 'metrics.csv'));
            testCase.verifyError(@()emi_workbench_evaluation_result(data), 'EMIWorkbench:EvaluationCoverage');
        end

        function closureCannotEnterPrimaryScoring(testCase)
            data = fullfile(testCase.ProjectRoot, 'data'); mkdir(data);
            localClosure(data, true);
            summary = jsondecode(fileread(fullfile(data, 'stage_summary.json')));
            summary.excluded_from_primary_evaluation = false;
            localWrite(fullfile(data, 'stage_summary.json'), jsonencode(summary));
            testCase.verifyError(@()emi_workbench_closure_result(data), 'EMIWorkbench:ClosureStage');
        end
    end
end

function result = localResult(testCase)
result = jsondecode(fileread(fullfile(testCase.RunDirectory, 'result.json')));
end

function localRunner(testCase, kind, complete, reject, mutate)
data = fullfile(testCase.ProjectRoot, 'fixture_data'); mkdir(data);
if kind == "evaluation", localEvaluation(data, complete); else, localClosure(data, complete); end
mkdir(fullfile(data, 'record_fixture'));
localWrite(fullfile(data, 'record_fixture', 'raw_trace.csv'), "time_s,value" + newline + "0,1");
scriptRoot = fullfile(testCase.ProjectRoot, '06_Circuit_Simulations', 'FOUR_WAY_V2', 'scripts');
if kind == "evaluation"
    name = 'run_fourway_v2_stage.m';
    lines = ["function out=run_fourway_v2_stage(partition,outputFolder,acceptancePath)"; "assert(partition==""evaluation"");"];
else
    name = 'run_fourway_v2_closure.m';
    lines = "function out=run_fourway_v2_closure(outputFolder,acceptancePath)";
end
lines = [lines; "assert(strcmp(fileread(acceptancePath),'accepted fixture'));"; ...
    "assert(~isfolder(outputFolder));"];
if reject, lines(end+1) = "error('EMIProject:V2Acceptance','Intentional core acceptance rejection.');"; end
lines = [lines; "mkdir(outputFolder);"; ...
    "source=fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))),'fixture_data');"; ...
    "copyfile(fullfile(source,'*'),outputFolder);"; ...
    "fid=fopen(fullfile(outputFolder,'acceptance_received.txt'),'w'); fprintf(fid,'%s',acceptancePath); fclose(fid);"; ...
    "out=struct();"];
if mutate, lines(end+1) = "fid=fopen(acceptancePath,'a'); fprintf(fid,'changed'); fclose(fid);"; end
lines(end+1) = "end";
localWrite(fullfile(scriptRoot, name), join(lines, newline));
end

function localEvaluation(folder, complete)
row = struct('Fixture',"V2EVAL01",'Variant',"V01",'Arm',"BASELINE", ...
    'ReceiverDomainPass',true,'ReceiverNumericsPass',true,'CleanGuardPass',true,'ExecutionGuardPass',true, ...
    'WindowPairedRMSE_deg',0.2,'WindowPairedPeak_deg',0.3,'PeakCurrent_A',0.4, ...
    'EMICountPeak_counts',1,'EMICountFinal_counts',0,'TaskSuccess',true);
rows = repmat(row, 768, 1); index = 0; arms = ["BASELINE","EM_ONLY","SW_ONLY","COMBINED"];
for variant = 1:16
    for fixture = 1:12
        for arm = arms
            index = index+1; rows(index).Variant = string(sprintf('V%02d',variant));
            rows(index).Fixture = string(sprintf('V2EVAL%02d',fixture)); rows(index).Arm = arm;
        end
    end
end
if ~complete, rows=rows(1); end
writetable(struct2table(rows), fullfile(folder, 'metrics.csv'));
summary = struct('partition','evaluation','receiver_hypotheses',16,'expected_records',1536, ...
    'logical_records',2*numel(rows),'paired_results',numel(rows),'failed_records',double(~complete), ...
    'failed_pairs',0,'complete',complete,'all_execution_clean_guards_pass',complete);
if complete
    screen = struct('variant',struct('id',"V01"),'combined_benefit_demonstrated',false, ...
        'all_execution_clean_guards_pass',true,'rescued_failures',0,'rescued_failure_gate',false);
    screens = repmat(screen,16,1);
    for k=1:16, screens(k).variant.id=string(sprintf('V%02d',k)); end
    summary.assessment=struct('hypotheses',screens,'passing_hypotheses',0,'all_hypotheses_pass',false);
end
localWrite(fullfile(folder,'stage_summary.json'),jsonencode(summary));
end

function localClosure(folder, complete)
row = struct('Fixture',"V2CLOS40",'Variant',"V01",'Arm',"BASELINE",'Ccp_pF',40, ...
    'ReturnSensitivityRMSE_deg',0.2,'ReturnSensitivityPeak_deg',0.3, ...
    'ShortReturnPeakCountError',0,'LongReturnPeakCountError',1, ...
    'ShortReturnFinalCountError',0,'LongReturnFinalCountError',1, ...
    'ShortReturnDomainNumericsPass',true,'LongReturnDomainNumericsPass',false);
rows = repmat(row,128,1); index=0; arms=["BASELINE","EM_ONLY","SW_ONLY","COMBINED"];
for variant=1:16
    for cp=[40 240]
        for arm=arms
            index=index+1; rows(index).Variant=string(sprintf('V%02d',variant));
            rows(index).Fixture="V2CLOS"+cp; rows(index).Ccp_pF=cp; rows(index).Arm=arm;
        end
    end
end
if ~complete, rows=rows(1); end
writetable(struct2table(rows), fullfile(folder,'closure_comparisons.csv'));
status=repmat("passed",2*numel(rows),1); if ~complete,status(end)="failed";end
writetable(table(status,'VariableNames',{'Status'}),fullfile(folder,'record_index.csv'));
summary=struct('stage','closure_diagnostic','expected_records',256,'logical_records',numel(status), ...
    'comparison_pairs',numel(rows),'complete',complete,'excluded_from_primary_evaluation',true);
localWrite(fullfile(folder,'stage_summary.json'),jsonencode(summary));
end

function localWrite(destination, text)
fid=fopen(destination,'w','n','UTF-8'); assert(fid>=0); closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',text);
end
