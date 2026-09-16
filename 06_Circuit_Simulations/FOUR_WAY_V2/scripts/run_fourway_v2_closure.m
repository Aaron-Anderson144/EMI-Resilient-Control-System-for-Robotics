function report=run_fourway_v2_closure(outputFolder,acceptancePath)
% Frozen source-return sensitivity; excluded from primary evaluation scoring.
fourway_v2_verify_freeze();fourway_v2_require_acceptance(acceptancePath);
assert(~isfolder(outputFolder),'EMIProject:V2Output','Use a fresh closure output directory.');mkdir(outputFolder);
identity=fourway_v2_execution_identity();pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',8);end
parts=cell(16,1);
parfor v=1:16,parts{v}=oneVariant(v,outputFolder);end
records=table();comparisons=table();
for v=1:16,records=[records;parts{v}.records];comparisons=[comparisons;parts{v}.comparisons];end %#ok<AGROW>
writetable(records,fullfile(outputFolder,'record_index.csv'));writetable(comparisons,fullfile(outputFolder,'closure_comparisons.csv'));
report=struct('design_id',"FOUR-WAY-EMI-PLAN-V2",'stage',"closure_diagnostic", ...
 'logical_records',height(records),'expected_records',256,'complete',height(records)==256&&all(records.Status=="passed"), ...
 'comparison_pairs',height(comparisons),'excluded_from_primary_evaluation',true,'physical_validation',false, ...
 'execution_identity',identity);
fid=fopen(fullfile(outputFolder,'stage_summary.json'),'w');fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end

function part=oneVariant(v,outputFolder)
records=table();comparisons=table();arms=["BASELINE","EM_ONLY","SW_ONLY","COMBINED"];
for cp=[40 240]
 for arm=arms
  pair=cell(1,2);index=0;
  for closure=[100e-9 45e-6]
   index=index+1;seed="V2EVAL01";if cp==240,seed="V2EVAL09";end
   f=fourway_v2_fixture(seed,arm,true,v,closure);f.id="V2CLOS"+string(cp);f.partition="closure_diagnostic";f.phase_s=0;
   recordId=f.id+"_"+f.variant.id+"_"+arm+"_return"+string(round(closure*1e9))+"ns";
   folder=fullfile(outputFolder,recordId);mkdir(folder);timer=tic;status="passed";errorText="";
   fprintf('FOURWAY V2 closure: %s\n',recordId);
   try
    result=simulate_fourway_v2_actuator(f);fourway_v2_write_record(result,folder);pair{index}=result;
   catch failure
    status="failed";errorText=string(getReport(failure,'extended','hyperlinks','off'));
    fid=fopen(fullfile(folder,'failure.txt'),'w');fprintf(fid,'%s\n',errorText);fclose(fid);
   end
   elapsed=toc(timer);records=[records;table(recordId,f.id,f.variant.id,arm,closure,elapsed,status,errorText, ...
    'VariableNames',{'Record','Fixture','Variant','Arm','Closure_s','Elapsed_s','Status','Error'})]; %#ok<AGROW>
  end
  if ~isempty(pair{1})&&~isempty(pair{2})
   a=pair{1}.timeSeries;b=pair{2}.timeSeries;delta=rad2deg(b.position_rad-a.position_rad);
   comparisons=[comparisons;table(f.id,f.variant.id,arm,cp,sqrt(mean(delta.^2)),max(abs(delta)), ...
    max(abs(a.emiCountError)),max(abs(b.emiCountError)),a.emiCountError(end),b.emiCountError(end), ...
    ~any(a.receiverDomainFailed|a.receiverNumericalRejected),~any(b.receiverDomainFailed|b.receiverNumericalRejected), ...
    'VariableNames',{'Fixture','Variant','Arm','Ccp_pF','ReturnSensitivityRMSE_deg','ReturnSensitivityPeak_deg', ...
    'ShortReturnPeakCountError','LongReturnPeakCountError','ShortReturnFinalCountError','LongReturnFinalCountError', ...
    'ShortReturnDomainNumericsPass','LongReturnDomainNumericsPass'})]; %#ok<AGROW>
  end
 end
end
part=struct('records',records,'comparisons',comparisons);
end
