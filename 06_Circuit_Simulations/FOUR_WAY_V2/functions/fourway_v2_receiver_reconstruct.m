function [queries,events,decoder,boundaries,logic]=fourway_v2_receiver_reconstruct(record,queryTimes)
p=record.parameters;
s=fourway_v2_receiver_init(p.coupling.Cp_F*1e12,p.coupling.Cn_F*1e12,p.receiver.Cdiff_F*1e12, ...
    record.source.phase_s,record.source.exposed,record.variant,record.source.closure_s,record.initial_state(8));
assert(strcmp(s.config.engine_function,record.config.engine_function),'FOURWAY_V2:ReconstructionVersion','Receiver source changed.');
assert(all(isfinite(queryTimes))&&all(diff(queryTimes)>=0)&&all(queryTimes>=0)&&all(queryTimes<=record.state(1)));
s.config.origins=record.source.pulse_origins_s;
[~,events,decoder,boundaries,queries,logic]=fourway_v2_exact(s.config,record.initial_state,record.state(1),record.intended,queryTimes(:));
end
