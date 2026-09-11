function record=sc01b_validate_spice_record(folder,expected,row,currentIdentity)
%SC01B_VALIDATE_SPICE_RECORD Read-only validation of one recorded attempt.
% Collection never reruns a simulation or updates its recorded provenance.
expected=sc01b_spice_normalize_parameters(expected);folder=string(folder);
manifestPath=fullfile(folder,'source_manifest.json');
assert(isfile(manifestPath),'SC01B:WorkerSpiceIdentity','Missing SPICE attempt source manifest: %s',manifestPath);
manifest=jsondecode(fileread(manifestPath));
assert(isfield(manifest,'source') && isfield(manifest.source,'fingerprint') && ...
    string(manifest.source.fingerprint)==string(currentIdentity.fingerprint), ...
    'SC01B:WorkerSpiceIdentity','SPICE attempt source differs from the current complete fingerprint: %s',folder);
assert(isfield(manifest,'parameters') && isequaln(manifest.parameters,jsondecode(jsonencode(expected))), ...
    'SC01B:WorkerSpiceParameters','SPICE attempt parameters differ from its declared case/settings: %s',folder);
assert(isfield(manifest,'completed') && logical(manifest.completed)==logical(row.Completed), ...
    'SC01B:WorkerSpiceRecord','SPICE completion status disagrees with the run table: %s',folder);
required=["halfbridge.cir","run.cir","ngspice.log"];
if row.Completed,required=[required,"result.mat"];end
assert(isfield(manifest,'artifacts'),'SC01B:WorkerSpiceIdentity','SPICE artifact manifest is missing.');
names=string({manifest.artifacts.name});
assert(numel(unique(names))==numel(names) && isequal(sort(names),sort(required)), ...
    'SC01B:WorkerSpiceIdentity','SPICE artifacts do not contain the exact required evidence: %s',folder);
for k=1:numel(manifest.artifacts)
    item=manifest.artifacts(k);path=fullfile(folder,string(item.name));
    assert(isfile(path) && fileHash(path)==string(item.sha256), ...
        'SC01B:WorkerSpiceIdentity','Recorded SPICE artifact changed or is missing: %s',path);
end
if row.Completed
    assert(~isfile(fullfile(folder,'rejected.json')),'SC01B:WorkerSpiceRecord','Completed SPICE run has contradictory rejection evidence.');
    cached=load(fullfile(folder,'result.mat'),'r','p');r=cached.r;
    assert(isequaln(cached.p,expected) && isequaln(r.parameters,expected) && isequaln(r.settings,expected.simulation), ...
        'SC01B:WorkerSpiceParameters','SPICE saved parameters/settings disagree with the declared run: %s',folder);
    assert(r.warningCount==0 && row.Warnings==0 && string(r.stopEvent)=="ReachedStopTime" && ...
        numel(r.time_s)==row.Samples && abs(r.time_s(end)-expected.simulation.stopTime_s)<1e-14 && ...
        abs(r.time_s(end)-row.StopTime_s)<1e-14 && abs(row.Step_s-expected.simulation.maxStep_s)<=1e-20 && ...
        isfield(r,'sourceIdentity') && string(r.sourceIdentity.fingerprint)==string(currentIdentity.fingerprint), ...
        'SC01B:WorkerSpiceRecord','SPICE saved completion/source facts disagree with the run table: %s',folder);
    sc01b_metrics(r,expected);
    observed=max(diff(r.time_s));
    assert(observed<=expected.simulation.maxStep_s+2e-20 && ...
        isfield(r,'observedMaxStep_s') && abs(r.observedMaxStep_s-observed)<=2e-20, ...
        'SC01B:WorkerSpiceRecord','SPICE actual integration grid exceeds the declared maximum step: %s',folder);
else
    assert(~isfile(fullfile(folder,'result.mat')) && isfile(fullfile(folder,'rejected.json')), ...
        'SC01B:WorkerSpiceRecord','Rejected SPICE run has missing or contradictory rejection evidence.');
    rejected=jsondecode(fileread(fullfile(folder,'rejected.json')));
    assert(isfield(rejected,'AcceptedTrace') && ~rejected.AcceptedTrace && row.Samples==0, ...
        'SC01B:WorkerSpiceRecord','Rejected SPICE run cannot admit a trace.');
    observed=NaN;
end
record=struct('case',string(row.Case),'run',string(row.Run),'completed',logical(row.Completed), ...
    'sourceFingerprint',string(manifest.source.fingerprint),'sourceManifestSHA256',fileHash(manifestPath), ...
    'observedMaxStep_s',observed,'sourceManifest',manifestPath,'recordedProvenanceUnchanged',true);
end

function hash=fileHash(path)
fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
hash=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end
