function summary=fourway_v2_native_audit(rawFolder,outputFolder)
% Compare every retained native step with the causal V2 engine, all variants.
arguments
    rawFolder (1,1) string
    outputFolder (1,1) string
end
assert(~isfolder(outputFolder)&&~isfile(outputFolder),'FOURWAYV2:NativeAuditExists','Use a fresh audit directory.');
mkdir(outputFolder);variants=fourway_v2_native_variants();variantRows=cell(384,1);refinementRows=cell(256,1);
nativeRows=cell(24,1);kclRows=cell(8,1);nr=0;nv=0;nf=0;nk=0;
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
engine=string(fourway_v2_build_engine());
generation=jsondecode(fileread(fullfile(rawFolder,'native_generation.json')));
inputs={fullfile(rawFolder,'native_generation.json'),generation.sourceModel,generation.copiedModel, ...
    fullfile(root,'04_EMI_Models','four_way_emi_v2_configuration.json'), ...
    fullfile(root,'06_Circuit_Simulations','RECEIVER_V2','receiver_characterization_config.json'), ...
    fullfile(root,'06_Circuit_Simulations','SC01B_R2','results','verification','nominal','native_finest.csv')};
implementation={which('fourway_v2_native_audit'),which('fourway_v2_native_events'), ...
    which('fourway_v2_native_hash'),which('fourway_v2_native_json'),which('fourway_v2_native_kcl'), ...
    which('fourway_v2_native_parameters'),which('fourway_v2_native_variants'),which('fourway_v2_native_generate'), ...
    which('fourway_v2_receiver_init'),which('fourway_v2_exact'),which('fourway_v2_build_engine'), ...
    which('fourway_v2_replay'),which(char(engine)), ...
    fullfile(root,'06_Circuit_Simulations','FOUR_WAY_V2','functions','fourway_v2_exact_mex.cpp'), ...
    fullfile(root,'06_Circuit_Simulations','RECEIVER_V2','functions','receiver_v2_native_source.m'), ...
    fullfile(root,'06_Circuit_Simulations','RECEIVER_V2','functions','receiver_v2_network.m'), ...
    fullfile(root,'06_Circuit_Simulations','RECEIVER_V2','functions','receiver_v2_parameters.m'), ...
    which('sc01a_parameters'),which('sc01a_simscape_signals'),which('fourway_replay')};
