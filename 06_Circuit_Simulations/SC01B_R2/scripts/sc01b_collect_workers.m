function study=sc01b_collect_workers(partFolders,folder,options)
%SC01B_COLLECT_WORKERS Merge disjoint case workers and run the complete gates.
arguments
    partFolders (1,:) string
    folder (1,1) string
    options.NgspiceExecutable (1,1) string = ""
end
assert(~isempty(partFolders));if ~isfolder(folder),mkdir(folder);end
root=fileparts(fileparts(mfilename('fullpath')));
if options.NgspiceExecutable=="",options.NgspiceExecutable=fullfile(root,'tools','ngspice','bin','ngspice.exe');end
[currentKey,manifest]=sc01b_native_cache_key();criteria=sc01b_criteria();
currentSpice=sc01b_spice_source_identity(options.NgspiceExecutable);spiceRecords={};
study=[];seen=strings(1,0);recordedKeys=strings(0,1);keyRecords={};workerStarts=strings(0,1);
for part=partFolders
    saved=load(fullfile(part,'study_partial.mat'),'study');s=saved.study;
    names=string(fieldnames(s.cases)).';
    assert(isequaln(s.criteria,criteria) && ~isempty(names) && all(ismember(names,criteria.caseNames)), ...
        'SC01B:WorkerMismatch','Worker cases/criteria do not match the declared revision.');
    workerStarts(end+1,1)=string(s.startedUTC);
    assert(~any(ismember(names,seen)),'SC01B:DuplicateWorker','Workers contain duplicate cases.');seen=[seen,names];
    for name=names
        assert(isequaln(s.cases.(name).parameters,sc01b_case(name)), ...
            'SC01B:WorkerParameters','Worker parameters differ from frozen case %s.',name);
        nativeRows=s.runs(string(s.runs.Case)==name & startsWith(string(s.runs.Run),"native_"),:);
        nativeSidecars=dir(fullfile(part,name,'native*.mat.key'));
        assert(isequal(sort(string({nativeSidecars.name}).'),sort(string(nativeRows.Run)+'.mat.key')), ...
            'SC01B:WorkerSourceIdentity','Native sidecar files do not exactly match recorded runs for %s.',name);
        for k=1:height(nativeRows)
            sidecar=fullfile(part,name,string(nativeRows.Run(k))+'.mat.key');
            assert(isfile(sidecar),'SC01B:WorkerSourceIdentity','Missing native source-key sidecar: %s',sidecar);
            value=string(strtrim(fileread(sidecar)));
            assert(~isempty(regexp(char(value),'^[0-9a-f]{64}$','once')), ...
                'SC01B:WorkerSourceIdentity','Invalid native source key: %s',sidecar);
            assert(value==string(currentKey),'SC01B:WorkerSourceIdentity', ...
                'Native record source differs from the current complete fingerprint: %s',sidecar);
            cached=load(fullfile(part,name,string(nativeRows.Run(k))+'.mat'),'r','p');
            nativeCheck=sc01b_validate_native_record(cached.r,cached.p, ...
                s.cases.(name).parameters,nativeRows(k,:),criteria);
            sc01b_metrics(cached.r,cached.p);
            recordedKeys(end+1,1)=value;
            keyRecords{end+1}=struct('case',name,'run',string(nativeRows.Run(k)), ...
                'recordedKey',value,'sidecar',sidecar,'nativeRecordValidation',nativeCheck);
        end
        spiceRows=s.runs(string(s.runs.Case)==name & startsWith(string(s.runs.Run),"spice_"),:);
        for k=1:height(spiceRows)
            expected=s.cases.(name).parameters;expected.simulation.maxStep_s=spiceRows.Step_s(k);
            if string(spiceRows.Run(k))=="spice_tight_tolerance"
                expected.simulation.relativeTolerance=1e-6;expected.simulation.absoluteTolerance=1e-10;
                expected.simulation.voltageTolerance=1e-8;
            end
            spiceRecords{end+1}=sc01b_validate_spice_record(fullfile(part,name,string(spiceRows.Run(k))), ...
                expected,spiceRows(k,:),currentSpice);
        end
    end
    if isempty(study)
        study=s;
    else
        assert(isequaln(study.criteria,s.criteria) && study.matlabVersion==s.matlabVersion,'SC01B:WorkerMismatch','Worker criteria/version differ.');
        for name=names,study.cases.(name)=s.cases.(name);end
        for field=["metrics","events","balance","comparisons","waveforms","runs"]
            study.(field)=[study.(field);s.(field)];
        end
    end
    for name=names
        source=fullfile(part,name);target=fullfile(folder,name);
        if ~isfolder(target),mkdir(target);end
        copyfile(fullfile(source,'*'),target,'f');
        spiceRows=s.runs(string(s.runs.Case)==name & startsWith(string(s.runs.Run),"spice_"),:);
        for k=1:height(spiceRows)
            attemptFolder=fullfile(target,string(spiceRows.Run(k)));
            if spiceRows.Completed(k),stale=fullfile(attemptFolder,'rejected.json');
            else,stale=fullfile(attemptFolder,'result.mat');end
            if isfile(stale),delete(stale);end
        end
    end
end
assert(~isempty(recordedKeys) && numel(unique(recordedKeys))==1, ...
    'SC01B:WorkerSourceIdentity','Native records do not share one recorded source identity.');
recordedKey=recordedKeys(1);
identity=struct('method',"Compare every native-record sidecar; retain original keys without backstamping", ...
    'recordedFingerprint',recordedKey,'currentCompleteFingerprint',string(currentKey), ...
    'recordedMatchesCurrentComplete',recordedKey==string(currentKey), ...
    'recordedKeysUnchanged',true,'records',vertcat(keyRecords{:}),'currentManifest',manifest);
identity.traceabilityLimitation="Every recorded native key matches the current complete fingerprint; legacy or modified-source records are rejected.";
firstStart=min(datetime(workerStarts,'TimeZone','UTC'));
firstStart.Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
identity.earliestWorkerStartedUTC=string(firstStart);
vendorFiles=manifest.files([manifest.files.vendorDependency]);
modified=datetime(reshape([vendorFiles.modifiedUTC],[],1),'InputFormat',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",'TimeZone','UTC');
identity.allVendorModificationTimesPrecedeWorkers=all(modified<=firstStart);
study.sourceIdentity=identity;
fid=fopen(fullfile(folder,'source_identity.json'),'w');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(identity,'PrettyPrint',true));clear cleanup
assert(~isempty(spiceRecords),'SC01B:WorkerSpiceIdentity','SPICE attempt provenance is missing.');
study.spiceSourceIdentity=struct('method',"Read-only validation of every recorded SPICE source/artifact hash, normalized parameters, and actual integration grid", ...
    'currentFingerprint',currentSpice.fingerprint,'allRecordedSourcesMatchCurrent',true, ...
    'recordedProvenanceUnchanged',true,'records',vertcat(spiceRecords{:}),'currentManifest',currentSpice);
fid=fopen(fullfile(folder,'spice_source_identity.json'),'w');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(study.spiceSourceIdentity,'PrettyPrint',true));clear cleanup
copyfile(fullfile(partFolders(1),'criteria.json'),fullfile(folder,'criteria.json'),'f');
study=sc01b_finalize(study,folder);
end
