function report=run_receiver_characterization(outputDir)
%RUN_RECEIVER_CHARACTERIZATION Reproducible, conditional electrical campaign.
% Requires a fresh output directory. Does not modify historic experiments.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'functions'));
if nargin<1,outputDir=fullfile(root,'results',char(datetime('now','Format','yyyyMMdd_HHmmss')));end
if isfolder(outputDir)
    content=dir(outputDir);assert(numel(content)<=2,'RECEIVER_V2:OutputNotEmpty','Output directory must be empty.');
else,mkdir(outputDir);end
detailDir=fullfile(outputDir,'details');mkdir(detailDir);p=receiver_v2_parameters();
write_json(fullfile(outputDir,'parameters.json'),p);source=receiver_v2_native_source(p);
identity=source_identity(root,source);write_json(fullfile(outputDir,'source_identity.json'),identity);
fixtures=struct([]);
for polarity=p.source.polarities.'
    fixtures=append_struct(fixtures,receiver_v2_fixture(p,source,'native',polarity));
    for width=p.source.syntheticPulseWidths_s.'
        fixtures=append_struct(fixtures,receiver_v2_fixture(p,source,'pulse',polarity,width));
    end
end
cases=struct([]);records=struct([]);started=tic;nc=0;nr=0;
for f=fixtures
    couplings=p.network.Ccp_pF.';if strcmp(f.kind,'pulse'),couplings=couplings(1);end
    for cp=couplings
        for cd=p.network.Cdiff_pF.'
            c=receiver_v2_network(p,cd,cp);
            for exposed=[false true]
                nr=nr+1;recordId=sprintf('%s_cp%g_cd%g_%s',f.id,cp,cd,string(exposed));
                fprintf('Receiver characterization %d: %s\n',nr,recordId);
                s=receiver_v2_segments(p,c,f,exposed);
                coarse=receiver_v2_analyze(p,s,p.numerics.coarseCell_s);
                fine=receiver_v2_analyze(p,s,p.numerics.fineCell_s);
                extremaDifference=max(abs([fine.minSample(1:5)-coarse.minSample(1:5),fine.maxSample(1:5)-coarse.maxSample(1:5)]));
                sameSequence=isequal(size(fine.events),size(coarse.events));eventDifference=Inf;
                if sameSequence
                    sameSequence=isequal(fine.events(:,2:4),coarse.events(:,2:4));
                    eventDifference=max([0;abs(fine.events(:,1)-coarse.events(:,1))]);
                end
                converged=~fine.unresolved&&~coarse.unresolved&&sameSequence ...
                    &&eventDifference<=p.numerics.eventAllowance_s ...
                    &&extremaDifference<=p.numerics.extremaAllowance_V ...
                    &&fine.extremaBoundWidth<=p.numerics.extremaAllowance_V ...
                    &&strcmp(fine.domainStatus,coarse.domainStatus);
                behaviors=struct([]);bi=0;
                for th=p.receiver.thresholdPairs.'
                    for latency=p.receiver.postThresholdLatency_s.'
                        for law=string(p.receiver.pulseLaws).'
                            b=receiver_v2_behavior(s,fine,th,latency,char(law));
                            bc=receiver_v2_behavior(s,coarse,th,latency,char(law));
                            behaviorConverged=converged&&events_equal(b.outputEvents,bc.outputEvents,p.numerics.eventAllowance_s) ...
                                &&events_equal(b.decoderEvents,bc.decoderEvents,p.numerics.eventAllowance_s);
                            bi=bi+1;behaviors=append_struct(behaviors,b);nc=nc+1;
                            caseId=sprintf('%s_%s_%gns_%s',recordId,th.id,latency*1e9,law);
                            newCase=struct('caseId',caseId,'recordId',recordId,'fixtureId',f.id, ...
                                'sourceKind',f.kind,'capacitance_pF',cd,'couplingP_pF',cp, ...
                                'exposed',exposed,'polarity',f.polarity,'pulseLaw',char(law), ...
                                'thresholdVariant',th.id,'latency_ns',latency*1e9,'domainStatus',fine.domainStatus, ...
                                'stressFlag',fine.stressFlag,'stressUnresolved',fine.stressUnresolved, ...
                                'finalCountError',b.finalCountError,'outputEdges',b.outputEdges, ...
                                'extraEdges',b.extraEdges,'missedEdges',b.missedEdges,'invalidTransitions',b.invalidTransitions, ...
                                'minVp_V',fine.minSample(1),'maxVp_V',fine.maxSample(1), ...
                                'minVn_V',fine.minSample(2),'maxVn_V',fine.maxSample(2), ...
                                'minVd_V',fine.minSample(3),'maxVd_V',fine.maxSample(3), ...
                                'maxAbsGround_V',max(abs([fine.minBound(5),fine.maxBound(5)])), ...
                                'firstViolation_s',fine.firstViolation_s,'timeOutsideDomain_s',fine.timeOutsideDomain_s, ...
                                'maxTransitionDelay_ns',b.maxTransitionDelay_s*1e9, ...
                                'maxPositiveOverdrive_V',fine.maxSample(3)-th.rise_V, ...
                                'maxNegativeOverdrive_V',th.fall_V-fine.minSample(3), ...
                                'minInputPulseWidth_ns',min_or_nan(b.inputPulseWidths_s)*1e9, ...
                                'minOutputPulseWidth_ns',min_or_nan(b.outputPulseWidths_s)*1e9, ...
                                'extremaBoundWidth_V',fine.extremaBoundWidth, ...
                                'refinementDifference_V',extremaDifference,'eventDifference_ns',eventDifference*1e9, ...
                                'numericalConverged',behaviorConverged);
                            cases=append_struct(cases,newCase);
                        end
                    end
                end
                record=struct('recordId',recordId,'fixture',f,'capacitance_pF',cd,'couplingP_pF',cp, ...
                    'exposed',exposed,'analysis',fine,'behaviors',behaviors,'refinementDifference_V',extremaDifference, ...
                    'eventDifference_s',eventDifference,'numericalConverged',converged);
                save(fullfile(detailDir,[recordId '.mat']),'record','p','-v7');
                writetable(fine.trace,fullfile(detailDir,[recordId '_trace.csv']));
                writematrix(fine.events,fullfile(detailDir,[recordId '_crossings.csv']));
                eventRows=zeros(0,8);
                for ib=1:numel(behaviors)
                    input=behaviors(ib).inputEvents;output=behaviors(ib).outputEvents;
                    dec=behaviors(ib).decoderEvents;
                    eventRows=[eventRows; ...
                        repmat([ib 1],size(input,1),1),input,nan(size(input,1),4); ...
                        repmat([ib 2],size(output,1),1),output,nan(size(output,1),4); ...
                        repmat([ib 3],size(dec,1),1),dec]; %#ok<AGROW>
                end
                writetable(array2table(eventRows,'VariableNames', ...
                    {'variantIndex','kind_1input_2output_3decoder','time_s','A','B','increment','count','invalid'}), ...
                    fullfile(detailDir,[recordId '_logic.csv']));
                newRecord=struct('recordId',recordId,'domainStatus',fine.domainStatus,'numericalConverged',converged, ...
                    'minBounds_V',fine.minBound(1:5),'maxBounds_V',fine.maxBound(1:5), ...
                    'timeOutsidePin_s',fine.timeOutsidePin_s,'timeOutsideDifferential_s',fine.timeOutsideDifferential_s, ...
                    'maxAbsCircuitCurrent_A',fine.maxAbsCircuitCurrent_A,'maxAbsCouplingCurrent_A',fine.maxAbsCouplingCurrent_A, ...
                    'maxAbsPinSlew_V_s',fine.maxAbsPinSlew_V_s,'clampCurrent_A',NaN);
                records=append_struct(records,newRecord);
            end
        end
    end
