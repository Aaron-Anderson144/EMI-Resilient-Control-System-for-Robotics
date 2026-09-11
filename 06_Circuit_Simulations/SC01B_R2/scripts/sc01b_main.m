function study=sc01b_main(options)
%SC01B_MAIN Reproduce native-device and original-SPICE numerical verification.
% MATLAB R2026a + Simscape Electrical and the installed vendor source required.
arguments
    options.OutputFolder (1,1) string = ""
    options.NgspiceExecutable (1,1) string = ""
    options.Cases (1,:) string = strings(1,0)
    options.ReuseCompletedRuns (1,1) logical = false
    options.Finalize (1,1) logical = true
end
root=fileparts(fileparts(mfilename('fullpath')));run(fullfile(root,'sc01b_startup.m'));
if options.OutputFolder==""
    stamp=string(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS'));
    baseFolder=fullfile(root,'results','verification_'+stamp);
    options.OutputFolder=baseFolder;suffix=0;
    while isfolder(options.OutputFolder) || isfile(options.OutputFolder)
        suffix=suffix+1;options.OutputFolder=baseFolder+'_'+string(suffix);
    end
end
if options.NgspiceExecutable=="",options.NgspiceExecutable=fullfile(root,'tools','ngspice','bin','ngspice.exe');end
assert(isfile(options.NgspiceExecutable),'SC01B:RuntimeMissing','See README for the portable ngspice runtime.');
folder=options.OutputFolder;
assert(~isfile(folder),'SC01B:OutputFolderExists','Output path is an existing file: %s',folder);
if isfolder(folder) && ~options.ReuseCompletedRuns
    entries=dir(folder);entries=entries(~ismember({entries.name},{'.','..'}));
    assert(isempty(entries),'SC01B:OutputFolderNotEmpty', ...
        ['Output folder is populated: %s. Choose a fresh folder, or explicitly ', ...
        'set ReuseCompletedRuns=true to resume/rewrite this campaign.'],folder);
end
if ~isfolder(folder),mkdir(folder);end
c=sc01b_criteria();writeJSON(fullfile(folder,'criteria.json'),c);
caseNames=c.caseNames;if ~isempty(options.Cases),caseNames=options.Cases;end
assert(all(ismember(caseNames,c.caseNames)) && numel(unique(caseNames))==numel(caseNames),'SC01B:Cases','Unknown or duplicate cases.');
assert(~options.Finalize || isequal(caseNames,c.caseNames),'SC01B:PartialFinalize','Partial workers must use Finalize=false; collect all five cases before finalization.');
oldConfig=Simulink.fileGenControl('getConfig');restoreConfig=onCleanup(@()Simulink.fileGenControl('setConfig','config',oldConfig));
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'),'CodeGenFolder',fullfile(folder,'codegen'),'createDir',true);
study=struct('criteria',c,'startedUTC',string(datetime('now','TimeZone','UTC')), ...
    'matlabVersion',string(version),'cases',struct());
metricRows={};eventTables={};balanceRows={};comparisonRows={};waveTables={};runRows={};
for name=caseNames
    p=sc01b_case(name);caseFolder=fullfile(folder,name);if ~isfolder(caseFolder),mkdir(caseFolder);end
    writeJSON(fullfile(caseFolder,'parameters.json'),p);
    native=cell(size(c.nativeSteps_s));spice=cell(size(c.spiceSteps_s));
    for k=1:numel(native)
        settings=p.simulation;settings.maxStep_s=c.nativeSteps_s(k);
        tag=string(sprintf('native_%g_ns',settings.maxStep_s*1e9));
        [r,runtime]=sc01b_native_run(p,settings,fullfile(caseFolder,tag+'.mat'),options.ReuseCompletedRuns);native{k}=r;
        runRows{end+1}=runRow(name,tag,r,runtime);
        fprintf('SC01B COMPLETE %s %s samples %d elapsed %.1fs\n',name,tag,numel(r.time_s),runtime);
    end
    for k=1:numel(spice)
        pp=p;pp.simulation.maxStep_s=c.spiceSteps_s(k);tag=string(sprintf('spice_%g_ns',pp.simulation.maxStep_s*1e9));
        runFolder=fullfile(caseFolder,tag);
        [r,runtime]=sc01b_spice_run(pp,runFolder,options.NgspiceExecutable,options.ReuseCompletedRuns);spice{k}=r;
        runRows{end+1}=runRow(name,tag,r,runtime);
        % The complete native data remain in result.mat; remove duplicate ASCII.
        duplicate=fullfile(runFolder,'waveform.dat');if isfile(duplicate),delete(duplicate);end
        fprintf('SC01B COMPLETE %s %s samples %d elapsed %.1fs\n',name,tag,numel(r.time_s),runtime);
    end
    for engine=["native","spice"]
        if engine=="native",r=native{end};else,r=spice{end};end
        [m,e]=sc01b_metrics(r,p);m.Case=name;m.Engine=engine;metricRows{end+1}=m;
        e=addvars(e,repmat(name,height(e),1),repmat(engine,height(e),1),'Before',1,'NewVariableNames',{'Case','Engine'});eventTables{end+1}=e;
        b=sc01b_energy_balance(r,p);b.Case=name;b.Engine=engine;
        b.AcceptanceLimit_J=max(c.balanceAbsoluteTolerance_J,c.balanceRelativeTolerance*b.EnergyScale_J);
        b.Pass=abs(b.Residual_J)<=b.AcceptanceLimit_J;balanceRows{end+1}=b;
        sc01b_export_trace(r,fullfile(caseFolder,engine+'_finest.csv'));
    end
    pairs={native{1},native{3},string(sprintf('native_%g_to_%gns',c.nativeSteps_s(1)*1e9,c.nativeSteps_s(3)*1e9)); ...
        native{2},native{3},string(sprintf('native_%g_to_%gns',c.nativeSteps_s(2)*1e9,c.nativeSteps_s(3)*1e9)); ...
        spice{1},spice{2},string(sprintf('spice_%g_to_%gns',c.spiceSteps_s(1)*1e9,c.spiceSteps_s(2)*1e9)); ...
        native{3},spice{2},string(sprintf('native_to_original_spice_%gns',c.nativeSteps_s(3)*1e9))};
    if ismember(name,c.consistencyCases)
        settings=p.simulation;settings.maxStep_s=c.nativeSteps_s(end);
        settings.consistencyAbsoluteTolerance=1e-13;settings.consistencyRelativeTolerance=1e-9;
        [r,runtime]=sc01b_native_run(p,settings,fullfile(caseFolder,'native_tight_consistency.mat'),options.ReuseCompletedRuns);
        runRows{end+1}=runRow(name,"native_tight_consistency",r,runtime);
        pairs(end+1,:)={native{end},r,"native_consistency_10x"};
        pp=p;pp.simulation.maxStep_s=c.spiceSteps_s(end);
        pp.simulation.relativeTolerance=1e-6;pp.simulation.absoluteTolerance=1e-10;pp.simulation.voltageTolerance=1e-8;
        runFolder=fullfile(caseFolder,'spice_tight_tolerance');clock=tic;
        try
            [r,runtime]=sc01b_spice_run(pp,runFolder,options.NgspiceExecutable,options.ReuseCompletedRuns);
            runRows{end+1}=runRow(name,"spice_tight_tolerance",r,runtime);
            duplicate=fullfile(runFolder,'waveform.dat');if isfile(duplicate),delete(duplicate);end
            pairs(end+1,:)={spice{end},r,"spice_tolerances_10x"};
        catch failure
            if ~strcmp(failure.identifier,'SC01B:NgspiceDiagnostic'),rethrow(failure);end
            % A failed strict-tolerance attempt is evidence of a numerical
            % limitation. Its partial trace is never accepted or compared.
            runtime=toc(clock);diagnostic=string(failure.message);
            rejected=struct('Case',name,'Run',"spice_tight_tolerance",'Step_s',pp.simulation.maxStep_s, ...
                'Samples',0,'StopTime_s',NaN,'Warnings',0,'Runtime_s',runtime, ...
                'Completed',false,'Reused',false,'Diagnostic',diagnostic, ...
                'ChannelOverlapKnown',false,'NativeChannelOverlap_s',NaN);
            runRows{end+1}=rejected;
            writeJSON(fullfile(runFolder,'rejected.json'),struct('Identifier',failure.identifier,'Message',diagnostic,'AcceptedTrace',false));
            duplicate=fullfile(runFolder,'waveform.dat');if isfile(duplicate),delete(duplicate);end
            [~,s]=sc01b_compare(spice{end},spice{end},p,c,"spice_tolerances_10x");
            for field=["WaveformsPassed","InitialStatePassed","EventTimingPassed","EventClassificationMatched", ...
                    "AllEventsResolved","EnergyPassed","CurrentTimingPassed","ExecutionComplete","Pass"]
                s.(field)=false;
            end
            s.MaxWaveformLimitRatio=Inf;s.InitialStateMaxLimitRatio=Inf;s.MaxEventTimeDifference_s=Inf;s.MaxEnergyLimitRatio=Inf;
            s.CurrentTimingComparedEvents=0;s.MaxCurrentEventTimeDifference_s=NaN;s.Diagnostic=diagnostic;
            comparisonRows{end+1}=s;
            fprintf('SC01B REJECTED %s strict SPICE tolerance: incomplete transient; evidence retained.\n',name);
        end
    end
    for k=1:size(pairs,1)
        [w,s]=sc01b_compare(pairs{k,1},pairs{k,2},p,c,pairs{k,3});
        waveTables{end+1}=w;comparisonRows{end+1}=s;
    end
    study.cases.(name)=struct('parameters',p,'nativeFine',native{end},'spiceFine',spice{end});
    save(fullfile(folder,'checkpoint.mat'),'study','metricRows','eventTables','balanceRows','comparisonRows','waveTables','runRows','-v7');
end
study.metrics=struct2table(vertcat(metricRows{:}));study.events=vertcat(eventTables{:});
study.balance=struct2table(vertcat(balanceRows{:}));study.comparisons=struct2table(vertcat(comparisonRows{:}));
study.waveforms=vertcat(waveTables{:});study.runs=struct2table(vertcat(runRows{:}));
for field=["metrics","events","balance","comparisons","waveforms","runs"]
    writetable(study.(field),fullfile(folder,field+'.csv'));
end
if options.Finalize
    study=sc01b_finalize(study,folder);
else
    study.completedUTC=string(datetime('now','TimeZone','UTC'));
    save(fullfile(folder,'study_partial.mat'),'study','-v7');
    fprintf('SC01B worker complete: %d cases, %d recorded runs. Full campaign finalization pending.\n',numel(caseNames),height(study.runs));
end
end

function row=runRow(name,tag,r,runtime)
row=struct('Case',name,'Run',string(tag),'Step_s',r.settings.maxStep_s, ...
    'Samples',numel(r.time_s),'StopTime_s',r.time_s(end),'Warnings',r.warningCount,'Runtime_s',runtime, ...
    'Completed',true,'Reused',runtime==0,'Diagnostic',"", ...
    'ChannelOverlapKnown',false,'NativeChannelOverlap_s',NaN);
if startsWith(string(tag),"native_")
    m=sc01b_metrics(r,r.params);
    row.ChannelOverlapKnown=m.ChannelOverlapKnown;
    row.NativeChannelOverlap_s=m.nativeChannelOverlap_s;
end
end
function writeJSON(path,value)
fid=fopen(path,'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
