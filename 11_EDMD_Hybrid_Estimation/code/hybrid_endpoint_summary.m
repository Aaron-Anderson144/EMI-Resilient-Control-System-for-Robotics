function [summary,perRun,paired] = hybrid_endpoint_summary(endpoints,baselines)
%HYBRID_ENDPOINT_SUMMARY OFFLINE event diagnostics with equal trajectory weight.
% Position/error fields use radians. Std is population within-run error std;
% P95 is nearest-rank absolute error. Summary bias/std/RMSE/P95 are means of
% trajectory metrics, never pooled-origin statistics. Max is the worst error.
% Event windows overlap across event types: nearReversal is target time within
% +/-50 ms of a truth-velocity sign reversal. Missing velocity labels are
% excluded from both reversal groups, but retained in all. Default scoring
% origins exclude initial startup before .2 s; this function adds no origins.
% Failed forecasts remain in counts and make magnitude metrics Inf and signed
% bias NaN. An Inf-Inf paired delta is NaN with bothFailed=true, never a win.
arguments
    endpoints table
    baselines (1,:) string = ["Nominal physics","Persistent innovation","Linear hybrid"]
end
required={'modelName','regime','runName','runIndex','seed','originIndex', ...
    'horizonSamples','horizonSeconds','truthError','measurementError', ...
    'posteriorTruthError','nonfinite','reversalLabelAvailable','nearReversal', ...
    'awayFromReversal','targetInStartup'};
assert(height(endpoints)>0 && all(ismember(required,endpoints.Properties.VariableNames)), ...
    'HybridEndpoints:Schema','A nonempty hybrid_score endpoint table is required.');
keys={'modelName','regime','runIndex','horizonSamples','originIndex'};
assert(height(unique(endpoints(:,keys)))==height(endpoints), ...
    'HybridEndpoints:Duplicate','Duplicate model/run/horizon/origin endpoint.');
assert(all(~endpoints.nearReversal | endpoints.reversalLabelAvailable) && ...
    all(~endpoints.awayFromReversal | endpoints.reversalLabelAvailable) && ...
    all(~(endpoints.nearReversal & endpoints.awayFromReversal)) && ...
    all(~endpoints.reversalLabelAvailable | endpoints.nearReversal | endpoints.awayFromReversal), ...
    'HybridEndpoints:Events','Reversal groups must partition only available labels.');
endpoints.modelName=string(endpoints.modelName);endpoints.regime=string(endpoints.regime);
endpoints.runName=string(endpoints.runName);
names=unique(endpoints.modelName,'stable');regimes=unique(endpoints.regime,'stable');
horizons=unique(endpoints.horizonSamples,'sorted');
events=["all","nearReversal","awayFromReversal"];
runRows=repmat(localRunRow(),0,1);summaryRows=repmat(localSummaryRow(),0,1);
% Cache each trajectory/event origin set once; pair checks do not rescan the
% much larger endpoint table. Cell indices match perRun rows exactly.
runOrigins=cell(0,1);
for regime=regimes'
    for name=names'
        for horizon=horizons'
            common=endpoints(endpoints.regime==regime & endpoints.modelName==name & ...
                endpoints.horizonSamples==horizon,:);
            if isempty(common),continue;end
            for event=events
                selected=localEvent(common,event);firstRow=numel(runRows)+1;
                for runIndex=unique(selected.runIndex,'stable')'
                    part=selected(selected.runIndex==runIndex,:);
                    row=localRunRow();row.modelName=name;row.regime=regime;
                    row.eventGroup=event;row.runName=part.runName(1);row.runIndex=runIndex;
                    row.seed=part.seed(1);row.horizonSamples=horizon;
                    row.horizonSeconds=part.horizonSeconds(1);row.forecastCount=height(part);
                    failed=logical(part.nonfinite) | ~isfinite(part.truthError) | ...
                        ~isfinite(part.measurementError) | ~isfinite(part.posteriorTruthError);
                    row.nonfiniteForecastCount=sum(failed);
                    if ismember('learnedCandidateNonfinite',part.Properties.VariableNames)
                        row.learnedCandidateNonfiniteCount=sum(part.learnedCandidateNonfinite);
                    end
                    row.unknownReversalForecastCount=sum(~part.reversalLabelAvailable);
                    row.startupTargetCount=sum(part.targetInStartup);
                    [row.truthBias,row.truthStd,row.truthRMSE,row.truthP95AbsoluteError, ...
                        row.truthMaxAbsoluteError]=localMetrics(part.truthError,failed);
                    [row.measurementBias,row.measurementStd,row.measurementRMSE, ...
                        row.measurementP95AbsoluteError,row.measurementMaxAbsoluteError]= ...
                        localMetrics(part.measurementError,failed);
                    if any(failed),row.posteriorTruthRMSE=Inf;
                    else,row.posteriorTruthRMSE=sqrt(mean(part.posteriorTruthError.^2));end
                    runRows(end+1,1)=row; %#ok<AGROW>
                    runOrigins{numel(runRows),1}=sort(part.originIndex); %#ok<AGROW>
                end
                row=localSummaryRow();row.modelName=name;row.regime=regime;
                row.eventGroup=event;row.horizonSamples=horizon;
                row.horizonSeconds=common.horizonSeconds(1);
                group=runRows(firstRow:end);row.runCount=numel(group);
                if ~isempty(group)
                    row.forecastCount=sum([group.forecastCount]);
                    row.nonfiniteForecastCount=sum([group.nonfiniteForecastCount]);
                    row.learnedCandidateNonfiniteCount=sum([group.learnedCandidateNonfiniteCount]);
                    row.unknownReversalForecastCount=sum([group.unknownReversalForecastCount]);
                    row.startupTargetCount=sum([group.startupTargetCount]);
                    metricNames={'truthBias','truthStd','truthRMSE','truthP95AbsoluteError', ...
                        'measurementBias','measurementStd','measurementRMSE', ...
                        'measurementP95AbsoluteError','posteriorTruthRMSE'};
                    for field=metricNames,row.(field{1})=mean([group.(field{1})]);end
                    row.truthMaxAbsoluteError=max([group.truthMaxAbsoluteError]);
                    row.measurementMaxAbsoluteError=max([group.measurementMaxAbsoluteError]);
                end
                summaryRows(end+1,1)=row; %#ok<AGROW>
            end
        end
    end
