function summary = packet_profile_summary(profile, sourceWindowActive)
%PACKET_PROFILE_SUMMARY Count final scheduled outcomes by source population.
% V1 counts every source sample as a transmitted packet, including packets
% subsequently dropped. Record counts cover all sources; faultWindow counts
% cover the supplied source mask (enabled communication windows plus forced
% gaps in Phase 3). Accepted packets belong to their source-time population,
% even when received outside that window. Unreceived packets that would arrive
% beyond the record are pending, not dropped. This helper changes no schedule.
id='EMIProject:InvalidPacketSummary';
assert(isstruct(profile)&&isscalar(profile),id,'A scalar scheduled profile is required.');
required={'packetDropped','sampleReceived','arrivalIndex','acceptedSourceIndex','transmitDelay_samples'};
assert(all(isfield(profile,required)),id,'The final packet schedule is incomplete.');
n=numel(profile.packetDropped);
assert(n>0 && islogical(sourceWindowActive) && isequal(size(sourceWindowActive),[n,1]), ...
    id,'The source-window mask must be a logical column matching the schedule.');
for name={'packetDropped','sampleReceived'}
    value=profile.(name{1});
    assert(islogical(value)&&isequal(size(value),[n,1]),id,'Schedule flags must be matching logical columns.');
end
for name={'arrivalIndex','acceptedSourceIndex','transmitDelay_samples'}
    value=profile.(name{1});
    assert(isnumeric(value)&&isreal(value)&&isequal(size(value),[n,1])&& ...
        all(isfinite(value))&&all(value>=0&value==fix(value)),id, ...
        'Schedule indices and delays must be matching nonnegative integer columns.');
end
delay=double(profile.transmitDelay_samples);
assert(all(delay<=flintmax-n),id,'Packet arrival indices must be exactly representable.');
expectedArrival=(1:n)'+delay;
expectedArrival(profile.packetDropped|expectedArrival>n)=0;
assert(isequal(double(profile.arrivalIndex),expectedArrival),id,'Arrival indices contradict final delays/drop flags.');
received=find(profile.sampleReceived);
sources=double(profile.acceptedSourceIndex(received));
assert(all(profile.acceptedSourceIndex(~profile.sampleReceived)==0)&& ...
    all(sources>=1&sources<=received)&&all(diff(sources)>0),id, ...
    'Accepted source indices must be causal, unique and increasing.');
assert(all(expectedArrival(sources)==received),id,'Accepted packets must arrive on their reception sample.');
accepted=false(n,1);accepted(sources)=true;
arrived=expectedArrival>0;
pending=~profile.packetDropped&~arrived;
discarded=arrived&~accepted;
summary.schemaVersion="PACKET-SUMMARY-V1";
summary.population="Source packets; transmitted includes packets subsequently dropped; accepted is attributed by source index";
summary.faultWindowSourceActive=sourceWindowActive;
summary.record=counts(true(n,1));
summary.faultWindow=counts(sourceWindowActive);

    function result=counts(mask)
        result=struct('transmittedPacketCount',nnz(mask), ...
            'droppedPacketCount',nnz(mask&profile.packetDropped), ...
            'arrivedPacketCount',nnz(mask&arrived), ...
            'acceptedPacketCount',nnz(mask&accepted), ...
            'discardedAfterArrivalPacketCount',nnz(mask&discarded), ...
            'pendingBeyondRecordPacketCount',nnz(mask&pending));
    end
end
