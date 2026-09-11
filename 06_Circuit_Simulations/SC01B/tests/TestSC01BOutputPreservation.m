classdef TestSC01BOutputPreservation < matlab.unittest.TestCase
    %TESTSC01BOUTPUTPRESERVATION No solver or circuit model is invoked here.
    methods (Test)
        function defaultSelectsFreshTimestampedPathWithoutWriting(testCase)
            root=localTemporaryRoot(testCase);
            historical=fullfile(root,'results','verification');mkdir(historical);
            sentinel=fullfile(historical,'historical.txt');localWrite(sentinel,'frozen evidence');
            first=sc01b_output_folder(root);
            testCase.verifyTrue(startsWith(first,fullfile(root,'results','verification_')));
            testCase.verifyNotEqual(first,string(historical));
            testCase.verifyFalse(isfolder(first));
            testCase.verifyEqual(fileread(sentinel),'frozen evidence');
            mkdir(first);
            second=sc01b_output_folder(root);
            testCase.verifyNotEqual(second,first);
            testCase.verifyFalse(isfolder(second));
        end

        function populatedExplicitFolderIsRejectedWithoutChanges(testCase)
            root=localTemporaryRoot(testCase);
            sentinel=fullfile(root,'criteria.json');localWrite(sentinel,'original criteria');
            before=dir(root);
            testCase.verifyError(@()sc01b_output_folder(root,root,false), ...
                'SC01B:OutputFolderNotEmpty');
            testCase.verifyEqual(fileread(sentinel),'original criteria');
            after=dir(root);
            testCase.verifyEqual({after.name},{before.name});
        end

        function mainRefusesPopulatedOutputBeforeAnyCampaignWrite(testCase)
            root=localTemporaryRoot(testCase);
            sentinel=fullfile(root,'criteria.json');localWrite(sentinel,'original criteria');
            % Missing runtime and invalid case are secondary safety stops.
            % The preservation error must take precedence over both, and
            % there is no route from this test to a native/SPICE execution.
            testCase.verifyError(@()sc01b_main(OutputFolder=root, ...
                NgspiceExecutable=fullfile(root,'missing_runtime.exe'), ...
                Cases="not_a_case",Finalize=false), ...
                'SC01B:OutputFolderNotEmpty');
            testCase.verifyEqual(fileread(sentinel),'original criteria');
            entries=dir(root);entries=entries(~ismember({entries.name},{'.','..'}));
            testCase.verifyEqual({entries.name},{'criteria.json'});
        end

        function explicitReuseAndEmptyFolderAreAllowedWithoutWriting(testCase)
            root=localTemporaryRoot(testCase);
            emptyFolder=fullfile(root,'empty');mkdir(emptyFolder);
            testCase.verifyEqual(sc01b_output_folder(root,emptyFolder,false),string(emptyFolder));
            sentinel=fullfile(root,'existing.txt');localWrite(sentinel,'existing run');
            testCase.verifyEqual(sc01b_output_folder(root,root,true),string(root));
            testCase.verifyEqual(fileread(sentinel),'existing run');
            testCase.verifyFalse(isfile(fullfile(root,'criteria.json')));
        end

        function existingFileIsRejectedEvenWithReuse(testCase)
            root=localTemporaryRoot(testCase);
            file=fullfile(root,'output');localWrite(file,'keep this file');
            for reuse=[false,true]
                testCase.verifyError(@()sc01b_output_folder(root,file,reuse), ...
                    'SC01B:OutputFolderExists');
            end
            testCase.verifyEqual(fileread(file),'keep this file');
        end
    end
end

function root=localTemporaryRoot(testCase)
root=string(tempname(tempdir));mkdir(root);
testCase.addTeardown(@()localRemoveTemporaryRoot(root));
end

function localWrite(file,text)
fid=fopen(file,'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',text);
end

function localRemoveTemporaryRoot(root)
% Refuse recursive removal unless the resolved target stays inside tempdir.
target=char(java.io.File(char(root)).getCanonicalPath());
temporary=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith(target,[temporary filesep],'IgnoreCase',true), ...
    'SC01B:UnsafeTestCleanup','Test cleanup target is outside the temporary directory.');
if isfolder(target),rmdir(target,'s');end
end
