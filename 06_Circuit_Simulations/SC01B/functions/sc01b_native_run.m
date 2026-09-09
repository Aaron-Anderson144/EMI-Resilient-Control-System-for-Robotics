function [r,runtime]=sc01b_native_run(p,settings,path,reuse)
%SC01B_NATIVE_RUN Optional exact-configuration reuse of completed native runs.
path=string(path);key=sc01b_native_cache_key();settings=sc01b_local_solver_settings(settings);
if reuse && isfile(path) && isfile(path+'.key') && strcmp(strtrim(fileread(path+'.key')),key)
    cached=load(path,'r','p');
    assert(isequaln(cached.p,p) && isequaln(cached.r.settings,settings), ...
        'SC01B:CacheConfiguration','Cached parameters/settings do not match the requested run.');
    r=cached.r;assert(r.warningCount==0 && abs(r.time_s(end)-settings.stopTime_s)<1e-14, ...
        'SC01B:InvalidCache','Only completed warning-free runs can be reused.');
    sc01b_metrics(r,p);
    runtime=0;fprintf('SC01B REUSE verified native record %s\n',path);return;
end
clock=tic;r=simulate_sc01b_simscape(p,settings);runtime=toc(clock);
save(path,'r','p','-v7');fid=fopen(path+'.key','w');assert(fid>=0);fprintf(fid,'%s\n',key);fclose(fid);
end
