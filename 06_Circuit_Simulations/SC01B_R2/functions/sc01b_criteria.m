function c=sc01b_criteria()
%SC01B_CRITERIA Frozen numerical verification gates, not physical acceptance.
c.version="SC01B-R2-numerical-gates-v2";
c.caseNames=["nominal","holdout_bus18","holdout_load4ohm", ...
    "holdout_gate47","holdout_bus30_load16_gate10"];
c.nativeSteps_s=[0.5 0.25 0.125]*1e-9;
c.spiceSteps_s=[0.25 0.125]*1e-9;
c.relativeWaveformTolerance=0.01;
c.voltageAbsoluteTolerance_V=0.01;
c.currentAbsoluteTolerance_A=0.01;
c.relativeMetricTolerance=0.01;
c.energyAbsoluteTolerance_J=1e-9;
c.eventTimeTolerance_s=1e-9;
c.balanceRelativeTolerance=1e-3;
c.balanceAbsoluteTolerance_J=1e-10;
c.consistencyCases=["nominal","holdout_bus30_load16_gate10"];
c.nativeChannelOverlapTolerance_s=0;
c.provenance="R2 retains the original five operating points, waveform/energy/timing tolerances and event windows. Driver settings were selected using these cases; the historical holdout names are not blinded validation. Full execution and zero native channel overlap above the existing current floor are mandatory. Numerical integration refinements are recorded explicitly; no gate was relaxed.";
end