end
tab=struct2table(cases);writetable(tab,fullfile(outputDir,'cases.csv'));
valid=strcmp({cases.domainStatus},'inside')&[cases.numericalConverged];
outside=strcmp({cases.domainStatus},'outside');clean=~[cases.exposed];
cleanError=clean&([cases.finalCountError]~=0|[cases.extraEdges]>0|[cases.missedEdges]>0|[cases.invalidTransitions]>0);
exposedError=~clean&[cases.finalCountError]~=0;
dependent=0;validDependent=0;
for j=1:2:numel(cases)
    if cases(j).finalCountError~=cases(j+1).finalCountError||cases(j).outputEdges~=cases(j+1).outputEdges
        dependent=dependent+2;
        if all(valid(j:j+1)),validDependent=validDependent+2;end
    end
end
report=struct('schemaVersion',1,'studyId',p.studyId,'receiverId',p.receiver.part, ...
    'status','conditional_characterization_complete','scope',p.scope,'totalCases',numel(cases), ...
    'circuitRecords',numel(records),'validCases',sum(valid),'invalidCases',sum(outside), ...
    'unresolvedCases',sum(~valid&~outside),'cleanErrorCases',sum(cleanError), ...
    'exposedErrorCases',sum(exposedError),'pulseLawDependentCases',dependent, ...
    'validExposedErrorCases',sum(exposedError&valid),'diagnosticExposedErrorCases',sum(exposedError&~valid), ...
    'validPulseLawDependentCases',validDependent,'physicalValidation',false,'evaluationReady',false, ...
    'suitableForFourWay',all(valid(clean))&&~any(cleanError)&&all(isfinite([cases(clean).maxTransitionDelay_ns])) ...
        &&all([cases(clean).maxTransitionDelay_ns]<=1000)&&all([cases(clean).maxTransitionDelay_ns]>=0), ...
    'generatedAt',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX')), ...
    'elapsedSeconds',toc(started),'source',rmfield(source,{'t','v'}),'sourceIdentity',identity,'cases',cases,'records',records);
