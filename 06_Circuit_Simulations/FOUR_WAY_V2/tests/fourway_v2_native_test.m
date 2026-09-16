function tests=fourway_v2_native_test
tests=functiontests(localfunctions);
end
function setupOnce(test)
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'06_Circuit_Simulations','FOUR_WAY_V2','functions'), ...
    fullfile(root,'06_Circuit_Simulations','SC01A','functions'));
end
function testAllFrozenVariantsPresent(test)
variants=fourway_v2_native_variants();
verifyEqual(test,numel(variants),16);verifyEqual(test,numel(unique(string({variants.id}))),16);
verifyEqual(test,unique([variants.latencyRise_s]),[2.5e-8 4e-8]);
verifyEqual(test,numel(unique([variants.fall_V])),4);
end
function testTransportRetainsShortPulse(test)
native=trace([0 100 110 120 130 250]*1e-9,[-1 -1 1 1 -1 -1]);
v=variant('transport',40e-9);r=fourway_v2_native_events(native,0,v,250e-9);
verifyEqual(test,size(r.outputEvents,1),2);verifyEqual(test,r.decoderEvents(:,4),[1;-1]);
verifyEqual(test,r.counts,0);verifyFalse(test,r.grazingUnresolved);
end
function testInertialCancelsShortPulse(test)
native=trace([0 100 110 120 130 250]*1e-9,[-1 -1 1 1 -1 -1]);
r=fourway_v2_native_events(native,0,variant('inertial',40e-9),250e-9);
verifyEmpty(test,r.outputEvents);verifyEqual(test,r.counts,0);
end
function testEventsPrecedeExactTimeSample(test)
native=trace([0 100 200 300]*1e-9,[-1 -1 1 1]);v=variant('transport',25e-9);
r=fourway_v2_native_events(native,0,v,300e-9);when=r.outputEvents(1,1);
r=fourway_v2_native_events(native,0,v,[when-1e-13;when;when+1e-13]);
verifyEqual(test,r.counts,[0;1;1]);
end
function testHighInitialPolarityCountsNegative(test)
native=trace([0 100 200 300]*1e-9,[1 1 -1 -1]);
r=fourway_v2_native_events(native,1,variant('transport',25e-9),300e-9);
verifyEqual(test,r.counts,-1);verifyEqual(test,r.decoderEvents(1,[2 4 7]),[0 -1 1]);
end
function testSignedDifferentialLimitWithZeroCommonMode(test)
native=trace([0 100 200 300]*1e-9,[1 1 20 20]);
r=fourway_v2_native_events(native,1,variant('transport',25e-9),300e-9);
verifyFalse(test,r.linearNativeOperatingDomainPass);verifyTrue(test,r.linearNativeStressFlag);
verifyTrue(test,any(r.thresholdEvents(:,2)==4));verifyTrue(test,any(r.thresholdEvents(:,2)==7));
end
function testThresholdGrazingIsRejected(test)
native=trace([0 100 200]*1e-9,[-1 0 -1]);
r=fourway_v2_native_events(native,0,variant('transport',25e-9),200e-9);
verifyTrue(test,r.grazingUnresolved);
end
function testIndependentBranchKCLAcrossNativeTopologies(test)
for cp=[40 240]
    for cd=[100 1000]
        p=fourway_v2_native_parameters(cp,7,cd);c=sc01a_state_space(p);
        r=fourway_v2_native_kcl(p,c);verifyTrue(test,r.passed);
        wrong=p;wrong.driver.Rp_Ohm=p.driver.Rp_Ohm*1.01;
        rejected=fourway_v2_native_kcl(wrong,c);verifyFalse(test,rejected.passed);
    end
end
end
function n=trace(t,d)
n=struct('time_s',t(:),'positive_V',d(:)/2,'negative_V',-d(:)/2,'returnCurrent_A',zeros(numel(t),1));
end
function v=variant(law,latency)
v=struct('rise_V',0,'fall_V',-.1,'latencyRise_s',latency,'latencyFall_s',latency,'pulseLaw',law);
end
