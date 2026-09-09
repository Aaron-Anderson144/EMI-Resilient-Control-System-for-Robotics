classdef TestSensitivityDesign < matlab.unittest.TestCase
    %TESTSENSITIVITYDESIGN Check meaningful sweep invariants and reproducibility.
    methods (Test)
        function nominalCatalogReconstructsOriginalPhysicalProfile(testCase)
            p = actuator_parameters();
            catalog = phase2b_sensitivity_catalog(p);
            t = (0:round(p.simulation.stopTime_s/p.control.sampleTime_s)).'*p.control.sampleTime_s;
            scenario = phase2b_scenario("combined_phase2b",p);
            reference = physical_coupling_profile(t,p,scenario);
            for j = 1:height(catalog)
                changed = apply_phase2b_sensitivity_value(p,catalog(j,:),catalog.Nominal(j));
                actual = physical_coupling_profile(t,changed,scenario);
                testCase.verifyEqual(actual.receiverDifferentialVoltage_V, ...
                    reference.receiverDifferentialVoltage_V,'AbsTol',1e-14);
            end
        end
        function signedImbalancesPreservePairMean(testCase)
            p = actuator_parameters();
            catalog = phase2b_sensitivity_catalog(p);
            c = apply_phase2b_sensitivity_value(p,catalog(catalog.Key=="cap_imbalance",:),-5);
            m = apply_phase2b_sensitivity_value(p,catalog(catalog.Key=="ind_imbalance",:),-15);
            testCase.verifyEqual(c.phase2b.coupling.capacitive.linePositive_F- ...
                c.phase2b.coupling.capacitive.lineNegative_F,-5e-12,'AbsTol',1e-26);
            testCase.verifyEqual(c.phase2b.coupling.capacitive.linePositive_F+ ...
                c.phase2b.coupling.capacitive.lineNegative_F,19e-12,'AbsTol',1e-26);
            testCase.verifyEqual(m.phase2b.coupling.inductive.linePositive_H- ...
                m.phase2b.coupling.inductive.lineNegative_H,-15e-9,'AbsTol',1e-23);
            testCase.verifyEqual(m.phase2b.coupling.inductive.linePositive_H+ ...
                m.phase2b.coupling.inductive.lineNegative_H,37e-9,'AbsTol',1e-23);
        end
        function stratifiedDesignReproducesWithoutChangingCallerRandomState(testCase)
            catalog = phase2b_sensitivity_catalog(actuator_parameters());
            catalog = catalog(catalog.Role=="response",:);
            before = rng;
            first = phase2b_sensitivity_design(catalog,64,12345);
            testCase.verifyEqual(rng,before);
            second = phase2b_sensitivity_design(catalog,64,12345);
            different = phase2b_sensitivity_design(catalog,64,12346);
            testCase.verifyEqual(first,second);
            testCase.verifyNotEqual(first,different);
            for j = 1:height(catalog)
                testCase.verifyGreaterThanOrEqual(first(:,j),catalog.Low(j));
                testCase.verifyLessThanOrEqual(first(:,j),catalog.High(j));
                if catalog.Scale(j)=="log"
                    u = log(first(:,j)/catalog.Low(j))/log(catalog.High(j)/catalog.Low(j));
                else
                    u = (first(:,j)-catalog.Low(j))/(catalog.High(j)-catalog.Low(j));
                end
                testCase.verifyEqual(sort(floor(u*64)),(0:63).');
            end
        end
        function outsideRangeRejected(testCase)
            p = actuator_parameters();
            catalog = phase2b_sensitivity_catalog(p);
            testCase.verifyError(@() apply_phase2b_sensitivity_value(p,catalog(1,:),6), ...
                'EMIProject:SensitivityOutsideRange');
        end
    end
end
