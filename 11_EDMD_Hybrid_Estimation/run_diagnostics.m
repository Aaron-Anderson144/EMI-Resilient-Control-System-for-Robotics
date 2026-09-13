function result = run_diagnostics(sourceRun,outputRoot)
%RUN_DIAGNOSTICS Inspect frozen forecasts without refitting or retuning.
% Reuses previously examined test data for exploratory diagnosis only.
root=fileparts(mfilename('fullpath'));
if nargin<1 || strlength(string(sourceRun))==0
    latest=jsondecode(fileread(fullfile(root,'results','latest_run.json')));
    sourceRun=fullfile(root,'results',latest.folder);
end
if nargin<2,outputRoot=fullfile(root,'results','diagnostics');end
oldPath=path;restore=onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(fullfile(root,'code'));
assert(isfolder(sourceRun),'HybridDiagnostics:Source','Source experiment does not exist.');
fitted=load(fullfile(sourceRun,'selected_models.mat'),'models','names');
held=load(fullfile(sourceRun,'test_records.mat'),'test');
plan=jsondecode(fileread(fullfile(sourceRun,'study_plan.json')));
if ~isfolder(outputRoot),mkdir(outputRoot);end
runDir=tempname(outputRoot);mkdir(runDir);
fprintf('DIAGNOSTICS_OUTPUT %s\n',runDir);
[summary,perRun,endpoints]=hybrid_score(fitted.models,fitted.names,held.test, ...
    plan.testHorizonsSamples,plan.originStride,plan.warmupSeconds);
writetable(summary,fullfile(runDir,'forecast_summary.csv'));
writetable(perRun,fullfile(runDir,'forecast_per_run.csv'));
writetable(endpoints,fullfile(runDir,'forecast_endpoints.csv'));
[eventSummary,eventPerRun,paired]=hybrid_endpoint_summary(endpoints);
writetable(eventSummary,fullfile(runDir,'event_summary.csv'));
writetable(eventPerRun,fullfile(runDir,'event_per_run.csv'));
writetable(paired,fullfile(runDir,'event_paired_comparisons.csv'));
[modelSummary,singularSpectrum,rollout]=hybrid_model_diagnostics( ...
    fitted.models,fitted.names,held.test,plan.testHorizonsSamples, ...
    plan.originStride,plan.warmupSeconds);
writetable(modelSummary,fullfile(runDir,'model_diagnostics.csv'));
writetable(singularSpectrum,fullfile(runDir,'singular_spectrum.csv'));
writetable(rollout,fullfile(runDir,'lifted_rollout_diagnostics.csv'));
reference=readtable(fullfile(sourceRun,'forecast_per_run.csv'),'TextType','string');
keys={'modelName','regime','runName','horizonSamples'};
reference=sortrows(reference,keys);current=sortrows(perRun,keys);
assert(height(reference)==height(current),'HybridDiagnostics:Coverage','Forecast coverage changed.');
assert(isequal(reference(:,keys),current(:,keys)),'HybridDiagnostics:Pairing','Forecast pairing changed.');
delta=abs(reference.truthRMSE-current.truthRMSE);
sameInf=isinf(reference.truthRMSE)&isinf(current.truthRMSE);
assert(all(delta<=1e-12|sameInf),'HybridDiagnostics:Regression','Frozen benchmark changed.');
assert(isequal(reference.nonfiniteForecastCount,current.nonfiniteForecastCount), ...
    'HybridDiagnostics:Failures','Failure counts changed.');
localFigures(endpoints,perRun,singularSpectrum,runDir);
result=struct('schema','hybrid-diagnostics-v1','sourceRun',string(sourceRun), ...
    'outputDirectory',string(runDir),'endpointRows',height(endpoints), ...
    'maximumBaselineRMSEDifference_rad',max(delta,[],'omitnan'), ...
    'baselineReproduced',true,'scope','Exploratory reuse of previously examined data; no model changes, no new generalization claim.', ...
    'completedLocal',char(datetime('now')));
hybrid_write_json(fullfile(runDir,'execution.json'),result);
localReport(endpoints,perRun,modelSummary,runDir,result);
hybrid_write_json(fullfile(outputRoot,'latest_diagnostics.json'), ...
    struct('folder',string(localName(runDir)),'sourceRun',string(sourceRun)));
fprintf('DIAGNOSTICS_COMPLETE: %d endpoints; baseline difference %.3g radians.\n', ...
    height(endpoints),result.maximumBaselineRMSEDifference_rad);
end

function localFigures(endpoints,perRun,spectrum,folder)
f=figure('Visible','off','Theme','light','Color','w','Position',[50 50 1100 700]);
guard=onCleanup(@()close(f)); %#ok<NASGU>
tiledlayout(2,2,'TileSpacing','compact');
regimes=unique(perRun.regime,'stable');names=unique(perRun.modelName,'stable');
for j=1:numel(regimes)
    nexttile;hold on
    for name=names'
        group=perRun(perRun.regime==regimes(j)&perRun.modelName==name,:);
        horizons=unique(group.horizonSeconds);values=zeros(size(horizons));
        for k=1:numel(horizons),values(k)=rad2deg(mean(group.truthRMSE(group.horizonSeconds==horizons(k))));end
        semilogy(1000*horizons,values,'-o','DisplayName',name,'LineWidth',1.5);
    end
    set(gca,'YScale','log');grid on;title(regimes(j));xlabel('Forecast horizon (ms)');ylabel('Mean trajectory RMSE (degrees)');
