function record=fourway_receiver_export(sensor)
%FOURWAY_RECEIVER_EXPORT Full event records plus exact reconstruction inputs.
record=sensor;
record.events=join(sensor.event_blocks,8);record.decoder=join(sensor.decoder_blocks,8);
record.intended=join(sensor.intended_blocks,3);record.boundaries=join(sensor.boundary_blocks,7);
record.packets=join(sensor.packet_blocks,10);
record=rmfield(record,{'event_blocks','decoder_blocks','intended_blocks','boundary_blocks','packet_blocks'});
% Immutable replay is pinned by hash, avoiding millions of redundant rows.
record.config=rmfield(record.config,{'knots','volts','slopes'});
end
function a=join(blocks,n)
if isempty(blocks),a=zeros(0,n);else,a=vertcat(blocks{:});end
end
