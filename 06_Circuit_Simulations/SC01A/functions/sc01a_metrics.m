function [m,events] = sc01a_metrics(r,baseline,p)
%SC01A_METRICS Loaded input waveforms and interpolated exposure diagnostics.
arguments
    r (1,1) struct
    baseline (1,1) struct
    p (1,1) struct
end
assert(isequal(r.time_s,baseline.time_s),'SC01A:MetricTimeMismatch','Metric time grids must match.');
t=r.time_s;
vd=r.positive_V-r.negative_V;
vcm=(r.positive_V+r.negative_V)/2;
dm=vd-(baseline.positive_V-baseline.negative_V);
cm=vcm-(baseline.positive_V+baseline.negative_V)/2;
ground=r.ground_V-baseline.ground_V;
[noiseEvents,noiseExposure,noiseGrazing]=sc01a_threshold_events(t,dm, ...
    p.diagnostics.noiseThreshold_V,p.verification.voltageFloor_V);
[receiverEvents,outsideBand,receiverGrazing]=sc01a_threshold_events(t,vd, ...
    p.diagnostics.receiverThreshold_V,p.verification.voltageFloor_V);
noiseEvents.Channel=repmat("noise_delta",height(noiseEvents),1);
receiverEvents.Channel=repmat("total_receiver_input",height(receiverEvents),1);
events=[noiseEvents;receiverEvents];
m.PeakDM_V=max(abs(dm));
m.PeakCM_V=max(abs(cm));
m.PeakGround_V=max(abs(ground));
m.AbsAreaDM_Vs=trapz(t,abs(dm));
m.AbsAreaCM_Vs=trapz(t,abs(cm));
m.NoiseExposure_s=noiseExposure;
m.ReceiverBand_s=max(0,t(end)-t(1)-outsideBand);
m.NoiseCrossings=height(noiseEvents);
m.ReceiverCrossings=height(receiverEvents);
m.Grazing=noiseGrazing || receiverGrazing;
m.MinimumTotalDifferential_V=min(vd);
m.MaximumTotalDifferential_V=max(vd);
m.MaximumTotalCommonMode_V=max(abs(vcm));
m.CommonModeLimitExceeded=any(abs(vcm)>p.diagnostics.commonModeLimit_V);
end