report.limitations={ ...
    'Voltage-domain passage establishes only a conditional model-domain result, never physical validation.'; ...
    'Threshold pairs and post-threshold latencies are a finite assumed sensitivity grid, not guaranteed component corners.'; ...
    'Transport and inertial behavior are competing assumptions; propagation delay is not a pulse-rejection specification.'; ...
    'Ideal B, lumped cable, assumed network impedances, no protection/clamp model, and no driver/MCU hardware qualification.'; ...
    'Negative native polarity is a mirrored diagnostic. Synthetic pulses use plateau widths plus two 5 ns ramps.'; ...
    'Domain violations retain diagnostic events and counts but cannot enter control scoring.'; ...
    'This development characterization does not execute or validate the new four-way control experiment.'};
report.findings={sprintf('%d of %d variant cases are continuously inside the modeled voltage domain with converged numerics.',sum(valid),numel(cases)); ...
    sprintf('%d variant cases leave the operating domain; %d remain numerically unresolved.',sum(outside),sum(~valid&~outside)); ...
    sprintf('%d clean cases have count/edge errors; %d valid-domain exposed cases have final count error (%d additional diagnostic rejected cases).',sum(cleanError),sum(exposedError&valid),sum(exposedError&~valid)); ...
    sprintf('%d valid-domain variant cases change final count or edge count between assumed pulse laws (%d total including rejected diagnostics).',validDependent,dependent)};
if ~report.suitableForFourWay,report.status='blocked_by_clean_or_numerical_characterization';end
write_json(fullfile(outputDir,'summary.json'),report);
write_report(fullfile(outputDir,'report.md'),report,p);
make_plot(fullfile(outputDir,'characterization.png'),tab);
fprintf('Completed %d cases in %.1f s.\n',report.totalCases,report.elapsedSeconds);
end
function array=append_struct(array,item)
if isempty(array),array=item;else,array(end+1)=item;end
end
function yes=events_equal(a,b,tol)
yes=isequal(size(a),size(b));if ~yes||isempty(a),return,end
yes=isequal(a(:,2:end),b(:,2:end))&&max(abs(a(:,1)-b(:,1)))<=tol;
end
function value=min_or_nan(values)
value=NaN;if ~isempty(values),value=min(values);end
end
function identity=source_identity(root,source)
files=[dir(fullfile(root,'functions','*.m'));dir(fullfile(root,'scripts','*.m')); ...
    dir(fullfile(root,'tests','*.m'));dir(fullfile(root,'receiver_characterization_config.json'))];
