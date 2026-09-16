function engine=fourway_v2_build_engine()
% Source-addressed V2 binary; historic engines and frozen protocol untouched.
root=fileparts(fileparts(mfilename('fullpath')));
src=fullfile(root,'functions','fourway_v2_exact_mex.cpp');
dst=fullfile(root,'work');if ~isfolder(dst),mkdir(dst);end;addpath(dst);
fid=fopen(src,'rb');assert(fid>=0);closer=onCleanup(@()fclose(fid));bytes=fread(fid,inf,'*uint8');
d=java.security.MessageDigest.getInstance('SHA-256');d.update(bytes);
hash=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
engine=['fourway_v2_exact_' hash(1:16)];
if ~isfile(fullfile(dst,[engine '.' mexext]))
    mex('-R2018a','-outdir',dst,'-output',engine,src);
end
end
