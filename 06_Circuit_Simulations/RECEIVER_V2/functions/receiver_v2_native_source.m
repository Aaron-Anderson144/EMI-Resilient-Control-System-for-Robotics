function s=receiver_v2_native_source(p)
% Verify original bytes, then retain every original timestamp and voltage.
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
path=fullfile(root,p.source.path);
fid=fopen(path,'rb');assert(fid>=0,'RECEIVER_V2:SourceMissing','Native source missing.');
closer=onCleanup(@()fclose(fid));bytes=fread(fid,inf,'*uint8');
d=java.security.MessageDigest.getInstance('SHA-256');d.update(bytes);
hash=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
assert(strcmp(hash,p.source.sha256),'RECEIVER_V2:SourceHash','Source SHA mismatch.');
opts=detectImportOptions(path);opts.SelectedVariableNames={'time_s','switch_V'};
tab=readtable(path,opts);
assert(height(tab)==40001&&all(diff(tab.time_s)>0),'RECEIVER_V2:SourceShape','Unexpected source timestamps.');
s=struct('t',tab.time_s,'v',tab.switch_V,'path',p.source.path,'sha256',hash, ...
    'originalPoints',height(tab),'interpolation',p.source.interpolation);
end
