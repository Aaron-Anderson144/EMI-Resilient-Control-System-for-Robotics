function verification=fourway_verify_freeze()
%FOURWAY_VERIFY_FREEZE Reject altered design, policy, equations or replay.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
manifest=jsondecode(fileread(fullfile(root,'04_EMI_Models','four_way_emi_freeze_manifest.json')));
for j=1:numel(manifest.files)
 e=manifest.files(j);path=fullfile(root,e.path);fid=fopen(path,'rb');
 assert(fid>=0,'EMIProject:FourWayFrozenInput','Missing pinned input: %s',path);
 bytes=fread(fid,Inf,'*uint8');fclose(fid);
 digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
 hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
 assert(numel(bytes)==e.bytes&&strcmp(hash,e.sha256),'EMIProject:FourWayFrozenInput','Frozen input changed: %s',e.path);
end
verification=struct('design_id',string(manifest.design_id),'frozen_files_verified',numel(manifest.files), ...
 'verified_utc',string(datetime('now','TimeZone','UTC')),'passed',true);
end
