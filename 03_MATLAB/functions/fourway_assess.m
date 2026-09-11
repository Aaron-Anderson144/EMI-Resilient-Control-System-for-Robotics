function assessment=fourway_assess(metrics)
%FOURWAY_ASSESS Frozen shared-denominator and rescued-failure gates.
m=metrics(metrics.Partition=="evaluation",:);b=m(m.Arm=="BASELINE",:);c=m(m.Arm=="COMBINED",:);
[~,i]=sort(b.Fixture);b=b(i,:);[~,i]=sort(c.Fixture);c=c(i,:);
assert(height(m)==48&&height(b)==12&&isequal(b.Fixture,c.Fixture), ...
 'EMIProject:FourWayAssessment','Assessment requires all 12 complete four-arm evaluation fixtures.');
fixtures=unique(m.Fixture);
assert(numel(fixtures)==12&&numel(unique(b.Fixture))==12, ...
 'EMIProject:FourWayAssessment','Evaluation fixture IDs must be distinct.');
for fixture=fixtures'
 arms=sort(m.Arm(m.Fixture==fixture));
 assert(isequal(arms,sort(["BASELINE";"EM_ONLY";"SW_ONLY";"COMBINED"])), ...
  'EMIProject:FourWayAssessment','Every fixture must contain each declared arm exactly once.');
end
d=max(b.WindowPairedRMSE_deg,.25);
assessment=struct('design_id',"FOUR-WAY-EMI-PLAN-V1",'evaluation_fixtures',12, ...
 'all_execution_clean_guards_pass',all(m.ExecutionGuardPass), ...
 'baseline_normalized_mean',mean(b.WindowPairedRMSE_deg./d), ...
 'combined_normalized_mean',mean(c.WindowPairedRMSE_deg./d), ...
 'baseline_raw_mean_RMSE_deg',mean(b.WindowPairedRMSE_deg), ...
 'combined_raw_mean_RMSE_deg',mean(c.WindowPairedRMSE_deg));
assessment.aggregate_gate=assessment.combined_normalized_mean<=.9*assessment.baseline_normalized_mean;
assessment.per_fixture_rmse_gate=all(c.WindowPairedRMSE_deg<=b.WindowPairedRMSE_deg+max(.1*b.WindowPairedRMSE_deg,.25));
assessment.per_fixture_peak_gate=all(c.WindowPairedPeak_deg<=b.WindowPairedPeak_deg+max(.1*b.WindowPairedPeak_deg,.25));
assessment.current_gate=all(c.PeakCurrent_A<=b.PeakCurrent_A+max(.1*b.PeakCurrent_A,.05));
assessment.rescued_failures=sum(~b.TaskSuccess&c.TaskSuccess);
assessment.rescued_failure_gate=assessment.rescued_failures>=1;
assessment.combined_benefit_demonstrated=assessment.all_execution_clean_guards_pass&& ...
 assessment.aggregate_gate&&assessment.per_fixture_rmse_gate&&assessment.per_fixture_peak_gate&& ...
 assessment.current_gate&&assessment.rescued_failure_gate;
assessment.physical_validation=false;
assessment.conclusion="not demonstrated at the frozen exposures";
if assessment.combined_benefit_demonstrated,assessment.conclusion="supported within the frozen conditional numerical fixtures";end
end
