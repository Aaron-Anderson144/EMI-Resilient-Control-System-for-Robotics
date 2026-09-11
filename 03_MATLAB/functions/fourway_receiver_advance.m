function [sensor,packet]=fourway_receiver_advance(sensor,tEnd,intendedTransitions)
%FOURWAY_RECEIVER_ADVANCE Consume causal A/B transitions through tEnd inclusive.
% intendedTransitions is [absolute time,A,B], chronological, with no truth
% annotation passed into the receiver. The packet has source index supplied
% separately by the caller; its value is the persistent decoded count.
if nargin<3||isempty(intendedTransitions),intendedTransitions=zeros(0,3);end
assert(size(intendedTransitions,2)==3&&all(isfinite(intendedTransitions),'all'));
assert(all(diff(intendedTransitions(:,1))>=0)&&...
    all(intendedTransitions(:,1)>=sensor.state(1))&&...
    all(intendedTransitions(:,1)<=tEnd));
assert(all(ismember(intendedTransitions(:,2:3),[0 1]),'all'));
assert(isfinite(tEnd)&&tEnd>=sensor.state(1));
[sensor.state,events,decoder,boundaries]=fourway_exact(sensor.config,sensor.state,tEnd,intendedTransitions);
packet=struct('count',sensor.state(11),'count_rad',sensor.state(11)*(2*pi/4096),...
    'ideal_count',sensor.state(17),'domain_failed',logical(sensor.state(14)),...
    'vp',sensor.state(2),'vn',sensor.state(3),'ir',sensor.state(4),...
    'ideal_A',sensor.state(8),'ideal_B',sensor.state(9),'time_s',tEnd,...
    'max_abs_common_mode_V',sensor.state(18));
if ~isempty(events),sensor.event_blocks{end+1}=events;end
if ~isempty(decoder),sensor.decoder_blocks{end+1}=decoder;end
if ~isempty(boundaries),sensor.boundary_blocks{end+1}=boundaries;end
if ~isempty(intendedTransitions),sensor.intended_blocks{end+1}=intendedTransitions;end
sensor.packet_blocks{end+1}=[tEnd packet.count packet.count_rad packet.ideal_count packet.domain_failed packet.vp packet.vn packet.ir packet.ideal_A packet.ideal_B];
end
