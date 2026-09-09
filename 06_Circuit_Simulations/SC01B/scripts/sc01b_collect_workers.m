function study=sc01b_collect_workers(partFolders,folder)
%SC01B_COLLECT_WORKERS Merge disjoint case workers and run the complete gates.
arguments
    partFolders (1,:) string
    folder (1,1) string
end
assert(~isempty(partFolders));if ~isfolder(folder),mkdir(folder);end
study=[];seen=strings(1,0);recordedKeys=strings(0,1);keyRecords={};workerStarts=strings(0,1);
for part=partFolders
    saved=load(fullfile(part,'study_partial.mat'),'study');s=saved.study;
    names=string(fieldnames(s.cases)).';
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
            recordedKeys(end+1,1)=value;
            keyRecords{end+1}=struct('case',name,'run',string(nativeRows.Run(k)),'recordedKey',value,'sidecar',sidecar);
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
[currentKey,manifest]=sc01b_native_cache_key();
recordedKey=recordedKeys(1);
identity=struct('method',"Compare every native-record sidecar; retain original keys without backstamping", ...
    'recordedFingerprint',recordedKey,'currentCompleteFingerprint',string(currentKey), ...
    'recordedMatchesCurrentComplete',recordedKey==string(currentKey), ...
    'recordedKeysUnchanged',true,'records',vertcat(keyRecords{:}),'currentManifest',manifest);
if recordedKey~=string(currentKey)
    identity.traceabilityLimitation="Run-time legacy keys cover the saved model, builder, adapter, gate/solver helpers, MATLAB version and outer device wrapper, but omit the vendor core/helper package. The current complete manifest is supplemental and is not retroactive proof of those omitted files. Session source files were not changed; filesystem timestamps below are supporting evidence only.";
else
    identity.traceabilityLimitation="Recorded keys match the current complete fingerprint.";
end
firstStart=min(datetime(workerStarts,'TimeZone','UTC'));
firstStart.Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
identity.earliestWorkerStartedUTC=string(firstStart);
vendorFiles=manifest.files([manifest.files.vendorDependency]);
modified=datetime(reshape([vendorFiles.modifiedUTC],[],1),'InputFormat',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",'TimeZone','UTC');
identity.allVendorModificationTimesPrecedeWorkers=all(modified<=firstStart);
study.sourceIdentity=identity;
fid=fopen(fullfile(folder,'source_identity.json'),'w');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(identity,'PrettyPrint',true));clear cleanup
copyfile(fullfile(partFolders(1),'criteria.json'),fullfile(folder,'criteria.json'),'f');
study=sc01b_finalize(study,folder);
end
