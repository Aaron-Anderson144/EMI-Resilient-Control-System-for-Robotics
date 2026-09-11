classdef TestSC01BRevisedDriver < matlab.unittest.TestCase
    methods(Test)
        function behavioralExpressionPreservesEveryCornerAndInterior(testCase)
            p=sc01b_parameters();g=sc01b_gate_signals(p);
            % Source syntax is evaluated independently against MATLAB's PWL
            % interpolation, including exact corners and adjacent doubles.
            time=unique([g.time_s;g.time_s+eps(g.time_s);g.time_s-eps(g.time_s); ...
                linspace(0,p.simulation.stopTime_s,1003).']);
            time=time(time>=0 & time<=p.simulation.stopTime_s);
            for field=["high_V","low_V"]
                expected=interp1(g.time_s,g.(field),time,'linear');
                actual=eval(sc01b_spice_pwl_expression(g.time_s,g.(field)));
                testCase.verifyEqual(actual,expected,'AbsTol',2e-13);
            end
        end
        function bipolarCommandHasDeclaredRailsAndDeadTime(testCase)
            p=sc01b_parameters();g=sc01b_gate_signals(p);
            testCase.verifyEqual(g.high_V(1),12,'AbsTol',1e-14);
            testCase.verifyEqual(g.low_V(1),-1.5,'AbsTol',1e-14);
            testCase.verifyEqual(min(g.high_V),-1.5,'AbsTol',1e-14);
            testCase.verifyEqual(max(g.low_V),12,'AbsTol',1e-14);
            testCase.verifyEqual(g.highOn_s-g.lowOff_s,301e-9,'AbsTol',1e-20);
            testCase.verifyEqual(g.lowOn_s-g.highOff_s,301e-9,'AbsTol',1e-20);
        end
        function gateStressVariationRemainsPresent(testCase)
            names=["nominal","holdout_gate47","holdout_bus30_load16_gate10"];
            expected=[25,50,13];
            for k=1:numel(names)
                p=sc01b_case(names(k));
                testCase.verifyEqual(p.driver.outputResistance_Ohm+p.driver.externalResistance_Ohm+ ...
                    p.driver.additionalTurnOnResistance_Ohm,expected(k));
                testCase.verifyEqual(p.driver.turnOffResistance_Ohm,3);
                testCase.verifyEqual(p.driver.offVoltage_V,-1.5);
            end
        end
    end
end
