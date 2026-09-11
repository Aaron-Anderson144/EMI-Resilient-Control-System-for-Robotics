function study = run_phase2a_evidence_study(outputFolder)
%RUN_PHASE2A_EVIDENCE_STUDY E-002B sampled spectrum and E-003B recovery evidence.
% Writes only a new/empty destination. Existing simulators and their nominal
% parameters are unchanged; each fixture stores its actual parameter set.
arguments
    outputFolder (1,1) string = ""
end
root = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(root,'startup_project.m'));
if outputFolder==""
    stem = fullfile(root,'results','development', ...
        "phase2a_evidence_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
    outputFolder=stem;suffix=0;
    while isfolder(outputFolder) || isfile(outputFolder)
        suffix=suffix+1;outputFolder=stem+"_"+string(suffix);
    end
end
assert(~isfile(outputFolder),'EMIProject:OutputExists','Destination is an existing file.');
if isfolder(outputFolder)
    entries=dir(outputFolder);entries=entries(~ismember({entries.name},{'.','..'}));
    assert(isempty(entries),'EMIProject:OutputExists','Use a new or empty evidence directory.');
else
    mkdir(outputFolder);
end
model = 'EMI_Resilient_Actuator_Phase2';
assert_actuator_model_schema(string(model),"phase2");
modelCleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
study.startedUTC=string(datetime('now','TimeZone','UTC'));
study.scope="Synthetic sampled encoder faults; no physical EMI-frequency, encoder decoder or supervisory recovery validation";
study.spectralCases=struct();study.recoveryCases=struct();
spectralRows={};recoveryRows={};simRows={};channelTables={};caseManifest={};

for name=["sinusoid_120Hz","sinusoid_off_bin","sinusoid_faster_sampling"]
    p=actuator_parameters();p.simulation.stopTime_s=3;
    if name=="sinusoid_off_bin",p.faults.encoder.sinusoid.frequency_Hz=123.4;end
    if name=="sinusoid_faster_sampling",p.control.sampleTime_s=0.0005;end
    scenario=encoder_fault_scenario("sinusoidal",p);
    [r,b,simEvidence,simRow,channels]=localExecute(name,p,scenario,model);
    t=r.timeSeries.time_s;
    measurementDelta=r.timeSeries.theta_measured_rad-b.timeSeries.theta_measured_rad;
    [injected,firstSpectrum]=phase2a_windowed_spectrum(t,r.profile.sinusoidal_rad, ...
        scenario.sinusoid.startTime_s,scenario.sinusoid.stopTime_s);
    [measurement,secondSpectrum]=phase2a_windowed_spectrum(t,measurementDelta, ...
        scenario.sinusoid.startTime_s,scenario.sinusoid.stopTime_s);
    commandedFrequency=scenario.sinusoid.frequency_Hz;
    peakError=abs(injected.PeakFrequency_Hz-commandedFrequency);
    peakAllowance=injected.FrequencyBinSpacing_Hz/2+1e-9;
    peakPassed=injected.HasACSignal && injected.PeakInteriorBand && ...
        commandedFrequency>2*injected.FrequencyBinSpacing_Hz && ...
        commandedFrequency<injected.Nyquist_Hz-2*injected.FrequencyBinSpacing_Hz && peakError<=peakAllowance;
    spectrum=table(firstSpectrum.Frequency_Hz,firstSpectrum.OneSidedAmplitude_rad, ...
        secondSpectrum.OneSidedAmplitude_rad,'VariableNames', ...
        {'Frequency_Hz','InjectedEncoderErrorAmplitude_rad','MeasurementMinusBaselineAmplitude_rad'});
    row=struct('Case',name,'TestID',"E-002B",'SampleRate_Hz',injected.SampleRate_Hz, ...
        'ActiveSamples',injected.ActiveSamples,'FFTLength',injected.FFTLength, ...
        'FrequencyBinSpacing_Hz',injected.FrequencyBinSpacing_Hz, ...
        'CommandedFrequency_Hz',commandedFrequency,'InjectedPeakFrequency_Hz',injected.PeakFrequency_Hz, ...
        'InjectedPeakError_Hz',peakError,'PeakAllowance_Hz',peakAllowance, ...
        'InjectedPeakPassed',peakPassed,'InjectedPeakAmplitude_rad',injected.PeakAmplitude_rad, ...
        'MeasurementDiagnosticPeakFrequency_Hz',measurement.PeakFrequency_Hz, ...
        'MeasurementDiagnosticPeakAmplitude_rad',measurement.PeakAmplitude_rad, ...
        'SimulinkPassed',simRow.Passed,'Passed',peakPassed && simRow.Passed);
    spectralRows{end+1}=row;simRows{end+1}=simRow;channelTables{end+1}=channels; %#ok<AGROW>
    study.spectralCases.(name)=struct('parameters',p,'scenario',scenario,'result',r,'baseline',b, ...
        'injectedSettings',injected,'measurementDiagnosticSettings',measurement, ...
        'spectrum',spectrum,'simulink',simEvidence,'acceptance',row);
    caseManifest{end+1}=struct('caseName',name,'testID',"E-002B", ...
        'parameters',p,'scenario',scenario,'analysis',struct('injected',injected,'measurementDiagnostic',measurement)); %#ok<AGROW>
    settings=[struct2table(injected);struct2table(measurement)];
    settings.Channel=["injected_encoder_error";"measurement_minus_matched_baseline_diagnostic"];
    writetable(settings,fullfile(outputFolder,name+"_spectral_settings.csv"));
    writetable(spectrum,fullfile(outputFolder,name+"_spectrum.csv"));
    series=r.timeSeries;series.measurement_minus_baseline_rad=measurementDelta;
    series.position_minus_baseline_rad=r.timeSeries.theta_rad-b.timeSeries.theta_rad;
    writetable(series,fullfile(outputFolder,name+"_timeseries.csv"));
    fprintf('E-002B %s: injected peak %.6g Hz, bin %.6g Hz, pass %d\n', ...
        name,injected.PeakFrequency_Hz,injected.FrequencyBinSpacing_Hz,row.Passed);
end

for name=["count_jump_default","count_jump_reverse","count_jump_loaded", ...
        "count_jump_off_grid","count_jump_endpoint_censored"]
    p=actuator_parameters();p.simulation.stopTime_s=3;
    if name=="count_jump_reverse",p.faults.encoder.countJump.magnitude_counts=-128;end
    if name=="count_jump_loaded",p.mechanical.nominalLoadTorque_Nm=0.01;end
    if name=="count_jump_off_grid",p.faults.encoder.countJump.time_s=0.4504;end
    if name=="count_jump_endpoint_censored",p.faults.encoder.countJump.time_s=p.simulation.stopTime_s;end
    scenario=encoder_fault_scenario("count_jump",p);
    [r,b,simEvidence,simRow,channels]=localExecute(name,p,scenario,model);
    t=r.timeSeries.time_s;Ts=p.control.sampleTime_s;
    active=find(r.profile.countJump_rad~=0);
    assert(numel(active)==1,'EMIProject:CountJumpEvidence','Expected exactly one injected sample.');
    actualTime=t(active);
    if active<numel(t),faultEnd=t(active+1);else,faultEnd=actualTime+Ts;end
    delta=r.timeSeries.theta_rad-b.timeSeries.theta_rad;
    recovery=phase2a_recovery_metrics(t,delta,faultEnd, ...
        p.phase2b.metrics.recoveryThreshold_rad,p.phase2b.metrics.recoveryDwellSamples);
    pre=t<actualTime;preDifference=max([0;abs(delta(pre))]);
    expectedCensored=name=="count_jump_endpoint_censored";
    recoveryPassed=recovery.RecoveryCensored==expectedCensored && preDifference<=1e-12;
    row=recovery;row.Case=name;row.TestID="E-003B";
    row.RequestedJumpTime_s=scenario.countJump.time_s;row.ActualJumpSample=active;
    row.ActualJumpTime_s=actualTime;row.JumpCounts=scenario.countJump.magnitude_counts;
    row.JumpAngle_rad=r.profile.countJump_rad(active);row.PreOnsetPositionDelta_rad=preDifference;
    row.ExpectedCensored=expectedCensored;row.RecoveryOutcomePassed=recoveryPassed;
    row.SimulinkPassed=simRow.Passed;row.Passed=recoveryPassed && simRow.Passed;
    recoveryRows{end+1}=row;simRows{end+1}=simRow;channelTables{end+1}=channels; %#ok<AGROW>
    study.recoveryCases.(name)=struct('parameters',p,'scenario',scenario,'result',r,'baseline',b, ...
        'deltaPosition_rad',delta,'recovery',row,'simulink',simEvidence);
    caseManifest{end+1}=struct('caseName',name,'testID',"E-003B", ...
        'parameters',p,'scenario',scenario,'analysis',row); %#ok<AGROW>
    series=r.timeSeries;series.position_minus_baseline_rad=delta;
    series.post_fault_window=t>=faultEnd;
    writetable(series,fullfile(outputFolder,name+"_timeseries.csv"));
    fprintf('E-003B %s: onset %.6g s, end %.6g s, delay %.6g s, censored %d, pass %d\n', ...
        name,actualTime,faultEnd,row.RecoveryDelay_s,row.RecoveryCensored,row.Passed);
end
study.spectralValidation=struct2table(vertcat(spectralRows{:}));
study.recoveryValidation=struct2table(vertcat(recoveryRows{:}));
study.simulinkValidation=struct2table(vertcat(simRows{:}));
study.simulinkChannels=vertcat(channelTables{:});
study.completedUTC=string(datetime('now','TimeZone','UTC'));
study.allPassed=all(study.spectralValidation.Passed) && all(study.recoveryValidation.Passed) && ...
    all(study.simulinkValidation.Passed);
writetable(study.spectralValidation,fullfile(outputFolder,'phase2a_spectral_validation.csv'));
writetable(study.recoveryValidation,fullfile(outputFolder,'phase2a_recovery_validation.csv'));
writetable(study.simulinkValidation,fullfile(outputFolder,'phase2a_simulink_validation.csv'));
writetable(study.simulinkChannels,fullfile(outputFolder,'phase2a_simulink_channel_comparisons.csv'));
save(fullfile(outputFolder,'phase2a_evidence_study.mat'),'study','-v7');
localWriteJSON(fullfile(outputFolder,'phase2a_case_manifest.json'),vertcat(caseManifest{:}));
write_run_manifest(outputFolder,root,struct('workflow',"phase2a_spectrum_recovery", ...
    'startedUTC',study.startedUTC,'completedUTC',study.completedUTC,'allPassed',study.allPassed, ...
    'spectralCases',3,'recoveryCases',5,'simulinkCases',8));
localPlot(study,outputFolder);
localSummary(study,outputFolder);
assert(study.allPassed,'EMIProject:Phase2AEvidenceFailed','Inspect the saved evidence acceptance tables.');
end

function [r,b,evidence,row,channels]=localExecute(name,p,scenario,model)
r=simulate_faulted_actuator(p,scenario);
b=simulate_faulted_actuator(p,encoder_fault_scenario("none",p));
input=create_phase2_simulation_input(string(model),p,scenario);
output=sim(input);logged=output.get('phase2Simout');
expected=[r.timeSeries.theta_ref_rad,r.timeSeries.theta_rad, ...
    r.timeSeries.theta_measured_rad,r.profile.additive_rad,double(r.profile.dropoutActive)];
[check,channels]=compare_logged_arrays(logged.time,logged.signals.values, ...
    r.timeSeries.time_s,expected,["Reference_rad","Position_rad","Measurement_rad", ...
    "InjectedAdditive_rad","DropoutMask"],1e-9,5, ...
    round(p.simulation.stopTime_s/p.control.sampleTime_s)+1);
warnings=numel(output.SimulationMetadata.ExecutionInfo.WarningDiagnostics);
completed=strcmp(output.SimulationMetadata.ExecutionInfo.StopEvent,'ReachedStopTime');
row=struct('Case',name,'Samples',check.LoggedSamples,'AllFinite',check.AllFinite, ...
    'ComparisonPassed',check.Passed,'MaxDifference',max(check.MaxDifferences), ...
    'SimulationWarnings',warnings,'Completed',completed, ...
    'Passed',check.Passed && warnings==0 && completed);
channels.Case=repmat(name,height(channels),1);
evidence=struct('time_s',logged.time,'values',logged.signals.values,'comparison',check, ...
    'warningCount',warnings,'completed',completed);
end

function localWriteJSON(path,value)
fid=fopen(path,'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end

function localPlot(study,folder)
figureHandle=figure('Visible','off','Color','white','Position',[100,100,1250,500]);
theme(figureHandle,'light');
cleanup=onCleanup(@()close(figureHandle)); %#ok<NASGU>
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
s=study.spectralCases.sinusoid_120Hz.spectrum;
ax=nexttile;plot(ax,s.Frequency_Hz,rad2deg(s.InjectedEncoderErrorAmplitude_rad), ...
    s.Frequency_Hz,rad2deg(s.MeasurementMinusBaselineAmplitude_rad),'LineWidth',1.2);
xlim(ax,[0,200]);grid(ax,'on');xlabel(ax,'Sampled frequency (Hz)');ylabel(ax,'One-sided amplitude (deg)');
title(ax,'Synthetic encoder spectra: active window only');
legend(ax,["Injected encoder error","Measurement minus matched baseline"],'Location','northwest');
item=study.recoveryCases.count_jump_default;ax=nexttile;
plot(ax,item.result.timeSeries.time_s,rad2deg(item.deltaPosition_rad),'LineWidth',1.3);hold(ax,'on');
yline(ax,rad2deg(item.recovery.Threshold_rad),'--');yline(ax,-rad2deg(item.recovery.Threshold_rad),'--');
xline(ax,item.recovery.FaultEndTime_s,':','Fault end');
if ~item.recovery.RecoveryCensored
    xline(ax,item.recovery.RecoveryStartTime_s,':','Dwell starts');
    xline(ax,item.recovery.RecoveryConfirmationTime_s,':','Dwell confirmed');
end
xlim(ax,[0.4,0.85]);grid(ax,'on');xlabel(ax,'Time (s)');ylabel(ax,'Position minus matched baseline (deg)');
title(ax,'Count jump: 50 consecutive in-band samples');
exportgraphics(figureHandle,fullfile(folder,'phase2a_evidence_overview.png'), ...
    'Resolution',180,'BackgroundColor','white');
end

function localSummary(study,folder)
fid=fopen(fullfile(folder,'Phase2A_Evidence_Summary.md'),'w');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# Phase 2A sampled spectrum and count-jump recovery\n\n');
fprintf(fid,'Completed: %s. All declared checks passed: %d.\n\n',study.completedUTC,study.allPassed);
fprintf(fid,'E-002B: %d/%d spectral fixtures passed. E-003B: %d/%d recovery outcomes passed. MATLAB/Simulink: %d/%d complete warning-free comparisons passed.\n\n', ...
    nnz(study.spectralValidation.Passed),height(study.spectralValidation), ...
    nnz(study.recoveryValidation.Passed),height(study.recoveryValidation), ...
    nnz(study.simulinkValidation.Passed),height(study.simulinkValidation));
fprintf(fid,['The spectrum selects the half-open injected sinusoid window, removes its mean, applies an explicit periodic Hann window, ', ...
    'and computes an unpadded N-point FFT. One-sided amplitude is corrected by window coherent gain; DC and Nyquist are not doubled. ', ...
    'Frequency-bin spacing is Fs/N. The first largest non-DC bin is reported without interpolation. ', ...
    'Only the injected signal is required to peak within half a bin of its configured frequency. ', ...
    'The measurement-minus-matched-baseline spectrum also contains closed-loop response and is diagnostic.\n\n', ...
    'The frequency fixtures are in the interior band, more than two FFT bins from DC and Nyquist. ', ...
    'Coherent-gain-corrected spectral ordinates are not universal tone amplitudes for off-bin tones or near boundaries where image lobes overlap. ', ...
    'Equal peak maxima choose the first bin; nearly equal peaks may exchange order with roundoff. Boundary peaks are flagged as diagnostic.\n\n', ...
    'These are sampled synthetic encoder-error frequencies. No anti-alias filter is modeled, and physical frequencies above Nyquist cannot be identified. ', ...
    'The analysis does not characterize physical EMI spectra or receiver susceptibility.\n\n']);
fprintf(fid,['Recovery uses baseline-subtracted true position. The count jump acts on the nearest controller sample (first sample wins an exact tie); ', ...
    'its effective interval ends one sample period later. Requested and actual onset, event end, recovery start and confirmation are retained. ', ...
    'The first full post-fault run with absolute delta <= the threshold qualifies. ', ...
    'The default threshold is 0.05 degree for 50 consecutive samples: a 49 ms start-to-confirmation span at 1 kHz. ', ...
    'Delay is measured from the effective fault end to dwell start, not confirmation. ', ...
    'The endpoint jump deliberately has no post-fault record and must remain censored even if its final position delta is zero.\n\n']);
fprintf(fid,'| Case | Injected peak (Hz) | Bin spacing (Hz) | Measurement peak, diagnostic (Hz) |\n|---|---:|---:|---:|\n');
for k=1:height(study.spectralValidation)
    row=study.spectralValidation(k,:);
    fprintf(fid,'| %s | %.8g | %.8g | %.8g |\n',row.Case,row.InjectedPeakFrequency_Hz, ...
        row.FrequencyBinSpacing_Hz,row.MeasurementDiagnosticPeakFrequency_Hz);
end
fprintf(fid,'\n| Case | Actual jump (s) | Fault end (s) | Recovery delay (s) | Censored |\n|---|---:|---:|---:|---|\n');
for k=1:height(study.recoveryValidation)
    row=study.recoveryValidation(k,:);
    fprintf(fid,'| %s | %.8g | %.8g | %.8g | %d |\n',row.Case,row.ActualJumpTime_s, ...
        row.FaultEndTime_s,row.RecoveryDelay_s,row.RecoveryCensored);
end
fprintf(fid,['\nExact settings and both spectra are in each spectral-settings/spectrum CSV. ', ...
    '`phase2a_recovery_validation.csv` records thresholds, sample counts, origins, dwell start/confirmation and censor reasons. ', ...
    '`phase2a_evidence_study.mat` retains each parameter/scenario, analytical result, matched baseline, Simulink record and comparison. ', ...
    '`phase2a_case_manifest.json` and `run_manifest.json` bind fixtures and source/model identity. ', ...
    'This is trajectory-recovery evidence; no fault detector, supervisor recovery policy or hardware experiment is implemented by this study.\n']);
end
