classdef TestOutputPreservation < matlab.unittest.TestCase
    % Evidence destinations reject reuse before startup, tests or simulation.
    properties
        Folder
        MatlabRoot
        CircuitRoot
    end
    methods(TestMethodSetup)
        function prepare(testCase)
            testCase.MatlabRoot=fileparts(fileparts(mfilename('fullpath')));
            testCase.CircuitRoot=fullfile(fileparts(testCase.MatlabRoot),'06_Circuit_Simulations','SC01A');
            originalPath=path;testCase.addTeardown(@()path(originalPath));
            addpath(testCase.MatlabRoot,fullfile(testCase.MatlabRoot,'functions'), ...
                fullfile(testCase.MatlabRoot,'scripts'),fullfile(testCase.MatlabRoot,'parameters'), ...
                testCase.CircuitRoot,fullfile(testCase.CircuitRoot,'functions'),fullfile(testCase.CircuitRoot,'scripts'));
            base=string(getenv('EMI_OUTPUT_GUARD_TEST_ROOT'));
            if base=="",base=string(tempdir);end
            assert(isfolder(base),'Output guard test root must already exist.');
            testCase.Folder=string(tempname(base));mkdir(testCase.Folder);
            testCase.addTeardown(@()localRemoveOwnedFolder(testCase.Folder,base));
            visible=get(groot,'DefaultFigureVisible');set(groot,'DefaultFigureVisible','off');
            testCase.addTeardown(@()set(groot,'DefaultFigureVisible',visible));
            figures=findall(groot,'Type','figure');
            testCase.addTeardown(@()delete(setdiff(findall(groot,'Type','figure'),figures)));
        end
    end
    methods(Test)
        function newAndEmptyFoldersAreAccepted(testCase)
            guards={@prepare_fresh_output_folder,@sc01a_prepare_output_folder};
            for k=1:numel(guards)
                dest=fullfile(testCase.Folder,"explicit_"+k);
                actual=guards{k}(dest,testCase.Folder,"unused");
                testCase.verifyTrue(isfolder(actual));
                testCase.verifyEqual(guards{k}(dest,testCase.Folder,"unused"),actual);
            end
        end
        function populatedAndNestedFoldersAreRejected(testCase)
            dest=fullfile(testCase.Folder,'populated');mkdir(dest);mkdir(fullfile(dest,'nested'));
            testCase.verifyError(@()prepare_fresh_output_folder(dest,testCase.Folder,"unused"),'EMIProject:OutputFolderExists');
            testCase.verifyError(@()sc01a_prepare_output_folder(dest,testCase.Folder,"unused"),'SC01A:OutputFolderExists');
            testCase.verifyEqual(numel(dir(dest)),3);
        end
        function existingFileIsNeverReplaced(testCase)
            dest=fullfile(testCase.Folder,'evidence');localWrite(dest,"preserve bytes");
            testCase.verifyError(@()prepare_fresh_output_folder(dest,testCase.Folder,"unused"),'EMIProject:OutputFolderExists');
            testCase.verifyError(@()sc01a_prepare_output_folder(dest,testCase.Folder,"unused"),'SC01A:OutputFolderExists');
            testCase.verifyEqual(string(fileread(dest)),"preserve bytes");
        end
        function missingAndWhitespacePathsDoNotSelectDefaults(testCase)
            testCase.verifyError(@()prepare_fresh_output_folder(string(missing),testCase.Folder,"unused"),'EMIProject:OutputFolderExists');
            testCase.verifyError(@()prepare_fresh_output_folder(" ",testCase.Folder,"unused"),'EMIProject:OutputFolderExists');
            testCase.verifyError(@()sc01a_prepare_output_folder(string(missing),testCase.Folder,"unused"),'SC01A:OutputFolderExists');
            testCase.verifyError(@()sc01a_prepare_output_folder(" ",testCase.Folder,"unused"),'SC01A:OutputFolderExists');
            testCase.verifyEqual(numel(dir(testCase.Folder)),2);
        end
        function defaultFoldersAreUniqueEvenWhenPreviousIsEmpty(testCase)
            guards={@prepare_fresh_output_folder,@sc01a_prepare_output_folder};
            for k=1:numel(guards)
                first=guards{k}("",testCase.Folder,"fresh");second=guards{k}("",testCase.Folder,"fresh");
                testCase.verifyNotEqual(first,second);
                testCase.verifyTrue(isfolder(first)&&isfolder(second));
            end
        end
        function baselineRejectsExistingEvidence(testCase)
            testCase.verifyRunnerGuard(@run_baseline,'EMIProject:OutputFolderExists');
        end
        function phase2StudyAndMainRejectExistingEvidence(testCase)
            testCase.verifyRunnerGuard(@run_phase2_fault_study,'EMIProject:OutputFolderExists');
            testCase.verifyRunnerGuard(@phase2_main,'EMIProject:OutputFolderExists');
        end
        function phase2SmokeRejectsBeforeSimulation(testCase)
            testCase.verifyRunnerGuard(@smoke_test_phase2_model,'EMIProject:OutputFolderExists');
        end
        function phase2ValidationRejectsBeforeSimulation(testCase)
            testCase.verifyRunnerGuard(@validate_phase2_simulink,'EMIProject:OutputFolderExists');
        end
        function sensitivityStudyRejectsBeforeSweep(testCase)
            testCase.verifyRunnerGuard(@run_phase2b_sensitivity_study,'EMIProject:OutputFolderExists');
        end
        function sensitivityWorkflowRejectsBeforeTests(testCase)
            testCase.verifyRunnerGuard(@phase2b_sensitivity_main,'EMIProject:OutputFolderExists');
        end
        function sensitivityValidationRejectsBeforeInputOrSimulation(testCase)
            testCase.verifyRunnerGuard(@(folder)validate_phase2b_sensitivity(struct(),folder),'EMIProject:OutputFolderExists');
        end
        function phase2bStudyRejectsExistingEvidence(testCase)
            testCase.verifyRunnerGuard(@run_phase2b_study,'EMIProject:OutputFolderExists');
        end
        function packetStudyRejectsExistingEvidence(testCase)
            testCase.verifyRunnerGuard(@run_phase2b_packet_loss_monte_carlo,'EMIProject:OutputFolderExists');
        end
        function smokeValidationRejectsBeforeSimulation(testCase)
            testCase.verifyRunnerGuard(@smoke_test_phase2b_model,'EMIProject:OutputFolderExists');
        end
        function channelValidationRejectsBeforeSimulation(testCase)
            testCase.verifyRunnerGuard(@validate_phase2b_simulink,'EMIProject:OutputFolderExists');
        end
        function phase2bWorkflowRejectsBeforeAnyChildRun(testCase)
            testCase.verifyRunnerGuard(@phase2b_main,'EMIProject:OutputFolderExists');
        end
        function circuitRunnerRejectsBeforeSimulation(testCase)
            testCase.verifyRunnerGuard(@run_sc01a,'SC01A:OutputFolderExists');
        end
        function circuitWorkflowRejectsBeforeTestsOrSimulation(testCase)
            testCase.verifyRunnerGuard(@sc01a_main,'SC01A:OutputFolderExists');
        end
        function baselineExportsToChosenFolder(testCase)
            dest=fullfile(testCase.Folder,'baseline');study=run_baseline(dest);
            testCase.verifyEqual(study.outputFolder,string(java.io.File(char(dest)).getCanonicalPath()));
            testCase.verifyTrue(study.metrics.stable);
            testCase.verifyTrue(all(isfinite(study.timeSeries{:,:}),'all'));
            for name=["baseline_timeseries.csv","baseline_metrics.mat","baseline_response.png"]
                testCase.verifyTrue(isfile(fullfile(dest,name)));
            end
            testCase.verifyEqual(numel(dir(testCase.Folder)),3);
        end
        function phase2bExportsCompleteStudyToChosenFolder(testCase)
            dest=fullfile(testCase.Folder,'phase2b');study=run_phase2b_study(dest);
            testCase.verifyEqual(height(study.metrics),10);
            testCase.verifyEqual(numel(study.results),10);
            for name=study.scenarioNames
                testCase.verifyTrue(isfile(fullfile(dest,"phase2b_"+name+"_timeseries.csv")));
            end
            for name=["phase2b_metrics.csv","phase2b_scenario_manifest.csv","phase2b_fault_study.mat","phase2b_receiver_faults_and_response.png"]
                testCase.verifyTrue(isfile(fullfile(dest,name)));
            end
            testCase.verifyEqual(numel(dir(testCase.Folder)),3);
        end
        function phase2ExportsCompleteStudyToChosenFolder(testCase)
            dest=fullfile(testCase.Folder,'phase2');study=run_phase2_fault_study(dest);
            testCase.verifyEqual(height(study.metrics),5);
            for name=study.scenarioNames
                testCase.verifyTrue(isfile(fullfile(dest,"phase2_"+name+"_timeseries.csv")));
            end
            testCase.verifyTrue(isfile(fullfile(dest,'phase2_encoder_faults.png')));
            testCase.verifyEqual(numel(dir(testCase.Folder)),3);
        end
    end
    methods(Access=private)
        function verifyRunnerGuard(testCase,runner,errorID)
            dest=fullfile(testCase.Folder,'saved');if ~isfolder(dest),mkdir(dest);end
            sentinel=fullfile(dest,'keep.txt');localWrite(sentinel,"old partial evidence");
            before=dir(dest);configuration=Simulink.fileGenControl('getConfig');
            testCase.verifyError(@()runner(dest),errorID);
            testCase.verifyEqual(string(fileread(sentinel)),"old partial evidence");
            remaining=dir(dest);testCase.verifyEqual({remaining.name},{before.name});
            after=Simulink.fileGenControl('getConfig');
            testCase.verifyEqual(after.CacheFolder,configuration.CacheFolder);
            testCase.verifyEqual(after.CodeGenFolder,configuration.CodeGenFolder);
        end
    end
end

function localWrite(path,value)
fid=fopen(path,'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',value);
end
function localRemoveOwnedFolder(folder,base)
resolved=string(java.io.File(char(folder)).getCanonicalPath());
parent=string(java.io.File(char(base)).getCanonicalPath());
assert(startsWith(lower(resolved),lower(parent+filesep)) && resolved~=parent);
if isfolder(resolved),rmdir(resolved,'s');end
end
