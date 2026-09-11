function result=simulate_sc01b_simscape(p,settings)
%SIMULATE_SC01B_SIMSCAPE Native vendor-model halfbridge integration.
% Samples are actual local physical-network integration points, with no output
% resampling or filtering. maxStep_s sets the physical local integration step
% and matching Simulink discrete step, not merely the output sample interval.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'scripts'));
if nargin<2,settings=p.simulation;end
settings=sc01b_local_solver_settings(settings);
model='EMI_SC01B_R2_Halfbridge';modelFile=fullfile(root,'models',[model '.slx']);
if ~bdIsLoaded(model) && exist(modelFile,'file'),load_system(modelFile);end
rebuild=~bdIsLoaded(model);
if ~rebuild
    ws=get_param(model,'ModelWorkspace');rebuild=~hasVariable(ws,'sc01bSchema') || getVariable(ws,'sc01bSchema')~=4;
end
if rebuild,build_sc01b_model(p);end
g=sc01b_gate_signals(p);input=Simulink.SimulationInput(model);
input=input.setVariable('sc01bParams',p,'Workspace',model);
input=input.setVariable('sc01bGateHigh',g.high,'Workspace',model);
input=input.setVariable('sc01bGateLow',g.low,'Workspace',model);
input=input.setModelParameter('SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep',num2str(settings.maxStep_s,17),'RelTol',num2str(settings.relativeTolerance,17), ...
    'AbsTol',num2str(settings.absoluteTolerance,17),'StopTime',num2str(settings.stopTime_s,17), ...
    'MinStepSizeMsg','error','ReturnWorkspaceOutputs','on');
blockSettings={'LocalSolverSampleTime',num2str(settings.maxStep_s,17); ...
    'LocalSolverChoice',settings.localSolverEnum; 'DoFixedCost','off'; ...
    'ConsistencyTolSource','LOCAL'; ...
    'ConsistencyAbsTol',num2str(settings.consistencyAbsoluteTolerance,17); ...
    'ConsistencyRelTol',num2str(settings.consistencyRelativeTolerance,17); ...
    'ConsistencyTolFactor',num2str(settings.consistencyToleranceFactor,17)};
for k=1:size(blockSettings,1)
    input=input.setBlockParameter([model '/ElectricalSolver'],blockSettings{k,1},blockSettings{k,2});
end
out=sim(input);info=out.SimulationMetadata.ExecutionInfo;
if ~isempty(info.WarningDiagnostics)
    folder=fullfile(root,'results','diagnostics');if ~exist(folder,'dir'),mkdir(folder);end
    evidence=[tempname(folder) '.mat'];save(evidence,'info','p','settings');
    diagnostic=info.WarningDiagnostics(1).Diagnostic;
    error('SC01B:SimulationWarning','Simulation has %d warning(s): %s. Diagnostic evidence: %s', ...
        numel(info.WarningDiagnostics),diagnostic.message,evidence);
end
assert(strcmp(info.StopEvent,'ReachedStopTime'),'SC01B:IncompleteSimulation','Native circuit did not reach stop time.');
names={'SwitchVoltage','BusVoltage','HighVgs','HighVds','LowVgs','LowVds', ...
    'HighDrainCurrent','HighSourceCurrent','LowDrainCurrent','LowSourceCurrent', ...
    'HighGateCurrent','LowGateCurrent','LoadCurrent','FeedCurrent'};
fields={'switchVoltage_V','busVoltage_V','highVgs_V','highVds_V','lowVgs_V','lowVds_V', ...
    'highDrainCurrent_A','highSourceCurrent_A','lowDrainCurrent_A','lowSourceCurrent_A', ...
    'highGateCurrent_A','lowGateCurrent_A','loadCurrent_A','feedCurrent_A'};
first=out.get(['sc01b' names{1}]);[result.time_s,index]=unique(first.Time(:),'last');
for k=1:numel(names)
    signal=out.get(['sc01b' names{k}]);assert(isequal(signal.Time,first.Time),'SC01B:LoggingTimes','Native sensor logging times differ.');
    data=double(signal.Data(:));result.(fields{k})=data(index);
end
result.switch_V=result.switchVoltage_V;
result.bus_V=result.busVoltage_V;
result.highCurrent_A=result.highDrainCurrent_A;
result.lowCurrent_A=result.lowDrainCurrent_A;
result.params=p;result.settings=settings;result.solver=settings.localSolverDescription;result.warningCount=0;
result.consistency=struct('source','LOCAL','absoluteTolerance',settings.consistencyAbsoluteTolerance, ...
    'relativeTolerance',settings.consistencyRelativeTolerance, ...
    'factor',settings.consistencyToleranceFactor,'fixedCostIterations',false);
result.warningDiagnostics=info.WarningDiagnostics;result.executionInfo=info;result.modelFile=modelFile;
result.gateSignals=g;result.sampleCount=numel(result.time_s);
nativeLog=out.get('sc01bSimlog');
for prefix={'High','Low'}
    core=nativeLog.([prefix{1} 'MOSFET']).subcircuit.X_1;
    for branch={'G_CHAN','G_DIODE'}
        series=core.(branch{1}).series;
        internalTime=series.time;
        assert(isequal(internalTime(:),first.Time(:)),'SC01B:InternalLoggingTimes', ...
            'Internal device and sensor integration points differ.');
        values=series.values('A');
        suffix='ChannelCurrent_A';if strcmp(branch{1},'G_DIODE'),suffix='DiodeCurrent_A';end
        result.([lower(prefix{1}) suffix])=values(index);
    end
end
result.internalCurrentConvention='Channel: drain-to-source; body diode: source-to-drain';
% The complete internal log is optional; retained channel/diode arrays already
% preserve exact native integration points without making routine files huge.
if isfield(settings,'retainSimscapeLog') && settings.retainSimscapeLog
    result.simscapeLog=nativeLog;
end
end
