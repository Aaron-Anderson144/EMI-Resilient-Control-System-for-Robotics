function metadata=fourway_source_metadata(phase_s,closure_s)
%FOURWAY_SOURCE_METADATA Exact nonzero derivative support, including closure.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
c=jsondecode(fileread(fullfile(root,'04_EMI_Models','four_way_emi_configuration.json')));
raw=readtable(fullfile(root,c.source.path));t=raw.time_s;v=raw.switch_V;
assert(t(1)==0&&all(diff(t)>0)&&all(isfinite([t;v])),'EMIProject:FourWaySource','Invalid pinned record.');
active=find(diff(v)~=0);
first=t(active(1));last=t(active(end)+1);
if v(end)~=v(1),last=t(end)+closure_s;end
origin=c.source.burst_anchor_s(:)+phase_s-c.source.command_edge_anchor_s;
metadata=struct('source_sha256',string(c.source.sha256),'source_samples',numel(t), ...
 'source_duration_s',t(end),'initial_V',v(1),'final_V',v(end),'return_duration_s',closure_s, ...
 'burst_first_derivative_s',origin+first, ...
 'burst_last_derivative_s',origin+(c.source.pulses_per_burst-1)*c.source.period_s+last, ...
 'burst_origin_s',origin,'burst_end_s',origin+c.source.pulses_per_burst*c.source.period_s, ...
 'pulses_per_burst',c.source.pulses_per_burst,'period_s',c.source.period_s);
end
