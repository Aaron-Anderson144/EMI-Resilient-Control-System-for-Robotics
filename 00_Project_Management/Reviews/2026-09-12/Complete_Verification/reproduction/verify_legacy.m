project='C:/Users/adand/OneDrive/Desktop/Projects/EMI-Resilient Control System for Robotics/03_MATLAB';
boundaryWork='C:/Users/adand/Documents/Codex/2026-09-11/let/work/measurement_boundary';
run(fullfile(project,'startup_project.m'));
assert(strcmp(which('phase3_loop_step'),fullfile(project,'functions','phase3_loop_step.m')));
before=load(fullfile(boundaryWork,'legacy_before.mat'));p=before.p;cfg=before.cfg;cases=before.cases;
record=0;first20Checks=0;fullChecks=0;stateChecks=0;reasonChecks=0;
for j=1:numel(cases)
 s=cases(j);clean=phase3_matched_clean_scenario(s,p);
 for isClean=[false true]
  scenario=s;if isClean,scenario=clean;end
  profiles=phase3_fault_profiles(p,scenario);
  for protection=[false true]
   r=simulate_phase3_actuator(p,scenario,protection,cfg,profiles);record=record+1;
   old=before.records{record};name=scenario.name+"_protected_"+string(protection);
   assert(name==before.names(record));
   assert(isequaln(r.loopValues(:,1:20),old.loopValues(:,1:20)), ...
    'EMIProject:LegacyFirst20Changed','First 20 channels changed for %s',name);first20Checks=first20Checks+1;
   assert(isequaln(r.loopValues,old.loopValues), ...
    'EMIProject:LegacyChannelsChanged','Any logged channel changed for %s',name);fullChecks=fullChecks+1;
   assert(isequaln(r.state,old.state),'EMIProject:LegacyPlantChanged','Plant changed for %s',name);stateChecks=stateChecks+1;
   assert(isequaln(r.timeSeries.gateReason,old.gateReason)&& ...
    isequaln(r.timeSeries.transitionReason,old.transitionReason)&& ...
    isequaln(r.timeSeries.reacquisitionReason,old.reacquisitionReason), ...
    'EMIProject:LegacyReasonChanged','Reason changed for %s',name);reasonChecks=reasonChecks+1;
  end
 end
 fprintf('Verified exact legacy fixture %d/%d\n',j,numel(cases));
end
summary=struct('records',record,'samplesPerRecord',3001,'first20ExactRecords',first20Checks, ...
 'all31ChannelsExactRecords',fullChecks,'plantExactRecords',stateChecks,'reasonExactRecords',reasonChecks, ...
 'prechangeLoopSHA256','0c79081c2172cdb493c97255dee3d059481780b9fbb131e0bd093748de3bb94c', ...
 'comparison','isequaln: exact, matching NaN masks, no tolerance','passed',true);
fid=fopen('C:/Users/adand/Documents/Codex/2026-09-12/a/outputs/Project_Verification_2026-09-12/legacy_equivalence.json','w');fprintf(fid,'%s',jsonencode(summary,'PrettyPrint',true));fclose(fid);
disp(summary);fprintf('EXACT_LEGACY_COMPLETE\n');
