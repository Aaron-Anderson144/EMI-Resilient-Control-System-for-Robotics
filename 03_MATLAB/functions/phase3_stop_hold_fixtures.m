function fixtures=phase3_stop_hold_fixtures(design,matlabRoot)
%PHASE3_STOP_HOLD_FIXTURES Frozen mechanisms, signs, events and failure cases.
base=struct('id','record_stop','x0',[0 0 0],'duration_s',.6, ...
 'loadTimes_s',0,'loadValues_Nm',.008,'preEngaged',false, ...
 'engagementDelay_s',design.nominalEngagementDelay_s,'ramp_s',design.capacityRamp_s, ...
 'releaseTime_s',-1,'failedEngagement',false,'failedRelease',false, ...
 'expectedMechanicalHold',true,'purpose','nominal stop');
fixtures=repmat(base,20,1);
source=fullfile(matlabRoot,'results','development','phase3_motion_20260910_144242', ...
 'campaign','evaluation','GOVERNED','fault_loaded_supply_interruption','response.csv');
r=readtable(source);k=find(abs(r.time_s-.873)<1e-12);
assert(isscalar(k) && r.command_V(k)==0 && r.mode(k)==4,'Verified stop entry is required.');
fixtures(1).x0=[r.position_rad(k),r.velocity_rad_s(k),r.current_A(k)];
fixtures(1).duration_s=1.126;fixtures(1).purpose='Replay previous loaded stop from 0.873 through 1.999 seconds';
fixtures(2)=fixtures(1);fixtures(2).id='record_stop_mirror';fixtures(2).x0=-fixtures(1).x0;fixtures(2).loadValues_Nm=-.008;
ids={'moving_positive_aiding','moving_positive_opposing','moving_negative_aiding','moving_negative_opposing'};
speeds=[8 8 -8 -8];loads=[-.008 .008 .008 -.008];
for j=1:4,fixtures(j+2).id=ids{j};fixtures(j+2).x0=[0 speeds(j) 0];fixtures(j+2).loadValues_Nm=loads(j);end
ids={'engaged_positive_load','engaged_negative_load','engaged_load_reversal','below_capacity','at_capacity','above_capacity','overload_recapture','current_breakaway'};
for j=1:8,fixtures(j+6).id=ids{j};fixtures(j+6).preEngaged=true;end
fixtures(8).loadValues_Nm=-.008;
fixtures(9).duration_s=.7;fixtures(9).loadTimes_s=[0 .3];fixtures(9).loadValues_Nm=[.008 -.008];
fixtures(10).loadValues_Nm=.0297;fixtures(11).loadValues_Nm=.030;
fixtures(12).loadValues_Nm=.0303;fixtures(12).expectedMechanicalHold=false;fixtures(12).purpose='Finite capacity must allow overload slip';
fixtures(13).duration_s=1;fixtures(13).loadTimes_s=[0 .3 .6];fixtures(13).loadValues_Nm=[.008 .039 .008];
fixtures(14).x0=[0 0 .6];fixtures(14).purpose='Stored magnetic energy can cause initial breakaway';
fixtures(15).id='delayed_engagement';fixtures(15).engagementDelay_s=.05;fixtures(15).x0=[0 8 0];
fixtures(16).id='instant_capacity';fixtures(16).preEngaged=true;fixtures(16).x0=[0 8 0];
fixtures(17).id='release_under_load';fixtures(17).preEngaged=true;fixtures(17).releaseTime_s=.3;fixtures(17).duration_s=.7;fixtures(17).expectedMechanicalHold=false;fixtures(17).purpose='Release at zero drive must permit renewed backdrive';
fixtures(18).id='failed_engagement';fixtures(18).failedEngagement=true;fixtures(18).expectedMechanicalHold=false;fixtures(18).purpose='Missing capacity is expected failure to hold';
fixtures(19).id='failed_release';fixtures(19).preEngaged=true;fixtures(19).releaseTime_s=.3;fixtures(19).failedRelease=true;fixtures(19).purpose='Brake remains held: expected failed release, not a successful restart';
fixtures(20).id='no_load_moving';fixtures(20).x0=[0 8 0];fixtures(20).loadValues_Nm=0;fixtures(20).duration_s=.8;
for j=1:numel(fixtures)
 f=fixtures(j);knots=[f.duration_s,f.loadTimes_s,f.engagementDelay_s,f.engagementDelay_s+f.ramp_s];
 if f.releaseTime_s>=0,knots=[knots,f.releaseTime_s,f.releaseTime_s+f.ramp_s];end
 for h=design.steps_s,assert(all(abs(knots/h-round(knots/h))<1e-8),'Events must align to all integration grids.');end
end
end
