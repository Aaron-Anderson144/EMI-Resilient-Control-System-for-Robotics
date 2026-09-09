function c=sc01b_criteria()
%SC01B_CRITERIA Frozen numerical verification gates, not physical acceptance.
c.version="SC01B-numerical-gates-v1";
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
c.provenance="Frozen before the five-case refinement campaign. Exploratory nominal solver selection and first SPICE screen preceded freezing. Holdouts are unfitted operating points, not blinded physical validation.";
end
