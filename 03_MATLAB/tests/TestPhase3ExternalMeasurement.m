classdef TestPhase3ExternalMeasurement < matlab.unittest.TestCase
 methods(Test)
  function decodedPacketHasOneBasedTimestamp(test)
   packet=localPacket(.125,1,true);
   [value,sensor,source,received]=phase3_external_measurement(packet,1,0);
   test.verifyEqual([value,sensor,source],[.125,.125,1]);test.verifyTrue(received);
   for protection=[false true]
    loop=localLoop(protection);[loop,sample]=phase3_loop_step(loop,[],localPacket(0,1,true));
    test.verifyEqual(sample.sourceIndex,1);test.verifyTrue(sample.credibleFresh);
    test.verifyEqual(loop.observer.sampleIndex,1);test.verifyEqual(loop.sampleIndex,1);
    [~,sample]=phase3_loop_step(loop,[],localPacket(0,2,true));
    test.verifyEqual(sample.sourceIndex,2);test.verifyTrue(sample.measurementAccepted);
    test.verifyEqual(sample.predictionAge_s,0);
   end
  end
  function noReceiptHoldsValueAndDoesNotEarnCredibility(test)
   loop=localLoop(true);[loop,~]=phase3_loop_step(loop,[],localPacket(.001,1,true));
   [~,sample]=phase3_loop_step(loop,[],localPacket(9,1,false));
   test.verifyEqual(sample.receivedMeasurement_rad,.001);test.verifyEqual(sample.sensorMeasurement_rad,9);
   test.verifyFalse(sample.measurementAccepted);test.verifyFalse(sample.credibleFresh);
   test.verifyEqual(sample.predictionAge_s,.001);
   [value,~,source,received]=phase3_external_measurement(localPacket(1,0,false),1,0);
   test.verifyEqual([value,source],[0,0]);test.verifyFalse(received);
  end
  function sameValueWithFreshTimestampIsFresh(test)
   loop=localLoop(true);
   for k=1:5
    [loop,sample]=phase3_loop_step(loop,[],localPacket(0,k,true));
    test.verifyTrue(sample.credibleFresh);test.verifyEqual(sample.sourceIndex,k);
   end
  end
  function nonincreasingReceiptReachesObserverRejection(test)
   loop=localLoop(true);[loop,~]=phase3_loop_step(loop,[],localPacket(0,1,true));
   [~,sample]=phase3_loop_step(loop,[],localPacket(.001,1,true));
   test.verifyEqual(sample.gateReason,"nonincreasing_timestamp");
   test.verifyFalse(sample.measurementAccepted);test.verifyTrue(sample.alarm);
  end
  function futureAndInvalidTimestampFailBeforeControl(test)
   loop=localLoop(true);
   for source=[-1,0,.5,2,Inf,NaN]
    test.verifyError(@()phase3_loop_step(loop,[],localPacket(0,source,true)), ...
     'EMIProject:InvalidExternalMeasurement');
   end
  end
  function externalMeasurementActuallyDrivesBothControllers(test)
   for protection=[false true]
    loop=localLoop(protection);
    [~,a]=phase3_loop_step(loop,[999;999;999],localPacket(0,1,true));
    [~,b]=phase3_loop_step(loop,[999;999;999],localPacket(.001,1,true));
    test.verifyNotEqual(a.command_V,b.command_V);test.verifyEqual(b.receivedMeasurement_rad,.001);
    test.verifyEqual(b.innovation_rad,.001);test.verifyTrue(b.measurementAccepted);
   end
  end
  function truePlantAndAllOfflineAnnotationsAreIgnored(test)
   for protection=[false true]
    a=localLoop(protection);b=a;
    b.run.scenario.name="offline changed";b.run.scenario.expectation="detect";
    b.run.profiles.sensorFaultAtSource(:)=true;b.run.profiles.sourceFault(:)=true;
    b.run.profiles.receiverFault(:)=true;b.run.profiles.exposure=true;
    b.run.profiles.idealCount=999;b.run.profiles.countError=-999;
    b.run.profiles.receiverDomainFailure=true;b.run.scenario.initialPlantState(:)=NaN;
    for k=1:5
     packet=localPacket(k*.0001,k,true);
     [a,sa]=phase3_loop_step(a,zeros(3,1),packet);
     [b,sb]=phase3_loop_step(b,[NaN;Inf;-1e100],packet);
     test.verifyEqual(sa,sb);test.verifyEqual(a.observer,b.observer);
     test.verifyEqual(a.controller,b.controller);test.verifyEqual(a.supervisor,b.supervisor);
     test.verifyEqual(a.legacyControllerState,b.legacyControllerState);
    end
   end
  end
  function externalPathNeverReadsLegacySensorOrCommunicationFixtures(test)
   for protection=[false true]
    a=localLoop(protection);b=a;
    b.run.profiles=rmfield(b.run.profiles,{'encoder','physical','bias_rad', ...
     'benignNoise_rad','nonfinite','communication'});
    for k=1:3
     packet=localPacket(.0001*k,k,true);
     [a,sa]=phase3_loop_step(a,[],packet);[b,sb]=phase3_loop_step(b,struct(),packet);
     test.verifyEqual(sa,sb);
    end
   end
  end
  function truthAndUnknownFieldsAreRejected(test)
   loop=localLoop(true);
   for field=["trueAngle_rad","idealCount","countError","faultMask","exposure", ...
     "receiverDomainFailure","offline","time_s"]
    packet=localPacket(0,1,true);packet.(field)=999;
    test.verifyError(@()phase3_loop_step(loop,[],packet),'EMIProject:InvalidExternalMeasurement');
   end
  end
  function independentTruthReferenceFailsClosed(test)
   for protection=[false true]
    loop=localLoop(protection);loop.run.configuration.reacquisitionEnabled=true;
    test.verifyError(@()phase3_loop_step(loop,[],localPacket(0,1,true)), ...
     'EMIProject:ExternalMeasurementIndependentReference');
   end
  end
  function packetShapeAndValuesAreValidated(test)
   valid=localPacket(0,1,true);invalid={[],struct(),[valid valid],rmfield(valid,'sourceIndex')};
   for j=1:numel(invalid)
    test.verifyError(@()phase3_external_measurement(invalid{j},1,0), ...
     'EMIProject:InvalidExternalMeasurement');
   end
   for value={NaN,Inf,1i,[0;1],"0",true}
    packet=valid;packet.measurement_rad=value{1};
    test.verifyError(@()phase3_external_measurement(packet,1,0), ...
     'EMIProject:InvalidExternalMeasurement');
   end
   for received={1,0,NaN,[true false],"true"}
    packet=valid;packet.sampleReceived=received{1};
    test.verifyError(@()phase3_external_measurement(packet,1,0), ...
     'EMIProject:InvalidExternalMeasurement');
   end
  end
  function suppliedCurrentTickValueIsResolvedBeforeSampling(test)
   delta=2*pi/4096;
   loop=localLoop(false);[loop,~]=phase3_loop_step(loop,[],localPacket(0,1,true));
   [~,before]=phase3_loop_step(loop,[],localPacket(0,2,true));
   [~,atEvent]=phase3_loop_step(loop,[],localPacket(delta,2,true));
   test.verifyEqual(atEvent.receivedMeasurement_rad,delta);
   test.verifyNotEqual(before.command_V,atEvent.command_V);
   test.verifyEqual(atEvent.sourceIndex,2);test.verifyEqual(atEvent.innovation_rad,delta);
  end
  function unusedBoundaryMatchesEquivalentCleanPacketsExactly(test)
   for protection=[false true]
    legacy=localLoop(protection);external=legacy;
    for k=1:20
     sensor=.0001*sin(k/4);
     [legacy,a]=phase3_loop_step(legacy,[sensor;123;456]);
     [external,b]=phase3_loop_step(external,[],localPacket(sensor,k,true));
     test.verifyEqual(phase3_logged_values(a),phase3_logged_values(b));
     test.verifyEqual(a.gateReason,b.gateReason);test.verifyEqual(a.transitionReason,b.transitionReason);
     test.verifyEqual(legacy.observer,external.observer);
    end
   end
  end
  function scheduledReferenceSupplyAndResetRemainOperationalInputs(test)
   loop=localLoop(false);changed=loop;changed.run.profiles.reference_rad(1)=.01;
   [~,a]=phase3_loop_step(loop,[],localPacket(0,1,true));
   [~,b]=phase3_loop_step(changed,[],localPacket(0,1,true));
   test.verifyNotEqual(a.command_V,b.command_V);test.verifyEqual(b.reference_rad,.01);
   loop=localLoop(true);loop.run.profiles.supply.voltage_V(1)=0;
   loop.run.profiles.supply.commandLimit_V(1)=0;
   [~,a]=phase3_loop_step(loop,[],localPacket(0,1,true));
   test.verifyEqual(a.mode,4);test.verifyEqual(a.command_V,0);test.verifyFalse(a.supplyHealthy);
   loop=localLoop(true);loop.supervisor.mode=4;
   loop.supervisor.goodCount=loop.run.configuration.supervisor.safeStopRelease_samples-1;
   changed=loop;changed.run.profiles.resetRequest(1)=true;
   [~,a]=phase3_loop_step(loop,[],localPacket(0,1,true));
   [~,b]=phase3_loop_step(changed,[],localPacket(0,1,true));
   test.verifyEqual(a.mode,4);test.verifyEqual(b.mode,3);test.verifyTrue(b.resetRequest);
  end
  function activityDistinguishesSlewAmplitudeAndStop(test)
   loop=localLoop(true);loop.run.profiles.reference_rad(1)=100;
   [~,slew]=phase3_loop_step(loop,[],localPacket(0,1,true));
   test.verifyTrue(slew.commandSlewLimited);test.verifyFalse(slew.commandAmplitudeLimited);
   test.verifyFalse(slew.controllerRebased);test.verifyEqual(abs(slew.command_V),10);
   loop.run.profiles.supply.commandLimit_V(1)=1;
   [~,both]=phase3_loop_step(loop,[],localPacket(0,1,true));
   test.verifyTrue(both.commandSlewLimited);test.verifyTrue(both.commandAmplitudeLimited);
   test.verifyEqual(abs(both.command_V),1);
   loop.run.profiles.supply.voltage_V(1)=0;loop.run.profiles.supply.commandLimit_V(1)=0;
   [~,stopped]=phase3_loop_step(loop,[],localPacket(0,1,true));
   test.verifyTrue(stopped.controllerRebased);test.verifyEqual(stopped.command_V,0);
   test.verifyFalse(stopped.commandSlewLimited);test.verifyFalse(stopped.commandAmplitudeLimited);
   loop=localLoop(false);loop.run.profiles.reference_rad(1)=100;
   [~,unprotected]=phase3_loop_step(loop,[],localPacket(0,1,true));
   test.verifyTrue(unprotected.commandAmplitudeLimited);test.verifyFalse(unprotected.commandSlewLimited);
   test.verifyFalse(unprotected.controllerRebased);test.verifyEqual(abs(unprotected.command_V),24);
  end
  function externalActivityDoesNotChangeLegacySampleSchema(test)
   loop=localLoop(true);
   [~,legacy]=phase3_loop_step(loop,zeros(3,1));
   [~,external]=phase3_loop_step(loop,[],localPacket(0,1,true));
   names={'commandSlewLimited','commandAmplitudeLimited','controllerRebased'};
   test.verifyFalse(any(isfield(legacy,names)));test.verifyTrue(all(isfield(external,names)));
   test.verifyEqual(fieldnames(rmfield(external,names)),fieldnames(legacy));
   test.verifyEqual(legacy,rmfield(external,names));
  end
 end
end

function packet=localPacket(value,source,received)
packet=struct('measurement_rad',value,'sourceIndex',source,'sampleReceived',received);
end

function loop=localLoop(protection)
p=actuator_parameters();s=phase3_scenario("external_boundary",p);
run=struct('params',p,'scenario',s,'protectionEnabled',protection, ...
 'configuration',phase3_configuration(p),'profiles',phase3_fault_profiles(p,s));
loop=phase3_loop_initialize(run);
end