items=cell(numel(files),1);
for j=1:numel(files)
    path=fullfile(files(j).folder,files(j).name);fid=fopen(path,'rb');assert(fid>=0);
    bytes=fread(fid,inf,'*uint8');fclose(fid);
    digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(bytes);
    hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
    relative=replace(path,[root filesep],'');
    items{j}=struct('path',replace(relative,'\','/'),'sha256',hash,'bytes',numel(bytes));
end
identity=struct('studyRoot','06_Circuit_Simulations/RECEIVER_V2','files',[items{:}], ...
    'nativeSourcePath',source.path,'nativeSourceSha256',source.sha256);
end
function write_json(path,value)
fid=fopen(path,'w');assert(fid>=0);closer=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
function write_report(path,r,p)
fid=fopen(path,'w');assert(fid>=0);closer=onCleanup(@()fclose(fid));
fprintf(fid,'# Receiver characterization V2\n\n%s\n\nGenerated %s. %d circuit records / %d behavioral cases.\n\n',r.scope,r.generatedAt,r.circuitRecords,r.totalCases);
for j=1:numel(r.findings),fprintf(fid,'- %s\n',r.findings{j});end
fprintf(fid,'\n## Scope and interpretation\n\n');
for j=1:numel(r.limitations),fprintf(fid,'- %s\n',r.limitations{j});end
fprintf(fid,'\n## Continuous numerical method\n\n%s All source and driver knots retain persistent state. On each interval the stable exponential modes bound the second derivative, giving a continuous interpolation error envelope M2 h^2 / 8. Nonmonotone candidate root cells are subdivided; remaining unresolved cells reject acceptance. Threshold roots are bisected to %.3g s. Extrema are observed values with retained enclosing bounds, not certified exact extrema. Coarse/fine event sequences and count results must agree. Per-record bounds and current/slew bounds are in summary.json and details.\n',p.numerics.method,p.numerics.rootTolerance_s);
fprintf(fid,'\n## Topology and timing\n\n%s Input driver has 47/53 ohm output resistance, 120 ohm termination and assumed shunts/bias paths. THVD1450DR is pre-enabled for at least20us before t=0 with a DC-equilibrium network; supply5V, ambient25C and output load15pF are assumptions. There is no enable transient. Post-threshold latency is an explicit modeling assumption: TI times are referenced to input vd=0. Inertial events at exactly the required duration are accepted; simultaneous A/B changes are grouped before decoding.\n',p.network.groundDefinition);
fprintf(fid,'\n## Reproduction\n\nRun `addpath(genpath(''06_Circuit_Simulations/RECEIVER_V2'')); run_receiver_characterization(freshOutputDirectory)` from the project. Source SHA-256: `%s`. Parameters are copied into parameters.json. Original native timestamps are retained; 100ns synthetic return is separately declared. Synthetic pulse widths mean plateau duration. All synthetic cases are development diagnostics.\n',r.source.sha256);
fprintf(fid,'\nThe `suitableForFourWay` flag is only the clean numerical prerequisite; every exposed control case still requires its own domain and behavior checks. No benefit claim follows from this flag.\n');
fprintf(fid,'\n`extraEdges` and `missedEdges` are net excess/deficit of A-edge count versus the intended sequence, not matched-event classifications. Pulse-law dependence counts paired variants whose total output-edge count or final count differs; it does not compare every waveform timestamp. Input/output pulses and complete decoder events are retained per record in MAT and logic CSV files. Decoder events within1ps are grouped at the latest time in the group before a same-time sample.\n');
end
function make_plot(path,t)
fig=figure('Visible','off','Color','w','Position',[100 100 1250 700]);cl=onCleanup(@()close(fig));
inertial=t(strcmp(t.pulseLaw,'inertial')&strcmp(t.thresholdVariant,'typical_illustration')&t.latency_ns==25,:);
t=t(strcmp(t.pulseLaw,'transport')&strcmp(t.thresholdVariant,'typical_illustration')&t.latency_ns==25,:);
tiledlayout(2,1,'TileSpacing','compact');nexttile;
bar([t.minVp_V t.maxVp_V t.minVn_V t.maxVn_V]);hold on;yline(15,'r--');yline(-15,'r--');
ylabel('Pin voltage (V)');title('Conditional receiver characterization: signed pin extrema');grid on;
legend('vp min','vp max','vn min','vn max','Operating bounds','Location','eastoutside');
nexttile;bar([t.extraEdges-t.missedEdges,inertial.extraEdges-inertial.missedEdges]);
ylabel('Net A-edge surplus');xlabel('Circuit record (cases.csv order)');grid on;
title('Transient edge counts under two assumed pulse laws: typical thresholds, 25 ns latency');
legend('Transport','Inertial','Location','eastoutside');
set(findall(fig,'Type','axes'),'Color','w','XColor',[.15 .15 .15],'YColor',[.15 .15 .15]);
set(findall(fig,'Type','text'),'Color',[.15 .15 .15]);
set(findall(fig,'Type','legend'),'Color','w','TextColor',[.15 .15 .15]);
exportgraphics(fig,path,'Resolution',150);
end
