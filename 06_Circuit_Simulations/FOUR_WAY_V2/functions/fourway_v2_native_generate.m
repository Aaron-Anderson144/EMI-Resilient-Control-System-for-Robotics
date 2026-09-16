function summary=fourway_v2_native_generate(outputFolder,options)
% Retain independent conserving-port time-domain records; no receiver engine.
arguments
    outputFolder (1,1) string
    options (1,1) struct=struct()
end
if ~isfield(options,'caseSelection'),options.caseSelection=strings(1,0);end
if ~isfield(options,'relativeTolerance'),options.relativeTolerance=1e-9;end
if ~isfield(options,'absoluteTolerance'),options.absoluteTolerance=1e-12;end
assert(~isfolder(outputFolder)&&~isfile(outputFolder),'FOURWAYV2:NativeOutputExists','Use a fresh native attempt directory.');
mkdir(outputFolder);
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
sourceFile=fullfile(root,'06_Circuit_Simulations','SC01A','models','EMI_SC01A_Finite_Edge.slx');
model='EMI_FourWay_V2_Native';modelFolder=fullfile(outputFolder,'model');mkdir(modelFolder);
modelFile=fullfile(modelFolder,[model '.slx']);copyfile(sourceFile,modelFile);
assert(strcmp(fourway_v2_native_hash(sourceFile),fourway_v2_native_hash(modelFile)));
load_system(modelFile);cleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
cache=fullfile(outputFolder,'cache');mkdir(cache);
prior=Simulink.fileGenControl('getConfig');
restore=onCleanup(@()Simulink.fileGenControl('setConfig','config',prior)); %#ok<NASGU>
Simulink.fileGenControl('set','CacheFolder',cache,'CodeGenFolder',cache);
src=fourway_replay();rows=cell(24,1);n=0;
for cd=[100 1000]
    for cp=[40 240]
        for initialA=[0 1]
            name=sprintf('Cd%d_Ccp%d_Ccn7_A%d',cd,cp,initialA);
            if ~isempty(options.caseSelection)&&~any(string(options.caseSelection)==string(name)),continue,end
            [p,design]=fourway_v2_native_parameters(cp,7,cd);
            edge=design.source.command_edge_anchor_s;stop=design.source.period_s;
            sourceT=[src.time_s;src.time_s(end)+design.source.synthetic_return_s;stop];
            sourceV=[src.switch_V;src.switch_V(1);src.switch_V(1)];
            level=2*initialA-1;
            dt=[0;edge;edge+p.driver.transitionTime_s;stop];
            values=[level;level;-level;-level]*p.driver.differential_V/2;
            stimulus.voltageAggressor=timeseries(sourceV,sourceT);
            stimulus.sourcePositive=timeseries(p.driver.commonMode_V+values,dt);
            stimulus.sourceNegative=timeseries(p.driver.commonMode_V-values,dt);
            stimulus.currentCommutation=timeseries([0;0],[0;stop]);
            stimulus.inducedPositive=stimulus.currentCommutation;stimulus.inducedNegative=stimulus.currentCommutation;
            caseFolder=fullfile(outputFolder,name);mkdir(caseFolder);
            save(fullfile(caseFolder,'physical_fixture.mat'),'p','design','stimulus','cp','cd','initialA');
            for step=[.5 .25 .125]*1e-9
                n=n+1;folder=fullfile(caseFolder,sprintf('native_%gns',step*1e9));mkdir(folder);
                settings=struct('maxStep_s',step,'stopTime_s',stop, ...
                    'relativeTolerance',options.relativeTolerance,'absoluteTolerance',options.absoluteTolerance);
                started=tic;
                row=struct('Case',string(name),'Cdiff_pF',cd,'Ccp_pF',cp,'Ccn_pF',7,'InitialA',initialA, ...
                    'MaxStep_ns',step*1e9,'Samples',0,'Warnings',NaN,'Completed',false,'Elapsed_s',0,'Error',"");
                try
                    native=localNative(model,p,stimulus,settings);
                    save(fullfile(folder,'native_raw.mat'),'native','settings','p','-v7');
                    row.Samples=numel(native.time_s);row.Warnings=native.warningCount;row.Completed=native.completed;
                catch failure
                    save(fullfile(folder,'rejected_exception.mat'),'failure','settings','p','stimulus');
                    row.Error=string(failure.identifier)+": "+string(failure.message);
                end
                row.Elapsed_s=toc(started);rows{n}=row;
                writetable(struct2table(vertcat(rows{1:n})),fullfile(outputFolder,'native_generation.csv'));
                fprintf('V2 native %d/24 %s %.3gns completed=%d elapsed=%.1fs\n',n,name,step*1e9,row.Completed,row.Elapsed_s);
            end
        end
    end
end
assert(n>0,'FOURWAYV2:NativeSelection','No native fixtures selected.');
completed=vertcat(rows{1:n});
summary=struct('scope','Native electrical solver records only; not yet an accepted Gate C comparison.', ...
    'requiredNativeRecords',24,'recordsGenerated',n,'completedRecords',sum([completed.Completed]), ...
    'sourceModel',sourceFile,'sourceModelSHA256',fourway_v2_native_hash(sourceFile), ...
    'copiedModel',modelFile,'copiedModelSHA256',fourway_v2_native_hash(modelFile), ...
    'sourceSHA256',src.sha256,'passed',false,'physicalValidation',false);
assert(strcmp(summary.sourceModelSHA256,summary.copiedModelSHA256));
fourway_v2_native_json(fullfile(outputFolder,'native_generation.json'),summary);
end

function native=localNative(model,p,stimulus,settings)
input=Simulink.SimulationInput(model);input=input.setVariable('sc01aParams',p,'Workspace',model);
signals=sc01a_simscape_signals(stimulus);names=fieldnames(signals);
for k=1:numel(names),input=input.setVariable(names{k},signals.(names{k}),'Workspace',model);end
input=input.setModelParameter('StopTime',num2str(settings.stopTime_s,17), ...
    'SolverType','Variable-step','Solver','ode23t','MaxStep',num2str(settings.maxStep_s,17), ...
    'RelTol',num2str(settings.relativeTolerance,17),'AbsTol',num2str(settings.absoluteTolerance,17), ...
    'OutputOption','RefineOutputTimes','Refine','1','ReturnWorkspaceOutputs','on');
output=sim(input);info=output.SimulationMetadata.ExecutionInfo;
native=struct('executionInfo',info,'warningCount',numel(info.WarningDiagnostics), ...
    'completed',strcmp(info.StopEvent,'ReachedStopTime'),'settings',settings);
positive=output.get('sc01aPositiveLog');negative=output.get('sc01aNegativeLog');
ground=output.get('sc01aGroundLog');current=output.get('sc01aReturnLog');
[native.time_s,index]=unique(positive.Time(:),'last');
data=double(reshape(positive.Data,[],1));native.positive_V=data(index);
data=double(reshape(negative.Data,[],1));native.negative_V=data(index);
data=double(reshape(ground.Data,[],1));native.ground_V=data(index);
data=double(reshape(current.Data,[],1));native.returnCurrent_A=data(index);
native.differential_V=native.positive_V-native.negative_V;
native.commonMode_V=(native.positive_V+native.negative_V)/2;
end
