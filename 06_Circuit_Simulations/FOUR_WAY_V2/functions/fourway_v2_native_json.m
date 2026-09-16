function fourway_v2_native_json(file,value)
fid=fopen(file,'w');assert(fid>=0,'FOURWAYV2:EvidenceWrite','Cannot write %s.',file);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true,'ConvertInfAndNaN',true));
end
