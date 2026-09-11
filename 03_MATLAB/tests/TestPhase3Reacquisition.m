classdef TestPhase3Reacquisition < matlab.unittest.TestCase
    %TESTPHASE3REACQUISITION Independent evidence, bounded uncertainty and trust.
    methods (Test)
        function windowCoversPhysicalDurationAcrossSampleTimes(testCase)
            for Ts=[.001,.0005]
                p=actuator_parameters();p.control.sampleTime_s=Ts;
                c=phase3_reacquisition_configuration(phase3_observer_configuration(p));
                testCase.verifyGreaterThanOrEqual(c.windowSamples,51);
                testCase.verifyGreaterThanOrEqual((c.windowSamples-1)*Ts,.050);
                testCase.verifyTrue(c.modelQualified);
                testCase.verifyLessThan(c.normalizedCondition,c.maxNormalizedCondition);
                testCase.verifyLessThanOrEqual(abs(c.currentStateMap)* ...
                    repmat(c.maxReferenceUncertainty_rad,c.windowSamples,1),c.maxStateUncertainty);
            end
        end

        function fullStateUsesActualInputAndAssumedLoad(testCase)
            [c,~]=localConfiguration();c.assumedLoadTorque_Nm=.006;
            n=c.windowSamples;voltage=.6*sin((1:n)'/7);
            truth=localTrajectory(c,[.3;.4;-.2],voltage);
            [~,d]=localFeed(c,truth(1,:)',voltage,1e-7,n);
            testCase.verifyTrue(d.qualified && d.committed);
            testCase.verifyEqual(d.estimatedState,truth(:,end),'AbsTol',1e-9);
            testCase.verifyGreaterThan(norm(d.estimatedState(2:3)),.01);
        end

        function requestBeforeWindowIsReadyDoesNotQueue(testCase)
            [c,~]=localConfiguration();s=phase3_reacquisition_initialize(c);
            for k=1:c.windowSamples
                in=localInput(k,0);in.request=(k==c.windowSamples-1);
                [s,d]=phase3_reacquisition_step(s,in);
                if k<c.windowSamples,testCase.verifyFalse(d.qualified || d.committed);end
            end
            testCase.verifyTrue(d.qualified);testCase.verifyFalse(d.committed);
        end

        function qualificationAloneNeverCommitsAndWindowStaysBounded(testCase)
            [c,~]=localConfiguration();s=phase3_reacquisition_initialize(c);
            for k=1:4*c.windowSamples,[s,d]=phase3_reacquisition_step(s,localInput(k,0));end
            testCase.verifyTrue(d.qualified);testCase.verifyFalse(d.committed);
            testCase.verifyEqual(s.count,c.windowSamples);
            testCase.verifySize(s.position_rad,[c.windowSamples,1]);
        end

        function commitConsumesEvidenceAndNeedsAnotherCompleteWindow(testCase)
            [c,~]=localConfiguration();s=phase3_reacquisition_initialize(c);
            for k=1:2*c.windowSamples
                in=localInput(k,0);in.request=true;
                [s,d]=phase3_reacquisition_step(s,in);
                testCase.verifyEqual(d.committed,mod(k,c.windowSamples)==0);
                if d.committed,testCase.verifyEqual(s.count,0);end
            end
        end

        function missingReferenceClearsContiguousEvidence(testCase)
            [c,~]=localConfiguration();s=phase3_reacquisition_initialize(c);
            for k=1:c.windowSamples-1,[s,~]=phase3_reacquisition_step(s,localInput(k,0));end
            in=localInput(c.windowSamples,0);in.sampleReceived=false;in.request=true;
            [s,d]=phase3_reacquisition_step(s,in);
            testCase.verifyEqual(d.reason,"missing_sample");testCase.verifyEqual(s.count,0);
            for k=c.windowSamples+1:2*c.windowSamples-1
                [s,d]=phase3_reacquisition_step(s,localInput(k,0));
                testCase.verifyFalse(d.qualified);
            end
            [~,d]=phase3_reacquisition_step(s,localInput(2*c.windowSamples,0));
            testCase.verifyTrue(d.qualified);
        end

        function leavingStopDiscardsWindowAndRejectsRequest(testCase)
            [c,~]=localConfiguration();s=phase3_reacquisition_initialize(c);
            for k=1:c.windowSamples,[s,~]=phase3_reacquisition_step(s,localInput(k,0));end
            in=localInput(c.windowSamples+1,0);in.stopped=false;in.request=true;
            [s,d]=phase3_reacquisition_step(s,in);
            testCase.verifyFalse(d.qualified || d.committed);testCase.verifyEqual(s.count,0);
            in=localInput(c.windowSamples+2,0);in.request=true;
            [~,d]=phase3_reacquisition_step(s,in);testCase.verifyFalse(d.committed);
        end

        function duplicateLateAndFuturePacketsClearEvidence(testCase)
            [c,~]=localConfiguration();s=phase3_reacquisition_initialize(c);
            [s,~]=phase3_reacquisition_step(s,localInput(1,0));
            in=localInput(2,0);in.sourceIndex=1;
            [s,d]=phase3_reacquisition_step(s,in);
            testCase.verifyEqual(d.reason,"nonincreasing_timestamp");testCase.verifyEqual(s.count,0);
            in=localInput(3,0);in.sourceIndex=2;
            [s,d]=phase3_reacquisition_step(s,in);
            testCase.verifyEqual(d.reason,"late_timestamp");testCase.verifyEqual(s.count,0);
            in=localInput(4,0);in.sourceIndex=1e9;
            [s,d]=phase3_reacquisition_step(s,in);
            testCase.verifyEqual(d.reason,"future_timestamp");testCase.verifyEqual(s.lastSeenSourceIndex,1);
            [s,d]=phase3_reacquisition_step(s,localInput(5,0));
            testCase.verifyEqual(d.reason,"collecting");testCase.verifyEqual(s.count,1);
        end

        function malformedReferenceValuesAreFiniteDiagnostics(testCase)
            [c,~]=localConfiguration();bad={NaN,Inf,1i,[0,0],"invalid",[],struct()};
            for field={'position_rad','sourceIndex','uncertainty_rad'}
                for j=1:numel(bad)
                    s=phase3_reacquisition_initialize(c);[s,~]=phase3_reacquisition_step(s,localInput(1,0));
                    in=localInput(2,0);in.(field{1})=bad{j};in.request=true;
                    [s,d]=phase3_reacquisition_step(s,in);
                    testCase.verifyFalse(d.qualified || d.committed);testCase.verifyEqual(s.count,0);
                    testCase.verifyTrue(all(isfinite([d.estimatedState;d.stateUncertainty;d.fitResidual_rad])));
                end
            end
            s=phase3_reacquisition_initialize(c);in=rmfield(localInput(1,0),'position_rad');
            [~,d]=phase3_reacquisition_step(s,in);testCase.verifyEqual(d.reason,"missing_reference_fields");
        end

        function uncertaintyBoundsRejectUnderstatementAndExcess(testCase)
            [c,~]=localConfiguration();
            for uncertainty=[-1,0,c.minReferenceUncertainty_rad/2,2*c.maxReferenceUncertainty_rad]
                s=phase3_reacquisition_initialize(c);in=localInput(1,0);in.uncertainty_rad=uncertainty;
                [s,d]=phase3_reacquisition_step(s,in);
                testCase.verifyEqual(d.reason,"invalid_uncertainty");testCase.verifyEqual(s.count,0);
            end
            for uncertainty=[c.minReferenceUncertainty_rad,c.maxReferenceUncertainty_rad]
                [~,d]=localFeed(c,zeros(c.windowSamples,1),zeros(c.windowSamples,1),uncertainty,0);
                testCase.verifyTrue(d.qualified);
            end
        end

        function implausibleReferencePositionNeverEntersWindow(testCase)
            [c,~]=localConfiguration();s=phase3_reacquisition_initialize(c);
            in=localInput(1,c.positionLimit_rad);in.request=true;
            [s,d]=phase3_reacquisition_step(s,in);
            testCase.verifyEqual(d.reason,"position_range");testCase.verifyEqual(s.count,0);
        end

        function dynamicOutliersCannotQualify(testCase)
            [c,~]=localConfiguration();n=c.windowSamples;
            [~,d]=localFeed(c,.002*(-1).^(1:n)',zeros(n,1),c.maxReferenceUncertainty_rad,n);
            testCase.verifyEqual(d.reason,"dynamic_fit");testCase.verifyFalse(d.committed);
        end

        function smallResidualStillMustAgreeWithDeclaredErrorBound(testCase)
            [c,~]=localConfiguration();n=c.windowSamples;
            [~,d]=localFeed(c,1e-5*(-1).^(1:n)',zeros(n,1),c.minReferenceUncertainty_rad,n);
            testCase.verifyLessThan(d.fitResidual_rad,c.maxFitResidual_rad);
            testCase.verifyEqual(d.reason,"inconsistent_uncertainty");testCase.verifyFalse(d.committed);
        end

        function poorConditionOrWeakNormalizedObservabilityFailsClosed(testCase)
            [~,o]=localConfiguration();
            for override={struct('maxNormalizedCondition',100),struct('minNormalizedSingularValue',1)}
                c=phase3_reacquisition_configuration(o,override{1});n=c.windowSamples;
                [~,d]=localFeed(c,zeros(n,1),zeros(n,1),1e-7,n);
                testCase.verifyEqual(d.reason,"unobservable_window");testCase.verifyFalse(d.committed);
                testCase.verifyTrue(all(isfinite([d.estimatedState;d.stateUncertainty;d.fitResidual_rad])));
            end
        end

        function uncertaintyAmplificationCanRejectAnOtherwiseExactFit(testCase)
            [~,o]=localConfiguration();c=phase3_reacquisition_configuration(o, ...
                struct('maxStateUncertainty',[1e-5;.1;.05]));n=c.windowSamples;
            [~,d]=localFeed(c,zeros(n,1),zeros(n,1),c.maxReferenceUncertainty_rad,n);
            testCase.verifyEqual(d.reason,"state_uncertainty");testCase.verifyFalse(d.committed);
            testCase.verifyEqual(d.stateUncertainty,abs(c.currentStateMap)* ...
                repmat(c.maxReferenceUncertainty_rad,n,1),'AbsTol',1e-14);
        end

        function worstCaseMeasurementSignsAttainCurrentStateBound(testCase)
            [c,~]=localConfiguration();n=c.windowSamples;voltage=.3*cos((1:n)'/9);
            truth=localTrajectory(c,[.2;.1;-.2],voltage);uncertainty=1e-5;
            for component=1:3
                noise=uncertainty*sign(c.currentStateMap(component,:))';
                [~,d]=localFeed(c,truth(1,:)'+noise,voltage,uncertainty,n);
                testCase.verifyTrue(d.committed);
                testCase.verifyLessThanOrEqual(abs(d.estimatedState-truth(:,end)),d.stateUncertainty+1e-10);
                testCase.verifyEqual(d.estimatedState(component)-truth(component,end), ...
                    d.stateUncertainty(component),'AbsTol',1e-10);
            end
        end

        function stateIntervalMustFitVelocityAndCurrentLimits(testCase)
            [c,~]=localConfiguration();n=c.windowSamples;
            velocity=25;current=velocity*1e-4/.08;
            voltage=repmat(1.2*current+.08*velocity,n,1);
            truth=localTrajectory(c,[0;velocity;current],voltage);
            [~,d]=localFeed(c,truth(1,:)',voltage,1e-7,n);
            testCase.verifyEqual(d.reason,"state_range");testCase.verifyFalse(d.committed);
            voltage=zeros(n,1);voltage(end)=40;truth=localTrajectory(c,zeros(3,1),voltage);
            [~,d]=localFeed(c,truth(1,:)',voltage,1e-7,n);
            testCase.verifyGreaterThan(d.estimatedState(3),12);
            testCase.verifyEqual(d.reason,"state_range");testCase.verifyFalse(d.committed);
        end

        function mismatchedAppliedInputCannotReplaceKnownVoltageHistory(testCase)
            [c,~]=localConfiguration();n=c.windowSamples;voltage=2*sin((1:n)'/6);
            truth=localTrajectory(c,[.1;.2;0],voltage);
            [~,valid]=localFeed(c,truth(1,:)',voltage,1e-7,n);
            [~,invalid]=localFeed(c,truth(1,:)',zeros(n,1),1e-7,n);
            testCase.verifyTrue(valid.committed);testCase.verifyFalse(invalid.qualified || invalid.committed);
            testCase.verifyTrue(any(invalid.reason==["dynamic_fit","inconsistent_uncertainty"]));
        end

        function invalidSchedulingAndRequiredInputsThrow(testCase)
            [c,~]=localConfiguration();s=phase3_reacquisition_initialize(c);id='EMIProject:InvalidReacquisitionInput';
            invalid={struct('currentIndex',2),struct('currentIndex',1.5),struct('stopped',2), ...
                struct('request',[]),struct('sampleReceived',"yes"),struct('previousAppliedVoltage_V',Inf)};
            for j=1:numel(invalid)
                in=localInput(1,0);names=fieldnames(invalid{j});in.(names{1})=invalid{j}.(names{1});
                testCase.verifyError(@()phase3_reacquisition_step(s,in),id);
            end
            [s,~]=phase3_reacquisition_step(s,localInput(1,0));
            testCase.verifyError(@()phase3_reacquisition_step(s,localInput(1,0)),id);
        end

        function malformedConfigurationAndTamperedMapsThrow(testCase)
            [c,o]=localConfiguration();id='EMIProject:InvalidReacquisitionConfiguration';
            invalid={struct('windowDuration_s',.049),struct('windowDuration_s',Inf), ...
                struct('currentLimit_A',13),struct('maxStateUncertainty',[1;2]), ...
                struct('minReferenceUncertainty_rad',0),struct('maxReferenceUncertainty_rad',1e-10), ...
                struct('unknownField',1)};
            for j=1:numel(invalid)
                testCase.verifyError(@()phase3_reacquisition_configuration(o,invalid{j}),id);
            end
            c.currentStateMap(:)=0;testCase.verifyError(@()phase3_reacquisition_initialize(c),id);
        end

        function reanchorPreservesPrimaryTrustAndNeedsSubsequentPrimaryPacket(testCase)
            [~,o]=localConfiguration();s=phase3_observer_initialize(o);
            [s,~]=phase3_observer_step(s,0,1,true,0);
            [s,~]=phase3_observer_step(s,.1,2,true,0);
            for k=3:300,[s,~]=phase3_observer_step(s,NaN,NaN,false,0);end
            before=s;s=phase3_observer_reanchor(s,[.01;.1;0]);
            for field={'lastSeenSourceIndex','lastTrustedSourceIndex','lastTrustedMeasurement_rad','residualLatched'}
                testCase.verifyEqual(s.(field{1}),before.(field{1}));
            end
            [s,missing]=phase3_observer_step(s,NaN,NaN,false,0);
            testCase.verifyFalse(missing.estimateUsable || missing.credibleFresh);
            measurement=o.C*o.A*s.estimatedState;
            [~,fresh]=phase3_observer_step(s,measurement,302,true,0);
            testCase.verifyTrue(fresh.measurementAccepted && fresh.credibleFresh && fresh.estimateUsable);
            testCase.verifyEqual(fresh.trustedSourceIndex,302);
        end

        function reanchorClearsPreAnchorReplayHistory(testCase)
            [~,o]=localConfiguration();s=phase3_observer_initialize(o);
            for k=1:10,[s,~]=phase3_observer_step(s,NaN,NaN,false,0);end
            anchor=[.1;.2;-.1];s=phase3_observer_reanchor(s,anchor);
            testCase.verifyEqual(nnz(s.historyIndices),1);
            slot=mod(s.sampleIndex-1,o.historyCapacity)+1;
            testCase.verifyEqual(s.historyIndices(slot),10);
            testCase.verifyEqual(s.historyStates(:,slot),anchor);
            [s,d]=phase3_observer_step(s,0,9,true,.3);
            testCase.verifyEqual(d.gateReason,"outside_history");
            testCase.verifyFalse(d.measurementAccepted || d.credibleFresh);
            testCase.verifyEqual(s.estimatedState,o.A*anchor+o.B*[.3;o.assumedLoadTorque_Nm],'AbsTol',1e-13);
        end

        function invalidReanchorCannotInstallUnsafeOrNonfiniteState(testCase)
            [~,o]=localConfiguration();s=phase3_observer_initialize(o);id='EMIProject:InvalidObserverReanchor';
            testCase.verifyError(@()phase3_observer_reanchor(s,zeros(3,1)),id);
            [s,~]=phase3_observer_step(s,0,1,true,0);
            for invalid={NaN,[0;0;Inf],[pi+.1;0;0],[0;26;0],[0;0;13],[0;0]}
                testCase.verifyError(@()phase3_observer_reanchor(s,invalid{1}),id);
            end
        end
    end
end

function [c,o]=localConfiguration()
o=phase3_observer_configuration(actuator_parameters());
c=phase3_reacquisition_configuration(o);
end

function input=localInput(k,position)
input=struct('currentIndex',k,'stopped',true,'request',false,'sampleReceived',true, ...
    'position_rad',position,'sourceIndex',k,'uncertainty_rad',1e-7,'previousAppliedVoltage_V',0);
end

function truth=localTrajectory(c,initial,voltage)
n=numel(voltage);truth=zeros(3,n);truth(:,1)=initial;
for k=2:n,truth(:,k)=c.A*truth(:,k-1)+c.B*[voltage(k);c.assumedLoadTorque_Nm];end
end

function [s,d]=localFeed(c,position,voltage,uncertainty,requestIndex)
s=phase3_reacquisition_initialize(c);
for k=1:numel(position)
    input=localInput(k,position(k));input.previousAppliedVoltage_V=voltage(k);
    input.uncertainty_rad=uncertainty;input.request=(k==requestIndex);
    [s,d]=phase3_reacquisition_step(s,input);
end
end
