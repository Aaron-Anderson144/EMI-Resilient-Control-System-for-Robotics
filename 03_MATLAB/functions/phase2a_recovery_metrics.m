function metrics = phase2a_recovery_metrics(time_s, deltaPosition_rad, faultEndTime_s, threshold_rad, dwellSamples)
%PHASE2A_RECOVERY_METRICS First complete post-fault threshold dwell.
% Semantics match phase2b_metrics: inclusive absolute threshold, start at
% t>=faultEnd, report the beginning of the first full qualifying sample run.
% N samples span (N-1)*Ts. Confirmation is the final sample in that dwell.
id = 'EMIProject:InvalidRecoveryInput';
assert(isnumeric(time_s) && isreal(time_s) && isvector(time_s) && ...
    isnumeric(deltaPosition_rad) && isreal(deltaPosition_rad) && isvector(deltaPosition_rad),id, ...
    'Time and position delta must be real numeric vectors.');
t = double(time_s(:));delta = double(deltaPosition_rad(:));
assert(numel(t)>=2 && numel(t)==numel(delta) && all(isfinite(t)) && ...
    all(isfinite(delta)) && all(diff(t)>0),id,'Finite equal-length ordered records are required.');
assert(isnumeric(faultEndTime_s) && isreal(faultEndTime_s) && isscalar(faultEndTime_s) && ...
    isfinite(faultEndTime_s) && faultEndTime_s>=t(1),id,'Fault end must be finite and not before the record.');
assert(isnumeric(threshold_rad) && isreal(threshold_rad) && isscalar(threshold_rad) && ...
    isfinite(threshold_rad) && threshold_rad>=0,id,'Threshold must be finite and nonnegative.');
assert(isnumeric(dwellSamples) && isreal(dwellSamples) && isscalar(dwellSamples) && ...
    isfinite(dwellSamples) && dwellSamples>=1 && dwellSamples<=flintmax && dwellSamples==fix(dwellSamples),id, ...
    'Dwell must be a positive integer sample count.');
faultEndTime_s=double(faultEndTime_s);threshold_rad=double(threshold_rad);
Ts = median(diff(t));
assert(isfinite(Ts) && Ts>0 && all(isfinite(diff(t))) && ...
    isfinite((double(dwellSamples)-1)*Ts),id,'Sample time and dwell span must remain finite.');
dwellSamples=double(dwellSamples);
assert(all(abs(diff(t)-Ts)<=max(1e-12,64*eps(max(abs(t))))),id, ...
    'Recovery requires a uniform sample grid.');
post = t>=faultEndTime_s;
within = abs(delta)<=threshold_rad;
metrics = struct('FaultEndTime_s',faultEndTime_s,'Threshold_rad',threshold_rad, ...
    'DwellSamples',dwellSamples,'SampleTime_s',Ts,'DwellSpan_s',(dwellSamples-1)*Ts, ...
    'PostSamples',nnz(post),'WithinThresholdPostSamples',nnz(within & post), ...
    'RecoveryCensored',true,'RecoveryStartSample',NaN,'RecoveryStartTime_s',NaN, ...
    'RecoveryConfirmationSample',NaN,'RecoveryConfirmationTime_s',NaN, ...
    'RecoveryDelay_s',NaN,'LastObservedTime_s',t(end), ...
    'ObservedPostDuration_s',max(0,t(end)-faultEndTime_s), ...
    'FinalAbsPositionDelta_rad',abs(delta(end)),'MaxAbsPostPositionDelta_rad',NaN, ...
    'CensorReason',"no_complete_in_threshold_dwell");
first = find(post,1);
if isempty(first)
    metrics.CensorReason = "no_post_fault_samples";
    return
end
metrics.MaxAbsPostPositionDelta_rad = max(abs(delta(post)));
if nnz(post)<dwellSamples
    metrics.CensorReason = "insufficient_post_fault_samples";
    return
end
for k=first:numel(t)-dwellSamples+1
    if all(within(k:k+dwellSamples-1))
        metrics.RecoveryCensored = false;
        metrics.RecoveryStartSample = k;
        metrics.RecoveryStartTime_s = t(k);
        metrics.RecoveryConfirmationSample = k+dwellSamples-1;
        metrics.RecoveryConfirmationTime_s = t(k+dwellSamples-1);
        metrics.RecoveryDelay_s = t(k)-faultEndTime_s;
        metrics.CensorReason = "observed";
        return
    end
end
end
