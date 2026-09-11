function summary=run_fourway_native_acceptance(outputFolder,caseSelection)
%RUN_FOURWAY_NATIVE_ACCEPTANCE Frozen eight-case native/exact event gate.
% Every native run integrates a cloned conserving-port SC01A Simscape model.
% No historical model is rebuilt, saved, or overwritten. All raw numerical
% records and rejected diagnostics are retained under a fresh output folder.
arguments
 outputFolder (1,1) string
 caseSelection (1,:) string = strings(1,0)
end
assert(~isfolder(outputFolder),'FOURWAY:NativeOutputExists','Use a fresh native evidence folder.');
mkdir(outputFolder);
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
nativeSource=fullfile(root,'06_Circuit_Simulations','SC01A','models','EMI_SC01A_Finite_Edge.slx');
model='EMI_FourWay_Native_Event';
modelFolder=fullfile(outputFolder,'model');mkdir(modelFolder);
modelFile=fullfile(modelFolder,[model '.slx']);copyfile(nativeSource,modelFile);
load_system(modelFile);cleanup=onCleanup(@()close_system(model,0));
cacheFolder=fullfile(outputFolder,'cache');mkdir(cacheFolder);
previousConfig=Simulink.fileGenControl('getConfig');
cacheCleanup=onCleanup(@()Simulink.fileGenControl('setConfig','config',previousConfig));
Simulink.fileGenControl('set','CacheFolder',cacheFolder,'CodeGenFolder',cacheFolder);
row=0;rows=cell(24,1);refinementRows=cell(16,1);refineRow=0;caseCount=0;
for cd=[100 1000]
 for cp=[30 300]
  for initialA=[0 1]
   caseName=sprintf('Cd%d_Ccp%d_A%d',cd,cp,initialA);
   if ~isempty(caseSelection)&&~any(caseSelection==string(caseName)),continue;end
   caseCount=caseCount+1;caseFolder=fullfile(outputFolder,caseName);mkdir(caseFolder);
   sensor=fourway_receiver_init(cp,5,cd,0,true,100e-9,initialA);sensor.config.origins=0;
   transition=[2.019e-6,1-initialA,0];
   [exactState,exactEvents,exactDecoder,exactBoundaries]= ...
    fourway_exact(sensor.config,sensor.state,50e-6,transition);
   virtualTimes=2.019e-6-[-50;0;50]*1e-9;
   exactCounts=fourway_decoder_count_at(exactDecoder,virtualTimes);
   save(fullfile(caseFolder,'exact_reference.mat'),'sensor','transition','exactState', ...
    'exactEvents','exactDecoder','exactBoundaries','virtualTimes','exactCounts','-v7');
   writematrix(exactEvents,fullfile(caseFolder,'exact_threshold_events.csv'));
   writematrix(exactDecoder,fullfile(caseFolder,'exact_decoder_events.csv'));
   stimulus=localStimulus(sensor,initialA);
   previous=[];
   for maxStep=[.5 .25 .125]*1e-9
    row=row+1;runFolder=fullfile(caseFolder,sprintf('native_%gns',maxStep*1e9));mkdir(runFolder);
    settings=struct('maxStep_s',maxStep,'stopTime_s',50e-6, ...
     'relativeTolerance',1e-9,'absoluteTolerance',1e-12);
    started=tic;
    try
     native=localNative(model,sensor.parameters,stimulus,settings);
     save(fullfile(runFolder,'native_raw.mat'),'native','settings','-v7');
     [~,~,~,~,queries]=fourway_exact(sensor.config,sensor.state,50e-6,transition,native.time_s);
     reference=queries(:,2:4);actual=[native.positive_V,native.negative_V,native.returnCurrent_A];
     [events,decoder]=fourway_native_events(native,initialA);
     counts=fourway_decoder_count_at(decoder,virtualTimes);
     voltageError=max(abs(actual(:,1:2)-reference(:,1:2)),[],'all');
     differentialError=max(abs((actual(:,1)-actual(:,2))-(reference(:,1)-reference(:,2))));
     commonError=max(abs((actual(:,1)+actual(:,2)-reference(:,1)-reference(:,2))/2));
     [eventSequence,eventTimeError]=localEventMatch(events,exactEvents);
     decoderSequence=isequal(decoder(:,2:end),exactDecoder(:,2:end));
     [~,decoderTimeError]=localEventMatch(decoder,exactDecoder);
     countsExact=isequal(counts,exactCounts);
     domainPass=all(abs(native.commonMode_V)<=7)&&exactState(14)==0;
     initialError=max(abs(actual(1,:)-sensor.state(2:4).'));
     gridPass=all(diff(native.time_s)>0)&&max(diff(native.time_s))<=maxStep*(1+1e-6)&& ...
      abs(native.time_s(1))<=1e-15&&abs(native.time_s(end)-50e-6)<=1e-15;
     finitePass=all(isfinite(actual),'all');
     % Numerical agreement is separate from receiver-domain usability. The
     % frozen pointwise 0.1mV allowance applies to vp and vn individually;
     % differential/common-mode errors remain explicit diagnostics.
     accepted=native.warningCount==0&&native.completed&&gridPass&&finitePass&& ...
      voltageError<=1e-4&&eventSequence&&eventTimeError<=1e-9&& ...
      decoderSequence&&decoderTimeError<=1e-9&&countsExact&&initialError<=1e-6;
     r=struct('Case',string(caseName),'Cdiff_pF',cd,'Ccp_pF',cp,'InitialA',initialA, ...
      'MaxStep_ns',maxStep*1e9,'Samples',numel(native.time_s),'Warnings',native.warningCount, ...
      'VoltageError_V',voltageError,'DifferentialError_V',differentialError,'CommonModeError_V',commonError, ...
      'EventSequenceExact',eventSequence,'EventTimeError_ns',eventTimeError*1e9, ...
      'DecoderSequenceExact',decoderSequence,'DecoderTimeError_ns',decoderTimeError*1e9, ...
      'VirtualCountsExact',countsExact,'DomainPass',domainPass,'GridPass',gridPass, ...
      'FinitePass',finitePass,'InitialError',initialError,'Pass',accepted,'Elapsed_s',toc(started),'Error',"");
     save(fullfile(runFolder,'native_record.mat'),'native','reference','events','decoder','counts', ...
      'virtualTimes','settings','r','-v7');
     writematrix(events,fullfile(runFolder,'threshold_events.csv'));
     writematrix(decoder,fullfile(runFolder,'decoder_events.csv'));
     if ~isempty(previous)
      refineRow=refineRow+1;
      % Compare pointwise at the finer native grid. Linear interpolation of
      % the coarser retained trace is explicit; this never changes either
      % simulation's native integration steps or decoder event decisions.
      oldVoltage=interp1(previous.native.time_s,[previous.native.positive_V,previous.native.negative_V],native.time_s,'linear');
      refinementVoltage=max(abs(oldVoltage-actual(:,1:2)),[],'all');
      refinementDiff=max(abs((oldVoltage(:,1)-oldVoltage(:,2))-(actual(:,1)-actual(:,2))));
      [eventSame,eventDelta]=localEventMatch(events,previous.events);
      [decoderSame,decoderDelta]=localEventMatch(decoder,previous.decoder);
      decoderSame=decoderSame&&isequal(decoder(:,2:end),previous.decoder(:,2:end));
      countSame=isequal(counts,previous.counts);
      refinementRows{refineRow}=struct('Case',string(caseName),'CoarseStep_ns',previous.settings.maxStep_s*1e9, ...
       'FineStep_ns',maxStep*1e9,'VoltageError_V',refinementVoltage,'DifferentialError_V',refinementDiff, ...
       'EventSequenceExact',eventSame,'EventTimeError_ns',eventDelta*1e9, ...
       'DecoderSequenceExact',decoderSame,'DecoderTimeError_ns',decoderDelta*1e9, ...
       'VirtualCountsExact',countSame,'Pass',refinementVoltage<=1e-4&& ...
       eventSame&&eventDelta<=1e-9&&decoderSame&&decoderDelta<=1e-9&&countSame);
     end
     previous=struct('native',native,'events',events,'decoder',decoder,'counts',counts,'settings',settings);
    catch caught
     save(fullfile(runFolder,'rejected_exception.mat'),'caught','settings','sensor','stimulus');
     r=struct('Case',string(caseName),'Cdiff_pF',cd,'Ccp_pF',cp,'InitialA',initialA, ...
      'MaxStep_ns',maxStep*1e9,'Samples',0,'Warnings',NaN,'VoltageError_V',NaN, ...
      'DifferentialError_V',NaN,'CommonModeError_V',NaN,'EventSequenceExact',false,'EventTimeError_ns',NaN, ...
      'DecoderSequenceExact',false,'DecoderTimeError_ns',NaN,'VirtualCountsExact',false,'DomainPass',false, ...
      'GridPass',false,'FinitePass',false,'InitialError',NaN,'Pass',false,'Elapsed_s',toc(started), ...
      'Error',string(caught.identifier)+": "+string(caught.message));
     previous=[];
    end
    rows{row}=r;writetable(struct2table(vertcat(rows{1:row})),fullfile(outputFolder,'native_acceptance.csv'));
    fprintf('FOURWAY native %d/24 %s %.3gns pass=%d elapsed=%.1fs\n',row,caseName,maxStep*1e9,r.Pass,r.Elapsed_s);
   end
  end
 end
end
assert(caseCount>0,'FOURWAY:NativeSelection','No frozen native fixtures selected.');
tableRows=struct2table(vertcat(rows{1:row}));
if refineRow>0,refinements=struct2table(vertcat(refinementRows{1:refineRow}));else,refinements=table();end
writetable(refinements,fullfile(outputFolder,'native_refinements.csv'));
summary=struct('requiredNativeRuns',3*caseCount,'executedNativeRuns',height(tableRows),'passedNativeRuns',sum(tableRows.Pass), ...
 'requiredRefinements',2*caseCount,'executedRefinements',refineRow,'passedRefinements',0, ...
 'receiverDomainRejectedRuns',sum(~tableRows.DomainPass), ...
 'absoluteVoltageGate_V',1e-4,'eventTimingGate_s',1e-9,'integerCountsExact',all(tableRows.VirtualCountsExact), ...
 'solver',"ode23t native Simscape conserving network",'sourceModel',string(nativeSource), ...
 'nativeModel',modelFile,'passed',false);
if refineRow>0,summary.passedRefinements=sum(refinements.Pass);end
summary.passed=summary.passedNativeRuns==3*caseCount&&summary.passedRefinements==2*caseCount;
fid=fopen(fullfile(outputFolder,'native_summary.json'),'w');fprintf(fid,'%s',jsonencode(summary,'PrettyPrint',true));fclose(fid);
save(fullfile(outputFolder,'native_summary.mat'),'summary','tableRows','refinements');
end

function s=localStimulus(sensor,initialA)
level=2*initialA-1;t=[0;2.019e-6;2.119e-6;50e-6];values=[level;level;-level;-level];
s.voltageAggressor=timeseries(sensor.config.volts,sensor.config.knots);
s.sourcePositive=timeseries(2.5+values,t);s.sourceNegative=timeseries(2.5-values,t);
s.currentCommutation=timeseries([0;0],[0;50e-6]);
s.inducedPositive=timeseries([0;0],[0;50e-6]);s.inducedNegative=s.inducedPositive;
end

function result=localNative(model,p,s,settings)
input=Simulink.SimulationInput(model);input=input.setVariable('sc01aParams',p,'Workspace',model);
signals=sc01a_simscape_signals(s);names=fieldnames(signals);
for k=1:numel(names),input=input.setVariable(names{k},signals.(names{k}),'Workspace',model);end
input=input.setModelParameter('StopTime',num2str(settings.stopTime_s,17), ...
 'SolverType','Variable-step','Solver','ode23t','MaxStep',num2str(settings.maxStep_s,17), ...
 'RelTol',num2str(settings.relativeTolerance,17),'AbsTol',num2str(settings.absoluteTolerance,17), ...
 'OutputOption','RefineOutputTimes','Refine','1','ReturnWorkspaceOutputs','on');
output=sim(input);execution=output.SimulationMetadata.ExecutionInfo;
result.executionInfo=execution;result.warningCount=numel(execution.WarningDiagnostics);
result.completed=strcmp(execution.StopEvent,'ReachedStopTime');
vpos=output.get('sc01aPositiveLog');vneg=output.get('sc01aNegativeLog');
ig=output.get('sc01aReturnLog');vg=output.get('sc01aGroundLog');
[result.time_s,idx]=unique(vpos.Time(:),'last');
result.positive_V=double(reshape(vpos.Data,[],1));result.positive_V=result.positive_V(idx);
result.negative_V=double(reshape(vneg.Data,[],1));result.negative_V=result.negative_V(idx);
result.returnCurrent_A=double(reshape(ig.Data,[],1));result.returnCurrent_A=result.returnCurrent_A(idx);
result.ground_V=double(reshape(vg.Data,[],1));result.ground_V=result.ground_V(idx);
result.differential_V=result.positive_V-result.negative_V;
result.commonMode_V=(result.positive_V+result.negative_V)/2;
result.settings=settings;
end

function [same,timeError]=localEventMatch(a,b)
same=isequal(size(a),size(b))&&isequal(a(:,2:4),b(:,2:4));
if size(a,1)~=size(b,1),timeError=Inf;elseif isempty(a),timeError=0;else,timeError=max(abs(a(:,1)-b(:,1)));end
end
