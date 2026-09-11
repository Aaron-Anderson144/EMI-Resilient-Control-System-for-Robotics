function source=fourway_replay()
%FOURWAY_REPLAY Verify bytes before parsing the original written doubles.
persistent cached
if ~isempty(cached),source=cached;return,end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
path=fullfile(root,'06_Circuit_Simulations','SC01B_R2','results','verification','nominal','native_finest.csv');
fid=fopen(path,'rb');assert(fid>=0,'FOURWAY:ReplayMissing','Pinned replay is absent.');
cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(bytes);
hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
expected='1ecdd83ee4f4846b70e2d40ba04f4b3188e737c94f08300a5bbbfcc36acb9cd5';
assert(strcmp(hash,expected),'FOURWAY:ReplayHash','Pinned replay SHA-256 mismatch.');
opts=detectImportOptions(path);opts.SelectedVariableNames={'time_s','switch_V'};
t=readtable(path,opts);
assert(all(isfinite(t.time_s))&&all(isfinite(t.switch_V))&&all(diff(t.time_s)>0));
assert(t.time_s(1)==0&&abs(t.time_s(end)-5e-6)<1e-18);
assert(t.switch_V(1)==23.8477134541286&&t.switch_V(end)==23.8322841912334);
source=struct('time_s',t.time_s,'switch_V',t.switch_V,'path',path,'sha256',hash,...
    'original_points',height(t),'native_duration_s',t.time_s(end),...
    'initial_V',t.switch_V(1),'final_V',t.switch_V(end),...
    'native_source_fingerprint','eba4730fdf73a0c5a146faa48615ea3aa559c72645de65e5fd5a27f7f5c8699d');
cached=source;
end
