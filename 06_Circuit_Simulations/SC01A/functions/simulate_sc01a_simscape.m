function result = simulate_sc01a_simscape(p,s,settings)
%SIMULATE_SC01A_SIMSCAPE Integrate the native Simscape conserving circuit.
% Logged samples are native variable-step solver points. No uniform output
% grid is used to impersonate an integration-step refinement. Initial state
% is the consistent DC solution for the sources at t=0 (Solver DoDC=on).
% s.initialState, if supplied, is checked against the resulting circuit DC.
% Rectangular induced voltages and dVa/dt are encoded with duplicate-time
% left/right values. From Workspace uses Interpolate=on and ZeroCross=on to
% register those exact discontinuities with the continuous solver. This
% preserves the specified pulses without filtering or tolerance relaxation.
% Source: https://www.mathworks.com/help/simulink/slref/fromworkspace.html

root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'scripts'));
model='EMI_SC01A_Finite_Edge';
modelFile=fullfile(root,'models',[model '.slx']);
topology=struct('schema',5,'positiveCoupling',p.coupling.Cp_F>0, ...
    'negativeCoupling',p.coupling.Cn_F>0);
if ~bdIsLoaded(model) && exist(modelFile,'file'), load_system(modelFile); end
rebuild=~bdIsLoaded(model);
if ~rebuild
    workspace=get_param(model,'ModelWorkspace');
    rebuild=~hasVariable(workspace,'sc01aTopology') || ...
        ~isequal(getVariable(workspace,'sc01aTopology'),topology);
end
if rebuild
    build_sc01a_model(p);
end
input=Simulink.SimulationInput(model);
input=input.setVariable('sc01aParams',p,'Workspace',model);
signals=sc01a_simscape_signals(s);
names=fieldnames(signals);
for k=1:numel(names)
    input=input.setVariable(names{k},signals.(names{k}),'Workspace',model);
end
input=input.setModelParameter('StopTime',num2str(settings.stopTime_s,17), ...
    'SolverType','Variable-step','Solver','ode23t', ...
    'MaxStep',num2str(settings.maxStep_s,17), ...
    'RelTol',num2str(settings.relativeTolerance,17), ...
    'AbsTol',num2str(settings.absoluteTolerance,17), ...
    'OutputOption','RefineOutputTimes','Refine','1', ...
    'ReturnWorkspaceOutputs','on');
output=sim(input);
% Inspect retained engine diagnostics, not lastwarn (which loses all but the
% final warning). Every simulation warning requires review before accepting
% a run. Preserve the complete diagnostic metadata on disk before failing.
% https://www.mathworks.com/help/simulink/slref/simulink.simulationmetadata.html
executionInfo=output.SimulationMetadata.ExecutionInfo;
if ~isempty(executionInfo.WarningDiagnostics)
    diagnosticDir=fullfile(root,'results','diagnostics');
    if ~exist(diagnosticDir,'dir'), mkdir(diagnosticDir); end
    diagnosticFile=[tempname(diagnosticDir) '.mat'];
    save(diagnosticFile,'executionInfo','p','settings');
    first=executionInfo.WarningDiagnostics(1).Diagnostic;
    error('SC01A:SimulationWarning', ...
        ['Simulation issued %d warning(s) and cannot be accepted. ' ...
         'First warning: %s: %s. Full diagnostics retained in %s'], ...
        numel(executionInfo.WarningDiagnostics),first.identifier,first.message,diagnosticFile);
end
assert(strcmp(executionInfo.StopEvent,'ReachedStopTime'), ...
    'SC01A:IncompleteSimulation','Simulation stopped before its requested stop time: %s', ...
    executionInfo.StopEvent);
result.executionInfo=executionInfo;
result.warningDiagnostics=executionInfo.WarningDiagnostics;
result.warningCount=numel(executionInfo.WarningDiagnostics);
vpos=output.get('sc01aPositiveLog'); vneg=output.get('sc01aNegativeLog');
vg=output.get('sc01aGroundLog'); ig=output.get('sc01aReturnLog');
[result.time_s,idx]=unique(vpos.Time(:),'last');
result.positive_V=double(reshape(vpos.Data,[],1)); result.positive_V=result.positive_V(idx);
result.negative_V=double(reshape(vneg.Data,[],1)); result.negative_V=result.negative_V(idx);
result.ground_V=double(reshape(vg.Data,[],1)); result.ground_V=result.ground_V(idx);
result.returnCurrent_A=double(reshape(ig.Data,[],1)); result.returnCurrent_A=result.returnCurrent_A(idx);
result.differential_V=result.positive_V-result.negative_V;
result.commonMode_V=(result.positive_V+result.negative_V)/2;
result.solver='ode23t'; result.settings=settings;
result.sampleCount=numel(result.time_s);
result.modelFile=modelFile;
result.initialization='Consistent DC steady state of the loaded conserving circuit';
if isfield(s,'initialState')
    actual=[result.positive_V(1); result.negative_V(1); result.returnCurrent_A(1)];
    scale=max(1,max(abs(s.initialState(:))));
    assert(max(abs(actual-s.initialState(:))) < max(1e-6,20*settings.absoluteTolerance*scale), ...
        'SC01A:InitialStateMismatch','Reference initial state differs from native Simscape DC initialization.');
end
end
