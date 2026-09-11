function fixture=fourway_fixture(id,armId,exposed,closure_s)
%FOURWAY_FIXTURE Materialize PLAN-V1 without changing historical defaults.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
c=jsondecode(fileread(fullfile(root,'04_EMI_Models','four_way_emi_configuration.json')));
matrix=readtable(fullfile(root,'04_EMI_Models','four_way_emi_fixtures.csv'),'TextType','string');
if nargin<4,closure_s=c.source.synthetic_return_s;end
row=matrix(matrix.id==string(id),:);
assert(height(row)==1,'EMIProject:FourWayFixture','Unknown or ambiguous frozen fixture.');
arm=c.arms(string({c.arms.id})==string(armId));
assert(isscalar(arm),'EMIProject:FourWayArm','Unknown frozen arm.');
assert(islogical(exposed)&&isscalar(exposed),'EMIProject:FourWayExposure','Exposure must be logical.');
assert(any(closure_s==c.closure_diagnostics.return_duration_s),'EMIProject:FourWayClosure','Return duration is not declared.');
p=actuator_parameters();p.simulation.stopTime_s=c.task.stop_time_s;
s=phase3_scenario(string(id)+"_"+string(armId),p);
s.referenceTimes_s=c.task.request_time_s(:);
s.referenceValues_rad=deg2rad(row.task_sign*c.task.positive_request_deg(:));
s.loadTorque_Nm=c.task.load_Nm;s.assumedLoadTorque_Nm=c.task.load_Nm;
s.resetRequestTime_s=c.task.reset_s;
cfg=phase3_configuration(p);assert(~cfg.reacquisitionEnabled);
options=struct('maxVelocity_rad_s',c.task.governor_velocity_rad_s, ...
 'maxAcceleration_rad_s2',c.task.governor_acceleration_rad_s2);
profiles=phase3_motion_profiles(p,s,cfg,options);
assert(~any(profiles.sourceFault)&&all(profiles.communication.sampleReceived)&& ...
 isequal(profiles.communication.acceptedSourceIndex,(1:numel(profiles.time_s))'), ...
 'EMIProject:FourWayIsolation','Unrelated fault or packet scheduling entered PLAN-V1.');
fixture=struct('id',string(id),'partition',row.partition,'arm',string(armId), ...
 'Ccp_pF',row.Ccp_pF,'Ccn_pF',row.Ccn_pF,'Cdiff_pF',arm.Cdiff_pF, ...
 'task_sign',row.task_sign,'phase_s',row.phase_ns*1e-9,'exposed',exposed, ...
 'closure_s',closure_s,'design',c,'root',string(root), ...
 'run',struct('params',p,'scenario',s,'protectionEnabled',logical(arm.protection_enabled), ...
 'configuration',cfg,'profiles',profiles));
end
