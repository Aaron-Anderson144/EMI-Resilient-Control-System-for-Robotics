function summary=audit_fourway_native_acceptance(nativeFolders,outputFolder)
%AUDIT_FOURWAY_NATIVE_ACCEPTANCE Bind retained native grids to final engine.
% Later source folders replace earlier ones only when the exact frozen
% fixture/step raw file exists there. Every selected raw path/hash is saved.
% Solver agreement and receiver-domain usability are separate outcomes.
arguments
 nativeFolders (1,:) string
 outputFolder (1,1) string
end
assert(~isfolder(outputFolder),'FOURWAY:AuditOutputExists','Use fresh audit output.');mkdir(outputFolder);
rows=cell(24,1);refinementRows=cell(16,1);runIndex=0;refinementIndex=0;engine="";
for cd=[100 1000]
 for cp=[30 300]
  for initialA=[0 1]
   caseName=sprintf('Cd%d_Ccp%d_A%d',cd,cp,initialA);caseFolder=fullfile(outputFolder,caseName);mkdir(caseFolder);
   sensor=fourway_receiver_init(cp,5,cd,0,true,100e-9,initialA);sensor.config.origins=0;
   if engine=="",engine=string(sensor.config.engine_function);end
   assert(engine==string(sensor.config.engine_function),'FOURWAY:EngineChanged','Engine changed during final audit.');
   transition=[2.019e-6,1-initialA,0];virtualTimes=2.019e-6-[-50;0;50]*1e-9;
   [exactState,exactEvents,exactDecoder,exactBoundaries]=fourway_exact(sensor.config,sensor.state,50e-6,transition);
   exactCounts=fourway_decoder_count_at(exactDecoder,virtualTimes);
   save(fullfile(caseFolder,'exact_reference.mat'),'sensor','transition','virtualTimes','exactState', ...
    'exactEvents','exactDecoder','exactBoundaries','exactCounts','-v7');
   previous=[];
   for step_ns=[.5 .25 .125]
    sourceFile="";
    for folder=nativeFolders
     candidate=fullfile(folder,caseName,sprintf('native_%gns',step_ns),'native_raw.mat');
     if isfile(candidate),sourceFile=candidate;end
    end
    assert(sourceFile~="",'FOURWAY:MissingNativeRecord','Missing native record for %s %.3gns.',caseName,step_ns);
    loaded=load(sourceFile,'native','settings');native=loaded.native;settings=loaded.settings;
    assert(settings.maxStep_s==step_ns*1e-9,'FOURWAY:WrongNativeSettings','Recorded step differs from fixture.');
    sourceHash=localHash(sourceFile);
    [~,~,~,~,queries]=fourway_exact(sensor.config,sensor.state,50e-6,transition,native.time_s);
    reference=queries(:,2:4);actual=[native.positive_V,native.negative_V,native.returnCurrent_A];
    assert(isequal(queries(:,1),native.time_s),'FOURWAY:ExactQueryTimes','Exact reference returned different query times.');
    [events,decoder]=fourway_native_events(native,initialA);counts=fourway_decoder_count_at(decoder,virtualTimes);
    voltageError=max(abs(actual(:,1:2)-reference(:,1:2)),[],'all');
    differentialError=max(abs(actual(:,1)-actual(:,2)-reference(:,1)+reference(:,2)));
    [eventSame,eventTimeError]=localMatch(events,exactEvents,false);
    [decoderSame,decoderTimeError]=localMatch(decoder,exactDecoder,true);
    countsSame=isequal(counts,exactCounts);
    nativeDomainFailed=any(abs(native.commonMode_V)>7);exactDomainFailed=logical(exactState(14));
    domainAgreement=nativeDomainFailed==exactDomainFailed;
    gridPass=all(diff(native.time_s)>0)&&max(diff(native.time_s))<=settings.maxStep_s*(1+1e-6)&& ...
     native.time_s(1)==0&&abs(native.time_s(end)-50e-6)<=1e-15;
    finitePass=all(isfinite(actual),'all');
    pass=native.warningCount==0&&native.completed&&gridPass&&finitePass&&voltageError<=1e-4&& ...
     eventSame&&eventTimeError<=1e-9&&decoderSame&&decoderTimeError<=1e-9&&countsSame&&domainAgreement;
    runIndex=runIndex+1;
    row=struct('Case',string(caseName),'MaxStep_ns',step_ns,'Samples',numel(native.time_s), ...
     'RelTol',settings.relativeTolerance,'AbsTol',settings.absoluteTolerance, ...
     'Warnings',native.warningCount,'VoltageError_V',voltageError,'DifferentialError_V',differentialError, ...
     'EventSequenceExact',eventSame,'EventTimeError_ns',eventTimeError*1e9, ...
     'DecoderSequenceExact',decoderSame,'DecoderTimeError_ns',decoderTimeError*1e9, ...
     'VirtualCountsExact',countsSame,'NativeDomainFailed',nativeDomainFailed,'ExactDomainFailed',exactDomainFailed, ...
     'DomainAgreement',domainAgreement,'GridPass',gridPass,'FinitePass',finitePass,'NumericalPass',pass, ...
     'RawNativeFile',sourceFile,'RawNativeSHA256',sourceHash,'Engine',engine);
    rows{runIndex}=row;
    runFolder=fullfile(caseFolder,sprintf('native_%gns',step_ns));mkdir(runFolder);
    save(fullfile(runFolder,'comparison.mat'),'reference','events','decoder','counts','virtualTimes','row','-v7');
    writematrix(events,fullfile(runFolder,'native_events.csv'));writematrix(decoder,fullfile(runFolder,'native_decoder.csv'));
    if ~isempty(previous)
     oldVoltage=interp1(previous.native.time_s,[previous.native.positive_V,previous.native.negative_V],native.time_s,'linear');
     error=max(abs(oldVoltage-actual(:,1:2)),[],'all');
     [sameEvent,eventDelta]=localMatch(events,previous.events,false);
     [sameDecoder,decoderDelta]=localMatch(decoder,previous.decoder,true);
     sameCounts=isequal(counts,previous.counts);
     refinementIndex=refinementIndex+1;
     refinementRows{refinementIndex}=struct('Case',string(caseName),'CoarseStep_ns',previous.step_ns, ...
      'FineStep_ns',step_ns,'VoltageError_V',error,'EventSequenceExact',sameEvent,'EventTimeError_ns',eventDelta*1e9, ...
      'DecoderSequenceExact',sameDecoder,'DecoderTimeError_ns',decoderDelta*1e9,'VirtualCountsExact',sameCounts, ...
      'NumericalPass',error<=1e-4&&sameEvent&&eventDelta<=1e-9&&sameDecoder&&decoderDelta<=1e-9&&sameCounts);
    end
    previous=struct('native',native,'events',events,'decoder',decoder,'counts',counts,'step_ns',step_ns);
   end
   fprintf('Final engine native audit: %s\n',caseName);
  end
 end
