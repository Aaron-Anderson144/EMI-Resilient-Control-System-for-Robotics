classdef TestPhase3Integration < matlab.unittest.TestCase
 methods(Test)
  function cleanNormalMatchesLegacy(test)
   p=actuator_parameters();s=phase3_scenario("clean",p);cfg=phase3_configuration(p);
   a=simulate_phase3_actuator(p,s,true,cfg);b=simulate_phase2b_actuator(p,s.phase2b);
   test.verifyEqual(a.state,b.state,'AbsTol',1e-10);
   test.verifyEqual(a.timeSeries.command_V,b.command_V,'AbsTol',1e-10);
   test.verifyEqual(a.timeSeries.mode,zeros(size(a.time_s)));
  end
  function unprotectedRetainsLegacyFaultBehavior(test)
   p=actuator_parameters();cfg=phase3_configuration(p);
   for name=["combined_phase2b","supply_interruption","supply_sag"]
    s=phase3_scenario(name,p);s.phase2b=phase2b_scenario(name,p);
    a=simulate_phase3_actuator(p,s,false,cfg);b=simulate_phase2b_actuator(p,s.phase2b);
    test.verifyEqual(a.state,b.state,'AbsTol',1e-12);
    test.verifyEqual(a.timeSeries.command_V,b.command_V,'AbsTol',1e-12);
   end
  end
  function impulseRejectedWithoutPlantTruth(test)
   p=actuator_parameters();s=phase3_scenario("jump",p);s.encoder=encoder_fault_scenario("count_jump",p);
   a=simulate_phase3_actuator(p,s);t=a.timeSeries;k=find(t.time_s>=.45,1);
   test.verifyEqual(t.mode(k),1);test.verifyFalse(logical(t.measurementAccepted(k)));
   test.verifyLessThan(abs(t.estimatedPosition_rad(k)-t.position_rad(k)),1e-10);
   test.verifyLessThan(max(abs(t.command_V)),2);
  end
  function stalePacketsAndFrozenSensorAreDifferent(test)
   p=actuator_parameters();
   s=phase3_scenario("stationary_freeze",p);s.referenceValues_rad(:)=0;
   s.encoder=encoder_fault_scenario("dropout",p);
   a=simulate_phase3_actuator(p,s);
   test.verifyTrue(all(a.timeSeries.sampleReceived==1));
   test.verifyEqual(sum(a.timeSeries.alarm),0); % Unobservable at rest, not stale.
   s.packetDropStartTime_s=.4;s.packetDropStopTime_s=.75;
   a=simulate_phase3_actuator(p,s);t=a.timeSeries;
   k=find(t.time_s>=.4,1);test.verifyEqual(t.mode(k+19),0);
   test.verifyEqual(t.mode(k+20),1);test.verifyTrue(any(t.mode==4));
  end
  function supplyStopIsImmediateAndLatched(test)
   p=actuator_parameters();p.simulation.stopTime_s=3;
   s=phase3_scenario("supply",p);s.phase2b=phase2b_scenario("supply_sag",p);
   a=simulate_phase3_actuator(p,s);t=a.timeSeries;
   stop=t.time_s>=.85&t.time_s<2;
   test.verifyTrue(all(t.mode(stop)==4));test.verifyEqual(t.command_V(stop),zeros(sum(stop),1));
   test.verifyEqual(t.mode(find(t.time_s>=2,1)),3);test.verifyEqual(t.mode(end),0);
   test.verifyTrue(all(abs(t.command_V)<=t.commandLimit_V+1e-12));
  end
  function invalidEstimateStillCommandsZero(test)
   p=actuator_parameters();s=phase3_scenario("invalid_estimate",p);f=phase3_fault_profiles(p,s);
   run=struct('params',p,'scenario',s,'protectionEnabled',true,'configuration',phase3_configuration(p),'profiles',f);
   loop=phase3_loop_initialize(run);loop.observer.estimatedState(:)=NaN;
   [~,sample]=phase3_loop_step(loop,zeros(3,1));
   test.verifyEqual(sample.mode,4);test.verifyEqual(sample.command_V,0);
   test.verifyFalse(sample.estimateUsable);test.verifyTrue(isnan(sample.estimatedPosition_rad));
  end
  function changingOfflineTruthDoesNotChangeControl(test)
   p=actuator_parameters();s=phase3_scenario("truth",p);
   f=phase3_fault_profiles(p,s);cfg=phase3_configuration(p);
   a=simulate_phase3_actuator(p,s,true,cfg,f);
   f.sensorFaultAtSource(:)=true;f.sourceFault(:)=true;f.receiverFault(:)=true;
   s.name="arbitrary label";s.expectation="detect";
   b=simulate_phase3_actuator(p,s,true,cfg,f);
   test.verifyEqual(a.state,b.state);test.verifyEqual(a.loopValues,b.loopValues);
  end
  function permittedDelayUsesPredictionWithoutNuisance(test)
   p=actuator_parameters();s=phase3_scenario("delay",p);s.phase2b=phase2b_scenario("communication_delay",p);s.phase2b.communication.jitterEnabled=true;
   a=simulate_phase3_actuator(p,s);test.verifyEqual(sum(a.timeSeries.alarm),0);
   test.verifyLessThan(max(abs(a.timeSeries.estimatedPosition_rad-a.state(:,1))),1e-10);
  end
  function fixtureGenerationPreservesRandomState(test)
   p=actuator_parameters();p.simulation.stopTime_s=3;cases=phase3_test_scenarios(p);
   before=rng;for k=1:numel(cases),f=phase3_fault_profiles(p,cases(k));test.verifyEqual(numel(f.time_s),3001);end
   test.verifyEqual(rng,before);
  end
  function mismatchedSampleTimesFailClosed(test)
   p=actuator_parameters();s=phase3_scenario("mismatch",p);cfg=phase3_configuration(p);cfg.control.sampleTime_s=.002;
   test.verifyError(@()simulate_phase3_actuator(p,s,true,cfg),'EMIProject:Phase3SampleTime');
  end
 end
end
