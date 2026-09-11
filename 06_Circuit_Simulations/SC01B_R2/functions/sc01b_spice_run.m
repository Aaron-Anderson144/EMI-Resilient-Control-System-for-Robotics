function [r,runtime]=sc01b_spice_run(p,folder,executable,reuse)
%SC01B_SPICE_RUN Reuse only exact, complete, source-bound independent runs.
if nargin<4,reuse=false;end
p=sc01b_spice_normalize_parameters(p);folder=string(folder);
path=fullfile(folder,'result.mat');manifestPath=fullfile(folder,'source_manifest.json');
if reuse && isfile(path) && isfile(manifestPath) && ~isfile(fullfile(folder,'rejected.json'))
    saved=load(path,'r','p');manifest=jsondecode(fileread(manifestPath));
    identity=sc01b_spice_source_identity(executable);
    sourceMatches=isfield(manifest,'source') && isfield(manifest.source,'fingerprint') && ...
        string(manifest.source.fingerprint)==identity.fingerprint;
    if sourceMatches && isequaln(saved.p,p) && isequaln(saved.r.parameters,p) && isequaln(saved.r.settings,p.simulation)
        r=saved.r;
        assert(isfield(manifest,'completed') && manifest.completed && r.warningCount==0 && ...
            string(r.stopEvent)=="ReachedStopTime" && abs(r.time_s(end)-p.simulation.stopTime_s)<1e-14, ...
            'SC01B:InvalidSpiceCache','Only complete, warning-free SPICE records can be reused.');
        assert(isfield(r,'sourceIdentity') && r.sourceIdentity.fingerprint==identity.fingerprint, ...
            'SC01B:InvalidSpiceCache','Recorded SPICE source identity is missing or inconsistent.');
        for k=1:numel(manifest.artifacts)
            item=manifest.artifacts(k);artifactPath=fullfile(folder,string(item.name));
            assert(isfile(artifactPath) && fileHash(artifactPath)==string(item.sha256), ...
                'SC01B:InvalidSpiceCache','Recorded SPICE artifact changed: %s',artifactPath);
        end
        sc01b_metrics(r,p);
        assert(max(diff(r.time_s))<=p.simulation.maxStep_s+2e-20 && ...
            isfield(r,'observedMaxStep_s') && abs(r.observedMaxStep_s-max(diff(r.time_s)))<=2e-20, ...
            'SC01B:InvalidSpiceCache','Cached SPICE integration grid exceeds its declared maximum step.');
        runtime=0;fprintf('SC01B REUSE verified SPICE record %s\n',path);return;
    end
end
r=simulate_sc01b_ngspice(p,folder,executable);runtime=r.runtime_s;
end

function hash=fileHash(path)
fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
hash=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end
