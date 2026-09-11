classdef TestFourWayContracts < matlab.unittest.TestCase
    % Treatment isolation and fail-closed pre-evaluation evidence guards.
    properties
        Folder
        Project
    end
    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.Project=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
            base=fullfile(testCase.Project,'03_MATLAB','work');
            if ~isfolder(base),mkdir(base);end
            testCase.Folder=string(tempname(base));mkdir(testCase.Folder);
            testCase.addTeardown(@()removeOwned(testCase.Folder,base));
        end
    end
    methods (Test)
        function allDevelopmentTreatmentsRetainExogenousTaskAndPolicy(testCase)
            arms=["BASELINE","EM_ONLY","SW_ONLY","COMBINED"];
            capacitance=[100,1000,100,1000];
            for id=["DEV01","DEV02"]
                base=fourway_fixture(id,"BASELINE",true);
                for j=1:4
                    a=fourway_fixture(id,arms(j),true);
                    b=fourway_fixture(id,arms(j),false);
                    testCase.verifyEqual(a.run,b.run);
                    testCase.verifyEqual(a.run.params,base.run.params);
                    testCase.verifyEqual(a.run.configuration,base.run.configuration);
                    testCase.verifyEqual(a.run.profiles,base.run.profiles);
                    scenario=rmfield(a.run.scenario,'name');
                    testCase.verifyEqual(scenario,rmfield(base.run.scenario,'name'));
                    testCase.verifyEqual(a.Cdiff_pF,capacitance(j));
                    testCase.verifyEqual(a.run.protectionEnabled,j>=3);
                    testCase.verifyEqual(a.phase_s,base.phase_s);
                    testCase.verifyEqual(a.closure_s,base.closure_s);
                    testCase.verifyEqual([a.Ccp_pF,a.Ccn_pF],[base.Ccp_pF,base.Ccn_pF]);
                end
                p=base.run.profiles;t=p.time_s;
                expected=zeros(size(t));expected(t>=.1)=deg2rad(30);expected(t>=1.6)=deg2rad(-15);
                testCase.verifyEqual(p.requestedReference_rad,expected,'AbsTol',1e-15);
                testCase.verifyEqual(t(p.resetRequest),2,'AbsTol',1e-15);
                testCase.verifyFalse(any(p.sourceFault));
                testCase.verifyEqual(p.loadTorque_Nm,zeros(size(t)));
                testCase.verifyFalse(base.run.configuration.reacquisitionEnabled);
            end
        end

        function twoCleanElectricalArmsUseExactCausalPlantAndPersistentDecoder(testCase)
            for arm=["BASELINE","EM_ONLY"]
                f=fourway_fixture("DEV01",arm,false);
                result=simulate_fourway_actuator(f);
                trace=result.timeSeries;
                testCase.verifyEqual(height(trace),3001);
                testCase.verifyEqual(trace.decodedCount,trace.shadowDecodedCount);
                testCase.verifyTrue(result.decoderAudit.cleanCountConservationPass);
                testCase.verifyTrue(result.decoderAudit.cleanSequencePass);
                [A,B]=ssdata(actuator_state_space(f.run.params));
                for k=[100,251,1701,2999]
                    augmented=[A,B*[trace.command_V(k);0];zeros(1,4)];
                    state=expm(augmented*.001)*[result.state(k,:)';1];
                    testCase.verifyEqual(result.state(k+1,:)',state(1:3),'AbsTol',2e-12);
                end
                independent=decodeAtSamples(result.receiver.decoder,trace.time_s);
                testCase.verifyEqual(independent,trace.decodedCount);
                testCase.verifyEqual(trace.receivedMeasurement_rad,trace.decodedCount*(2*pi/4096),'AbsTol',1e-15);
            end
        end

        function declaredValidCompleteEvidenceIsAcceptedWithoutRunningEvaluation(testCase)
            [acceptance,path]=makeAcceptance(testCase.Folder,testCase.Project);
            testCase.verifyWarningFree(@()fourway_require_acceptance(path));
            actual=fourway_require_acceptance(path);
            testCase.verifyEqual(string(actual.design_id),string(acceptance.design_id));
        end

        function emptyMissingAndDuplicateImplementationInventoriesAreRejected(testCase)
            [acceptance,path]=makeAcceptance(testCase.Folder,testCase.Project);
            for kind=1:3
                changed=acceptance;
                switch kind
                    case 1,changed.files=[];
                    case 2,changed.files(end)=[];
                    case 3,changed.files(end)=changed.files(1);
                end
                writeJson(path,changed);
                testCase.verifyError(@()fourway_require_acceptance(path),'EMIProject:FourWayAcceptance');
            end
        end

        function absoluteAndTraversalImplementationPathsAreRejected(testCase)
            [acceptance,path]=makeAcceptance(testCase.Folder,testCase.Project);
            bad=["../outside.m","03_MATLAB/../functions/file.m", ...
                "C:/outside.m","/outside.m","03_MATLAB\functions\file.m"];
            for badPath=bad
                changed=acceptance;changed.files(1).path=char(badPath);writeJson(path,changed);
                testCase.verifyError(@()fourway_require_acceptance(path),'EMIProject:FourWayAcceptance');
            end
        end

        function alteredImplementationDigestIsRejected(testCase)
            [acceptance,path]=makeAcceptance(testCase.Folder,testCase.Project);
            acceptance.files(1).sha256=repmat('0',1,64);writeJson(path,acceptance);
            testCase.verifyError(@()fourway_require_acceptance(path),'EMIProject:FourWayImplementationChanged');
        end

        function alteredEvidenceIsRejectedEvenWithTrueBooleans(testCase)
            [acceptance,path]=makeAcceptance(testCase.Folder,testCase.Project);
            evidence=acceptance.evidence.development.path;
            fid=fopen(evidence,'a');fprintf(fid,' ');fclose(fid);
            testCase.verifyError(@()fourway_require_acceptance(path),'EMIProject:FourWayEvidenceChanged');
        end

        function wrongDesignAndEmptyLegacyEvidenceCannotPass(testCase)
            [acceptance,path]=makeAcceptance(testCase.Folder,testCase.Project);
            changed=acceptance;changed.design_id='FOUR-WAY-EMI-PLAN-V2';writeJson(path,changed);
            testCase.verifyError(@()fourway_require_acceptance(path),'EMIProject:FourWayAcceptance');
            legacy=jsondecode(fileread(acceptance.evidence.legacy.path));legacy.tests=0;
            writeJson(acceptance.evidence.legacy.path,legacy);
            acceptance.evidence.legacy.sha256=fileHash(acceptance.evidence.legacy.path);
            writeJson(path,acceptance);
            testCase.verifyError(@()fourway_require_acceptance(path),'EMIProject:FourWayAcceptance');
        end

        function subsetNativeAndDomainRejectedNumericalPassesAreRejected(testCase)
            [acceptance,path]=makeAcceptance(testCase.Folder,testCase.Project);
            native=jsondecode(fileread(acceptance.evidence.native.path));
            for kind=1:2
                changed=native;
                if kind==1
                    changed.requiredNativeRuns=3;changed.executedNativeRuns=3;changed.passedNativeRuns=3;
                    changed.requiredRefinements=2;changed.executedRefinements=2;changed.passedRefinements=2;
                else
                    changed.receiverDomainRejectedRuns=12;
                end
                writeJson(acceptance.evidence.native.path,changed);
                acceptance.evidence.native.sha256=fileHash(acceptance.evidence.native.path);
                writeJson(path,acceptance);
                testCase.verifyError(@()fourway_require_acceptance(path),'EMIProject:FourWayAcceptance');
            end
        end

        function vacuousIndependentAuditAndMissingDevelopmentRecordsAreRejected(testCase)
            [acceptance,path]=makeAcceptance(testCase.Folder,testCase.Project);
            audit=jsondecode(fileread(acceptance.evidence.independent_audit.path));
            for kind=1:2
                changed=audit;
                if kind==1,changed.campaigns=[];else,changed.campaigns.records(end)=[];end
                writeJson(acceptance.evidence.independent_audit.path,changed);
                acceptance.evidence.independent_audit.sha256=fileHash(acceptance.evidence.independent_audit.path);
                writeJson(path,acceptance);
                testCase.verifyError(@()fourway_require_acceptance(path),'EMIProject:FourWayAcceptance');
            end
        end

        function developmentRunnerPreservesExistingEvidence(testCase)
            sentinel=fullfile(testCase.Folder,'retain.txt');
            fid=fopen(sentinel,'w');fprintf(fid,'retained evidence');fclose(fid);
            before=dir(testCase.Folder);
            testCase.verifyError(@()run_fourway_stage("development",testCase.Folder), ...
                'EMIProject:OutputFolderExists');
            testCase.verifyEqual(fileread(sentinel),'retained evidence');
            after=dir(testCase.Folder);testCase.verifyEqual({after.name},{before.name});
        end
    end
end

function counts=decodeAtSamples(events,t)
gray=[0,0;1,0;1,1;0,1];previous=1;count=0;index=1;counts=zeros(size(t));
for k=1:numel(t)
    while index<=size(events,1)&&events(index,1)<=t(k)+1e-12
        current=find(all(gray==events(index,2:3),2));step=mod(current-previous,4);
        if step==1,count=count+1;elseif step==3,count=count-1;end
        previous=current;index=index+1;
    end
    counts(k)=count;
end
end

function [acceptance,path]=makeAcceptance(folder,project)
paths=fourway_implementation_inventory();
files=repmat(struct('path','','sha256',''),numel(paths),1);
for k=1:numel(paths)
    files(k).path=char(paths(k));files(k).sha256=fileHash(fullfile(project,paths(k)));
end
acceptance=struct('schema_version',1,'design_id','FOUR-WAY-EMI-PLAN-V1', ...
    'passed',true,'development_passed',true,'native_passed',true,'legacy_passed',true, ...
    'files',files);
reports.development=struct('partition','development','logical_records',16,'unique_executions',16, ...
    'paired_results',8,'all_execution_clean_guards_pass',true);
reports.native=struct('passed',true,'requiredNativeRuns',24,'executedNativeRuns',24,'passedNativeRuns',24, ...
    'requiredRefinements',16,'executedRefinements',16,'passedRefinements',16, ...
    'integerCountsExact',true,'receiverDomainRejectedRuns',0);
reports.legacy=struct('passed',true,'tests',1,'failed',0,'incomplete',0,'legacy_first20_passed',true);
pairs=strings(0,1);
for fixture=["DEV01","DEV02"]
    for arm=["BASELINE","EM_ONLY","SW_ONLY","COMBINED"],pairs(end+1,1)=fixture+"_"+arm;end %#ok<AGROW>
end
names=[pairs+"_clean";pairs+"_exposed"];
records=repmat(struct('record','','checks',1,'passed',1,'failed',[]),16,1);
metrics=repmat(struct('pair','','checks',1,'failed',[]),8,1);
for k=1:16,records(k).record=char(names(k));end
for k=1:8,metrics(k).pair=char(pairs(k));end
reports.independent_audit=struct('all_passed',true,'campaigns', ...
    struct('all_passed',true,'records',records,'metrics',metrics));
for role=["development","native","legacy","independent_audit"]
    evidencePath=fullfile(folder,role+".json");writeJson(evidencePath,reports.(role));
    acceptance.evidence.(role)=struct('path',char(evidencePath),'sha256',fileHash(evidencePath));
end
path=fullfile(folder,'acceptance.json');writeJson(path,acceptance);
end

function hash=fileHash(path)
fid=fopen(path,'rb');assert(fid>=0,'Test fixture input missing: %s',path);
cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end

function writeJson(path,value)
fid=fopen(path,'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(value));
end

function removeOwned(folder,base)
resolved=string(java.io.File(char(folder)).getCanonicalPath());
parent=string(java.io.File(char(base)).getCanonicalPath());
assert(startsWith(lower(resolved),lower(parent+filesep))&&resolved~=parent);
if isfolder(resolved),rmdir(resolved,'s');end
end
