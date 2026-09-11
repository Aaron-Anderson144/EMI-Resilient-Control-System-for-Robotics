classdef TestPhase3MotionFixtures < matlab.unittest.TestCase
    methods (Test)
        function declarationsAreDeterministicAndPreserveDevelopmentReplay(testCase)
            before=rng;
            a=phase3_motion_fixtures();b=phase3_motion_fixtures();
            testCase.verifyEqual(rng,before);
            testCase.verifyTrue(isequaln(a,b));
            testCase.verifyEqual(numel(unique(string({a.id}))),20);
            partition=string({a.partition});kind=string({a.kind});
            testCase.verifyEqual(nnz(partition=="development"),2);
            testCase.verifyEqual(nnz(partition=="evaluation"&kind=="clean"),8);
            testCase.verifyEqual(nnz(partition=="evaluation"&kind=="fault"),8);
            testCase.verifyEqual(nnz(partition=="diagnostic"&kind=="diagnostic"),2);
            old=pick(phase3_tuning_fixtures(),"eval_benign_noise_reversal");
            noisy=pick(a,"development_original_noise_reversal");
            quiet=pick(a,"development_noiseless_reversal");
            testCase.verifyEqual(noisy.params,old.params);
            testCase.verifyEqual(noisy.scenario,old.scenario);
            testCase.verifyEqual(quiet.params,noisy.params);
            excluded={'name','description','benignNoiseStandardDeviation_rad'};
            testCase.verifyTrue(isequaln(rmfield(quiet.scenario,excluded), ...
                rmfield(noisy.scenario,excluded)));
            testCase.verifyEqual(quiet.scenario.benignNoiseStandardDeviation_rad,0);
            a(3).params.electrical.resistance_Ohm=99;
            testCase.verifyTrue(isequaln(phase3_motion_fixtures(),b));
        end

        function recordsAndOfflineDeadlinesHaveValidCausalExposure(testCase)
            cases=phase3_motion_fixtures();
            for k=1:numel(cases)
                f=cases(k);validate_parameters(f.params);
                validate_phase3_scenario(f.scenario,f.params);
                p=phase3_fault_profiles(f.params,f.scenario);
                testCase.verifyEqual(p.time_s,(0:3000)'*.001);
                testCase.verifySize(f.window_s,[1,2]);
                testCase.verifyGreaterThanOrEqual(f.window_s(1),0);
                testCase.verifyGreaterThan(f.window_s(2),f.window_s(1));
                testCase.verifyLessThanOrEqual(f.window_s(2),3);
                testCase.verifyEqual(f.window_s/.001,round(f.window_s/.001),'AbsTol',1e-9);
                testCase.verifyLessThanOrEqual(max(abs(p.reference_rad)),deg2rad(120));
                testCase.verifyTrue(islogical(f.requireStop)&&islogical(f.requireResetRelease));
                testCase.verifyFalse(isfield(p,'independentReference'));
                if f.kind=="fault"
                    first=find(p.receiverFault,1);
                    testCase.assertNotEmpty(first);
                    testCase.verifyGreaterThanOrEqual(f.alarmDeadline_s,p.time_s(first));
                    testCase.verifyLessThanOrEqual(f.alarmDeadline_s-p.time_s(first),.050+1e-12);
                    testCase.verifyTrue(any(f.responseKind==["alarm","stop"]));
                else
                    testCase.verifyTrue(isnan(f.alarmDeadline_s));
                    testCase.verifyEqual(f.responseKind,"none");
                    testCase.verifyFalse(f.requireStop||f.requireResetRelease);
                end
            end
        end

        function newCleanRequestsRemainIndependentOfPriorEvaluation(testCase)
            cases=phase3_motion_fixtures();old=phase3_tuning_fixtures();
            clean=cases(string({cases.partition})=="evaluation"&string({cases.kind})=="clean");
            for k=1:numel(clean)
                f=clean(k);p=phase3_fault_profiles(f.params,f.scenario);
                testCase.verifyFalse(any(p.sensorFaultAtSource));
                testCase.verifyFalse(any(p.communication.packetDropped));
                testCase.verifyFalse(any(p.supply.configuredWindowActive));
                testCase.verifyEqual(f.scenario.expectation,"clean");
                for j=1:numel(old)
                    same=isequal(f.scenario.referenceTimes_s,old(j).scenario.referenceTimes_s)&& ...
                        isequal(f.scenario.referenceValues_rad,old(j).scenario.referenceValues_rad);
                    testCase.verifyFalse(same,'New evaluation cannot silently reuse a prior trajectory.');
                end
            end
            f=pick(cases,"clean_new_noise_reversal");
            testCase.verifyEqual(f.scenario.noiseSeed,260932);
            testCase.verifyEqual(f.scenario.benignNoiseStandardDeviation_rad,deg2rad(.005));
            f=pick(cases,"clean_permitted_delay_jitter");
            p=phase3_fault_profiles(f.params,f.scenario);
            active=p.communication.configuredWindowActive;
            testCase.verifyGreaterThanOrEqual(p.communication.transmitDelay_samples(active),8);
            testCase.verifyLessThanOrEqual(p.communication.transmitDelay_samples(active),16);
            testCase.verifyEqual(f.params.phase2b.communication.jitterRandomSeed,260933);
            received=find(p.communication.sampleReceived);
            source=p.communication.acceptedSourceIndex(received);
            testCase.verifyLessThanOrEqual(source,received);
            testCase.verifyGreaterThan(diff(source),0);
        end

        function corruptionsRetainTheirDeclaredUnitsAndHalfOpenWindows(testCase)
            cases=phase3_motion_fixtures();
            f=pick(cases,"fault_count_jump_reversal");
            p=phase3_fault_profiles(f.params,f.scenario);t=p.time_s;
            testCase.verifyEqual(find(p.encoder.additive_rad~=0),1028);
            testCase.verifyEqual(p.encoder.additive_rad(1028),128*2*pi/4096,'AbsTol',1e-14);
            f=pick(cases,"fault_out_of_range");p=phase3_fault_profiles(f.params,f.scenario);
            testCase.verifyEqual(find(p.bias_rad~=0),824);
            testCase.verifyEqual(p.bias_rad(824),4);
            f=pick(cases,"fault_moving_freeze");p=phase3_fault_profiles(f.params,f.scenario);
            testCase.verifyEqual(p.encoder.dropoutActive,t>=.231&t<.381);
            testCase.verifyEqual(nnz(p.encoder.dropoutActive),150);
            f=pick(cases,"fault_short_packet_gap");p=phase3_fault_profiles(f.params,f.scenario);
            testCase.verifyEqual(p.communication.packetDropped,t>=.547&t<.657);
            testCase.verifyEqual(nnz(p.communication.packetDropped),110);
            f=pick(cases,"fault_long_packet_gap");p=phase3_fault_profiles(f.params,f.scenario);
            testCase.verifyEqual(p.communication.packetDropped,t>=.611&t<1.001);
            testCase.verifyEqual(nnz(p.communication.packetDropped),390);
            f=pick(cases,"fault_excessive_delay");p=phase3_fault_profiles(f.params,f.scenario);
            active=t>=.733&t<1.133;
            testCase.verifyEqual(p.communication.transmitDelay_samples(active),35*ones(nnz(active),1));
            testCase.verifyEqual(p.communication.transmitDelay_samples(~active),zeros(nnz(~active),1));
        end

        function stopAndResetRequirementsUseDeclaredPrimaryEvidence(testCase)
            cases=phase3_motion_fixtures();
            testCase.verifyEqual(string({cases([cases.requireStop]).id}), ...
                ["fault_long_packet_gap","fault_loaded_supply_interruption","fault_persistent_bias"]);
            testCase.verifyEqual(string({cases([cases.requireResetRelease]).id}),"fault_long_packet_gap");
            f=pick(cases,"fault_long_packet_gap");p=phase3_fault_profiles(f.params,f.scenario);
            testCase.verifyEqual(find(p.resetRequest),2001);
            reset=find(p.resetRequest);
            testCase.verifyTrue(all(p.communication.sampleReceived(reset-50:reset)));
            testCase.verifyEqual(p.communication.acceptedSourceIndex(reset-50:reset),(reset-50:reset)');
            testCase.verifyFalse(any(p.sensorFaultAtSource));
            f=pick(cases,"fault_loaded_supply_interruption");p=phase3_fault_profiles(f.params,f.scenario);
            mask=p.time_s>=.873&p.time_s<1.139;
            testCase.verifyEqual(f.responseKind,"stop");
            testCase.verifyEqual(p.supply.voltage_V(mask),zeros(nnz(mask),1));
            testCase.verifyEqual(f.scenario.loadTorque_Nm,.008);
            testCase.verifyEqual(f.scenario.assumedLoadTorque_Nm,.008);
            f=pick(cases,"fault_persistent_bias");p=phase3_fault_profiles(f.params,f.scenario);
            testCase.verifyEqual(p.bias_rad(p.time_s>=.687), ...
                deg2rad(5)*ones(nnz(p.time_s>=.687),1));
            testCase.verifyTrue(p.resetRequest(2001)&&p.sensorFaultAtSource(2001));
            testCase.verifyFalse(f.requireResetRelease);
        end

        function diagnosticsAndScoringMetadataCannotAlterAssumedInputs(testCase)
            cases=phase3_motion_fixtures();nominal=actuator_parameters();
            for name=["clean_known_positive_load","clean_known_negative_load"]
                f=pick(cases,name);
                testCase.verifyEqual(f.scenario.loadTorque_Nm,f.scenario.assumedLoadTorque_Nm);
            end
            f=pick(cases,"diagnostic_unknown_load");
            testCase.verifyEqual(f.scenario.loadTorque_Nm,.001);
            testCase.verifyEqual(f.scenario.assumedLoadTorque_Nm,0);
            testCase.verifyEqual(f.scenario.expectation,"observe");
            f=pick(cases,"diagnostic_model_mismatch");
            testCase.verifyEqual(f.params.electrical.resistance_Ohm,nominal.electrical.resistance_Ohm);
            testCase.verifyEqual(f.params.mechanical.inertia_kg_m2,nominal.mechanical.inertia_kg_m2);
            testCase.verifyEqual(f.scenario.actualParameters.electrical.resistance_Ohm, ...
                1.10*f.params.electrical.resistance_Ohm);
            testCase.verifyEqual(f.scenario.actualParameters.mechanical.inertia_kg_m2, ...
                1.15*f.params.mechanical.inertia_kg_m2);
            for k=1:numel(cases)
                f=cases(k);before=phase3_fault_profiles(f.params,f.scenario);
                f.id="offline label";f.partition="diagnostic";f.kind="diagnostic";
                f.window_s=[0,3];f.alarmDeadline_s=NaN;f.responseKind="none";
                f.requireStop=false;f.requireResetRelease=false;
                after=phase3_fault_profiles(f.params,f.scenario);
                testCase.verifyTrue(isequaln(before,after));
            end
        end
    end
end

function f=pick(cases,id)
index=find(string({cases.id})==id);
assert(isscalar(index),'Fixture id must identify exactly one declaration.');
f=cases(index);
end
