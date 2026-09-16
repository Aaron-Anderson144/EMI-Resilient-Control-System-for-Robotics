function source=fourway_v2_replay(p)
% Parse the pinned native CSV once while its path/size/write time stay fixed.
% Gate A independently checks bytes for each campaign; every cache refill
% calls the frozen reader's SHA-256 verification before parsing.
persistent cached signature
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
path=fullfile(root,p.source.path);info=dir(path);
assert(isscalar(info),'FOURWAY_V2:SourceMissing','Native source missing.');
key=struct('path',path,'sha256',p.source.sha256,'bytes',info.bytes,'datenum',info.datenum);
if isempty(cached)||~isequaln(signature,key)
    cached=receiver_v2_native_source(p);signature=key;
end
source=cached;
end
