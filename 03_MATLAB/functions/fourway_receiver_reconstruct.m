function [queries,events,decoder,boundaries]=fourway_receiver_reconstruct(record,queryTimes)
%FOURWAY_RECEIVER_RECONSTRUCT Independently replay exported circuit records.
% Original source bytes are reverified by fourway_replay; the circuit engine
% version must match the export. Query times are evaluated exactly without
% interpolating a saved/coarse receiver waveform.
p=record.parameters;
s=fourway_receiver_init(p.coupling.Cp_F*1e12,p.coupling.Cn_F*1e12,...
 p.receiver.Cdiff_F*1e12,record.source.phase_s,record.source.exposed,...
 record.source.closure_s,record.initial_state(8));
assert(strcmp(s.config.engine_function,record.config.engine_function),...
 'FOURWAY:ReconstructionVersion','Exported engine differs from current source hash.');
assert(all(isfinite(queryTimes))&&all(diff(queryTimes)>=0)&&all(queryTimes>=0)&&all(queryTimes<=record.state(1)));
s.config.origins=record.source.pulse_origins_s;
stop=record.state(1);
[~,events,decoder,boundaries,queries]=fourway_exact(s.config,record.initial_state,stop,record.intended,queryTimes(:));
end
