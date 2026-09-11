function manifest=write_run_manifest(outputFolder,matlabRoot,metadata)
%WRITE_RUN_MANIFEST Bind a new result directory to local source/model identity.
matlabRoot=char(java.io.File(matlabRoot).getCanonicalPath());
files=[dir(fullfile(matlabRoot,'**','*.m'));dir(fullfile(matlabRoot,'models','*.slx'))];
entries={};
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name);
    if contains(path,[filesep 'results' filesep]) || contains(path,[filesep 'slprj' filesep]),continue;end
    fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
    hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
    relative=replace(string(path(numel(matlabRoot)+2:end)),filesep,"/");
    entries{end+1}=struct('path',relative,'sha256',string(hash),'bytes',numel(bytes));
end
manifest=struct('createdUTC',string(datetime('now','TimeZone','UTC')), ...
    'matlabVersion',string(version),'products',ver,'metadata',metadata,'sourceFiles',vertcat(entries{:}));
fid=fopen(fullfile(outputFolder,'run_manifest.json'),'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(manifest,'PrettyPrint',true));
end
