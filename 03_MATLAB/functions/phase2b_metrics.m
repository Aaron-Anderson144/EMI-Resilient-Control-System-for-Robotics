function [metrics, detail] = phase2b_metrics(faultResult, baselineResult, params)
%PHASE2B_METRICS Compute matched-baseline pre/active/post metrics.

arguments
    faultResult (1,1) struct
    baselineResult (1,1) struct
    params (1,1) struct
end

assert(isequal(faultResult.time_s, baselineResult.time_s), ...
    "Phase 2B and baseline time vectors must match.");

t = faultResult.time_s;
scenario = faultResult.scenario;
deltaPosition_rad = faultResult.position_rad - baselineResult.position_rad;
deltaCommand_V = faultResult.command_V - baselineResult.command_V;
deltaMeasurement_rad = faultResult.receivedMeasurement_rad - ...
    baselineResult.receivedMeasurement_rad;

if isnan(scenario.analysisStartTime_s)
    preMask = true(size(t));
    activeMask = false(size(t));
    postMask = false(size(t));
else
    preMask = t < scenario.analysisStartTime_s;
    activeMask = t >= scenario.analysisStartTime_s & ...
        t < scenario.analysisStopTime_s;
    postMask = t >= scenario.analysisStopTime_s;
end

metrics.scenario = scenario.name;
metrics.preMaxAbsPositionDelta_rad = localMaxAbs(deltaPosition_rad(preMask));
metrics.activePositionDeltaRMSE_rad = localRms(deltaPosition_rad(activeMask));
metrics.activeMaxAbsPositionDelta_rad = localMaxAbs(deltaPosition_rad(activeMask));
metrics.activeMaxAbsMeasurementDelta_rad = localMaxAbs(deltaMeasurement_rad(activeMask));
metrics.activeMaxAbsCommandDelta_V = localMaxAbs(deltaCommand_V(activeMask));
metrics.postMaxAbsPositionDelta_rad = localMaxAbs(deltaPosition_rad(postMask));
metrics.packetDropFraction = localFraction( ...
    faultResult.communication.packetDropped, ...
    faultResult.communication.channelEnabled);
metrics.missingUpdateFraction = localFraction( ...
    faultResult.communication.heldLast, ...
    faultResult.communication.channelEnabled);

channelMask = faultResult.communication.channelEnabled;
if any(channelMask)
    metrics.meanMeasurementAge_samples = mean( ...
        faultResult.communication.measurementAge_samples(channelMask));
    metrics.maxMeasurementAge_samples = max( ...
        faultResult.communication.measurementAge_samples(channelMask));
else
    metrics.meanMeasurementAge_samples = 0;
    metrics.maxMeasurementAge_samples = 0;
end

[metrics.recoveryTime_s, metrics.recoveryCensored] = localRecoveryTime( ...
    t, deltaPosition_rad, scenario.analysisStopTime_s, ...
    params.phase2b.metrics.recoveryThreshold_rad, ...
    params.phase2b.metrics.recoveryDwellSamples);

detail.deltaPosition_rad = deltaPosition_rad;
detail.deltaCommand_V = deltaCommand_V;
detail.deltaMeasurement_rad = deltaMeasurement_rad;
detail.preMask = preMask;
detail.activeMask = activeMask;
detail.postMask = postMask;
end

function value = localRms(x)
if isempty(x)
    value = NaN;
else
    value = sqrt(mean(x.^2));
end
end

function value = localMaxAbs(x)
if isempty(x)
    value = NaN;
else
    value = max(abs(x));
end
end

function value = localFraction(eventMask, populationMask)
if any(populationMask)
    value = nnz(eventMask & populationMask) / nnz(populationMask);
else
    value = 0;
end
end

function [recoveryTime_s, censored] = localRecoveryTime( ...
        time_s, delta_rad, stopTime_s, threshold_rad, dwellSamples)
if isnan(stopTime_s)
    recoveryTime_s = NaN;
    censored = false;
    return
end

startIndex = find(time_s >= stopTime_s, 1, "first");
recoveryTime_s = NaN;
censored = true;
if isempty(startIndex)
    return
end

within = abs(delta_rad) <= threshold_rad;
lastStart = numel(time_s) - dwellSamples + 1;
for k = startIndex:max(startIndex, lastStart)
    if k + dwellSamples - 1 > numel(time_s)
        break
    end
    if all(within(k:k + dwellSamples - 1))
        recoveryTime_s = time_s(k) - stopTime_s;
        censored = false;
        return
    end
end
end
