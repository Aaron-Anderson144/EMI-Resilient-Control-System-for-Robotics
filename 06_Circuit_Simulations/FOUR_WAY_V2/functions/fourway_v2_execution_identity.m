function identity=fourway_v2_execution_identity()
% Bind executable causal/scoring source and native source binary before runs.
root=fourway_v2_root();paths=strings(0,1);
for relative=["03_MATLAB/functions","03_MATLAB/parameters", ...
 "06_Circuit_Simulations/FOUR_WAY/functions","06_Circuit_Simulations/FOUR_WAY_V2/functions", ...
 "06_Circuit_Simulations/FOUR_WAY_V2/scripts","06_Circuit_Simulations/RECEIVER_V2/functions", ...
 "06_Circuit_Simulations/SC01A/functions"]
 entries=dir(fullfile(root,relative,'*'));
 for k=1:numel(entries)
  [~,~,ext]=fileparts(entries(k).name);
  if ~entries(k).isdir&&any(string(ext)==[".m",".cpp",".h"])
   paths(end+1,1)=fullfile(root,relative,entries(k).name); %#ok<AGROW>
  end
 end
end
engine=fourway_v2_build_engine();paths(end+1,1)=string(which(engine));paths=sort(unique(paths));
files=cell(numel(paths),1);
for k=1:numel(paths)
 fid=fopen(paths(k),'rb');assert(fid>=0);bytes=fread(fid,inf,'*uint8');fclose(fid);
 d=java.security.MessageDigest.getInstance('SHA-256');d.update(typecast(bytes,'int8'));
 hash=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
 files{k}=struct('path',paths(k),'sha256',hash);
end
identity=struct('design_id',"FOUR-WAY-EMI-PLAN-V2",'engine',string(engine), ...
 'matlab_version',string(version),'captured_utc',string(datetime('now','TimeZone','UTC')), ...
 'files',vertcat(files{:}));
end
