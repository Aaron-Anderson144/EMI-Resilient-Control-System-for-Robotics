function diagnostics=run_fourway_closure(outputFolder,acceptancePath)
%RUN_FOURWAY_CLOSURE Sixteen separately declared source-construction records.
arguments
 outputFolder (1,1) string
 acceptancePath (1,1) string
end
fourway_verify_freeze();fourway_require_acceptance(acceptancePath);
root=fileparts(fileparts(mfilename('fullpath')));
outputFolder=prepare_fresh_output_folder(outputFolder,fullfile(root,'results','development'),"fourway_closure");
rows=table();
for ccp=[30,300]
 id="EVAL01";if ccp==300,id="EVAL09";end
 for arm=["BASELINE","EM_ONLY","SW_ONLY","COMBINED"]
  pair=cell(1,2);
  for j=1:2
   durations=[100e-9,45e-6];f=fourway_fixture(id,arm,true,durations(j));
   f.id="CLOSURE"+string(ccp);f.partition="closure_diagnostic";f.phase_s=0;
   f.run.scenario.name=f.id+"_"+arm;
   recordId=f.id+"_"+arm+"_return"+string(j);folder=fullfile(outputFolder,recordId);mkdir(folder);
   fprintf('FOURWAY closure: %s\n',recordId);
   result=simulate_fourway_actuator(f);fourway_write_record(result,folder);pair{j}=result;
  end
  a=pair{1}.timeSeries;b=pair{2}.timeSeries;
  decoderChanged=~isequal(pair{1}.receiver.decoder,pair{2}.receiver.decoder);
  row=table("CLOSURE"+string(ccp),arm,ccp,~any(a.receiverDomainFailed),~any(b.receiverDomainFailed), ...
   decoderChanged,sum(a.decodedCount~=b.decodedCount),max(abs(a.decodedCount-b.decodedCount)), ...
   max(abs(rad2deg(a.position_rad-b.position_rad))),sqrt(mean(rad2deg(a.position_rad-b.position_rad).^2)), ...
   max(abs(a.current_A-b.current_A)), ...
   'VariableNames',{'Fixture','Arm','Ccp_pF','ShortReturnDomainPass','LongReturnDomainPass', ...
   'DecoderEventRecordChanged','ChangedPacketSamples','PeakCountDifference','PeakPositionDifference_deg', ...
   'PositionDifferenceRMSE_deg','PeakCurrentDifference_A'});
  rows=[rows;row];writetable(rows,fullfile(outputFolder,'closure_comparison.csv')); %#ok<AGROW>
  clear pair result
 end
end
diagnostics=struct('logical_records',16,'unique_executions',16,'excluded_from_evaluation',true, ...
 'comparison',rows,'physical_validation',false);
save(fullfile(outputFolder,'closure_diagnostics.mat'),'diagnostics','-v7');
end
