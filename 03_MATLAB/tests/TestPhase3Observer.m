classdef TestPhase3Observer < matlab.unittest.TestCase
    %TESTPHASE3OBSERVER Causal replay, credible samples and timeout boundaries.
    methods (Test)
        function correctionPolesAndSecondsStayConsistentAcrossSampleTimes(testCase)
            p=actuator_parameters();
            for Ts=[.001,.0005]
                p.control.sampleTime_s=Ts;c=phase3_observer_configuration(p);
                poles=eig((eye(3)-c.correctionGain*c.C)*c.A);
                testCase.verifyEqual(sort(poles),sort(exp(-[80;100;120]*Ts)),'AbsTol',1e-7);
                testCase.verifyLessThan(max(abs(poles)),1);
                testCase.verifyEqual(c.historyDuration_s,.032);
                testCase.verifyEqual(c.maxMeasurementAge_s,.020);
                testCase.verifyEqual(c.maxPredictionTime_s,.250);
                testCase.verifyEqual(c.historyCapacity,ceil(.032/Ts)+1);
            end
        end

        function smallInitialMismatchConvergesWithoutCleanFalseAlarms(testCase)
            c=phase3_observer_configuration(actuator_parameters(), ...
                struct('initialEstimate',[deg2rad(.2);0;0]));
            state=phase3_observer_initialize(c);truth=zeros(3,1);
            allAccepted=true;anyAlarm=false;previousVoltage=0;
            for k=1:400
                [state,d]=phase3_observer_step(state,c.C*truth,k,true,previousVoltage);
                allAccepted=allAccepted && d.measurementAccepted;
                anyAlarm=anyAlarm || d.alarm;
                if k<400
                    previousVoltage=.7*sin(k/25);
                    truth=c.A*truth+c.B*[previousVoltage;c.assumedLoadTorque_Nm];
                end
            end
            testCase.verifyTrue(allAccepted);
            testCase.verifyFalse(anyAlarm);
            testCase.verifyLessThan(norm(state.estimatedState-truth),1e-8);
        end

        function delayedReplayMatchesUndelayedSourcePosteriorWithAppliedInputHistory(testCase)
            c=phase3_observer_configuration(actuator_parameters(), ...
                struct('initialEstimate',[deg2rad(.2);0;0],'assumedLoadTorque_Nm',.01));
            eager=phase3_observer_initialize(c);delayed=phase3_observer_initialize(c);
            n=200;delay=8;truth=zeros(3,n);posterior=zeros(3,n);
            command=2*sin((1:n)'/9);limit=ones(n,1);limit(60:90)=0;limit(91:130)=.4;
            applied=min(max(command,-limit),limit);maxDifference=0;anyAlarm=false;
            for k=1:n
                previous=0;if k>1,previous=applied(k-1);end
                [eager,~]=phase3_observer_step(eager,c.C*truth(:,k),k,true,previous);
                posterior(:,k)=eager.estimatedState;
                source=k-delay;
                if source>=1
                    [delayed,d]=phase3_observer_step(delayed,c.C*truth(:,source),source,true,previous);
                    expected=posterior(:,source);
                    for replay=source+1:k
                        expected=c.A*expected+c.B*[applied(replay-1);c.assumedLoadTorque_Nm];
                    end
                    maxDifference=max(maxDifference,max(abs(delayed.estimatedState-expected)));
                    testCase.verifyEqual(d.trustedAge_s,delay*c.sampleTime_s,'AbsTol',1e-14);
                    testCase.verifyTrue(d.measurementAccepted);
                else
                    [delayed,d]=phase3_observer_step(delayed,NaN,NaN,false,previous);
                end
                anyAlarm=anyAlarm || d.alarm;
                if k<n,truth(:,k+1)=c.A*truth(:,k)+c.B*[applied(k);c.assumedLoadTorque_Nm];end
            end
            testCase.verifyLessThan(maxDifference,1e-10);
            testCase.verifyFalse(anyAlarm);
            testCase.verifySize(delayed.historyStates,[3,c.historyCapacity]);
            testCase.verifyLessThanOrEqual(nnz(delayed.historyIndices),c.historyCapacity);
        end

        function corruptValueCannotPoisonEstimateOrTrustedTimestamp(testCase)
            c=phase3_observer_configuration(actuator_parameters());
            a=phase3_observer_initialize(c);b=a;
            [a,~]=phase3_observer_step(a,0,1,true,0);[b,~]=phase3_observer_step(b,0,1,true,0);
            [a,rejected]=phase3_observer_step(a,pi+.1,2,true,.1);
            [b,~]=phase3_observer_step(b,NaN,NaN,false,.1);
            testCase.verifyEqual(a.estimatedState,b.estimatedState);
            testCase.verifyEqual(rejected.gateReason,"position_range");
            testCase.verifyTrue(rejected.alarm);
            testCase.verifyFalse(rejected.measurementAccepted || rejected.credibleFresh);
            testCase.verifyEqual(rejected.trustedSourceIndex,1);
            testCase.verifyEqual(rejected.lastSeenSourceIndex,2);
            expected=c.A*b.estimatedState+c.B*[.2;c.assumedLoadTorque_Nm];
            [a,recovered]=phase3_observer_step(a,c.C*expected,3,true,.2);
            testCase.verifyEqual(a.estimatedState,expected,'AbsTol',1e-13);
            testCase.verifyTrue(recovered.credibleFresh);
            testCase.verifyFalse(recovered.alarm);
        end

        function rateAndInnovationGatesAreIndependent(testCase)
            c=phase3_observer_configuration(actuator_parameters(), ...
                struct('residualTrip_rad',1,'residualClear_rad',.5));
            s=phase3_observer_initialize(c);[s,~]=phase3_observer_step(s,0,1,true,0);
            [~,rate]=phase3_observer_step(s,.1,2,true,0);
            testCase.verifyEqual(rate.gateReason,"position_rate");
            testCase.verifyFalse(rate.measurementAccepted);
            c=phase3_observer_configuration(actuator_parameters());s=phase3_observer_initialize(c);
            [s,~]=phase3_observer_step(s,0,1,true,0);
            [~,residual]=phase3_observer_step(s,deg2rad(.6),2,true,0);
            testCase.verifyEqual(residual.gateReason,"innovation_limit");
            testCase.verifyTrue(residual.residualLatched);
        end

        function residualHysteresisNeedsNewAcceptedClearSample(testCase)
            c=phase3_observer_configuration(actuator_parameters());s=phase3_observer_initialize(c);
            [s,~]=phase3_observer_step(s,0,1,true,0);
            [s,trip]=phase3_observer_step(s,deg2rad(.6),2,true,0);
            [s,held]=phase3_observer_step(s,0,2,false,0);
            prediction=c.A*s.estimatedState;
            [s,middle]=phase3_observer_step(s,c.C*prediction+deg2rad(.375),4,true,0);
            prediction=c.A*s.estimatedState;
            [~,clear]=phase3_observer_step(s,c.C*prediction+deg2rad(.1),5,true,0);
            testCase.verifyTrue(trip.alarm && held.alarm && middle.alarm);
            testCase.verifyFalse(held.credibleFresh || middle.credibleFresh);
            testCase.verifyTrue(middle.measurementAccepted);
            testCase.verifyTrue(clear.credibleFresh);
            testCase.verifyFalse(clear.alarm || clear.residualLatched);
        end

        function exactResidualLimitsAreInclusive(testCase)
            c=phase3_observer_configuration(actuator_parameters());s=phase3_observer_initialize(c);
            [~,tripBoundary]=phase3_observer_step(s,c.residualTrip_rad,1,true,0);
            [~,clearBoundary]=phase3_observer_step(s,c.residualClear_rad,1,true,0);
            testCase.verifyTrue(tripBoundary.measurementAccepted);
            testCase.verifyFalse(tripBoundary.credibleFresh || tripBoundary.alarm);
            testCase.verifyTrue(clearBoundary.credibleFresh);
        end

        function duplicatesAndFutureTimestampsNeverCorrectTwice(testCase)
            c=phase3_observer_configuration(actuator_parameters());s=phase3_observer_initialize(c);
            [s,future]=phase3_observer_step(s,0,100,true,0);
            testCase.verifyEqual(future.gateReason,"invalid_timestamp");
            testCase.verifyEqual(s.lastSeenSourceIndex,0);
            [s,valid]=phase3_observer_step(s,deg2rad(.1),1,true,0);
            expected=c.A*s.estimatedState;
            [s,duplicate]=phase3_observer_step(s,deg2rad(.1),1,true,0);
            testCase.verifyTrue(valid.measurementAccepted);
            testCase.verifyEqual(duplicate.gateReason,"nonincreasing_timestamp");
            testCase.verifyEqual(s.estimatedState,expected,'AbsTol',1e-13);
            testCase.verifyFalse(duplicate.credibleFresh);
        end

        function nonfiniteMeasurementIsRejectedWithoutTrust(testCase)
            c=phase3_observer_configuration(actuator_parameters());s=phase3_observer_initialize(c);
            [s,bad]=phase3_observer_step(s,NaN,1,true,0);
            testCase.verifyEqual(bad.gateReason,"nonfinite_measurement");
            testCase.verifyEqual(bad.trustedSourceIndex,0);
            testCase.verifyEqual(s.estimatedState,zeros(3,1));
            [~,good]=phase3_observer_step(s,0,2,true,0);
            testCase.verifyTrue(good.credibleFresh);
            testCase.verifyFalse(good.alarm);
        end

        function missingSamplesHonorGraceThenPredictionExpiry(testCase)
            c=phase3_observer_configuration(actuator_parameters());s=phase3_observer_initialize(c);
            [s,~]=phase3_observer_step(s,0,1,true,0);
            for k=2:252
                [s,d]=phase3_observer_step(s,0,1,false,0);
                testCase.verifyFalse(d.credibleFresh || d.measurementAccepted);
                if k==21,testCase.verifyFalse(d.alarm);end
                if k==22,testCase.verifyTrue(d.alarm);testCase.verifyTrue(d.estimateUsable);end
                if k==251,testCase.verifyTrue(d.estimateUsable);end
            end
            testCase.verifyFalse(d.estimateUsable);
            testCase.verifyEqual(d.predictionAge_s,.251,'AbsTol',1e-14);
        end

        function initialPredictionHasExplicitGraceWithoutInventedTrustedTimestamp(testCase)
            c=phase3_observer_configuration(actuator_parameters());s=phase3_observer_initialize(c);
            [s,initial]=phase3_observer_step(s,NaN,NaN,false,0);
            testCase.verifyTrue(isinf(initial.trustedAge_s));
            testCase.verifyEqual(initial.trustedSourceIndex,0);
            testCase.verifyFalse(initial.alarm || initial.credibleFresh);
            for k=2:22,[s,d]=phase3_observer_step(s,NaN,NaN,false,0);end
            testCase.verifyTrue(d.alarm && d.estimateUsable);
        end

        function largePredictionOverrideDoesNotEnlargeFreshnessTolerance(testCase)
            c=phase3_observer_configuration(actuator_parameters(),struct('maxPredictionTime_s',1e20));
            s=phase3_observer_initialize(c);[s,~]=phase3_observer_step(s,0,1,true,0);
            for k=2:22,[s,d]=phase3_observer_step(s,NaN,NaN,false,0);end
            testCase.verifyTrue(d.stale && d.alarm && d.estimateUsable);
            s=phase3_observer_initialize(c);
            for k=1:21,[s,~]=phase3_observer_step(s,NaN,NaN,false,0);end
            [~,old]=phase3_observer_step(s,0,1,true,0);
            testCase.verifyEqual(old.gateReason,"measurement_too_old");
        end

        function oldPacketAgeAndEvictedHistoryFailClosed(testCase)
            c=phase3_observer_configuration(actuator_parameters());s=phase3_observer_initialize(c);
            for k=1:21,[s,~]=phase3_observer_step(s,NaN,NaN,false,0);end
            [s,old]=phase3_observer_step(s,0,1,true,0);
            testCase.verifyEqual(old.gateReason,"measurement_too_old");
            testCase.verifyEqual(old.trustedSourceIndex,0);
            for k=23:49,[s,~]=phase3_observer_step(s,NaN,NaN,false,0);end
            [~,evicted]=phase3_observer_step(s,0,2,true,0);
            testCase.verifyEqual(evicted.gateReason,"outside_history");
            testCase.verifyFalse(evicted.measurementAccepted);
        end

        function invalidConfigurationAndAppliedInputAreRejected(testCase)
            p=actuator_parameters();id='EMIProject:InvalidObserverConfiguration';
            testCase.verifyError(@()phase3_observer_configuration(p,struct('historyDuration_s',.01)),id);
            testCase.verifyError(@()phase3_observer_configuration(p,struct('residualClear_rad',1)),id);
            testCase.verifyError(@()phase3_observer_configuration(p,struct('rateLimit_rad_s',NaN)),id);
            testCase.verifyError(@()phase3_observer_configuration(p,struct('unknown',1)),id);
            testCase.verifyError(@()phase3_observer_configuration(p,struct('poleRates_rad_s',[80,80,120])),id);
            c=phase3_observer_configuration(p);bad=c;bad.sampleTime_s=.0005;
            testCase.verifyError(@()phase3_observer_initialize(bad),id);
            bad=c;bad.correctionGain(:)=0;
            testCase.verifyError(@()phase3_observer_initialize(bad),id);
            s=phase3_observer_initialize(c);
            testCase.verifyError(@()phase3_observer_step(s,0,1,true,Inf),'EMIProject:InvalidObserverInput');
            testCase.verifyError(@()phase3_observer_step(s,0,1,2,0),'EMIProject:InvalidObserverInput');
        end

        function numericOverridesNormalizeWithoutIntegerVoltageArithmetic(testCase)
            p=actuator_parameters();c=phase3_observer_configuration(p,struct('assumedLoadTorque_Nm',int32(0)));
            s=phase3_observer_initialize(c);[s,~]=phase3_observer_step(s,0,1,true,0);
            [s,~]=phase3_observer_step(s,NaN,NaN,false,.125);
            testCase.verifyClass(s.config.assumedLoadTorque_Nm,'double');
            testCase.verifyEqual(s.estimatedState,c.B*[.125;0],'AbsTol',1e-14);
        end
    end
end
