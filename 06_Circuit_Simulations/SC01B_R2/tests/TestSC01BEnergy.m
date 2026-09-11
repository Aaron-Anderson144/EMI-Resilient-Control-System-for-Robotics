classdef TestSC01BEnergy < matlab.unittest.TestCase
    methods (Test)
        function constantResistorClosesAndCurrentMismatchDoesNot(testCase)
            [r,p]=energyFixture();p.load.resistance_Ohm=8;
            b=sc01b_energy_balance(r,p);
            expected=24*3*(p.simulation.stopTime_s-p.validation.startTime_s);
            testCase.verifyEqual(b.DCSourceEnergy_J,expected,'AbsTol',1e-16);
            testCase.verifyEqual(b.LoadResistorEnergy_J,expected,'AbsTol',1e-16);
            testCase.verifyEqual(b.Residual_J,0,'AbsTol',1e-16);
            r.feedCurrent_A(:)=3.1;
            bad=sc01b_energy_balance(r,p);
            testCase.verifyEqual(bad.Residual_J,24*0.1*(p.simulation.stopTime_s-p.validation.startTime_s),'AbsTol',1e-16);
        end

        function inductorRampAndLinearProductHaveAnalyticEnergy(testCase)
            [r,p]=energyFixture();p.load.resistance_Ohm=0;p.load.inductance_H=1;
            r.loadCurrent_A=3+24*r.time_s;r.feedCurrent_A=r.loadCurrent_A;r.highCurrent_A=r.loadCurrent_A;
            b=sc01b_energy_balance(r,p);
            testCase.verifyEqual(b.Residual_J,0,'AbsTol',2e-15);
            testCase.verifyEqual(b.DCSourceEnergy_J,b.LoadInductorStorageChange_J,'AbsTol',2e-15);
            % The square of a linear voltage/current ramp integrates as t^3/3,
            % even on an uneven grid. Endpoint-power trapezoids do not do so.
            p.load.inductance_H=0;p.bus.voltage_V=0;
            r.feedCurrent_A(:)=0;r.highVds_V=r.time_s*1e6;r.highCurrent_A=-r.time_s*1e6;
            b=sc01b_energy_balance(r,p);
            expected=-(p.simulation.stopTime_s^3-p.validation.startTime_s^3)/3*1e12;
            testCase.verifyEqual(b.HighDeviceTerminalEnergy_J,expected,'AbsTol',1e-17);
            testCase.verifyEqual(b.Residual_J,-expected,'AbsTol',1e-17);
            testCase.verifyGreaterThan(b.EnergyScale_J,0);
            testCase.verifyFalse(b.SemiconductorHeatKnown);
        end
    end
end

function [r,p]=energyFixture()
p=sc01b_parameters();
p.bus.feedResistance_Ohm=0;p.bus.feedInductance_H=0;p.bus.capacitance_F=0;p.bus.capacitorESR_Ohm=0;
p.load.inductance_H=0;p.driver.outputResistance_Ohm=0;p.driver.externalResistance_Ohm=0;
t=[0;0.7;1.2;1.8;2.3;3.4;4.6;5]*1e-6;
z=zeros(size(t));
r=struct('time_s',t,'bus_V',24+z,'highVds_V',z,'lowVds_V',z, ...
    'highVgs_V',z,'lowVgs_V',z,'highCurrent_A',3+z,'lowCurrent_A',z, ...
    'highGateCurrent_A',z,'lowGateCurrent_A',z,'loadCurrent_A',3+z,'feedCurrent_A',3+z);
end
