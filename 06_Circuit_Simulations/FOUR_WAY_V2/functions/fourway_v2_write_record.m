function fourway_v2_write_record(result,recordFolder)
%FOURWAY_WRITE_RECORD Readable event evidence plus exact reconstruction state.
writetable(result.timeSeries,fullfile(recordFolder,'controller.csv'));
writetable(array2table(result.intendedTransitions,'VariableNames',{'time_s','A','B'}),fullfile(recordFolder,'intended_AB.csv'));
writetable(result.intervalStats,fullfile(recordFolder,'plant_interval_metrics.csv'));
for name=["receiver","shadow"]
 r=result.(name);prefix=fullfile(recordFolder,name+"_");
 if isfield(r,'logic')
  writetable(array2table(r.logic,'VariableNames',{'time_s','kind','A','dueTime_s'}),prefix+"logic_events.csv");
 end
 metadata=rmfield(r,intersect(fieldnames(r),{'events','decoder','boundaries','packets','logic','circuit'}));
 fid=fopen(prefix+"metadata.json",'w');fprintf(fid,'%s\n',jsonencode(metadata,'PrettyPrint',true));fclose(fid);
 writetable(array2table(r.events,'VariableNames',r.event_columns),prefix+"threshold_events.csv");
 writetable(array2table(r.decoder,'VariableNames',r.decoder_columns),prefix+"decoder_events.csv");
 writetable(array2table(r.boundaries,'VariableNames',r.boundary_columns),prefix+"circuit_boundaries.csv");
 writetable(array2table(r.packets,'VariableNames',r.packet_columns),prefix+"packets.csv");
 fid=fopen(prefix+"source.json",'w');fprintf(fid,'%s\n',jsonencode(r.source,'PrettyPrint',true));fclose(fid);
end
f=result.fixture;f=rmfield(f,{'run','root'});
fid=fopen(fullfile(recordFolder,'fixture.json'),'w');fprintf(fid,'%s\n',jsonencode(f,'PrettyPrint',true));fclose(fid);
save(fullfile(recordFolder,'record.mat'),'result','-v7.3');
fid=fopen(fullfile(recordFolder,'decoder_audit.json'),'w');
fprintf(fid,'%s\n',jsonencode(result.decoderAudit,'PrettyPrint',true));fclose(fid);
end
