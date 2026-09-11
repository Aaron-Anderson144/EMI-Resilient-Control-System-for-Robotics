classdef TestFourWayPlantEvents < matlab.unittest.TestCase
    % Independent matrix-exponential fixtures for causal angle events.
    methods (Test)
        function exactStateMatchesAugmentedMatrixExponential(testCase)
            p = actuator_parameters(); x = [0.017;-2.3;0.8];
            times = [0,1e-12,5e-6,5e-4,1e-3];
            actual = fourway_plant_state(x,17,0.03,times,p);
            expected = independentState(x,17,0.03,times,p);
            testCase.verifyEqual(actual,expected,'AbsTol',3e-12);
            testCase.verifyEqual(actual(:,1),x,'AbsTol',0);
        end

        function positiveAndNegativeGrayOrder(testCase)
            p = actuator_parameters(); delta = 2*pi/4096; dt = 1e-3;
            for direction = [-1,1]
                speed = direction*4*delta/dt;
                [x,voltage] = steadyMotion(0,speed,p);
                [events,next] = fourway_plant_events(x,voltage,0,dt,p,0);
                testCase.verifyEqual(events.newCount,direction*(1:4).');
                testCase.verifyEqual(events.direction,repmat(direction,4,1));
                testCase.verifyEqual(events.time_s,((0.5:3.5)*delta/abs(speed)).', ...
                    'AbsTol',1e-12);
                if direction > 0, expectedBits = [1,0;1,1;0,1;0,0];
                else, expectedBits = [0,1;1,1;1,0;0,0]; end
                testCase.verifyEqual([events.A,events.B],logical(expectedBits));
                testCase.verifyEqual(next(1),direction*4*delta,'AbsTol',1e-14);
            end
        end

        function interiorReversalCannotBeInferredFromEndpoints(testCase)
            p = actuator_parameters(); delta = 2*pi/4096; dt = 1e-3;
            turn = [0.6*delta;0;-5];
            x = independentState(turn,0,0,-dt/2,p);
            [events,next] = fourway_plant_events(x,0,0,dt,p,0);
            testCase.verifyEqual(floor([x(1),next(1)]/delta+0.5),[0,0]);
            testCase.verifyEqual(events.newCount,[1;0]);
            testCase.verifyEqual(events.direction,[1;-1]);
            testCase.verifyLessThan(events.time_s(1),dt/2);
            testCase.verifyGreaterThan(events.time_s(2),dt/2);
            boundaries = independentState(x,0,0,events.time_s,p);
            testCase.verifyEqual(boundaries(1,:),[delta/2,delta/2],'AbsTol',1e-12);
        end

        function tangencyAtEitherBoundaryDoesNotTransition(testCase)
            p = actuator_parameters(); delta = 2*pi/4096; dt = 1e-3;
            for direction = [-1,1]
                turn = [direction*delta/2;0;-direction*5];
                x = independentState(turn,0,0,-dt/2,p);
                events = fourway_plant_events(x,0,0,dt,p,0);
                testCase.verifyEmpty(events);
            end
        end

        function crossingAtSampleEndpointPrecedesSampleAndDoesNotRepeat(testCase)
            p = actuator_parameters(); delta = 2*pi/4096; dt = 1e-3;
            for direction = [-1,1]
                [x,voltage] = steadyMotion(0,direction*delta/(2*dt),p);
                [events,next] = fourway_plant_events(x,voltage,0,dt,p,0);
                testCase.verifyEqual(events.time_s,dt,'AbsTol',1e-12);
                testCase.verifyEqual(events.newCount,direction);
                second = fourway_plant_events(next,voltage,0,dt,p,direction);
                testCase.verifyEmpty(second);
            end
        end

        function rightLimitAtNegativeBoundaryAndAccelerationStart(testCase)
            p = actuator_parameters(); delta = 2*pi/4096;
            [x,voltage] = steadyMotion(delta/2,-delta,p);
            events = fourway_plant_events(x,voltage,0,1e-3,p,1);
            testCase.verifyEqual(events.time_s,0);
            testCase.verifyEqual(events.newCount,0);
            events = fourway_plant_events([delta/2;0;-1],0,0,1e-3,p,1);
            testCase.verifyEqual(events.time_s,0);
            testCase.verifyEqual(events.newCount,0);
        end

        function stationaryBoundaryIsNotAnArtificialTransition(testCase)
            p = actuator_parameters(); delta = 2*pi/4096;
            [events,next] = fourway_plant_events([delta/2;0;0],0,0,1e-3,p,1);
            testCase.verifyEmpty(events);
            testCase.verifyEqual(next,[delta/2;0;0],'AbsTol',0);
        end

        function subdividingHeldIntervalPreservesEventsAndCounts(testCase)
            p = actuator_parameters(); delta = 2*pi/4096; dt = 1e-3;
            x = independentState([2.6*delta;0;-20],0,0,-dt/2,p);
            initial = floor(x(1)/delta+0.5);
            [whole,next] = fourway_plant_events(x,0,0,dt,p,initial);
            [first,mid] = fourway_plant_events(x,0,0,dt/2,p,initial);
            if isempty(first), current = initial; else, current = first.newCount(end); end
            [second,splitNext] = fourway_plant_events(mid,0,0,dt/2,p,current);
            second.time_s = second.time_s+dt/2;
            joined = [first;second];
            testCase.verifyEqual(joined.newCount,whole.newCount);
            testCase.verifyEqual(joined.time_s,whole.time_s,'AbsTol',1e-12);
            testCase.verifyEqual(splitNext,next,'AbsTol',1e-12);
        end

        function rootsWithinOnePicosecondBecomeJointState(testCase)
            p = actuator_parameters(); delta = 2*pi/4096; dt = 1e-12;
            [x,voltage] = steadyMotion(0,4*delta/dt,p);
            events = fourway_plant_events(x,voltage,0,dt,p,0);
            testCase.verifyEqual(height(events),1);
            testCase.verifyEqual(events.newCount,4);
            testCase.verifyEqual([events.A,events.B],false(1,2));
        end

        function continuousMetricsMatchIndependentReference(testCase)
            p = actuator_parameters(); x = [0.1;2;-0.7]; dt = 1e-3;
            [~,~,stats] = fourway_plant_events(x,19,0.025,dt,p);
            samples = independentState(x,19,0.025,linspace(0,dt,1001),p);
            testCase.verifyGreaterThanOrEqual(stats.peakAbsVelocity_rad_s, ...
                max(abs(samples(2,:)))-1e-12);
            testCase.verifyEqual(stats.peakAbsVelocity_rad_s,max(abs(samples(2,:))), ...
                'AbsTol',2e-6);
            testCase.verifyGreaterThanOrEqual(stats.peakAbsCurrent_A, ...
                max(abs(samples(3,:)))-1e-12);
            testCase.verifyEqual(stats.peakAbsCurrent_A,max(abs(samples(3,:))), ...
                'AbsTol',2e-6);
            integralValue = quadgk(@(t) independentCurrentSquared(x,19,0.025,t,p), ...
                0,dt,'AbsTol',1e-13,'RelTol',1e-12);
            testCase.verifyEqual(stats.currentSquaredIntegral_A2s,integralValue, ...
                'AbsTol',1e-12);
        end

        function continuousPeaksIncludeInteriorCurrentAndSpeedMaxima(testCase)
            p = actuator_parameters(); dt = 1e-3;
            speedPeak = 2;
            balancedCurrent = p.mechanical.viscousDamping_Nm_s_rad*speedPeak/ ...
                p.motor.torqueConstant_Nm_A;
            x = independentState([0;speedPeak;balancedCurrent],-5,0,-dt/2,p);
            [~,next,stats] = fourway_plant_events(x,-5,0,dt,p);
            testCase.verifyGreaterThan(stats.peakAbsVelocity_rad_s,max(abs([x(2),next(2)])));
            testCase.verifyEqual(stats.peakAbsVelocity_rad_s,speedPeak,'AbsTol',1e-12);
            currentPeak = 1; speed = 1;
            voltage = p.motor.backEmfConstant_V_s_rad*speed+ ...
                p.electrical.resistance_Ohm*currentPeak;
            x = independentState([0;speed;currentPeak],voltage,0,-dt/2,p);
            [~,next,stats] = fourway_plant_events(x,voltage,0,dt,p);
            testCase.verifyGreaterThan(stats.peakAbsCurrent_A,max(abs([x(3),next(3)])));
            testCase.verifyEqual(stats.peakAbsCurrent_A,currentPeak,'AbsTol',1e-12);
        end
    end
end

function [x,voltage] = steadyMotion(theta,speed,p)
current = p.mechanical.viscousDamping_Nm_s_rad*speed/p.motor.torqueConstant_Nm_A;
x = [theta;speed;current];
voltage = p.electrical.resistance_Ohm*current+p.motor.backEmfConstant_V_s_rad*speed;
end

function state = independentState(x,voltage,load,times,p)
[A,B] = ssdata(actuator_state_space(p));
augmented = [A,B*[voltage;load];zeros(1,4)];
state = zeros(3,numel(times));
for n = 1:numel(times)
    result = expm(augmented*times(n))*[x;1];
    state(:,n) = result(1:3);
end
end

function value = independentCurrentSquared(x,voltage,load,t,p)
states = independentState(x,voltage,load,t,p);
value = reshape(states(3,:).^2,size(t));
end
