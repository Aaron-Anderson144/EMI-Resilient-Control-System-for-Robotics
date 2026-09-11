function paths=fourway_implementation_inventory()
%FOURWAY_IMPLEMENTATION_INVENTORY Complete code/equation/runtime freeze set.
% Returns sorted project-relative paths. Evidence outputs, work scripts and
% obsolete compiled engines are excluded; the current source-named MEX is
% included. A new implementation/test source therefore invalidates an older
% acceptance inventory rather than being silently omitted from its hashes.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
paths=strings(0,1);
paths=[paths;findSources(fullfile(root,'03_MATLAB'),".m")];
for area=["functions","tests"]
 paths=[paths;findSources(fullfile(root,'06_Circuit_Simulations','FOUR_WAY',area), ...
  [".m",".cpp",".c",".h",".hpp"])]; %#ok<AGROW>
end
paths=[paths;findSources(fullfile(root,'06_Circuit_Simulations','SC01A','functions'),".m")];
manifestPath="04_EMI_Models/four_way_emi_freeze_manifest.json";
manifest=jsondecode(fileread(fullfile(root,manifestPath)));
paths=[paths;manifestPath;string({manifest.files.path})'; ...
 "06_Circuit_Simulations/SC01A/models/EMI_SC01A_Finite_Edge.slx"];
source="06_Circuit_Simulations/FOUR_WAY/functions/fourway_exact_mex.cpp";
fid=fopen(fullfile(root,source),'rb');assert(fid>=0,'EMIProject:FourWayAcceptance','Exact engine source is missing.');
cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
paths=[paths;"06_Circuit_Simulations/FOUR_WAY/work/fourway_exact_"+string(hash(1:16))+"."+mexext];
paths=sort(unique(replace(paths,"\","/")));

 function found=findSources(folder,extensions)
  found=strings(0,1);if ~isfolder(folder),return,end
  entries=dir(fullfile(folder,'**','*'));entries=entries(~[entries.isdir]);
  for k=1:numel(entries)
   absolute=string(fullfile(entries(k).folder,entries(k).name));
   relative=replace(extractAfter(absolute,strlength(string(root))+1),"\","/");
   [~,~,extension]=fileparts(relative);
   if any(string(extension)==extensions)&&~contains("/"+relative,["/results/","/work/"])
    found(end+1,1)=relative; %#ok<AGROW>
   end
  end
 end
end