end
legend('Location','best');exportgraphics(f,fullfile(folder,'forecast_horizons.png'),'Resolution',160);
clf(f);tiledlayout(1,2,'TileSpacing','compact');
for horizon=[50,250]
    nexttile;hold on
    group=endpoints(endpoints.regime=="nominal"&endpoints.horizonSamples==horizon,:);
    first=group.runName(1);group=group(group.runName==first,:);
    for name=names'
        rows=group(group.modelName==name,:);
        plot(rows.targetTimeSeconds,rad2deg(rows.truthError),'DisplayName',name,'LineWidth',1.2);
    end
    yline(0,':','HandleVisibility','off');grid on;xlabel('Target time (s)');ylabel('Signed position error (degrees)');
    title(sprintf('Nominal example, %d ms horizon',horizon));
end
legend('Location','best');exportgraphics(f,fullfile(folder,'nominal_signed_error.png'),'Resolution',160);
clf(f);hold on
for name=unique(spectrum.modelName,'stable')'
    rows=spectrum(spectrum.modelName==name,:);
    semilogy(rows.singularIndex,rows.singularValue,'-o','DisplayName',name,'LineWidth',1.5);
end
set(gca,'YScale','log');grid on;xlabel('Singular direction');ylabel('Training regressor singular value');
title('Singular spectrum of the frozen learned models');legend('Location','best');
exportgraphics(f,fullfile(folder,'singular_spectrum.png'),'Resolution',160);
end

function localReport(endpoints,perRun,modelSummary,folder,result)
fid=fopen(fullfile(folder,'Diagnostic_Report.md'),'w','n','UTF-8');
assert(fid>=0,'HybridDiagnostics:Report','Could not create report.');cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# EDMD forecast diagnostics\n\n');
fprintf(fid,'Frozen-model exploratory analysis saved %d endpoint records. Per-run truth RMSE and failure counts reproduce the original saved benchmark (maximum RMSE difference %.3g radians). No model was refitted.\n\n',height(endpoints),result.maximumBaselineRMSEDifference_rad);
fprintf(fid,'The previously inspected evaluation set is used to diagnose behavior. It is not a fresh test of a revised model.\n\n');
fprintf(fid,'## Nominal error by horizon\n\n| Model | Horizon (ms) | Mean trajectory RMSE (degrees) | Mean absolute per-trajectory bias (degrees) | Mean centered error RMS (degrees) |\n|---|---:|---:|---:|---:|\n');
nominal=perRun(perRun.regime=="nominal",:);
for name=unique(nominal.modelName,'stable')'
    for horizon=unique(nominal.horizonSamples)'
        rows=nominal(nominal.modelName==name&nominal.horizonSamples==horizon,:);
        e=endpoints(endpoints.regime=="nominal"&endpoints.modelName==name&endpoints.horizonSamples==horizon,:);
        runs=unique(e.runName);bias=zeros(numel(runs),1);scatter=bias;
        for j=1:numel(runs)
            errors=e.truthError(e.runName==runs(j));bias(j)=mean(errors);
            scatter(j)=sqrt(mean((errors-bias(j)).^2));
        end
        fprintf(fid,'| %s | %d | %.6g | %.6g | %.6g |\n',name,horizon,rad2deg(mean(rows.truthRMSE)),rad2deg(mean(abs(bias))),rad2deg(mean(scatter)));
    end
end
fprintf(fid,'\nBias is calculated within each trajectory before averaging its magnitude; opposite-signed biases cannot cancel. Centered RMS describes scatter around each trajectory mean. Overlapping origins are not independent trials.\n\n');
fprintf(fid,'## Event and model evidence\n\n');
fprintf(fid,'`event_summary.csv` separates targets within 50 ms of a true-velocity sign reversal from targets away from reversals. Zero-velocity plateaus are handled explicitly. Labels are offline diagnostics only. Missing velocity excludes reversal groups. Origins start at 200 ms; the initial startup interval is outside coverage. No explicit load steps or receiver faults exist in these records.\n\n');
fprintf(fid,'`model_diagnostics.csv` contains %d fitted-model rows. `singular_spectrum.csv` records retained directions and ridge filtering. `lifted_rollout_diagnostics.csv` separates held-out one-step fitting error from recursive quadratic consistency. These are diagnostic quantities, not stability certificates or proof of a particular failure mechanism.\n\n',height(modelSummary));
fprintf(fid,'## Figures\n\n![Error across forecast horizons](forecast_horizons.png)\n\n![Signed nominal errors](nominal_signed_error.png)\n\n![Training singular spectra](singular_spectrum.png)\n');
end

function name=localName(folder)
[~,name]=fileparts(folder);
end
