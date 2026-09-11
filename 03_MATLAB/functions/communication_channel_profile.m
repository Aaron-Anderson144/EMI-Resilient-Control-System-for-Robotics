function profile = communication_channel_profile(time_s, params, scenario)
%COMMUNICATION_CHANNEL_PROFILE Schedule deterministic packet arrivals.
% Every sample is treated as a timestamped packet. Lost packets never
% arrive. At a collision, the newest source timestamp wins. Packets older
% than the last accepted timestamp are discarded.

arguments
    time_s
    params (1,1) struct
    scenario (1,1) struct
end

validate_parameters(params);
validate_phase2b_scenario(scenario, params);
validate_profile_time(time_s, params, true);
time_s = time_s(:);
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

schedule = schedule_timestamped_packets(transmitDelay_samples,packetDropped);

profile.channelEnabled = channelEnabled;
profile.configuredWindowActive = channelEnabled;
profile.transmitDelay_samples = transmitDelay_samples;
profile.packetDropped = packetDropped;
profile.arrivalIndex = schedule.arrivalIndex;
profile.sampleReceived = schedule.sampleReceived;
profile.acceptedSourceIndex = schedule.acceptedSourceIndex;
profile.acceptedDelay_samples = schedule.acceptedDelay_samples;
profile.lastAcceptedSourceIndex = schedule.lastAcceptedSourceIndex;
profile.heldLast = schedule.heldLast;
profile.measurementAge_samples = schedule.measurementAge_samples;
profile.measurementAge_s = schedule.measurementAge_samples .* ...
    params.control.sampleTime_s;
profile.collisionDiscardCount = schedule.collisionDiscardCount;
profile.outOfOrderDiscardCount = schedule.outOfOrderDiscardCount;
% Versioned summaries use one source population consistently. Top-level
% counts cover the full record; fault-window rates use packetSummary.faultWindow.
profile.packetSummary = packet_profile_summary(profile,channelEnabled);
profile.transmittedPacketCount = profile.packetSummary.record.transmittedPacketCount;
profile.droppedPacketCount = profile.packetSummary.record.droppedPacketCount;
profile.acceptedPacketCount = profile.packetSummary.record.acceptedPacketCount;
end
