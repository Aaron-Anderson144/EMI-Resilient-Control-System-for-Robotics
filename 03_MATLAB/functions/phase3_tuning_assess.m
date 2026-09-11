function [summary,comparison]=phase3_tuning_assess(candidate,historical,criteria)
%PHASE3_TUNING_ASSESS Paired frozen-window comparison with transparent gates.
if nargin<3,criteria=phase3_tuning_criteria();end
validateCriteria(criteria);
validateMetrics(candidate);validateMetrics(historical);
assert(istable(candidate)&&istable(historical)&&height(candidate)==height(historical)&& ...
 height(candidate)>0&&isequal(candidate.Fixture,historical.Fixture)&& ...
 isequal(candidate.WindowStart_s,historical.WindowStart_s)&&isequal(candidate.WindowStop_s,historical.WindowStop_s)&& ...
 isequal(candidate.Partition,historical.Partition)&&isequal(candidate.ExpectClean,historical.ExpectClean)&& ...
 isequal(candidate.WindowSamples,historical.WindowSamples), ...
 'EMIProject:TuningPairMismatch','Policies must use identical ordered fixtures and calendar windows.');
c=criteria;a=candidate;b=historical;
comparison=table(a.Fixture,'VariableNames',{'Fixture'});
comparison.InvariantsPass=a.InvariantsPass&b.InvariantsPass;
comparison.TrackingPass=a.WindowTrackingRMSE_deg<=max(b.WindowTrackingRMSE_deg*(1+c.rmseRelativeAllowance),b.WindowTrackingRMSE_deg+c.rmseAbsoluteAllowance_deg)+1e-10;
comparison.DisturbancePass=a.WindowDisturbanceRMSE_deg<=max(b.WindowDisturbanceRMSE_deg*(1+c.rmseRelativeAllowance),b.WindowDisturbanceRMSE_deg+c.rmseAbsoluteAllowance_deg)+1e-10;
comparison.PeakErrorPass=a.WindowPeakError_deg<=max(b.WindowPeakError_deg*(1+c.peakErrorRelativeAllowance),b.WindowPeakError_deg+c.peakErrorAbsoluteAllowance_deg)+1e-10;
comparison.WindowCurrentPass=a.WindowPeakCurrent_A<=max(b.WindowPeakCurrent_A*(1+c.currentRelativeAllowance),b.WindowPeakCurrent_A+c.currentAbsoluteAllowance_A)+1e-10;
comparison.FullCurrentPass=a.FullPeakCurrent_A<=max(b.FullPeakCurrent_A*(1+c.currentRelativeAllowance),b.FullPeakCurrent_A+c.currentAbsoluteAllowance_A)+1e-10;
comparison.FinalErrorPass=a.FinalTrackingError_deg<=max(b.FinalTrackingError_deg*(1+c.finalErrorRelativeAllowance),b.FinalTrackingError_deg+c.finalErrorAbsoluteAllowance_deg)+1e-10;
comparison.AlarmResponsePass=isnan(b.FirstAlarm_s)|(~isnan(a.FirstAlarm_s)&a.FirstAlarm_s<=b.FirstAlarm_s+c.alarmDelayAllowance_s+1e-12);
comparison.RecoveryPass=~b.RecoveryConfirmed|a.RecoveryConfirmed;
comparison.FinalModePass=b.FinalMode~=0|a.FinalMode==0;
comparison.StopDurationPass=(b.SafeStopDuration_s>0|a.SafeStopDuration_s==0)& ...
 a.SafeStopDuration_s<=b.SafeStopDuration_s+c.extraStopAllowance_s+1e-12;
comparison.Passed=all(comparison{:,2:end},2);
denominator=max(b.WindowTrackingRMSE_deg,c.normalizationFloor_deg);
score=mean(a.WindowTrackingRMSE_deg./denominator);
baselineScore=mean(b.WindowTrackingRMSE_deg./denominator);
improvement=0;if baselineScore>0,improvement=1-score/baselineScore;end
summary=struct('Policy',a.Policy(1),'FixtureCount',height(a),'PassedCases',nnz(comparison.Passed), ...
 'AllComparativeGatesPass',all(comparison.Passed),'TrackingScore',score, ...
 'HistoricalTrackingScore',baselineScore,'AggregateImprovementFraction',improvement, ...
 'MeaningfulImprovement',improvement>=c.requiredAggregateImprovement-1e-12);
