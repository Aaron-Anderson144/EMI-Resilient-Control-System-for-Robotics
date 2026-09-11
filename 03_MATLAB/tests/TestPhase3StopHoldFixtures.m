classdef TestPhase3StopHoldFixtures < matlab.unittest.TestCase
 methods(Test)
  function frozenScope(test)
   d=phase3_stop_hold_configuration();root=fileparts(fileparts(mfilename('fullpath')));f=phase3_stop_hold_fixtures(d,root);
   test.verifyEqual(numel(f),20);test.verifyEqual(numel(unique(string({f.id}))),20);
   test.verifyEqual(d.steps_s,[1e-4,5e-5,2.5e-5]);test.verifyEqual(d.mechanisms(3).capacity_Nm,.03);
  end
  function engagementCausal(test)
   [d,f]=config();c=phase3_stop_hold_capacity([0,.029,.030,.040,.050,.060],f,d.mechanisms(3));
   test.verifyEqual(c,[0,0,0,.015,.03,.03],'AbsTol',1e-15);
  end
  function noEarlyRelease(test)
   [d,f]=config();f.preEngaged=true;f.releaseTime_s=.3;
   test.verifyEqual(phase3_stop_hold_capacity([0,.3,.31,.32,.4],f,d.mechanisms(3)),[.03,.03,.015,0,0],'AbsTol',1e-15);
  end
  function mechanicalFailuresDistinct(test)
   [d,f]=config();f.failedEngagement=true;
   test.verifyEqual(phase3_stop_hold_capacity([0,.1,.5],f,d.mechanisms(3)),[0,0,0]);
   f.failedEngagement=false;f.preEngaged=true;f.failedRelease=true;f.releaseTime_s=.3;
   test.verifyEqual(phase3_stop_hold_capacity([0,.3,.5],f,d.mechanisms(3)),[.03,.03,.03]);
  end
  function resistorCannotHold(test)
   [d,f]=config();f.preEngaged=true;
   test.verifyEqual(phase3_stop_hold_capacity([0,.1,.5],f,d.mechanisms(2)),[0,0,0]);
  end
  function finiteImpulseAndLedger(test)
   [d,f]=config();f.x0=[0 8 0];f.duration_s=.1;f.preEngaged=true;p=actuator_parameters();
   [r,m]=phase3_stop_hold_simulate(p,f,d.mechanisms(3),1e-4,d);
   test.verifyGreaterThan(abs(r.Velocity_rad_s(2)),0);test.verifyLessThan(m.MaxEnergyResidual_J,1e-12);
   test.verifyGreaterThan(m.BrakeLoss_J,0);test.verifyGreaterThan(m.NumericalLoss_J,0);
  end
 end
end
function [d,f]=config()
d=phase3_stop_hold_configuration();f=struct('preEngaged',false,'engagementDelay_s',.03, ...
 'ramp_s',.02,'releaseTime_s',-1,'failedEngagement',false,'failedRelease',false, ...
 'x0',[0 0 0],'id','test','loadTimes_s',0,'loadValues_Nm',.008,'duration_s',.1);
end
