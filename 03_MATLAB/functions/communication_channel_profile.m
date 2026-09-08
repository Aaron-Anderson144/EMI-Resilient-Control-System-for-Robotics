function profile = communication_channel_profile(time_s, params, scenario)
%COMMUNICATION_CHANNEL_PROFILE Schedule deterministic packet arrivals.
% Every sample is treated as a timestamped packet. Lost packets never
% arrive. At a collision, the newest source timestamp wins. Packets older
% than the last accepted timestamp are discarded.

arguments
    time_s (:,1) double
    params (1,1) struct
    scenario (1,1) struct
end

validate_parameters(params);
if isempty(time_s) || any(~isfinite(time_s)) || any(diff(time_s) <= 0)
    error('EMIProject:InvalidTimeVector', ...
        'The time vector must be finite and strictly increasing.');
end

p = params.phase2b.communication;
n = numel(time_s);
windowActive = time_s >= p.startTime_s & time_s < p.stopTime_s;
channelEnabled = windowActive & scenario.communicationEnabled;

transmitDelay_samples = zeros(n, 1);
if scenario.communication.fixedDelayEnabled
    transmitDelay_samples(windowActive) = p.fixedDelay_samples;
end
if scenario.communication.jitterEnabled
    previousRng = rng;
    cleanupRng = onCleanup(@() rng(previousRng));
    rng(p.jitterRandomSeed, "twister");
    jitter = randi([0, p.maximumJitter_samples], n, 1);
    transmitDelay_samples(windowActive) = ...
        transmitDelay_samples(windowActive) + jitter(windowActive);
    clear cleanupRng
end

packetDropped = false(n, 1);
if scenario.communication.packetLossEnabled
    previousRng = rng;
    cleanupRng = onCleanup(@() rng(previousRng));
    rng(p.packetLossRandomSeed, "twister");
    draws = rand(n, 1);
    packetDropped(windowActive) = draws(windowActive) < p.packetLossProbability;
    clear cleanupRng
end

arrivalIndex = (1:n)' + transmitDelay_samples;
arrivalIndex(packetDropped | arrivalIndex > n) = 0;

newestSourceAtArrival = zeros(n, 1);
arrivalCount = zeros(n, 1);
for sourceIndex = 1:n
    destinationIndex = arrivalIndex(sourceIndex);
    if destinationIndex > 0
        newestSourceAtArrival(destinationIndex) = sourceIndex;
        arrivalCount(destinationIndex) = arrivalCount(destinationIndex) + 1;
    end
end

sampleReceived = false(n, 1);
acceptedSourceIndex = zeros(n, 1);
acceptedDelay_samples = zeros(n, 1);
collisionDiscardCount = zeros(n, 1);
outOfOrderDiscardCount = zeros(n, 1);
lastAccepted = 0;

for k = 1:n
    newestSource = newestSourceAtArrival(k);
    if newestSource == 0
        continue
    end

    collisionDiscardCount(k) = max(arrivalCount(k) - 1, 0);
    if newestSource > lastAccepted
        sampleReceived(k) = true;
        acceptedSourceIndex(k) = newestSource;
        acceptedDelay_samples(k) = k - newestSource;
        lastAccepted = newestSource;
    else
        outOfOrderDiscardCount(k) = 1;
    end
end

lastAcceptedSourceIndex = zeros(n, 1);
measurementAge_samples = zeros(n, 1);
lastAccepted = 0;
for k = 1:n
    if sampleReceived(k)
        lastAccepted = acceptedSourceIndex(k);
    end
    lastAcceptedSourceIndex(k) = lastAccepted;
    if lastAccepted == 0
        measurementAge_samples(k) = k - 1;
    else
        measurementAge_samples(k) = k - lastAccepted;
    end
end

profile.channelEnabled = channelEnabled;
profile.configuredWindowActive = channelEnabled;
profile.transmitDelay_samples = transmitDelay_samples;
profile.packetDropped = packetDropped;
profile.arrivalIndex = arrivalIndex;
profile.sampleReceived = sampleReceived;
profile.acceptedSourceIndex = acceptedSourceIndex;
profile.acceptedDelay_samples = acceptedDelay_samples;
profile.lastAcceptedSourceIndex = lastAcceptedSourceIndex;
profile.heldLast = ~sampleReceived;
profile.measurementAge_samples = measurementAge_samples;
profile.measurementAge_s = measurementAge_samples .* ...
    params.control.sampleTime_s;
profile.collisionDiscardCount = collisionDiscardCount;
profile.outOfOrderDiscardCount = outOfOrderDiscardCount;
profile.transmittedPacketCount = nnz(windowActive & scenario.communicationEnabled);
profile.droppedPacketCount = nnz(packetDropped);
profile.acceptedPacketCount = nnz(sampleReceived);
end
