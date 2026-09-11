classdef TestPhase2AEvidence < matlab.unittest.TestCase
    %TESTPHASE2AEVIDENCE Spectral method and explicit recovery boundaries.
    methods (Test)
        function coherentInteriorToneHasCorrectRateBinAndAmplitude(testCase)
            t=(0:600)'/1000;x=deg2rad(1)*sin(2*pi*120*t);
            [s,spectrum]=phase2a_windowed_spectrum(t,x,.1,.5);
            testCase.verifyEqual(s.ActiveSamples,400);
            testCase.verifyEqual(s.FFTLength,400);
            testCase.verifyEqual(s.SampleRate_Hz,1000,'AbsTol',1e-8);
            testCase.verifyEqual(s.FrequencyBinSpacing_Hz,2.5,'AbsTol',1e-10);
            testCase.verifyEqual(s.PeakFrequency_Hz,120,'AbsTol',1e-8);
            testCase.verifyEqual(s.PeakAmplitude_rad,deg2rad(1),'AbsTol',1e-13);
            testCase.verifyEqual(s.CoherentGain,.5,'AbsTol',1e-14);
            testCase.verifyTrue(s.PeakInteriorBand);
            testCase.verifyFalse(s.ZeroPadding);
            testCase.verifySize(spectrum,[201,2]);
        end

        function offBinToneUsesDeclaredResolutionWithoutInventedPrecision(testCase)
            t=(0:600)'/1000;x=sin(2*pi*123.4*t);
            s=phase2a_windowed_spectrum(t,x,.1,.5);
            testCase.verifyLessThanOrEqual(abs(s.PeakFrequency_Hz-123.4),s.FrequencyBinSpacing_Hz/2+1e-9);
            testCase.verifyEqual(s.PeakFrequency_Hz/s.FrequencyBinSpacing_Hz, ...
                s.PeakBin,'AbsTol',1e-12);
            testCase.verifyTrue(s.PeakInteriorBand);
        end

        function fasterSamplingUsesActualRateAndSameWindowDuration(testCase)
            t=(0:1200)'/2000;x=sin(2*pi*120*t);
            s=phase2a_windowed_spectrum(t,x,.1,.5);
            testCase.verifyEqual(s.ActiveSamples,800);
            testCase.verifyEqual(s.SampleRate_Hz,2000,'AbsTol',1e-8);
            testCase.verifyEqual(s.FrequencyBinSpacing_Hz,2.5,'AbsTol',1e-10);
            testCase.verifyEqual(s.PeakFrequency_Hz,120,'AbsTol',1e-8);
        end

        function halfOpenWindowExcludesOutsideAndStopSample(testCase)
            t=(0:600)'/1000;x=sin(2*pi*120*t);
            modified=x;modified(t<.1 | t>=.5)=1e6;
            [a,spectrumA]=phase2a_windowed_spectrum(t,x,.1,.5);
            [b,spectrumB]=phase2a_windowed_spectrum(t,modified,.1,.5);
            testCase.verifyEqual(a,b);
            testCase.verifyEqual(spectrumA,spectrumB);
            testCase.verifyEqual(a.FirstSelectedTime_s,.1,'AbsTol',1e-14);
            testCase.verifyEqual(a.LastSelectedTime_s,.499,'AbsTol',1e-14);
        end

        function offsetRemovalAndAmplitudeScalingHaveDefinedEffects(testCase)
            t=(0:600)'/1000;x=.02*sin(2*pi*120*t);
            [a,spectrumA]=phase2a_windowed_spectrum(t,x,.1,.5);
            [b,spectrumB]=phase2a_windowed_spectrum(t,3*x+.25,.1,.5);
            testCase.verifyEqual(b.MeanRemoved_rad-a.MeanRemoved_rad,.25,'AbsTol',1e-13);
            testCase.verifyEqual(spectrumB.OneSidedAmplitude_rad,3*spectrumA.OneSidedAmplitude_rad,'AbsTol',1e-13);
            testCase.verifyEqual(a.PeakFrequency_Hz,b.PeakFrequency_Hz);
        end

        function zeroAndConstantSignalsHaveNoInventedPeak(testCase)
            t=(0:600)'/1000;
            for level=[0,.1]
                [s,spectrum]=phase2a_windowed_spectrum(t,level*ones(size(t)),.1,.5);
                testCase.verifyFalse(s.HasACSignal);
                testCase.verifyTrue(isnan(s.PeakFrequency_Hz));
                testCase.verifyEqual(s.PeakAmplitude_rad,0);
                testCase.verifyTrue(all(isfinite(spectrum{:,:}),'all'));
            end
        end

        function nyquistPeakIsOnlyABoundaryDiagnostic(testCase)
            t=(0:399)'/1000;x=(-1).^(0:399)';
            s=phase2a_windowed_spectrum(t,x,0,.4);
            testCase.verifyTrue(s.HasACSignal);
            testCase.verifyFalse(s.PeakInteriorBand);
            % Hann image-lobe overlap can tie the final bins. Do not promise
            % sub-bin identification or a universal tone amplitude here.
            testCase.verifyLessThanOrEqual(abs(s.PeakFrequency_Hz-s.Nyquist_Hz), ...
                s.FrequencyBinSpacing_Hz+1e-9);
            testCase.verifyTrue(contains(s.BoundaryInterpretation,"first bin"));
        end

        function malformedSpectralRecordsFailClosed(testCase)
            t=(0:600)'/1000;x=sin(2*pi*120*t);id='EMIProject:InvalidSpectralInput';
            bad=x;bad(200)=NaN;
            testCase.verifyError(@()phase2a_windowed_spectrum(t,bad,.1,.5),id);
            badTime=t;badTime(200)=badTime(200)+.0001;
            testCase.verifyError(@()phase2a_windowed_spectrum(badTime,x,.1,.5),id);
            testCase.verifyError(@()phase2a_windowed_spectrum(t,x,.1,.107),id);
            testCase.verifyError(@()phase2a_windowed_spectrum(t,x(1:end-1),.1,.5),id);
        end

        function integerInputsConvertToDoubleAndOverflowIsRejected(testCase)
            t=uint16((0:399)');x=int32(1000*(-1).^(0:399)');
            [s,spectrum]=phase2a_windowed_spectrum(t,x,0,400);
            testCase.verifyEqual(s.SampleRate_Hz,1);
            testCase.verifyTrue(all(isfinite(spectrum{:,:}),'all'));
            testCase.verifyGreaterThan(s.PeakAmplitude_rad,999);
            huge=repmat([realmax;-realmax],200,1);
            testCase.verifyError(@()phase2a_windowed_spectrum(double(t)/1000,huge,0,.4), ...
                'EMIProject:InvalidSpectralInput');
        end

        function recoveryRequiresFirstCompleteInclusiveThresholdDwell(testCase)
            t=(0:10)'/10;delta=[9;9;.1;-.1;.1001;.1;-.1;.1;0;0;0];
            m=phase2a_recovery_metrics(t,delta,.2,.1,3);
            testCase.verifyFalse(m.RecoveryCensored);
            testCase.verifyEqual(m.RecoveryStartTime_s,.5,'AbsTol',1e-12);
            testCase.verifyEqual(m.RecoveryConfirmationTime_s,.7,'AbsTol',1e-12);
            testCase.verifyEqual(m.RecoveryDelay_s,.3,'AbsTol',1e-12);
            testCase.verifyEqual(m.DwellSpan_s,.2,'AbsTol',1e-12);
        end

        function insufficientOrAbsentPostFaultRecordIsCensored(testCase)
            t=(0:10)'/10;delta=zeros(size(t));
            none=phase2a_recovery_metrics(t,delta,1.1,0,3);
            short=phase2a_recovery_metrics(t,delta,.9,0,3);
            exact=phase2a_recovery_metrics(t,delta,.8,0,3);
            testCase.verifyTrue(none.RecoveryCensored && short.RecoveryCensored);
            testCase.verifyTrue(isnan(none.RecoveryDelay_s) && isnan(short.RecoveryStartTime_s));
            testCase.verifyEqual(none.CensorReason,"no_post_fault_samples");
            testCase.verifyEqual(short.CensorReason,"insufficient_post_fault_samples");
            testCase.verifyFalse(exact.RecoveryCensored);
            testCase.verifyEqual(exact.RecoveryDelay_s,0,'AbsTol',1e-12);
            testCase.verifyEqual(exact.RecoveryConfirmationTime_s,1,'AbsTol',1e-12);
        end

        function offGridFaultEndStartsAtFirstEligibleSample(testCase)
            t=(0:10)'/10;
            m=phase2a_recovery_metrics(t,zeros(size(t)),.55,0,1);
            testCase.verifyEqual(m.RecoveryStartTime_s,.6,'AbsTol',1e-12);
            testCase.verifyEqual(m.RecoveryConfirmationTime_s,.6,'AbsTol',1e-12);
            testCase.verifyEqual(m.RecoveryDelay_s,.05,'AbsTol',1e-12);
            testCase.verifyEqual(m.DwellSpan_s,0);
        end

        function recoveryRejectsMalformedInputs(testCase)
            t=(0:10)'/10;delta=zeros(size(t));id='EMIProject:InvalidRecoveryInput';
            bad=delta;bad(6)=Inf;
            testCase.verifyError(@()phase2a_recovery_metrics(t,bad,.2,.1,3),id);
            testCase.verifyError(@()phase2a_recovery_metrics(t,delta,.2,NaN,3),id);
            testCase.verifyError(@()phase2a_recovery_metrics(t,delta,.2,.1,2.5),id);
            testCase.verifyError(@()phase2a_recovery_metrics(t,delta,.2,.1,2*flintmax),id);
        end

        function recoveryMatchesExistingPhase2BSemantics(testCase)
            t=(0:10)'/10;delta=[9;9;.1;-.1;.1001;.1;-.1;.1;0;0;0];
            p=actuator_parameters();p.phase2b.metrics.recoveryThreshold_rad=.1;
            p.phase2b.metrics.recoveryDwellSamples=3;
            r.time_s=t;r.position_rad=delta;r.command_V=zeros(size(t));
            r.receivedMeasurement_rad=zeros(size(t));
            r.scenario=struct('name',"synthetic_recovery",'analysisStartTime_s',.1,'analysisStopTime_s',.2);
            r.communication=struct('packetDropped',false(size(t)),'channelEnabled',false(size(t)), ...
                'heldLast',false(size(t)),'measurementAge_samples',zeros(size(t)));
            b=r;b.position_rad=zeros(size(t));
            old=phase2b_metrics(r,b,p);
            current=phase2a_recovery_metrics(t,delta,.2,.1,3);
            testCase.verifyEqual(current.RecoveryDelay_s,old.recoveryTime_s,'AbsTol',1e-12);
            testCase.verifyEqual(current.RecoveryCensored,old.recoveryCensored);
        end

        function actualCountJumpRecordsEffectiveEndAndEndpointCensoring(testCase)
            p=actuator_parameters();p.simulation.stopTime_s=3;
            b=simulate_faulted_actuator(p,encoder_fault_scenario("none",p));
            r=simulate_faulted_actuator(p,encoder_fault_scenario("count_jump",p));
            t=r.timeSeries.time_s;index=find(r.profile.countJump_rad~=0);
            m=phase2a_recovery_metrics(t,r.timeSeries.theta_rad-b.timeSeries.theta_rad, ...
                t(index+1),p.phase2b.metrics.recoveryThreshold_rad,p.phase2b.metrics.recoveryDwellSamples);
            testCase.verifyEqual(t(index),.450,'AbsTol',1e-12);
            testCase.verifyEqual(m.FaultEndTime_s,.451,'AbsTol',1e-12);
            testCase.verifyEqual(m.RecoveryStartTime_s,.541,'AbsTol',1e-12);
            testCase.verifyEqual(m.RecoveryDelay_s,.090,'AbsTol',1e-12);
            testCase.verifyEqual(m.RecoveryConfirmationTime_s,.590,'AbsTol',1e-12);
            p.faults.encoder.countJump.time_s=p.simulation.stopTime_s;
            r=simulate_faulted_actuator(p,encoder_fault_scenario("count_jump",p));
            endpoint=phase2a_recovery_metrics(t,r.timeSeries.theta_rad-b.timeSeries.theta_rad, ...
                t(end)+p.control.sampleTime_s,p.phase2b.metrics.recoveryThreshold_rad,p.phase2b.metrics.recoveryDwellSamples);
            testCase.verifyEqual(r.timeSeries.theta_rad,b.timeSeries.theta_rad);
            testCase.verifyTrue(endpoint.RecoveryCensored);
            testCase.verifyEqual(endpoint.PostSamples,0);
        end

        function populatedEvidenceFolderIsNeverOverwritten(testCase)
            folder=tempname;mkdir(folder);marker=fullfile(folder,'existing.txt');
            cleanup=onCleanup(@()localRemoveFixture(marker,folder)); %#ok<NASGU>
            fid=fopen(marker,'w');fprintf(fid,'preserve');fclose(fid);
            testCase.verifyError(@()run_phase2a_evidence_study(string(folder)),'EMIProject:OutputExists');
            testCase.verifyEqual(fileread(marker),'preserve');
        end
    end
end

function localRemoveFixture(marker,folder)
if isfile(marker),delete(marker);end
if isfolder(folder),rmdir(folder);end
end
