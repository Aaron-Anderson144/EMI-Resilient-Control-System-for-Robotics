function c=phase3_tuning_criteria()
%PHASE3_TUNING_CRITERIA Fixed provisional comparison gates, not safety limits.
c.id="PHASE3-TUNING-COMPARISON-V1";
c.rmseRelativeAllowance=.10;c.rmseAbsoluteAllowance_deg=.25;
c.peakErrorRelativeAllowance=.05;c.peakErrorAbsoluteAllowance_deg=.5;
c.currentRelativeAllowance=.10;c.currentAbsoluteAllowance_A=.05;
c.finalErrorRelativeAllowance=.10;c.finalErrorAbsoluteAllowance_deg=.5;
c.extraStopAllowance_s=.050;c.alarmDelayAllowance_s=.001;
c.normalizationFloor_deg=.25;c.requiredAggregateImprovement=.10;
c.assumptions="Predeclared comparative tolerances against historical policy; not hardware limits or calibrated statistical criteria. Evaluation cannot be used to retune the chosen policy.";
end