summary.Eligible=summary.AllComparativeGatesPass&&summary.MeaningfulImprovement;
end

function validateMetrics(t)
id='EMIProject:InvalidTuningMetrics';
flags=["ExpectClean","RecoveryConfirmed","FiniteStateAndCommand","CommandBoundsPass", ...
 "StoppedCommandZero","CleanFalseAlarmPass","CommitsRemainStopped","ReleaseEvidencePass","InvariantsPass"];
required={'Fixture','Partition','Policy','ExpectClean','WindowStart_s','WindowStop_s','WindowSamples', ...
 'InvariantsPass','WindowTrackingRMSE_deg','WindowDisturbanceRMSE_deg','WindowPeakError_deg', ...
 'WindowPeakCurrent_A','FullPeakCurrent_A','FinalTrackingError_deg','FirstAlarm_s','AlarmSamples', ...
 'RecoveryConfirmed','FirstConfirmedNormal_s','FinalMode','SafeStopDuration_s'};
assert(istable(t)&&height(t)>0&&all(ismember(required,t.Properties.VariableNames)),id, ...
 'Comparison requires complete nonempty tuning metric tables.');
assert(numel(unique(string(t.Policy)))==1&&all(strlength(string(t.Policy))>0),id, ...
 'Each metric table must contain one identified policy.');
for name=string(t.Properties.VariableNames)
 value=t.(name);
 if any(name==["Fixture","Partition","Policy"])
  assert((isstring(value)||iscellstr(value))&&all(~ismissing(string(value)))&& ...
   all(strlength(string(value))>0),id,'Metric identifiers must be nonempty text.');
 else
  assert((isnumeric(value)||islogical(value))&&isreal(value)&&iscolumn(value),id, ...
   'Numeric and flag metrics must be real columns.');
  if any(name==["FirstAlarm_s","FirstConfirmedNormal_s"])
   assert(all(isnan(value)|(isfinite(value)&value>=0)),id,'Only absent event times may be NaN.');
  else
   assert(all(isfinite(value)&value>=0),id,'Metrics must be finite and nonnegative.');
  end
  if any(name==flags)
   assert(all(value==0|value==1),id,'Flag metrics must contain only zero or one.');
  end
 end
end

assert(all((t.AlarmSamples==0)==isnan(t.FirstAlarm_s))&& ...
 all((t.RecoveryConfirmed==0)==isnan(t.FirstConfirmedNormal_s)),id, ...
 'Event times must agree with recorded alarm/recovery evidence.');
assert(all(t.WindowStop_s>t.WindowStart_s&t.WindowSamples>=2& ...
 t.WindowSamples==fix(t.WindowSamples)&t.FinalMode<=4&t.FinalMode==fix(t.FinalMode)),id, ...
 'Window counts and mode IDs are invalid.');
end

function validateCriteria(c)
id='EMIProject:InvalidTuningCriteria';
relative=["rmseRelativeAllowance","peakErrorRelativeAllowance", ...
 "currentRelativeAllowance","finalErrorRelativeAllowance"];
absolute=["rmseAbsoluteAllowance_deg","peakErrorAbsoluteAllowance_deg", ...
 "currentAbsoluteAllowance_A","finalErrorAbsoluteAllowance_deg", ...
 "extraStopAllowance_s","alarmDelayAllowance_s"];
required=[relative,absolute,"normalizationFloor_deg","requiredAggregateImprovement"];
assert(isstruct(c)&&isscalar(c)&&all(isfield(c,required)),id, ...
 'Comparison criteria must be a complete scalar structure.');
for name=required
 value=c.(name);
 assert(isfloat(value)&&isreal(value)&&isscalar(value)&&isfinite(value),id, ...
  'Criteria must contain finite real floating-point scalars.');
end
for name=relative
 assert(c.(name)>=0&&c.(name)<=1,id,'Relative allowances must lie in [0,1].');
end
for name=absolute
 assert(c.(name)>=0,id,'Absolute and timing allowances must be nonnegative.');
end
assert(c.normalizationFloor_deg>0,id,'The normalization floor must be positive.');
assert(c.requiredAggregateImprovement>0&&c.requiredAggregateImprovement<=1,id, ...
 'Required aggregate improvement must lie in (0,1].');
end
