function study = run_communication_edge_study(outputFolder)
%RUN_COMMUNICATION_EDGE_STUDY Save exact constructed E-006D schedule evidence.
% This runs packet bookkeeping only; it does not launch a plant or Simulink.
arguments
    outputFolder (1,1) string = ""
end
matlabRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(matlabRoot,'startup_project.m'));
if outputFolder == ""
    stamp = string(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS'));
    base = fullfile(matlabRoot,'results','development',"communication_edges_"+stamp);
    outputFolder = base; suffix = 0;
    while isfolder(outputFolder) || isfile(outputFolder)
        suffix = suffix+1; outputFolder = base+"_"+suffix;
    end
end
assert(~isfile(outputFolder),'EMIProject:OutputExists','Output path is an existing file.');
if isfolder(outputFolder)
    entries=dir(outputFolder);entries=entries(~ismember({entries.name},{'.','..'}));
    assert(isempty(entries),'EMIProject:OutputExists','Use a new output folder to preserve earlier evidence.');
else
    mkdir(outputFolder);
end
cases = communication_edge_cases();
study.startedUTC = string(datetime('now','TimeZone','UTC'));
study.matlabVersion = string(version);
study.requirement = "E-006D: constructed collision and out-of-order reception";
study.cases = cases;
records = cell(numel(cases),1);
traces = cell(numel(cases),1);
for k = 1:numel(cases)
    c = cases(k);
    actual = schedule_timestamped_packets(c.transmitDelay_samples,c.packetDropped);
    n = numel(c.transmitDelay_samples);
    trace = table(repmat(c.name,n,1),(1:n)',c.transmitDelay_samples,c.packetDropped, ...
        'VariableNames',{'Case','SampleIndex','TransmitDelay_samples','PacketDropped'});
    fields = fieldnames(c.expected);
    exact = true;
    for j = 1:numel(fields)
        name = fields{j};
        trace.(['Expected_' name]) = c.expected.(name);
        trace.(['Actual_' name]) = actual.(name);
        exact = exact && isequal(actual.(name),c.expected.(name));
    end
    accepted = actual.acceptedSourceIndex(actual.sampleReceived);
    causal = all(accepted <= find(actual.sampleReceived));
    increasing = all(diff(accepted) > 0);
    arrivals = nnz(actual.arrivalIndex);
    collisions = sum(actual.collisionDiscardCount);
    outOfOrder = sum(actual.outOfOrderDiscardCount);
    conserved = arrivals == nnz(actual.sampleReceived)+collisions+outOfOrder;
    records{k} = struct('Case',c.name,'Samples',n,'ExpectedScheduleExact',exact, ...
        'AcceptedSourcesCausal',causal,'AcceptedSourcesStrictlyIncreasing',increasing, ...
        'ArrivedPackets',arrivals,'AcceptedPackets',nnz(actual.sampleReceived), ...
        'CollisionDiscards',collisions,'OutOfOrderDiscards',outOfOrder, ...
        'ArrivalAccountingExact',conserved,'Passed',exact && causal && increasing && conserved);
    traces{k} = trace;
    study.cases(k).actual = actual;
end
study.validation = struct2table(vertcat(records{:}));
study.traces = vertcat(traces{:});
study.completedUTC = string(datetime('now','TimeZone','UTC'));
writetable(study.validation,fullfile(outputFolder,'communication_edge_validation.csv'));
writetable(study.traces,fullfile(outputFolder,'communication_edge_schedules.csv'));
save(fullfile(outputFolder,'communication_edge_study.mat'),'study','-v7');
write_run_manifest(outputFolder,matlabRoot,struct('workflow',"communication_edges", ...
    'startedUTC',study.startedUTC,'completedUTC',study.completedUTC, ...
    'requirement',study.requirement,'allPassed',all(study.validation.Passed)));
assert(all(study.validation.Passed),'EMIProject:CommunicationEdgeVerificationFailed', ...
    'A constructed communication schedule differs from its independent expectation.');
disp(study.validation);
end
