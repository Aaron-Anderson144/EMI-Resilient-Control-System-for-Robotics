function schedule = schedule_timestamped_packets(transmitDelay_samples,packetDropped)
%SCHEDULE_TIMESTAMPED_PACKETS Deterministic arrival/acceptance bookkeeping.
% Element j is the packet sampled at controller index j. A nonnegative
% integer delay places it at j+delay; dropped and beyond-record packets
% never arrive. Newest source timestamp wins a collision. If even that
% winner is older than the last accepted timestamp, reception holds.
%
% Discard counts partition packets that actually arrive: all collision
% losers count as collisions, and a stale collision winner counts once as
% out-of-order. Thus accepted + collision + out-of-order = arrived packets.
% Before the first reception the held measurement is the receiver's initial
% value; its age is k-1. Output vectors are always columns.

id = 'EMIProject:InvalidPacketSchedule';
if ~isnumeric(transmitDelay_samples) || ~isreal(transmitDelay_samples) || ...
        ~isvector(transmitDelay_samples) || isempty(transmitDelay_samples) || ...
        any(~isfinite(transmitDelay_samples(:)))
    error(id,'Transmit delays must be a nonempty finite real numeric vector.');
end
if ~islogical(packetDropped) || ~isvector(packetDropped) || ...
        numel(packetDropped) ~= numel(transmitDelay_samples)
    error(id,'Packet-drop flags must be a logical vector matching the delays.');
end
delay = double(transmitDelay_samples(:));
packetDropped = packetDropped(:);
n = numel(delay);
if any(delay < 0 | delay ~= fix(delay) | delay > flintmax-n)
    error(id,'Transmit delays must be nonnegative integers with exactly representable arrival indices.');
end

arrivalIndex = (1:n)' + delay;
arrivalIndex(packetDropped | arrivalIndex > n) = 0;
newestSourceAtArrival = zeros(n,1);
arrivalCount = zeros(n,1);
for sourceIndex = 1:n
    destinationIndex = arrivalIndex(sourceIndex);
    if destinationIndex > 0
        newestSourceAtArrival(destinationIndex) = sourceIndex;
        arrivalCount(destinationIndex) = arrivalCount(destinationIndex)+1;
    end
end

sampleReceived = false(n,1);
acceptedSourceIndex = zeros(n,1);
acceptedDelay_samples = zeros(n,1);
collisionDiscardCount = zeros(n,1);
outOfOrderDiscardCount = zeros(n,1);
lastAccepted = 0;
for k = 1:n
    newestSource = newestSourceAtArrival(k);
    if newestSource == 0, continue; end
    collisionDiscardCount(k) = max(arrivalCount(k)-1,0);
    if newestSource > lastAccepted
        sampleReceived(k) = true;
        acceptedSourceIndex(k) = newestSource;
        acceptedDelay_samples(k) = k-newestSource;
        lastAccepted = newestSource;
    else
        outOfOrderDiscardCount(k) = 1;
    end
end

lastAcceptedSourceIndex = zeros(n,1);
measurementAge_samples = zeros(n,1);
lastAccepted = 0;
for k = 1:n
    if sampleReceived(k), lastAccepted = acceptedSourceIndex(k); end
    lastAcceptedSourceIndex(k) = lastAccepted;
    if lastAccepted == 0
        measurementAge_samples(k) = k-1;
    else
        measurementAge_samples(k) = k-lastAccepted;
    end
end

schedule.arrivalIndex = arrivalIndex;
schedule.sampleReceived = sampleReceived;
schedule.acceptedSourceIndex = acceptedSourceIndex;
schedule.acceptedDelay_samples = acceptedDelay_samples;
schedule.lastAcceptedSourceIndex = lastAcceptedSourceIndex;
schedule.heldLast = ~sampleReceived;
schedule.measurementAge_samples = measurementAge_samples;
schedule.collisionDiscardCount = collisionDiscardCount;
schedule.outOfOrderDiscardCount = outOfOrderDiscardCount;
end
