function result=simulate_fourway_actuator(fixture)
%SIMULATE_FOURWAY_ACTUATOR Plant -> A/B circuit/decoder -> sampled controller.
% Only current held input is used to generate the next plant interval. The
% own-trajectory clean shadow is evaluated after the closed loop has ended.
run=fixture.run;loop=phase3_loop_initialize(run);n=numel(run.profiles.time_s);
t=run.profiles.time_s;Ts=run.params.control.sampleTime_s;delta=2*pi/4096;
sensor=fourway_receiver_init(fixture.Ccp_pF,fixture.Ccn_pF,fixture.Cdiff_pF, ...
 fixture.phase_s,fixture.exposed,fixture.closure_s);
[sensor,packet]=fourway_receiver_advance(sensor,0,zeros(0,3));
[~,names]=phase3_logged_values();values=zeros(n,numel(names));states=zeros(n,3);
counts=zeros(n,1);ideal=zeros(n,1);domain=false(n,1);intended=cell(n-1,1);
slew=false(n,1);amplitude=false(n,1);rebased=false(n,1);intervalStats=cell(n-1,1);
reasons=strings(n,1);transitions=reasons;reacquisitionReasons=reasons;
x=run.scenario.initialPlantState;q=0;
for k=1:n
 states(k,:)=x';counts(k)=packet.count;ideal(k)=q;domain(k)=packet.domain_failed;
 primary=struct('measurement_rad',packet.count_rad,'sourceIndex',k,'sampleReceived',true);
 [loop,sample]=phase3_loop_step(loop,[],primary);
 values(k,:)=phase3_logged_values(sample);reasons(k)=sample.gateReason;
 slew(k)=sample.commandSlewLimited;amplitude(k)=sample.commandAmplitudeLimited;rebased(k)=sample.controllerRebased;
 transitions(k)=sample.transitionReason;reacquisitionReasons(k)=sample.reacquisitionReason;
 if k<n
  [events,x,intervalStats{k}]=fourway_plant_events(x,sample.command_V,run.profiles.loadTorque_Nm(k),Ts,run.params,q);
  if ~isempty(events),q=events.newCount(end);end
  ab=[t(k)+events.time_s,events.A,events.B];intended{k}=ab;
  [sensor,packet]=fourway_receiver_advance(sensor,t(k+1),ab);
 end
end
trace=[table(t,states(:,1),states(:,2),states(:,3), ...
 'VariableNames',{'time_s','position_rad','velocity_rad_s','current_A'}),array2table(values,'VariableNames',names)];
trace.gateReason=reasons;trace.transitionReason=transitions;trace.reacquisitionReason=reacquisitionReasons;
trace.requestedReference_rad=run.profiles.requestedReference_rad;
trace.idealCount=ideal;trace.decodedCount=counts;trace.idealMinusDecodedCount=ideal-counts;
trace.continuousQuantizationError_rad=states(:,1)-ideal*delta;
trace.receiverDomainFailed=domain;
trace.commandSlewLimited=slew;trace.commandAmplitudeLimited=amplitude;trace.controllerRebased=rebased;
shadow=fourway_receiver_init(fixture.Ccp_pF,fixture.Ccn_pF,fixture.Cdiff_pF,fixture.phase_s,false,fixture.closure_s);
shadowCounts=zeros(n,1);
[shadow,~]=fourway_receiver_advance(shadow,0,zeros(0,3));
for k=2:n
 [shadow,shadowPacket]=fourway_receiver_advance(shadow,t(k),intended{k-1});
 shadowCounts(k)=shadowPacket.count;
end
trace.shadowDecodedCount=shadowCounts;trace.emiCountError=counts-shadowCounts;
result=struct('fixture',fixture,'run',loop.run,'time_s',t,'state',states,'loopValues',values, ...
 'timeSeries',trace,'intendedTransitions',vertcat(intended{:}), ...
 'receiver',fourway_receiver_export(sensor),'shadow',fourway_receiver_export(shadow), ...
 'intervalStats',struct2table(vertcat(intervalStats{:})));
result.decoderAudit=fourway_decoder_audit(result);
end
