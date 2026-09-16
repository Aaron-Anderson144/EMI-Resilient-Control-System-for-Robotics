function acceptance=fourway_v2_require_acceptance(path)
% Fail closed until a separate V2 implementation and evidence freeze exists.
assert(strlength(path)>0&&isfile(path),'EMIProject:V2Acceptance','Accepted V2 implementation freeze is required.');
script=fullfile(fourway_v2_root(),'06_Circuit_Simulations','FOUR_WAY_V2','audit','verify_v2_acceptance.py');
assert(~contains(path,'"'),'EMIProject:V2Acceptance','Invalid path.');
[status,output]=system(sprintf('py -3.12 "%s" --acceptance "%s"',script,path));
assert(status==0,'EMIProject:V2Acceptance','V2 acceptance verification failed: %s',output);
acceptance=jsondecode(fileread(path));
end
