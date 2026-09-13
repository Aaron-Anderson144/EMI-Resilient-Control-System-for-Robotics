function [summary,comparisons,benefit] = hybrid_summarize(perRun,plan,runDir)
%HYBRID_SUMMARIZE Equal-run metrics and paired trajectory comparisons.
regimes=plan.testRegimes;names=unique(string(perRun.modelName),'stable');
horizons=plan.testHorizonsSamples;summary=table;comparisons=table;
for regime=regimes
    for name=names'
        for h=horizons
            part=perRun(string(perRun.regime)==regime & string(perRun.modelName)==name & perRun.horizonSamples==h,:);
            assert(height(part)==plan.testRunsPerRegime,'Hybrid:RunCount','Unexpected or missing trajectories.');
            row=table(regime,name,h,height(part),rad2deg(mean(part.truthRMSE)), ...
                rad2deg(mean(part.measurementRMSE)),rad2deg(max(part.peakAbsoluteError)), ...
                mean(part.catastrophicFraction),sum(part.nonfiniteForecastCount), ...
                'VariableNames',{'regime','modelName','horizonSamples','runCount','meanTruthRMSE_deg', ...
                'meanMeasurementRMSE_deg','peakAbsoluteError_deg','meanCatastrophicFraction','nonfiniteForecastCount'});
            summary=[summary;row]; %#ok<AGROW>
        end
    end
end
stream=RandStream('mt19937ar','Seed',20260912);
passes=false(numel(regimes),1);nonfiniteCount=sum(perRun.nonfiniteForecastCount);
for j=1:numel(regimes)
    regime=regimes(j);pass=true;
    edmdNonfinite=sum(perRun.nonfiniteForecastCount(string(perRun.regime)==regime & string(perRun.modelName)=="EDMD hybrid"));
    edmd=sortrows(perRun(string(perRun.regime)==regime & string(perRun.modelName)=="EDMD hybrid" & perRun.horizonSamples==50,:),'seed');
    for baseline=plan.baselines
        other=sortrows(perRun(string(perRun.regime)==regime & string(perRun.modelName)==baseline & perRun.horizonSamples==50,:),'seed');
        assert(isequal(edmd.seed,other.seed),'Hybrid:Pairing','Trajectory pairing differs.');
        a=other.truthRMSE;b=edmd.truthRMSE;n=numel(a);
        improvement=100*(1-mean(b)/mean(a));wins=sum(b<a);
        ci=[NaN,NaN];
        if all(isfinite([a;b])) && mean(a)>0
            index=randi(stream,n,n,10000);
            boot=sort(100*(1-mean(b(index),1)./mean(a(index),1)));
            ci=[boot(250),boot(9750)];
        end
        passed=isfinite(improvement) && improvement>=10 && wins>=7 && edmdNonfinite==0;
        pass=pass && passed;
        comparisons=[comparisons;table(regime,baseline,rad2deg(mean(a)),rad2deg(mean(b)), ...
            improvement,ci(1),ci(2),wins,n,passed,'VariableNames', ...
            {'regime','baseline','baselineMeanRMSE_deg','EDMDMeanRMSE_deg','improvementPercent', ...
            'bootstrap95LowPercent','bootstrap95HighPercent','pairedWins','runCount','comparisonPass'})]; %#ok<AGROW>
    end
    passes(j)=pass;
end
benefit=struct('regimes',regimes,'passed',passes','allRegimesPass',all(passes), ...
    'nonfiniteForecastCountAllModelsAndHorizons',nonfiniteCount,'screen',plan.benefitScreen);
writetable(summary,fullfile(runDir,'regime_forecast_summary.csv'));
writetable(comparisons,fullfile(runDir,'paired_comparisons_50ms.csv'));
hybrid_write_json(fullfile(runDir,'benefit_screen.json'),benefit);
end
