function engine=fourway_build_engine()
%FOURWAY_BUILD_ENGINE Build only the new exact engine, leaving history intact.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
src=fullfile(root,'06_Circuit_Simulations','FOUR_WAY','functions','fourway_exact_mex.cpp');
dst=fullfile(root,'06_Circuit_Simulations','FOUR_WAY','work');
if ~exist(dst,'dir'),mkdir(dst);end
addpath(dst);
fid=fopen(src,'rb');cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(bytes);
hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
engine=['fourway_exact_' hash(1:16)];
bin=fullfile(dst,[engine '.' mexext]);
if ~exist(bin,'file')
    mex('-R2018a','-outdir',dst,'-output',engine,src);
end
end
