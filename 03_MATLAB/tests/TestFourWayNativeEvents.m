classdef TestFourWayNativeEvents < matlab.unittest.TestCase
 methods(Test)
  function transientAEdgesCancelPersistentCount(test)
   n=localTrace([-1;1;-1],[2.5;2.5;2.5]);
   [events,decoder]=fourway_native_events(n,0);
   test.verifyEqual(size(events,1),4);test.verifyEqual(decoder(:,4),[1;-1]);
   test.verifyEqual(decoder(:,5),[1;0]);test.verifyEqual(decoder(:,2),[1;0]);
   test.verifyEqual(decoder(:,1),[.6;1.6]*1e-6,'AbsTol',1e-20);
  end
  function negativeTransitionUsesNegativeCount(test)
   n=localTrace([1;-1;-1],[2.5;2.5;2.5]);
   [~,decoder]=fourway_native_events(n,1);
   test.verifyEqual(decoder(:,4),-1);test.verifyEqual(decoder(:,5),-1);
   test.verifyEqual(decoder(:,7),1);test.verifyEqual(decoder(:,2),0);
  end
  function domainExcursionLatchesAHold(test)
   n=localTrace([-1;-1;1],[2.5;8;2.5]);
   [events,decoder]=fourway_native_events(n,0);
   test.verifyEqual(sum(events(:,2)==2),2);test.verifyEmpty(decoder);
   test.verifyEqual(events(:,8),zeros(size(events,1),1));
   n=localTrace([-1;1;1],[8;2.5;2.5]);
   [~,decoder]=fourway_native_events(n,0);test.verifyEmpty(decoder);
  end
  function samplingIncludesEqualButNeverFutureEvents(test)
   n=localTrace([-1;1;-1],[2.5;2.5;2.5]);
   [~,decoder]=fourway_native_events(n,0);t=decoder(1,1);
   counts=fourway_decoder_count_at(decoder,[t-eps(t),t,t+eps(t)]);
   test.verifyEqual(counts,[0,1,1]);
   test.verifyEqual(fourway_decoder_count_at(decoder,2e-6),0);
  end
 end
end

function n=localTrace(differential,common)
n.time_s=(0:numel(differential)-1)'*1e-6;
n.differential_V=differential;n.commonMode_V=common;
n.positive_V=common+differential/2;n.negative_V=common-differential/2;
n.returnCurrent_A=zeros(size(differential));
end
