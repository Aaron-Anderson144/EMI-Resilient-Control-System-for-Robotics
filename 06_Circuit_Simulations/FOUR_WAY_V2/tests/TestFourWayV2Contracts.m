classdef TestFourWayV2Contracts < matlab.unittest.TestCase
 methods(Test)
  function declaredHypotheses(test)
   v=fourway_v2_variant();test.verifyEqual(numel(v),16);
   test.verifyEqual(string({v.id}),compose("V%02d",1:16));
   test.verifyEqual([v(1:4).rise_V],repmat(-.1,1,4));
   test.verifyEqual([v(1:4).latencyRise_s],[25 25 40 40]*1e-9,'AbsTol',1e-23);
   test.verifyEqual(string({v(1:4).pulseLaw}),["transport","inertial","transport","inertial"]);
   test.verifyEqual([v(13:16).fall_V],repmat(-.105,1,4));
  end
  function fourTreatmentsRetainTask(test)
   arms=["BASELINE","EM_ONLY","SW_ONLY","COMBINED"];
   expectedCd=[100 1000 100 1000];expectedProtection=[false false true true];
   first=fourway_v2_fixture("V2DEV01",arms(1),true,"V01");
   for k=1:4
    f=fourway_v2_fixture("V2DEV01",arms(k),true,"V01");
    test.verifyEqual(f.Cdiff_pF,expectedCd(k));test.verifyEqual(f.run.protectionEnabled,expectedProtection(k));
    test.verifyEqual(f.run.profiles.reference_rad,first.run.profiles.reference_rad);
    test.verifyEqual(f.variant,first.variant);test.verifyFalse(f.run.configuration.reacquisitionEnabled);
   end
  end
  function mismatchedVariantRejected(test)
   exposed=struct('fixture',fourway_v2_fixture("V2DEV01","BASELINE",true,"V01"));
   clean=struct('fixture',fourway_v2_fixture("V2DEV01","BASELINE",false,"V02"));
   test.verifyError(@()fourway_v2_metrics(exposed,clean,[1 2],[0 1]),'EMIProject:V2Companion');
  end
  function changedHypothesisRejected(test)
   exposed=struct('fixture',fourway_v2_fixture("V2DEV01","BASELINE",true,"V01"));
   exposed.fixture.variant.rise_V=-.09;clean=exposed;clean.fixture.exposed=false;
   test.verifyError(@()fourway_v2_metrics(exposed,clean,[1 2],[0 1]),'EMIProject:V2Variant');
  end
  function incompleteEvaluationRejected(test)
   test.verifyError(@()fourway_v2_assess(table()),'EMIProject:V2Coverage');
  end
  function evaluationRequiresAcceptance(test)
   test.verifyError(@()fourway_v2_require_acceptance(""),'EMIProject:V2Acceptance');
  end
  function protocolUnchanged(test)
   v=fourway_v2_verify_freeze();test.verifyTrue(v.passed);test.verifyEqual(v.frozen_files_verified,54);
  end
 end
end
