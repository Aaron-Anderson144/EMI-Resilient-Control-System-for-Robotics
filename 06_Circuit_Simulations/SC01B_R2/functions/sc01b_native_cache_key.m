function [key,manifest]=sc01b_native_cache_key()
%SC01B_NATIVE_CACHE_KEY Hash model, source adapter and complete vendor core.
% Version 2 adds the core component and its complete helper-function package.
% Existing version-1 sidecars are deliberately not rewritten or backstamped.
root=fileparts(fileparts(mfilename('fullpath')));
vendor=fullfile(matlabroot,'toolbox','physmod','elec','spice','mosfets','m', ...
    '+ee_spice_mosfets','+spiceinfineon','+spiceOptiMOS_6_40V');
paths=string({fullfile(root,'models','EMI_SC01B_R2_Halfbridge.slx'), ...
    fullfile(root,'+sc01b_driver','split_resistor.ssc'),fullfile(root,'sc01b_driver_lib.slx'), ...
    fullfile(root,'scripts','build_sc01b_model.m'), ...
    fullfile(root,'functions','simulate_sc01b_simscape.m'), ...
    fullfile(root,'functions','sc01b_gate_signals.m'), ...
    fullfile(root,'functions','sc01b_local_solver_settings.m'), ...
    fullfile(vendor,'IAUC100N04S6L014.ssc'),fullfile(vendor,'a6_40_d_var.ssc')});
helpers=dir(fullfile(vendor,'+a6_40_d_var_simscape_functions','**','*'));
helpers=helpers(~[helpers.isdir]);assert(~isempty(helpers),'SC01B:CacheSource','Vendor helper package is empty.');
helperPaths=sort(string(fullfile({helpers.folder},{helpers.name})));
paths=[paths,reshape(helperPaths,1,[])];
digest=java.security.MessageDigest.getInstance('SHA-256');
rows=cell(numel(paths),1);
for k=1:numel(paths)
    path=paths(k);
    fid=fopen(path,'rb');assert(fid>=0,'SC01B:CacheSource','Cache source missing.');
    bytes=fread(fid,Inf,'*uint8');fclose(fid);digest.update(typecast(bytes,'int8'));
    one=java.security.MessageDigest.getInstance('SHA-256');one.update(typecast(bytes,'int8'));
    fileHash=lower(reshape(dec2hex(typecast(one.digest(),'uint8'),2).',1,[]));
    details=dir(path);modified=datetime(details.datenum,'ConvertFrom','datenum','TimeZone','local');
    modified.TimeZone='UTC';modified.Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    rows{k}=struct('path',path,'sha256',string(fileHash),'bytes',numel(bytes), ...
        'modifiedUTC',string(modified),'vendorDependency',startsWith(path,string(vendor)));
end
digest.update(int8(unicode2native(version,'UTF-8')));
key=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
manifest=struct('schema',"SC01B-native-source-fingerprint-v2",'fingerprint',string(key), ...
    'matlabVersion',string(version),'capturedUTC',string(datetime('now','TimeZone','UTC')), ...
    'files',vertcat(rows{:}));
end
