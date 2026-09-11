function result=simulate_phase3_actuator(params,scenario,protectionEnabled,configuration,profiles)
%SIMULATE_PHASE3_ACTUATOR Causal closed loop with continuously evolving plant.
if nargin<3,protectionEnabled=true;end
if nargin<4,configuration=phase3_configuration(params);end
if nargin<5,profiles=phase3_fault_profiles(params,scenario);end
run=struct('params',params,'scenario',scenario,'protectionEnabled',logical(protectionEnabled), ...
 'configuration',configuration,'profiles',profiles);
loop=phase3_loop_initialize(run);run=loop.run;n=numel(profiles.time_s);
plant=ss(c2d(actuator_state_space(scenario.actualParameters),params.control.sampleTime_s,'zoh'));
[A,B,C,D]=ssdata(plant);
assert(all(D(:)==0),'EMIProject:Phase3PlantFeedthrough','Plant sensor must have no direct feedthrough.');
x=scenario.initialPlantState;
[~,names]=phase3_logged_values();values=zeros(n,numel(names));state=zeros(n,3);reasons=strings(n,1);transitions=strings(n,1);reacquisitionReasons=strings(n,1);
for k=1:n
 state(k,:)=x';[loop,sample]=phase3_loop_step(loop,C*x);
 values(k,:)=phase3_logged_values(sample);reasons(k)=sample.gateReason;transitions(k)=sample.transitionReason;
 reacquisitionReasons(k)=sample.reacquisitionReason;
 if k<n,x=A*x+B*[sample.command_V;profiles.loadTorque_Nm(k)];end
end
result.run=run;result.time_s=profiles.time_s;result.state=state;result.loopValues=values;
result.timeSeries=[table(result.time_s,state(:,1),state(:,2),state(:,3), ...
 'VariableNames',{'time_s','position_rad','velocity_rad_s','current_A'}),array2table(values,'VariableNames',names)];
result.timeSeries.gateReason=reasons;
result.timeSeries.transitionReason=transitions;
result.timeSeries.reacquisitionReason=reacquisitionReasons;
end
