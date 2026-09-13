function hybrid_write_json(file,value)
%HYBRID_WRITE_JSON Write auditable study metadata.
fid=fopen(file,'w');assert(fid>=0,'Hybrid:Output','Cannot open output file.');
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
