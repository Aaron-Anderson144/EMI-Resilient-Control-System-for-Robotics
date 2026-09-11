function profile = encoder_fault_profile(time_s, params, scenario)
%ENCODER_FAULT_PROFILE Generate deterministic additive and dropout faults.

validate_parameters(params);
validate_encoder_scenario(scenario, params);
validate_profile_time(time_s, params);
time_s = time_s(:);

if isempty(time_s) || any(~isfinite(time_s)) || ...
        any(diff(time_s) <= 0)
    error('EMIProject:InvalidTimeVector', ...
        'The time vector must be finite and strictly increasing.');
end

sampleCount = numel(time_s);
profile.gaussian_rad = zeros(sampleCount, 1);
profile.sinusoidal_rad = zeros(sampleCount, 1);
profile.countJump_rad = zeros(sampleCount, 1);
profile.dropoutActive = false(sampleCount, 1);

if scenario.gaussian.enabled
    gaussianMask = time_s >= scenario.gaussian.startTime_s & ...
        time_s < scenario.gaussian.stopTime_s;
    originalRandomState = rng;
    restoreRandomState = onCleanup(@() rng(originalRandomState));
    rng(scenario.gaussian.randomSeed, 'twister');
    generatedNoise = scenario.gaussian.standardDeviation_rad .* ...
        randn(sampleCount, 1);
    profile.gaussian_rad(gaussianMask) = generatedNoise(gaussianMask);
    clear restoreRandomState
end

if scenario.sinusoid.enabled
    sinusoidMask = time_s >= scenario.sinusoid.startTime_s & ...
        time_s < scenario.sinusoid.stopTime_s;
    sinusoid = scenario.sinusoid.amplitude_rad .* sin( ...
        2 * pi * scenario.sinusoid.frequency_Hz .* time_s + ...
        scenario.sinusoid.phase_rad);
    profile.sinusoidal_rad(sinusoidMask) = sinusoid(sinusoidMask);
end

if scenario.countJump.enabled
    [~, jumpIndex] = min(abs(time_s - scenario.countJump.time_s));
    radiansPerCount = 2 * pi / params.sensor.encoderCountsPerRevolution;
    profile.countJump_rad(jumpIndex) = ...
        scenario.countJump.magnitude_counts * radiansPerCount;
end

if scenario.dropout.enabled
    profile.dropoutActive = ...
        time_s >= scenario.dropout.startTime_s & ...
        time_s < scenario.dropout.stopTime_s;
end

profile.additive_rad = profile.gaussian_rad + ...
    profile.sinusoidal_rad + profile.countJump_rad;
profile.additiveFaultActive = ...
    (profile.gaussian_rad ~= 0) | ...
    (profile.sinusoidal_rad ~= 0) | ...
    (profile.countJump_rad ~= 0);
profile.anyFaultActive = ...
    profile.additiveFaultActive | profile.dropoutActive;
profile.scenarioName = scenario.name;
end
