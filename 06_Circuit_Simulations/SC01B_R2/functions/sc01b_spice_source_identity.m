function identity=sc01b_spice_source_identity(executable)
%SC01B_SPICE_SOURCE_IDENTITY Bind SPICE records to vendor/runtime/source bytes.
root=fileparts(fileparts(mfilename('fullpath')));
vendor=fullfile(matlabroot,'toolbox','physmod','elec','supporting_files','IAUC100N04S6L014.cir');
labels=["vendor.cir","ngspice.exe","simulate_sc01b_ngspice.m","sc01b_spice_pwl_expression.m", ...
    "sc01b_gate_signals.m","sc01b_spice_run.m","sc01b_spice_normalize_parameters.m","sc01b_spice_source_identity.m"];
paths=[string(vendor),string(executable),fullfile(root,'functions',labels(3:end))];
dlls=dir(fullfile(fileparts(executable),'*.dll'));
for k=1:numel(dlls)
    labels(end+1)="runtime/"+string(dlls(k).name);paths(end+1)=string(fullfile(dlls(k).folder,dlls(k).name));
end
runtimeRoot=fileparts(fileparts(executable));
spinit=fullfile(runtimeRoot,'share','ngspice','scripts','spinit');
if isfile(spinit),labels(end+1)="runtime/share/ngspice/scripts/spinit";paths(end+1)=string(spinit);end
codeModels=dir(fullfile(runtimeRoot,'lib','ngspice','*.cm'));
for k=1:numel(codeModels)
    labels(end+1)="runtime/lib/ngspice/"+string(codeModels(k).name);
    paths(end+1)=string(fullfile(codeModels(k).folder,codeModels(k).name));
end
[labels,index]=sort(labels);paths=paths(index);
digest=java.security.MessageDigest.getInstance('SHA-256');rows=cell(numel(paths),1);
for k=1:numel(paths)
    fid=fopen(paths(k),'rb');assert(fid>=0,'SC01B:SpiceSource','SPICE dependency is missing: %s',paths(k));
    bytes=fread(fid,Inf,'*uint8');fclose(fid);
    one=java.security.MessageDigest.getInstance('SHA-256');one.update(typecast(bytes,'int8'));
    hash=lower(reshape(dec2hex(typecast(one.digest(),'uint8'),2).',1,[]));
    digest.update(int8(unicode2native(char(labels(k)+"|"+string(hash)+newline),'UTF-8')));
    rows{k}=struct('label',labels(k),'path',paths(k),'sha256',string(hash),'bytes',numel(bytes));
end
digest.update(int8(unicode2native(version,'UTF-8')));
key=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
identity=struct('schema',"SC01B-R2-spice-source-fingerprint-v1",'fingerprint',string(key), ...
    'matlabVersion',string(version),'capturedUTC',string(datetime('now','TimeZone','UTC')), ...
    'files',vertcat(rows{:}));
end
