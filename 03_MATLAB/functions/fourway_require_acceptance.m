function acceptance=fourway_require_acceptance(acceptancePath)
%FOURWAY_REQUIRE_ACCEPTANCE Fail closed on incomplete/changed acceptance.
% Schema 1 pins the complete implementation inventory and four JSON evidence
% reports. Acceptance booleans alone are insufficient; full development,
% native, legacy and independent reconstruction counts must also pass.
project=fileparts(fileparts(fileparts(mfilename('fullpath'))));
id='EMIProject:FourWayAcceptance';
assert(strlength(acceptancePath)>0&&isfile(acceptancePath),'EMIProject:FourWayAcceptance', ...
 'Complete development/native acceptance and freeze implementation before evaluation.');
acceptance=jsondecode(fileread(acceptancePath));
requireFields(acceptance,["schema_version","design_id","passed","development_passed", ...
 "native_passed","legacy_passed","files","evidence"]);
assert(isequal(acceptance.schema_version,1)&& ...
 string(acceptance.design_id)=="FOUR-WAY-EMI-PLAN-V1",id,'Wrong acceptance schema or design identity.');
for field=["passed","development_passed","native_passed","legacy_passed"]
 requireTrue(acceptance.(field));
end
assert(isstruct(acceptance.files)&&~isempty(acceptance.files),id,'Implementation hash inventory is empty.');
requireFields(acceptance.files,["path","sha256"]);
listed=strings(numel(acceptance.files),1);
for j=1:numel(acceptance.files)
 listed(j)=string(acceptance.files(j).path);
 implementationPath(listed(j));
end
assert(numel(unique(lower(listed)))==numel(listed),id,'Duplicate implementation hash paths.');
assert(isequal(sort(listed),fourway_implementation_inventory()),id, ...
 'Acceptance does not cover exactly the complete current implementation inventory.');
for j=1:numel(acceptance.files)
 e=acceptance.files(j);
 verifyHash(implementationPath(string(e.path)),e.sha256,'EMIProject:FourWayImplementationChanged');
end
roles=["development","native","legacy","independent_audit"];
requireFields(acceptance.evidence,roles);
reports=struct();evidencePaths=strings(4,1);
for j=1:numel(roles)
 entry=acceptance.evidence.(roles(j));requireFields(entry,["path","sha256"]);
 path=string(entry.path);assert(isscalar(path)&&~ismissing(path)&&strlength(path)>0,id,'Empty evidence path.');
 assert(~any(split(replace(path,"\","/"),"/")==".."),id,'Evidence path contains parent traversal.');
 if ~java.io.File(char(path)).isAbsolute(),path=fullfile(project,path);end
 path=string(java.io.File(char(path)).getCanonicalPath());evidencePaths(j)=path;
 verifyHash(path,entry.sha256,'EMIProject:FourWayEvidenceChanged');
 reports.(roles(j))=jsondecode(fileread(path));
end
assert(numel(unique(lower(evidencePaths)))==4,id,'Each acceptance role needs its own evidence report.');
d=reports.development;
requireFields(d,["partition","logical_records","unique_executions","paired_results","all_execution_clean_guards_pass"]);
assert(string(d.partition)=="development"&&d.logical_records==16&&d.unique_executions==16&&d.paired_results==8,id, ...
 'Development evidence is incomplete or is from another partition.');
requireTrue(d.all_execution_clean_guards_pass);
n=reports.native;
requireFields(n,["passed","requiredNativeRuns","executedNativeRuns","passedNativeRuns", ...
 "requiredRefinements","executedRefinements","passedRefinements","integerCountsExact","receiverDomainRejectedRuns"]);
requireTrue(n.passed);requireTrue(n.integerCountsExact);
assert(all([n.requiredNativeRuns,n.executedNativeRuns,n.passedNativeRuns]==24)&& ...
 all([n.requiredRefinements,n.executedRefinements,n.passedRefinements]==16)&&n.receiverDomainRejectedRuns==0,id, ...
 'Native evidence must pass all 24 runs and all 16 refinements without receiver-domain rejections.');
l=reports.legacy;
requireFields(l,["passed","tests","failed","incomplete","legacy_first20_passed"]);
requireTrue(l.passed);requireTrue(l.legacy_first20_passed);
assert(isscalar(l.tests)&&isfinite(l.tests)&&l.tests>0&&l.tests==fix(l.tests)&&l.failed==0&&l.incomplete==0,id, ...
 'Legacy evidence is empty, failed or incomplete.');
a=reports.independent_audit;requireFields(a,["all_passed","campaigns"]);requireTrue(a.all_passed);
assert(isstruct(a.campaigns)&&~isempty(a.campaigns),id,'Independent audit has no campaigns.');
recordNames=strings(0,1);pairNames=strings(0,1);
for j=1:numel(a.campaigns)
 campaign=a.campaigns(j);requireFields(campaign,["all_passed","records","metrics"]);requireTrue(campaign.all_passed);
 for field=["records","metrics"]
  entries=campaign.(field);assert(isstruct(entries)&&~isempty(entries),id,'Independent audit has empty evidence.');
  requireFields(entries,["checks","failed"]);
  assert(all([entries.checks]>0)&&all(arrayfun(@(entry)isempty(entry.failed),entries)),id, ...
   'Independent audit contains failed or vacuous checks.');
 end
 requireFields(campaign.records,"record");requireFields(campaign.metrics,"pair");
 recordNames=[recordNames;string({campaign.records.record})']; %#ok<AGROW>
 pairNames=[pairNames;string({campaign.metrics.pair})']; %#ok<AGROW>
end
expectedPairs=strings(0,1);
for fixture=["DEV01","DEV02"]
 for arm=["BASELINE","EM_ONLY","SW_ONLY","COMBINED"]
  expectedPairs(end+1,1)=fixture+"_"+arm; %#ok<AGROW>
 end
end
expectedRecords=sort([expectedPairs+"_clean";expectedPairs+"_exposed"]);
assert(isequal(sort(pairNames),sort(expectedPairs))&&isequal(sort(recordNames),expectedRecords),id, ...
 'Independent audit must contain each of the 16 development records and eight pairs exactly once.');

 function requireFields(value,fields)
  assert(isstruct(value)&&all(isfield(value,cellstr(fields))),id,'Required acceptance/evidence field is missing.');
 end

 function requireTrue(value)
  assert(islogical(value)&&isscalar(value)&&value,id,'Required acceptance/evidence gate did not pass.');
 end

 function path=implementationPath(relative)
  assert(isscalar(relative)&&~ismissing(relative)&&strlength(relative)>0&& ...
   ~contains(relative,"\")&&~contains(relative,":")&&~startsWith(relative,"/"),id, ...
   'Implementation paths must use project-relative forward slashes.');
  parts=split(relative,"/");assert(~any(parts==".."|parts=="."|parts==""),id,'Invalid implementation path segments.');
  path=string(java.io.File(char(fullfile(project,relative))).getCanonicalPath());
  root=string(java.io.File(project).getCanonicalPath());
  assert(startsWith(lower(path),lower(root+filesep)),id,'Implementation path escapes the project.');
 end

 function verifyHash(path,expected,errorId)
  assert((ischar(expected)||isstring(expected))&& ...
   ~isempty(regexp(char(expected),'^[0-9a-f]{64}$','once')),id,'Malformed SHA-256 digest.');
  fid=fopen(path,'rb');assert(fid>=0,errorId,'Missing pinned file: %s',path);
  cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,Inf,'*uint8');
  digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
  hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
  assert(strcmp(hash,expected),errorId,'Pinned file changed after acceptance: %s',path);
 end
end
