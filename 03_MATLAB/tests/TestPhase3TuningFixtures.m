classdef TestPhase3TuningFixtures < matlab.unittest.TestCase
    methods (Test)
        function fixedPartitionsAndIndependentCallsPreserveStudyDeclaration(testCase)
            before = rng;
            a = phase3_tuning_fixtures();
            b = phase3_tuning_fixtures();
            testCase.verifyEqual(rng,before);
            testCase.verifyTrue(isequaln(a,b));
            ids = string({a.id});
            partition = string({a.partition});
            testCase.verifyEqual(numel(a),20);
            testCase.verifyEqual(numel(unique(ids)),20);
            testCase.verifyEqual(partition(1:8),repmat("tuning",1,8));
            testCase.verifyEqual(partition(9:20),repmat("evaluation",1,12));
            a(1).params.electrical.resistance_Ohm = 99;
            c = phase3_tuning_fixtures();
            testCase.verifyTrue(isequaln(c,b));
        end

        function allScenariosAndTargetWindowsFitCompleteValidRecords(testCase)
            cases = phase3_tuning_fixtures();
            for k = 1:numel(cases)
                f = cases(k);
                validate_parameters(f.params);
                validate_phase3_scenario(f.scenario,f.params);
                profile = phase3_fault_profiles(f.params,f.scenario);
                testCase.verifyEqual(profile.time_s,(0:3000)'*.001);
                testCase.verifySize(f.targetWindow_s,[1,2]);
                testCase.verifyGreaterThanOrEqual(f.targetWindow_s(1),0);
                testCase.verifyGreaterThan(f.targetWindow_s(2),f.targetWindow_s(1));
                testCase.verifyLessThanOrEqual(f.targetWindow_s(2),profile.time_s(end));
                testCase.verifyEqual(f.targetWindow_s/.001, ...
                    round(f.targetWindow_s/.001),'AbsTol',1e-9);
                testCase.verifyEqual(f.scenario.name,f.id);
                testCase.verifyEqual(f.expectClean,f.scenario.expectation=="clean");
                testCase.verifyTrue(islogical(f.useIndependentReference));
            end
        end

        function faultAndReferenceEventsKeepIndependentDeclaredTiming(testCase)
            cases = phase3_tuning_fixtures();
            f = select(cases,"freeze_during_motion");
            profile = phase3_fault_profiles(f.params,f.scenario);
            t = profile.time_s;
            testCase.verifyEqual(profile.encoder.dropoutActive,t>=.13&t<.45);
            f = select(cases,"short_packet_burst");
            profile = phase3_fault_profiles(f.params,f.scenario);
            testCase.verifyEqual(profile.communication.packetDropped,t>=.25&t<.34);
            f = select(cases,"reversal_during_recovery");
            profile = phase3_fault_profiles(f.params,f.scenario);
            jump = find(abs(t-.45)<1e-12);
            testCase.verifyEqual(find(profile.encoder.additive_rad~=0),jump);
            testCase.verifyEqual(profile.encoder.additive_rad(jump),2*pi*128/4096,'AbsTol',1e-14);
            testCase.verifyEqual(profile.reference_rad(t>=.48), ...
                repmat(deg2rad(-30),nnz(t>=.48),1));
            f = select(cases,"out_of_range_measurement");
            profile = phase3_fault_profiles(f.params,f.scenario);
            testCase.verifyEqual(find(profile.bias_rad~=0),jump);
            testCase.verifyEqual(profile.bias_rad(jump),4);
        end

        function actualLoadAndModelMismatchRemainSeparateFromAssumedInputs(testCase)
            cases = phase3_tuning_fixtures();
            for name = ["eval_known_positive_load","eval_known_negative_load"]
                f = select(cases,name);
                testCase.verifyEqual(abs(f.scenario.loadTorque_Nm),.01);
                testCase.verifyEqual(f.scenario.assumedLoadTorque_Nm,f.scenario.loadTorque_Nm);
            end
            f = select(cases,"eval_unknown_load_freeze");
            testCase.verifyEqual(f.scenario.loadTorque_Nm,.001);
            testCase.verifyEqual(f.scenario.assumedLoadTorque_Nm,0);
            testCase.verifyFalse(f.expectClean);
            f = select(cases,"eval_model_mismatch_burst");
            nominal = actuator_parameters();
            testCase.verifyEqual(f.params.electrical.resistance_Ohm,nominal.electrical.resistance_Ohm);
            testCase.verifyEqual(f.params.mechanical.inertia_kg_m2,nominal.mechanical.inertia_kg_m2);
            testCase.verifyEqual(f.scenario.actualParameters.electrical.resistance_Ohm, ...
                1.05*f.params.electrical.resistance_Ohm);
            testCase.verifyEqual(f.scenario.actualParameters.mechanical.inertia_kg_m2, ...
                1.10*f.params.mechanical.inertia_kg_m2);
            testCase.verifyFalse(f.expectClean);
        end

        function limitingStressChangesOnlyDeclaredSoftwareLimitAndMotion(testCase)
            cases = phase3_tuning_fixtures();
            for name = ["capped_reversal","eval_opposite_capped_reversal"]
                f = select(cases,name);
                testCase.verifyEqual(f.params.control.voltageLimit_V,2);
                testCase.verifyEqual(f.params.electrical.nominalVoltage_V,24);
                testCase.verifyEqual(f.scenario.actualParameters.control.voltageLimit_V,2);
                testCase.verifyTrue(contains(lower(f.description),"synthetic"));
                testCase.verifyFalse(f.expectClean);
                profile = phase3_fault_profiles(f.params,f.scenario);
                testCase.verifyEqual(profile.supply.commandLimit_V,2*ones(3001,1));
            end
            a = select(cases,"capped_reversal");
            b = select(cases,"eval_opposite_capped_reversal");
            testCase.verifyEqual(a.scenario.referenceValues_rad,-b.scenario.referenceValues_rad);
            testCase.verifyNotEqual(a.scenario.referenceTimes_s(end),b.scenario.referenceTimes_s(end));
        end

        function referenceAndOfflineMetadataCannotInventResetOrFaultInputs(testCase)
            cases = phase3_tuning_fixtures();
            testCase.verifyEqual(nnz([cases.useIndependentReference]),2);
            a = select(cases,"eval_independent_reference_recovery");
            b = select(cases,"eval_independent_reference_no_reset");
            pa = phase3_fault_profiles(a.params,a.scenario);
            pb = phase3_fault_profiles(b.params,b.scenario);
            testCase.verifyEqual(find(pa.resetRequest),2001);
            testCase.verifyFalse(any(pb.resetRequest));
            ra = phase3_reference_profile(pa.time_s,a.referenceOptions);
            rb = phase3_reference_profile(pb.time_s,b.referenceOptions);
            testCase.verifyTrue(isequaln(ra,rb));
            testCase.verifyEqual(find(ra.request),1501);
            testCase.verifyEqual(ra.sampleReceived,pa.time_s>=1.2&pa.time_s<1.8);
            testCase.verifyTrue(isequaln(rmfield(pa,'resetRequest'),rmfield(pb,'resetRequest')));
            % Study metadata never reaches the exogenous profile interface.
            a.id = "modified offline label";
            a.partition = "tuning";
            a.targetWindow_s = [0,3];
            after = phase3_fault_profiles(a.params,a.scenario);
            testCase.verifyTrue(isequaln(after,pa));
        end
    end
end

function f = select(cases,id)
index = find(string({cases.id})==id);
assert(isscalar(index),'Fixture id must identify exactly one declaration.');
f = cases(index);
end
