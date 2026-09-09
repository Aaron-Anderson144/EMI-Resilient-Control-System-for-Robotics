classdef TestSensitivityPhysics < matlab.unittest.TestCase
    %TESTSENSITIVITYPHYSICS Guard interpretation of Phase 2B parameter sweeps.
    % Uses only existing public project functions. The checks deliberately
    % separate active physics, diagnostic thresholds, and reserved inputs.

    properties
        Params
        Time_s
        CombinedReference
    end

    methods (TestClassSetup)
        function createReference(testCase)
            testCase.Params = actuator_parameters();
            testCase.CombinedReference = simulate_phase2b_actuator( ...
                testCase.Params, phase2b_scenario( ...
                "combined_phase2b", testCase.Params));
            testCase.Time_s = testCase.CombinedReference.time_s;
        end
    end

    methods (Test)
        function sharedResistanceScalesItsNonzeroContribution(testCase)
            params = testCase.Params;
            scenario = phase2b_scenario("shared_impedance", params);
            base = physical_coupling_profile(testCase.Time_s, params, scenario);
            params.phase2b.coupling.shared.returnResistance_Ohm = ...
                2 * params.phase2b.coupling.shared.returnResistance_Ohm;
            changed = physical_coupling_profile(testCase.Time_s, params, scenario);

            % Nominal return terms are 75 mV resistive and 300 mV inductive.
            % Doubling R alone therefore raises the total by 20%, not 100%.
            testCase.verifyGreaterThan(max(abs(base.sharedImpedanceVoltage_V)), 0);
            testCase.verifyEqual(changed.sharedImpedanceVoltage_V, ...
                1.2 * base.sharedImpedanceVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.derived.sharedReturnVoltagePeak_V, ...
                0.450, 'AbsTol', 1e-14);
        end

        function sharedInductanceScalesItsNonzeroContribution(testCase)
            params = testCase.Params;
            scenario = phase2b_scenario("shared_impedance", params);
            base = physical_coupling_profile(testCase.Time_s, params, scenario);
            params.phase2b.coupling.shared.returnInductance_H = ...
                2 * params.phase2b.coupling.shared.returnInductance_H;
            changed = physical_coupling_profile(testCase.Time_s, params, scenario);

            % Doubling the 300 mV inductive term retains the 75 mV R term.
            testCase.verifyGreaterThan(max(abs(base.sharedImpedanceVoltage_V)), 0);
            testCase.verifyEqual(changed.sharedImpedanceVoltage_V, ...
                1.8 * base.sharedImpedanceVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.derived.sharedReturnVoltagePeak_V, ...
                0.675, 'AbsTol', 1e-14);
        end

        function sharedConversionChangesDifferentialVoltageOnly(testCase)
            params = testCase.Params;
            scenario = phase2b_scenario("shared_impedance", params);
            base = physical_coupling_profile(testCase.Time_s, params, scenario);
            params.phase2b.coupling.shared.commonModeToDifferential = ...
                2 * params.phase2b.coupling.shared.commonModeToDifferential;
            changed = physical_coupling_profile(testCase.Time_s, params, scenario);

            testCase.verifyGreaterThan(max(abs(base.sharedImpedanceVoltage_V)), 0);
            testCase.verifyEqual(changed.sharedImpedanceVoltage_V, ...
                2 * base.sharedImpedanceVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.equivalentEncoderError_rad, ...
                2 * base.equivalentEncoderError_rad, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.derived.sharedReturnVoltagePeak_V, ...
                base.derived.sharedReturnVoltagePeak_V);
        end

        function groundConversionChangesDifferentialVoltageOnly(testCase)
            params = testCase.Params;
            scenario = phase2b_scenario("ground_offset", params);
            base = physical_coupling_profile(testCase.Time_s, params, scenario);
            params.phase2b.groundOffset.commonModeToDifferential = ...
                3 * params.phase2b.groundOffset.commonModeToDifferential;
            changed = physical_coupling_profile(testCase.Time_s, params, scenario);

            testCase.verifyGreaterThan(max(abs(base.groundDifferentialVoltage_V)), 0);
            testCase.verifyEqual(changed.groundDifferentialVoltage_V, ...
                3 * base.groundDifferentialVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.equivalentEncoderError_rad, ...
                3 * base.equivalentEncoderError_rad, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.groundCommonModeVoltage_V, ...
                base.groundCommonModeVoltage_V);
            testCase.verifyEqual(changed.commonModeLimitExceeded, ...
                base.commonModeLimitExceeded);
        end

        function voltageRiseTimeAffectsCapacitivePathOnly(testCase)
            params = testCase.Params;
            base = testCase.CombinedReference.physical;
            params.phase2b.source.voltageRiseTime_s = ...
                2 * params.phase2b.source.voltageRiseTime_s;
            changed = physical_coupling_profile(testCase.Time_s, params, ...
                phase2b_scenario("combined_phase2b", params));

            testCase.verifyGreaterThan(max(abs(base.capacitiveVoltage_V)), 0);
            testCase.verifyEqual(changed.capacitiveVoltage_V, ...
                0.5 * base.capacitiveVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.inductiveVoltage_V, base.inductiveVoltage_V);
            testCase.verifyEqual(changed.sharedImpedanceVoltage_V, ...
                base.sharedImpedanceVoltage_V);
            testCase.verifyEqual(changed.groundDifferentialVoltage_V, ...
                base.groundDifferentialVoltage_V);
        end

        function currentRiseTimeRetainsOhmicSharedReturnTerm(testCase)
            params = testCase.Params;
            base = testCase.CombinedReference.physical;
            params.phase2b.source.currentRiseTime_s = ...
                2 * params.phase2b.source.currentRiseTime_s;
            changed = physical_coupling_profile(testCase.Time_s, params, ...
                phase2b_scenario("combined_phase2b", params));

            testCase.verifyGreaterThan(max(abs(base.inductiveVoltage_V)), 0);
            testCase.verifyEqual(changed.inductiveVoltage_V, ...
                0.5 * base.inductiveVoltage_V, 'AbsTol', 1e-14);
            % Halving dI/dt leaves 75 + 150 = 225 mV, or 60% of 375 mV.
            testCase.verifyEqual(changed.sharedImpedanceVoltage_V, ...
                0.6 * base.sharedImpedanceVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.capacitiveVoltage_V, base.capacitiveVoltage_V);
            testCase.verifyEqual(changed.groundDifferentialVoltage_V, ...
                base.groundDifferentialVoltage_V);
        end

        function balancedPairOffsetsPreserveDifferentialCoupling(testCase)
            params = testCase.Params;
            base = testCase.CombinedReference.physical;
            params.phase2b.coupling.capacitive.linePositive_F = ...
                params.phase2b.coupling.capacitive.linePositive_F + 30e-12;
            params.phase2b.coupling.capacitive.lineNegative_F = ...
                params.phase2b.coupling.capacitive.lineNegative_F + 30e-12;
            params.phase2b.coupling.inductive.linePositive_H = ...
                params.phase2b.coupling.inductive.linePositive_H + 60e-9;
            params.phase2b.coupling.inductive.lineNegative_H = ...
                params.phase2b.coupling.inductive.lineNegative_H + 60e-9;
            changed = physical_coupling_profile(testCase.Time_s, params, ...
                phase2b_scenario("combined_phase2b", params));

            testCase.verifyEqual(changed.capacitiveVoltage_V, ...
                base.capacitiveVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.inductiveVoltage_V, ...
                base.inductiveVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.receiverDifferentialVoltage_V, ...
                base.receiverDifferentialVoltage_V, 'AbsTol', 1e-14);
        end

        function bandwidthFiltersEnvelopeButNotGroundOffset(testCase)
            params = testCase.Params;
            base = testCase.CombinedReference.physical;
            params.phase2b.receiver.bandwidth_Hz = ...
                params.phase2b.source.observedBasebandFrequency_Hz;
            changed = physical_coupling_profile(testCase.Time_s, params, ...
                phase2b_scenario("combined_phase2b", params));
            scale = (1 / sqrt(2)) / base.derived.receiverGain;

            testCase.verifyEqual(changed.derived.receiverGain, ...
                1 / sqrt(2), 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.capacitiveVoltage_V, ...
                scale * base.capacitiveVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.inductiveVoltage_V, ...
                scale * base.inductiveVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.sharedImpedanceVoltage_V, ...
                scale * base.sharedImpedanceVoltage_V, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.groundDifferentialVoltage_V, ...
                base.groundDifferentialVoltage_V);
        end

        function equivalentSensitivityChangesAngleButNotVoltage(testCase)
            params = testCase.Params;
            base = testCase.CombinedReference.physical;
            params.phase2b.receiver.systemLevelEquivalentSensitivity_rad_V = ...
                2 * params.phase2b.receiver.systemLevelEquivalentSensitivity_rad_V;
            changed = physical_coupling_profile(testCase.Time_s, params, ...
                phase2b_scenario("combined_phase2b", params));

            testCase.verifyGreaterThan(max(abs(base.equivalentEncoderError_rad)), 0);
            testCase.verifyEqual(changed.equivalentEncoderError_rad, ...
                2 * base.equivalentEncoderError_rad, 'AbsTol', 1e-14);
            testCase.verifyEqual(changed.receiverDifferentialVoltage_V, ...
                base.receiverDifferentialVoltage_V);
            testCase.verifyEqual(changed.receiverMarginExceeded, ...
                base.receiverMarginExceeded);
        end

        function reservedSourceAndDecoderInputsHaveNoEffect(testCase)
            groups = ["source", "source", "receiver", "receiver"];
            names = ["pwmFrequency_Hz", "voltageFallTime_s", ...
                "minimumPulseWidth_s", "maxSpuriousCountsPerSample"];
            values = [40e3, 400e-9, 500e-9, 0];
            for k = 1:numel(names)
                params = testCase.Params;
                params.phase2b.(groups(k)).(names(k)) = values(k);
                changed = simulate_phase2b_actuator(params, ...
                    phase2b_scenario("combined_phase2b", params));

                % Exact comparisons document that these parameters are
                % reserved metadata, not tested physical immunity factors.
                testCase.verifyEqual(changed.physical, ...
                    testCase.CombinedReference.physical, char(names(k)));
                testCase.verifyEqual(changed.timeSeries, ...
                    testCase.CombinedReference.timeSeries, char(names(k)));
            end
        end

        function differentialCapacitanceChangesDiagnosticPoleOnly(testCase)
            params = testCase.Params;
            params.phase2b.receiver.differentialCapacitance_F = ...
                4 * params.phase2b.receiver.differentialCapacitance_F;
            changed = simulate_phase2b_actuator(params, ...
                phase2b_scenario("combined_phase2b", params));
            base = testCase.CombinedReference;

            testCase.verifyEqual(changed.physical.derived.terminationPole_Hz, ...
                base.physical.derived.terminationPole_Hz / 4, 'RelTol', 1e-14);
            testCase.verifyEqual(changed.timeSeries, base.timeSeries);
            testCase.verifyEqual(changed.physical.receiverMarginExceeded, ...
                base.physical.receiverMarginExceeded);
        end

        function differentialNoiseMarginChangesDiagnosticOnly(testCase)
            params = testCase.Params;
            params.phase2b.receiver.differentialNoiseMargin_V = 1e-3;
            changed = simulate_phase2b_actuator(params, ...
                phase2b_scenario("combined_phase2b", params));
            base = testCase.CombinedReference;

            testCase.verifyFalse(any(base.physical.receiverMarginExceeded));
            testCase.verifyTrue(any(changed.physical.receiverMarginExceeded));
            testCase.verifyEqual(changed.physical.receiverMarginUtilization, ...
                200 * base.physical.receiverMarginUtilization, 'AbsTol', 1e-11);
            testCase.verifyEqual(changed.timeSeries, base.timeSeries);
        end

        function commonModeLimitChangesDiagnosticOnly(testCase)
            params = testCase.Params;
            params.phase2b.receiver.commonModeLimit_V = 0.05;
            changed = simulate_phase2b_actuator(params, ...
                phase2b_scenario("combined_phase2b", params));
            base = testCase.CombinedReference;

            testCase.verifyFalse(any(base.physical.commonModeLimitExceeded));
            testCase.verifyEqual(changed.physical.commonModeLimitExceeded, ...
                changed.physical.groundWindowActive);
            testCase.verifyTrue(any(changed.physical.commonModeLimitExceeded));
            testCase.verifyEqual(changed.timeSeries, base.timeSeries);
        end
    end
end
