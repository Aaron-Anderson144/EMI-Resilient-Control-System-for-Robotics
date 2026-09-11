classdef TestPhase3StopHoldStep < matlab.unittest.TestCase
    %TESTPHASE3STOPHOLDSTEP Bounded passive mechanics and discrete energy.
    methods (Test)
        function staticBrakeHoldsBothLoadSignsWithoutDissipatingAtRest(testCase)
            p=actuator_parameters();initial=[.7;0;0];capacity=.04;
            for load=[-.03,0,.03]
                [next,d]=phase3_stop_hold_step(initial,.001,p,load,capacity,0);
                testCase.verifyEqual(next,initial);
                testCase.verifyEqual(d.brakeTorque_Nm,-load);
                testCase.verifyEqual([d.brakeLoss_J,d.loadWork_J,d.energyChange_J,d.numericalLoss_J],zeros(1,4));
            end
        end

        function exactCapacityBoundaryHoldsAndAnOverloadSlips(testCase)
            p=actuator_parameters();capacity=.02;
            for direction=[-1,1]
                [held,d]=phase3_stop_hold_step(zeros(3,1),.001,p,direction*capacity,capacity,0);
                testCase.verifyEqual(held,zeros(3,1));
                testCase.verifyEqual(d.brakeTorque_Nm,-direction*capacity);
                [slip,d]=phase3_stop_hold_step(zeros(3,1),.001,p,direction*capacity*(1+1e-5),capacity,0);
                testCase.verifyLessThan(direction*slip(2),0);
                testCase.verifyEqual(d.brakeTorque_Nm,-direction*capacity);
                testCase.verifyGreaterThan(d.brakeLoss_J,0);
            end
        end

        function overloadHasTheAnalyticalImplicitVelocity(testCase)
            p=actuator_parameters();h=.002;load=.03;capacity=.008;resistance=.7;
            R=p.electrical.resistance_Ohm;L=p.electrical.inductance_H;
            J=p.mechanical.inertia_kg_m2;b=p.mechanical.viscousDamping_Nm_s_rad;K=p.motor.torqueConstant_Nm_A;
            g=h*K/(L+h*(R+resistance));D=J/h+b+K*g;
            [next,d]=phase3_stop_hold_step([.2;0;0],h,p,load,capacity,resistance);
            expectedVelocity=-(load-capacity)/D;
            testCase.verifyEqual(next,[.2+h*expectedVelocity;expectedVelocity;-g*expectedVelocity],'AbsTol',1e-14);
            testCase.verifyEqual(d.brakeTorque_Nm,-capacity);
        end

        function passiveSlidingEquilibriumIsPreservedForBothSigns(testCase)
            p=actuator_parameters();h=.003;capacity=.005;external=.3;
            R=p.electrical.resistance_Ohm+external;K=p.motor.torqueConstant_Nm_A;
            b=p.mechanical.viscousDamping_Nm_s_rad;
            for direction=[-1,1]
                load=direction*.02;velocity=-direction*(abs(load)-capacity)/(b+K^2/R);current=-K*velocity/R;
                [next,d]=phase3_stop_hold_step([.2;velocity;current],h,p,load,capacity,external);
                testCase.verifyEqual(next,[.2+h*velocity;velocity;current],'AbsTol',1e-13);
                testCase.verifyEqual(d.energyChange_J,0,'AbsTol',1e-15);
                testCase.verifyEqual(d.energyResidual_J,0,'AbsTol',1e-15);
            end
        end

        function unloadedPassiveMotionCannotCreateStoredEnergy(testCase)
            p=actuator_parameters();x=[0;15;2];before=localEnergy(x,p);
            for k=1:500
                [x,d]=phase3_stop_hold_step(x,.001,p,0,0,0);
                after=localEnergy(x,p);
                testCase.verifyLessThanOrEqual(after,before+1e-14);
                testCase.verifyEqual(d.energyResidual_J,0,'AbsTol',1e-14);
                before=after;
            end
            testCase.verifyLessThan(before,1e-9);
        end

        function nonzeroCurrentCanBeHeldWhileElectricalEnergyDecays(testCase)
            p=actuator_parameters();h=.001;
            for direction=[-1,1]
                initialCurrent=direction*2;
                [next,d]=phase3_stop_hold_step([.4;0;initialCurrent],h,p,0,.15,0);
                expectedCurrent=initialCurrent/(1+h*p.electrical.resistance_Ohm/p.electrical.inductance_H);
                testCase.verifyEqual(next,[.4;0;expectedCurrent],'AbsTol',1e-14);
                testCase.verifyEqual(d.brakeTorque_Nm,p.motor.torqueConstant_Nm_A*expectedCurrent,'AbsTol',1e-14);
                testCase.verifyEqual(d.brakeLoss_J,0);
                testCase.verifyGreaterThan(d.copperLoss_J,0);
                testCase.verifyLessThan(d.energyChange_J,0);
                testCase.verifyEqual(d.energyResidual_J,0,'AbsTol',1e-15);
            end
        end

        function exactCaptureUsesABoundedTorqueImpulseAndNumericalLoss(testCase)
            p=localUnitParameters();h=.25;initial=[.5;.25;0];capacity=1;
            [next,d]=phase3_stop_hold_step(initial,h,p,0,capacity,0);
            testCase.verifyEqual(next,[.5;0;0]);
            testCase.verifyEqual(d.brakeTorque_Nm,capacity);
            testCase.verifyEqual(d.brakeTorque_Nm*h,p.mechanical.inertia_kg_m2*initial(2));
            testCase.verifyEqual(d.brakeLoss_J,0);
            testCase.verifyEqual(d.numericalLoss_J,.5*initial(2)^2);
            testCase.verifyEqual(d.energyResidual_J,0);
        end

        function insufficientCapacityCannotManufactureAnInstantaneousStop(testCase)
            p=localUnitParameters();h=.25;initial=[0;.25;0];capacity=.5;
            [next,d]=phase3_stop_hold_step(initial,h,p,0,capacity,0);
            testCase.verifyGreaterThan(next(2),0);
            testCase.verifyLessThan(next(2),initial(2));
            testCase.verifyLessThanOrEqual(abs(d.brakeTorque_Nm*h),capacity*h);
            momentumChange=p.mechanical.inertia_kg_m2*(next(2)-initial(2));
            impulse=h*(p.motor.torqueConstant_Nm_A*next(3)-d.brakeTorque_Nm);
            testCase.verifyEqual(momentumChange,impulse,'AbsTol',1e-14);
        end

        function externalResistorVoltageAndHeatHavePassiveSigns(testCase)
            p=actuator_parameters();h=.001;initial=[.2;3;1];external=2;
            [next,d]=phase3_stop_hold_step(initial,h,p,.01,.02,external);
            testCase.verifyEqual(d.motorTerminalVoltage_V,-external*next(3),'AbsTol',1e-14);
            testCase.verifyEqual(d.resistorLoss_J,-d.motorTerminalVoltage_V*next(3)*h,'AbsTol',1e-15);
            testCase.verifyGreaterThan(d.resistorLoss_J,0);
            [~,zero]=phase3_stop_hold_step(initial,h,p,.01,.02,0);
            testCase.verifyEqual([zero.motorTerminalVoltage_V,zero.resistorLoss_J],[0,0]);
        end

        function independentStoredEnergyDifferenceMatchesTheLedger(testCase)
            p=actuator_parameters();stream=RandStream('mt19937ar','Seed',260940);
            for k=1:120
                initial=[2*rand(stream)-1;40*rand(stream)-20;6*rand(stream)-3];
                h=.0001+.004*rand(stream);load=.1*rand(stream)-.05;
                capacity=.15*rand(stream);external=10*rand(stream);
                [next,d]=phase3_stop_hold_step(initial,h,p,load,capacity,external);
                physicalLoss=d.copperLoss_J+d.resistorLoss_J+d.viscousLoss_J+d.brakeLoss_J;
                independentChange=localEnergy(next,p)-localEnergy(initial,p);
                testCase.verifyEqual(d.energyChange_J,independentChange,'AbsTol',1e-14);
                testCase.verifyEqual(independentChange,d.loadWork_J-physicalLoss-d.numericalLoss_J,'AbsTol',1e-14);
                testCase.verifyEqual(d.energyResidual_J,0,'AbsTol',1e-14);
                testCase.verifyGreaterThanOrEqual(min([d.copperLoss_J,d.resistorLoss_J,d.viscousLoss_J,d.brakeLoss_J,d.numericalLoss_J]),0);
                testCase.verifyLessThanOrEqual(abs(d.brakeTorque_Nm),capacity);
            end
        end

        function reversingStateAndLoadReversesMotionButPreservesDissipation(testCase)
            p=actuator_parameters();initial=[.4;7;-.3];
            [positive,a]=phase3_stop_hold_step(initial,.002,p,.012,.02,.8);
            [negative,b]=phase3_stop_hold_step(-initial,.002,p,-.012,.02,.8);
            testCase.verifyEqual(negative,-positive,'AbsTol',1e-14);
            testCase.verifyEqual(b.brakeTorque_Nm,-a.brakeTorque_Nm);
            testCase.verifyEqual(b.motorTerminalVoltage_V,-a.motorTerminalVoltage_V);
            for name={'loadWork_J','copperLoss_J','resistorLoss_J','viscousLoss_J','brakeLoss_J','numericalLoss_J','energyChange_J','energyResidual_J'}
                testCase.verifyEqual(b.(name{1}),a.(name{1}),'AbsTol',1e-14);
            end
        end

        function positionOffsetDoesNotInventStoredPotentialEnergy(testCase)
            p=actuator_parameters();initial=[.1;2;-.4];shifted=initial;shifted(1)=initial(1)+1.5;
            [a,da]=phase3_stop_hold_step(initial,.001,p,.01,.005,1);
            [b,db]=phase3_stop_hold_step(shifted,.001,p,.01,.005,1);
            testCase.verifyEqual(b-a,[1.5;0;0],'AbsTol',1e-14);
            testCase.verifyEqual(db,da);
        end

        function loadWorkCanRemoveOrSupplyEnergyAccordingToMotionDirection(testCase)
            p=actuator_parameters();
            [~,opposing]=phase3_stop_hold_step([0;5;0],.001,p,.02,0,0);
            [~,driving]=phase3_stop_hold_step([0;-5;0],.001,p,.02,0,0);
            testCase.verifyLessThan(opposing.loadWork_J,0);
            testCase.verifyGreaterThan(driving.loadWork_J,0);
        end

        function malformedStateStepLoadAndBoundsAreRejected(testCase)
            p=actuator_parameters();id='EMIProject:InvalidStopHoldInput';
            for state={[],[0;0],[0;0;Inf],[0;0;1i],"state",ones(3,2)}
                testCase.verifyError(@()phase3_stop_hold_step(state{1},.001,p,0,0,0),id);
            end
            for step={0,-.001,NaN,[.001,.002]}
                testCase.verifyError(@()phase3_stop_hold_step(zeros(3,1),step{1},p,0,0,0),id);
            end
            testCase.verifyError(@()phase3_stop_hold_step(zeros(3,1),.001,p,NaN,0,0),id);
            testCase.verifyError(@()phase3_stop_hold_step(zeros(3,1),.001,p,0,-1,0),id);
            testCase.verifyError(@()phase3_stop_hold_step(zeros(3,1),.001,p,0,0,-1),id);
            testCase.verifyError(@()phase3_stop_hold_step(zeros(3,1),.001,p,0,Inf,0),id);
        end

        function nonreciprocalConstantsAndInvalidPhysicalParametersAreRejected(testCase)
            p=actuator_parameters();bad=p;bad.motor.backEmfConstant_V_s_rad=.081;
            testCase.verifyError(@()phase3_stop_hold_step(zeros(3,1),.001,bad,0,0,0),'EMIProject:NonreciprocalStopHoldModel');
            id='EMIProject:InvalidStopHoldParameters';invalid={};
            bad=p;bad.electrical.resistance_Ohm=0;invalid{end+1}=bad;
            bad=p;bad.electrical.inductance_H=NaN;invalid{end+1}=bad;
            bad=p;bad.mechanical.inertia_kg_m2=-1;invalid{end+1}=bad;
            bad=p;bad.mechanical.viscousDamping_Nm_s_rad=-1;invalid{end+1}=bad;
            bad=p;bad.motor.torqueConstant_Nm_A=0;invalid{end+1}=bad;
            bad=p;bad.motor=rmfield(bad.motor,'torqueConstant_Nm_A');invalid{end+1}=bad;
            for k=1:numel(invalid)
                testCase.verifyError(@()phase3_stop_hold_step(zeros(3,1),.001,invalid{k},0,0,0),id);
            end
        end

        function integerInputsAreNormalizedBeforePhysicalArithmetic(testCase)
            p=actuator_parameters();
            [actual,a]=phase3_stop_hold_step(int16([0;1;0]),.001,p,int32(0),uint8(1),uint8(0));
            [expected,b]=phase3_stop_hold_step([0;1;0],.001,p,0,1,0);
            testCase.verifyClass(actual,'double');testCase.verifyEqual(actual,expected);testCase.verifyEqual(a,b);
        end

        function unrepresentableIntermediateOrOutputArithmeticFailsExplicitly(testCase)
            p=actuator_parameters();id='EMIProject:StopHoldOverflow';
            testCase.verifyError(@()phase3_stop_hold_step([0;1;0],1e-320,p,0,0,0),id);
            testCase.verifyError(@()phase3_stop_hold_step([0;realmax;0],.001,p,0,0,0),id);
            bad=p;bad.electrical.resistance_Ohm=realmax;
            testCase.verifyError(@()phase3_stop_hold_step(zeros(3,1),.001,bad,0,0,realmax),id);
        end
    end
end

function energy=localEnergy(x,p)
energy=.5*p.mechanical.inertia_kg_m2*x(2)^2+.5*p.electrical.inductance_H*x(3)^2;
end

function p=localUnitParameters()
p.electrical=struct('resistance_Ohm',1,'inductance_H',1);
p.mechanical=struct('inertia_kg_m2',1,'viscousDamping_Nm_s_rad',0);
p.motor=struct('torqueConstant_Nm_A',1,'backEmfConstant_V_s_rad',1);
end