end
perRun=struct2table(runRows);summary=struct2table(summaryRows);
pairRows=repmat(localPairRow(),0,1);
baselines=unique(baselines,'stable');baselines=baselines(ismember(baselines,names));
for k=1:height(perRun)
    candidate=perRun(k,:);
    for baseline=baselines
        if candidate.modelName==baseline,continue;end
        mask=perRun.modelName==baseline & perRun.regime==candidate.regime & ...
            perRun.runIndex==candidate.runIndex & perRun.horizonSamples==candidate.horizonSamples & ...
            perRun.eventGroup==candidate.eventGroup;
        assert(sum(mask)==1,'HybridEndpoints:Pairing','A matching baseline trajectory is missing.');
        other=perRun(mask,:);
        otherIndex=find(mask);
        assert(isequal(runOrigins{k},runOrigins{otherIndex}), ...
            'HybridEndpoints:Pairing','Paired methods must use identical event origins.');
        row=localPairRow();row.regime=candidate.regime;row.eventGroup=candidate.eventGroup;
        row.modelName=candidate.modelName;row.baseline=baseline;row.runName=candidate.runName;
        row.runIndex=candidate.runIndex;row.seed=candidate.seed;
        row.horizonSamples=candidate.horizonSamples;row.horizonSeconds=candidate.horizonSeconds;
        row.forecastCount=candidate.forecastCount;row.modelTruthRMSE=candidate.truthRMSE;
        row.baselineTruthRMSE=other.truthRMSE;
        row.truthRMSEDelta=candidate.truthRMSE-other.truthRMSE;
        row.modelNonfiniteForecastCount=candidate.nonfiniteForecastCount;
        row.baselineNonfiniteForecastCount=other.nonfiniteForecastCount;
        row.pairFailed=candidate.nonfiniteForecastCount>0 || other.nonfiniteForecastCount>0;
        row.bothFailed=candidate.nonfiniteForecastCount>0 && other.nonfiniteForecastCount>0;
        row.modelWins=candidate.truthRMSE<other.truthRMSE;
        pairRows(end+1,1)=row; %#ok<AGROW>
    end
end
paired=struct2table(pairRows);
end

function part=localEvent(part,event)
if event~="all",part=part(logical(part.(char(event))),:);end
end

function [bias,spread,rmse,p95,largest]=localMetrics(error,failed)
if any(failed),bias=NaN;spread=Inf;rmse=Inf;p95=Inf;largest=Inf;return;end
bias=mean(error);spread=std(error,1);rmse=sqrt(mean(error.^2));
ordered=sort(abs(error));p95=ordered(max(1,ceil(.95*numel(ordered))));largest=ordered(end);
end

function row=localRunRow()
row=struct('modelName',"",'regime',"",'eventGroup',"",'runName',"",'runIndex',0, ...
    'seed',NaN,'horizonSamples',0,'horizonSeconds',0,'forecastCount',0, ...
    'nonfiniteForecastCount',0,'learnedCandidateNonfiniteCount',0, ...
    'unknownReversalForecastCount',0,'startupTargetCount',0, ...
    'truthBias',NaN,'truthStd',NaN,'truthRMSE',NaN,'truthP95AbsoluteError',NaN, ...
    'truthMaxAbsoluteError',NaN,'measurementBias',NaN,'measurementStd',NaN, ...
    'measurementRMSE',NaN,'measurementP95AbsoluteError',NaN, ...
    'measurementMaxAbsoluteError',NaN,'posteriorTruthRMSE',NaN);
end

function row=localSummaryRow()
row=localRunRow();row=rmfield(row,{'runName','runIndex','seed'});row.runCount=0;
end

function row=localPairRow()
row=struct('regime',"",'eventGroup',"",'modelName',"",'baseline',"",'runName',"", ...
    'runIndex',0,'seed',NaN,'horizonSamples',0,'horizonSeconds',0,'forecastCount',0, ...
    'modelTruthRMSE',NaN,'baselineTruthRMSE',NaN,'truthRMSEDelta',NaN, ...
    'modelNonfiniteForecastCount',0,'baselineNonfiniteForecastCount',0, ...
    'pairFailed',false,'bothFailed',false,'modelWins',false);
end