source=struct('rawFolder',rawFolder,'records',{{}},'engine',engine, ...
    'startedAt',string(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX')), ...
    'matlabVersion',version,'matlabRelease',version('-release'),'platform',computer, ...
    'inputFiles',localHashes(inputs),'implementationFiles',localHashes(implementation));
for cd=[100 1000]
    for cp=[40 240]
        for initialA=[0 1]
            caseName=sprintf('Cd%d_Ccp%d_Ccn7_A%d',cd,cp,initialA);
            caseFolder=fullfile(outputFolder,caseName);mkdir(caseFolder);
            [p,design]=fourway_v2_native_parameters(cp,7,cd);
            stop=design.source.period_s;edge=design.source.command_edge_anchor_s;
            transition=[edge,1-initialA,0];virtualTimes=edge+[-75;0;75]*1e-9;
            references=cell(16,1);
            for vi=1:16
                sensor=fourway_v2_receiver_init(cp,7,cd,0,true,variants(vi),design.source.synthetic_return_s,initialA);
                sensor.config.origins=0;
                if engine=="",engine=string(sensor.config.engine_function);end
                assert(engine==string(sensor.config.engine_function),'FOURWAYV2:NativeEngineChanged','Engine changed during audit.');
                [state,events,decoder,boundaries,~,logic]=fourway_v2_exact(sensor.config,sensor.state,stop,transition);
                comparator=logic(logic(:,2)==1,[1 3]);output=logic(logic(:,2)==2,[1 3]);
                counts=localCounts(decoder,virtualTimes);
                references{vi}=struct('variant',variants(vi),'sensor',sensor,'state',state, ...
                    'thresholdEvents',events,'comparatorEvents',comparator,'outputEvents',output, ...
                    'decoderEvents',decoder,'boundaries',boundaries,'counts',counts);
            end
            save(fullfile(caseFolder,'exact_references.mat'),'references','virtualTimes','transition','-v7');
            reference=references{1};nk=nk+1;kcl=fourway_v2_native_kcl(p,reference.sensor.circuit);
            kcl.Case=string(caseName);kclRows{nk}=kcl;previous=[];
            for step_ns=[.5 .25 .125]
                nr=nr+1;rawFile=fullfile(rawFolder,caseName,sprintf('native_%gns',step_ns),'native_raw.mat');
                assert(isfile(rawFile),'FOURWAYV2:MissingNativeRecord','Missing %s.',rawFile);
                rawIdentity=localHashes({rawFile});
                source.inputFiles(end+1)=rawIdentity;
                loaded=load(rawFile,'native','settings','p');native=loaded.native;settings=loaded.settings;
                assert(settings.maxStep_s==step_ns*1e-9&&settings.stopTime_s==stop);
                assert(isequal(loaded.p,p),'FOURWAYV2:NativePhysicsChanged','Native parameters differ from frozen circuit.');
                [~,~,~,~,queries]=fourway_v2_exact(reference.sensor.config,reference.sensor.state,stop,transition,native.time_s);
                assert(isequal(queries(:,1),native.time_s),'FOURWAYV2:NativeQueryTimes','Engine changed query times.');
                actual=[native.positive_V,native.negative_V];voltage=queries(:,2:3);
                voltageError=max(abs(actual-voltage),[],'all');
                differentialError=max(abs((actual(:,1)-actual(:,2))-(voltage(:,1)-voltage(:,2))));
                grid=all(diff(native.time_s)>0)&&max(diff(native.time_s))<=settings.maxStep_s*(1+1e-6)&& ...
                    native.time_s(1)==0&&abs(native.time_s(end)-stop)<=1e-15;
                finite=all(isfinite([actual,native.returnCurrent_A,native.ground_V]),'all');
                initialError=max(abs([actual(1,:) native.returnCurrent_A(1)]-reference.sensor.state(2:4).'));
                physicalPass=native.completed&&native.warningCount==0&&grid&&finite&& ...
                    initialError<=1e-6&&voltageError<=1e-4&&differentialError<=1e-4&&kcl.passed;
                row=struct('Case',string(caseName),'Ccp_pF',cp,'Ccn_pF',7,'Cdiff_pF',cd,'InitialA',initialA, ...
                    'MaxStep_ns',step_ns,'Samples',numel(native.time_s),'Warnings',native.warningCount, ...
                    'RelTol',settings.relativeTolerance,'AbsTol',settings.absoluteTolerance, ...
                    'PointwiseVoltageError_V',voltageError,'DifferentialError_V',differentialError, ...
                    'InitialError',initialError,'GridPass',grid,'FinitePass',finite,'KCLPass',kcl.passed, ...
                    'Pass',physicalPass,'RawFile',rawFile,'RawSHA256',string(rawIdentity.sha256));
                folder=fullfile(caseFolder,sprintf('native_%gns',step_ns));mkdir(folder);
                nativeVariants=cell(16,1);allVariantsPassed=true;outside=false;
                if ~isempty(previous)
                    interpolated=interp1(previous.native.time_s,[previous.native.positive_V previous.native.negative_V],native.time_s,'linear');
                    refinementVoltage=max(abs(interpolated-actual),[],'all');
                    refinementDiff=max(abs((interpolated(:,1)-interpolated(:,2))-(actual(:,1)-actual(:,2))));
                end
                for vi=1:16
                    nv=nv+1;ref=references{vi};actualLogic=fourway_v2_native_events(native,initialA,variants(vi),virtualTimes);
                    nativeVariants{vi}=actualLogic;
                    [thresholdSame,thresholdTime]=localMatch(actualLogic.thresholdEvents,ref.thresholdEvents,2:4);
                    [comparatorSame,comparatorTime]=localMatch(actualLogic.comparatorEvents,ref.comparatorEvents,2);
                    [outputSame,outputTime]=localMatch(actualLogic.outputEvents,ref.outputEvents,2);
                    [decoderSame,decoderTime]=localMatch(actualLogic.decoderEvents,ref.decoderEvents,2:8);
                    countSame=isequal(actualLogic.counts,ref.counts);
                    referenceDomain=~logical(ref.state(14));domainSame=actualLogic.linearNativeOperatingDomainPass==referenceDomain;
                    pass=physicalPass&&thresholdSame&&thresholdTime<=1e-9&&comparatorSame&&comparatorTime<=1e-9&& ...
                        outputSame&&outputTime<=1e-9&&decoderSame&&decoderTime<=1e-9&&countSame&&domainSame&&~actualLogic.grazingUnresolved;
                    vr=struct('Case',string(caseName),'Variant',string(variants(vi).id),'MaxStep_ns',step_ns, ...
                        'ThresholdSequenceExact',thresholdSame,'ThresholdTimeError_ns',thresholdTime*1e9, ...
                        'ComparatorSequenceExact',comparatorSame,'ComparatorTimeError_ns',comparatorTime*1e9, ...
                        'OutputSequenceExact',outputSame,'OutputTimeError_ns',outputTime*1e9, ...
                        'DecoderSequenceExact',decoderSame,'DecoderTimeError_ns',decoderTime*1e9, ...
                        'VirtualCountsExact',countSame,'NativeDomainPass',actualLogic.linearNativeOperatingDomainPass, ...
                        'ReferenceContinuousDomainPass',referenceDomain,'DomainAgreement',domainSame, ...
                        'NativeStressFlag',actualLogic.linearNativeStressFlag,'GrazingUnresolved',actualLogic.grazingUnresolved,'Pass',pass);
                    variantRows{nv}=vr;allVariantsPassed=allVariantsPassed&&pass;outside=outside||~referenceDomain;
                    if ~isempty(previous)
                        nf=nf+1;old=previous.variants{vi};
                        [ts,td]=localMatch(actualLogic.thresholdEvents,old.thresholdEvents,2:4);
                        [cs,cDelta]=localMatch(actualLogic.comparatorEvents,old.comparatorEvents,2);
                        [os,oDelta]=localMatch(actualLogic.outputEvents,old.outputEvents,2);
                        [ds,dDelta]=localMatch(actualLogic.decoderEvents,old.decoderEvents,2:8);
                        integerSame=isequal(actualLogic.counts,old.counts);
                        refinementRows{nf}=struct('Case',string(caseName),'Variant',string(variants(vi).id), ...
                            'CoarseStep_ns',previous.step_ns,'FineStep_ns',step_ns,'VoltageError_V',refinementVoltage, ...
                            'DifferentialError_V',refinementDiff,'ThresholdSequenceExact',ts,'ThresholdTimeError_ns',td*1e9, ...
                            'ComparatorSequenceExact',cs,'ComparatorTimeError_ns',cDelta*1e9, ...
                            'OutputSequenceExact',os,'OutputTimeError_ns',oDelta*1e9, ...
                            'DecoderSequenceExact',ds,'DecoderTimeError_ns',dDelta*1e9,'VirtualCountsExact',integerSame, ...
                            'Pass',refinementVoltage<=1e-4&&refinementDiff<=1e-4&&ts&&td<=1e-9&&cs&&cDelta<=1e-9&& ...
                            os&&oDelta<=1e-9&&ds&&dDelta<=1e-9&&integerSame&&~actualLogic.grazingUnresolved&&~old.grazingUnresolved);
                    end
                end
                row.Pass=row.Pass&&allVariantsPassed;row.DomainRejected=outside;nativeRows{nr}=row;
                save(fullfile(folder,'comparison.mat'),'voltage','nativeVariants','virtualTimes','row','-v7');
                writetable(struct2table(vertcat(nativeRows{1:nr})),fullfile(outputFolder,'native_acceptance.csv'));
                writetable(struct2table(vertcat(variantRows{1:nv})),fullfile(outputFolder,'native_variant_acceptance.csv'));
                if nf>0,writetable(struct2table(vertcat(refinementRows{1:nf})),fullfile(outputFolder,'native_refinements.csv'));end
                previous=struct('native',native,'variants',{nativeVariants},'step_ns',step_ns);
                fprintf('V2 native audit %d/24 %s %.3gns pass=%d voltageError=%.6gV\n',nr,caseName,step_ns,row.Pass,voltageError);
            end
        end
    end
end
nativeTable=struct2table(vertcat(nativeRows{:}));variantTable=struct2table(vertcat(variantRows{:}));
refinementTable=struct2table(vertcat(refinementRows{:}));kclTable=struct2table(vertcat(kclRows{:}));
writetable(kclTable,fullfile(outputFolder,'independent_kcl.csv'));
assert(strcmp(generation.sourceModelSHA256,fourway_v2_native_hash(generation.sourceModel)));
assert(strcmp(generation.copiedModelSHA256,fourway_v2_native_hash(generation.copiedModel)));
summary=struct('gate','C','designId',design.design_id,'passed',false, ...
    'requiredNativeRuns',24,'executedNativeRuns',nr,'passedNativeRuns',sum(nativeTable.Pass), ...
    'requiredVariantRuns',384,'executedVariantRuns',nv,'passedVariantRuns',sum(variantTable.Pass), ...
    'requiredRefinements',256,'executedRefinements',nf,'passedRefinements',sum(refinementTable.Pass), ...
    'integerCountsExact',all(variantTable.VirtualCountsExact)&&all(refinementTable.VirtualCountsExact), ...
    'domainRejectedNativeRuns',sum(nativeTable.DomainRejected),'domainRejectedVariantRuns',sum(~variantTable.ReferenceContinuousDomainPass), ...
    'grazingUnresolvedVariantRuns',sum(variantTable.GrazingUnresolved), ...
    'peakPointwiseVoltageError_V',max(nativeTable.PointwiseVoltageError_V), ...
    'peakDifferentialVoltageError_V',max(nativeTable.DifferentialError_V), ...
    'peakRefinementVoltageError_V',max(refinementTable.VoltageError_V), ...
    'peakRefinementDifferentialError_V',max(refinementTable.DifferentialError_V), ...
    'peakThresholdTimeError_ns',max(variantTable.ThresholdTimeError_ns), ...
    'peakOutputTimeError_ns',max(variantTable.OutputTimeError_ns), ...
    'peakDecoderTimeError_ns',max(variantTable.DecoderTimeError_ns),'independentKCLPassed',all(kclTable.passed), ...
    'voltageAllowance_V',1e-4,'eventAllowance_s',1e-9,'virtualSamplingOffsets_ns',[-75 0 75], ...
    'engine',engine,'physicalValidation',false,'clampCurrent_A',NaN, ...
    'scope','Independent conserving-network numerical agreement and all sixteen conditional receiver variants; no physical receiver validation or integrated reserved evaluation.', ...
    'domainMethod','Exact engine continuous threshold/domain roots; independent native piecewise-linear crossing sequence, signed pin/differential extrema, grazing rejection, and three-step agreement.', ...
    'nativeGeneration',generation);
summary.passed=nr==24&&nv==384&&nf==256&&all(nativeTable.Pass)&&all(variantTable.Pass)&&all(refinementTable.Pass)&&all(kclTable.passed);
source.engine=engine;source.records=table2struct(nativeTable(:,{'Case','MaxStep_ns','RawFile','RawSHA256'}));
localVerifyHashes(source.inputFiles);localVerifyHashes(source.implementationFiles);
source.finishedAt=string(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
source.inputsAndImplementationUnchanged=true;
fourway_v2_native_json(fullfile(outputFolder,'native_source_identity.json'),source);
summary.sourceIdentityFile=fullfile(outputFolder,'native_source_identity.json');
summary.sourceIdentitySHA256=fourway_v2_native_hash(summary.sourceIdentityFile);
fourway_v2_native_json(fullfile(outputFolder,'native_summary.json'),summary);
save(fullfile(outputFolder,'native_summary.mat'),'summary','nativeTable','variantTable','refinementTable','kclTable','-v7');
end

function records=localHashes(paths)
items=cell(numel(paths),1);
for k=1:numel(paths)
    file=char(java.io.File(char(paths{k})).getCanonicalPath());info=dir(file);
    assert(numel(info)==1&&~info.isdir,'FOURWAYV2:IdentityInput','Missing identity file: %s',file);
    items{k}=struct('path',file,'bytes',info.bytes,'sha256',fourway_v2_native_hash(file));
end
records=vertcat(items{:});
end
function localVerifyHashes(records)
for k=1:numel(records)
    info=dir(records(k).path);
    assert(numel(info)==1&&info.bytes==records(k).bytes&&strcmp(fourway_v2_native_hash(records(k).path),records(k).sha256), ...
        'FOURWAYV2:AuditIdentityChanged','Audit input/source changed during execution: %s',records(k).path);
end
end

function [same,delta]=localMatch(a,b,columns)
same=size(a,1)==size(b,1)&&isequal(a(:,columns),b(:,columns));
if size(a,1)~=size(b,1),delta=Inf;elseif isempty(a),delta=0;else,delta=max(abs(a(:,1)-b(:,1)));end
end
function counts=localCounts(decoder,times)
counts=zeros(numel(times),1);
for k=1:numel(times)
    index=find(decoder(:,1)<=times(k),1,'last');if ~isempty(index),counts(k)=decoder(index,5);end
end
end