end
nativeTable=struct2table(vertcat(rows{:}));refinementTable=struct2table(vertcat(refinementRows{:}));
writetable(nativeTable,fullfile(outputFolder,'native_final_acceptance.csv'));
writetable(refinementTable,fullfile(outputFolder,'native_final_refinements.csv'));
summary=struct('requiredNativeRecords',24,'nativeRecordsAudited',runIndex, ...
 'nativeRecordsNumericallyPassed',sum(nativeTable.NumericalPass),'refinementsRequired',16, ...
 'refinementsPassed',sum(refinementTable.NumericalPass),'receiverDomainRejectedRecords',sum(nativeTable.NativeDomainFailed), ...
 'receiverDomainRejectedFixtures',numel(unique(nativeTable.Case(nativeTable.NativeDomainFailed))), ...
 'peakPointwiseVoltageError_V',max(nativeTable.VoltageError_V), ...
 'peakRefinementVoltageError_V',max(refinementTable.VoltageError_V), ...
 'peakThresholdTimeError_ns',max(nativeTable.EventTimeError_ns),'engine',engine, ...
 'passed',all(nativeTable.NumericalPass)&&all(refinementTable.NumericalPass), ...
 'scope',"Numerical engine/circuit agreement; domain-rejected cases remain unusable for control-effect inference.");
fid=fopen(fullfile(outputFolder,'native_final_summary.json'),'w');fprintf(fid,'%s',jsonencode(summary,'PrettyPrint',true));fclose(fid);
save(fullfile(outputFolder,'native_final_summary.mat'),'summary','nativeTable','refinementTable');disp(summary);
end

function [same,delta]=localMatch(a,b,decoder)
same=isequal(size(a),size(b));
if same
 if decoder,same=isequal(a(:,2:end),b(:,2:end));else,same=isequal(a(:,2:4),b(:,2:4));end
end
if size(a,1)~=size(b,1),delta=Inf;elseif isempty(a),delta=0;else,delta=max(abs(a(:,1)-b(:,1)));end
end

function value=localHash(path)
fid=fopen(path,'rb');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
digest=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid),bytes=fread(fid,1024*1024,'*uint8');digest.update(bytes);end
value=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end
