function study = run_sc01a(outputFolder,options)
%RUN_SC01A Execute the finite-edge native-circuit verification campaign.
arguments
    outputFolder (1,1) string = ""
    options.IncludePWM (1,1) logical = true
end
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'functions'));
outputFolder=sc01a_prepare_output_folder(outputFolder,fullfile(root,'results'),"sc01a");
oldConfig=Simulink.fileGenControl('getConfig');
cacheCleanup=onCleanup(@()Simulink.fileGenControl('setConfig','config',oldConfig));
Simulink.fileGenControl('set','CacheFolder',fullfile(outputFolder,'cache'), ...
    'CodeGenFolder',fullfile(outputFolder,'codegen'),'createDir',true);
rawFolder=fullfile(outputFolder,'raw');if ~isfolder(rawFolder),mkdir(rawFolder);end
p0=sc01a_parameters();
study.meta.createdUTC=string(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss z'));
study.meta.outputFolder=outputFolder;
study.meta.matlabVersion=string(version);
study.meta.parameterId=p0.meta.id;
study.meta.scope="Native Simscape finite-edge test-source harness; independent piecewise-exact circuit reference; assumed parameters";
study.meta.inductiveModel="Prescribed series M*dI/dt sources, not reciprocal mutual-inductor device model";
study.meta.referenceKnotPolicy="Algebraic ground error excludes exact source-corner timestamps (within 1e-15 s); state outputs remain checked everywhere";
study.params=p0;
names=["baseline","capacitive_rise","inductive_rise","shared_rise", ...
    "combined_rise","combined_fall","balanced_combined","zero_coupling", ...
    "zero_source","logic_low","transition_leads","transition_coincident", ...
    "transition_lags","stress_fall"];
if options.IncludePWM,names=[names,"pwm_10","pwm_20"];end
sc01a_write_manifest(p0,names,outputFolder);
steps=[1e-9 0.5e-9 0.25e-9];
records={}; convergence={}; details=cell(numel(names),3);
study.examples=struct;
for caseIndex=1:numel(names)
    c=sc01a_case(names(caseIndex),p0);p=c.params;
    s=sc01a_stimulus(p,c);
    baseCase=c;baseCase.capacitive=false;baseCase.inductive=false;baseCase.shared=false;
    baseStimulus=sc01a_stimulus(p,baseCase);
    for level=1:3
        settings=struct('stopTime_s',c.stopTime_s,'maxStep_s',steps(level), ...
            'relativeTolerance',1e-5,'absoluteTolerance',1e-9);
        clock=tic;
        r=simulate_sc01a_simscape(p,s,settings);
        runtime=toc(clock);
        baseline=sc01a_baseline(p,baseStimulus,r.time_s);
        [metrics,events]=sc01a_metrics(r,baseline,p);
        % Keep representative native solver grids for the required waveform
        % overlay. These are the existing campaign runs, not extra runs.
        if c.name=="combined_rise"
            study.refinementExamples.combined_rise(level)=struct( ...
                'result',r,'baseline',baseline,'stimulus',s,'params',p, ...
                'maxStep_s',steps(level));
        end
        % All native short-record points; a fixed 100,001-point subset of
        % native long-record points plus every source corner and neighbor.
        sampleIndex=localReferenceIndices(r.time_s,s.knots_s);
        oracle=sc01a_reference(p,s,r.time_s(sampleIndex));
        vgMask=true(numel(sampleIndex),1);
        for knot=s.knots_s.'
            vgMask=vgMask & abs(oracle.time_s-knot)>1e-15;
        end
        dmError=max(abs(r.differential_V(sampleIndex)-oracle.differential_V));
        cmError=max(abs(r.commonMode_V(sampleIndex)-oracle.commonMode_V));
        groundDelta=r.ground_V(sampleIndex)-oracle.ground_V;
        groundError=max(abs(groundDelta(vgMask)));
        currentError=max(abs(r.returnCurrent_A(sampleIndex)-oracle.returnCurrent_A));
        finite=all(isfinite([r.positive_V;r.negative_V;r.ground_V;r.returnCurrent_A]));
        referencePassed=dmError<=max(1e-4,0.01*metrics.PeakDM_V) && ...
            cmError<=max(1e-4,0.01*metrics.PeakCM_V) && ...
            groundError<=max(1e-4,0.01*metrics.PeakGround_V) && ...
            currentError<=max(1e-6,0.01*max(abs(r.returnCurrent_A)));
        record=metrics;
        record.Case=c.name;record.Level=level;
        record.MaxStep_s=settings.maxStep_s;record.RelativeTolerance=settings.relativeTolerance;
        record.AbsoluteTolerance=settings.absoluteTolerance;record.Runtime_s=runtime;
        record.NativeSamples=numel(r.time_s);record.ReferenceSamples=numel(sampleIndex);
        record.ReferenceDMError_V=dmError;record.ReferenceCMError_V=cmError;
        record.ReferenceGroundError_V=groundError;record.ReferenceCurrentError_A=currentError;
        record.ReferencePassed=referencePassed;record.AllFinite=finite;
        record.WarningCount=r.warningCount;record.StopEvent=string(r.executionInfo.StopEvent);
        records{end+1,1}=record; %#ok<AGROW>
        detail=struct('metrics',metrics,'events',events);
        details{caseIndex,level}=detail;
        if level>1
            check=sc01a_compare_refinement(details{caseIndex,level-1},detail,p);
            check.Case=c.name;check.Comparison="step_"+(level-1)+"_to_"+level;
            convergence{end+1,1}=check; %#ok<AGROW>
        end
        fprintf('%s | step %.2f ns | %.1f s | %d samples | peak DM %.6g V | oracle DM %.3g V\n', ...
            c.name,steps(level)*1e9,runtime,numel(r.time_s),metrics.PeakDM_V,dmError);
        if level==3
            save(fullfile(rawFolder,"sc01a_"+c.name+".mat"),'r','p','c','s','metrics','events','-v7');
            writetable(events,fullfile(outputFolder,"sc01a_"+c.name+"_events.csv"));
            if c.periods==0
                trajectory=localTable(r,baseline);
                writetable(trajectory,fullfile(outputFolder,"sc01a_"+c.name+"_timeseries.csv"));
                study.examples.(c.name)=struct('result',r,'baseline',baseline,'stimulus',s,'params',p);
            else
                lastPeriod=r.time_s>=c.stopTime_s-1/p.source.pwmFrequency_Hz;
                trajectory=localTable(localSubset(r,lastPeriod),localSubset(baseline,lastPeriod));
                writetable(trajectory,fullfile(outputFolder,"sc01a_"+c.name+"_last_period.csv"));
            end
        end
        study.metrics=struct2table(vertcat(records{:}));
        writetable(study.metrics,fullfile(outputFolder,'sc01a_case_metrics.csv'));
        if ~isempty(convergence)
            study.convergence=struct2table(vertcat(convergence{:}));
            writetable(study.convergence,fullfile(outputFolder,'sc01a_convergence.csv'));
        end
    end
end

% Tighten both tolerances tenfold on representative source/threshold cases.
tightNames=["capacitive_rise","combined_rise","stress_fall"];
tightRecords={};
for name=tightNames
    c=sc01a_case(name,p0);p=c.params;s=sc01a_stimulus(p,c);
    baseCase=c;baseCase.capacitive=false;baseCase.inductive=false;baseCase.shared=false;
    settings=struct('stopTime_s',c.stopTime_s,'maxStep_s',0.25e-9, ...
        'relativeTolerance',1e-6,'absoluteTolerance',1e-10);
    r=simulate_sc01a_simscape(p,s,settings);
    baseline=sc01a_baseline(p,sc01a_stimulus(p,baseCase),r.time_s);
    [m,e]=sc01a_metrics(r,baseline,p);
    check=sc01a_compare_refinement(details{find(names==name,1),3},struct('metrics',m,'events',e),p);
    check.Case=name;check.Comparison="tolerance_10x_tighter";
    check.WarningCount=r.warningCount;check.StopEvent=string(r.executionInfo.StopEvent);
    tightRecords{end+1,1}=check; %#ok<AGROW>
    fprintf('Tolerance refinement %s: passed=%d\n',name,check.Passed);
end
study.tolerance=struct2table(vertcat(tightRecords{:}));
writetable(study.tolerance,fullfile(outputFolder,'sc01a_tolerance_refinement.csv'));
study.nativeInvariants=localNativeInvariants(study.examples,p0);
writetable(study.nativeInvariants,fullfile(outputFolder,'sc01a_native_invariants.csv'));
if options.IncludePWM
    study.periodComparison=localPeriodComparison(rawFolder,p0);
    writetable(study.periodComparison,fullfile(outputFolder,'sc01a_period_settling.csv'));
end
study.meta.nativeRuns=height(study.metrics)+numel(tightNames);
study.meta.allGatesPassed=all(study.metrics.ReferencePassed & study.metrics.AllFinite) && ...
    all(study.convergence.Passed) && all(study.tolerance.Passed) && all(study.nativeInvariants.Passed) && ...
    all(study.metrics.WarningCount==0) && all(study.tolerance.WarningCount==0) && ...
    all(study.metrics.StopEvent=="ReachedStopTime") && all(study.tolerance.StopEvent=="ReachedStopTime");
if options.IncludePWM,study.meta.allGatesPassed=study.meta.allGatesPassed && all(study.periodComparison.Passed);end
save(fullfile(outputFolder,'sc01a_study.mat'),'study','-v7');
fid=fopen(fullfile(outputFolder,'sc01a_parameters.json'),'w');
assert(fid>=0,'SC01A:CannotWriteManifest','Cannot write parameter manifest.');
fprintf(fid,'%s',jsonencode(p0,PrettyPrint=true));fclose(fid);
plot_sc01a(study,outputFolder);
plot_sc01a_refinement(study.refinementExamples.combined_rise,outputFolder);
assert(study.meta.allGatesPassed,'SC01A:VerificationGateFailed', ...
    'At least one circuit verification gate failed; inspect the saved evidence tables.');
fprintf('SC-01A complete: %d native runs, all declared gates passed.\n',study.meta.nativeRuns);
% The adapter restores saved model defaults after each run. Rebuilding the
% stored model and its diagram is an explicit build_sc01a_model operation.
fprintf('Results folder: %s\n',outputFolder);
end

function indices=localReferenceIndices(t,knots)
if numel(t)<=100001,indices=(1:numel(t)).';return;end
indices=unique(round(linspace(1,numel(t),100001))).';
for knot=knots.'
    [~,near]=min(abs(t-knot));
    indices=[indices;(max(1,near-2):min(numel(t),near+2)).']; %#ok<AGROW>
end
indices=unique(indices);
end

function tab=localTable(r,b)
time_s=r.time_s;positive_V=r.positive_V;negative_V=r.negative_V;
differential_V=positive_V-negative_V;commonMode_V=(positive_V+negative_V)/2;
ground_V=r.ground_V;returnCurrent_A=r.returnCurrent_A;
deltaDifferential_V=differential_V-(b.positive_V-b.negative_V);
deltaCommonMode_V=commonMode_V-(b.positive_V+b.negative_V)/2;
tab=table(time_s,positive_V,negative_V,differential_V,commonMode_V,ground_V, ...
    returnCurrent_A,deltaDifferential_V,deltaCommonMode_V);
end

function out=localSubset(r,mask)
out=r;
for name=["time_s","positive_V","negative_V","ground_V","returnCurrent_A"]
    out.(name)=r.(name)(mask);
end
end

function tab=localNativeInvariants(examples,p)
t=linspace(0,p.simulation.singleStop_s,round(p.simulation.singleStop_s/0.25e-9)+1).';
fields=["differential_V","commonMode_V","returnCurrent_A"];
values=struct;
names=["baseline","capacitive_rise","inductive_rise","shared_rise", ...
    "combined_rise","combined_fall"];
for name=names
    r=examples.(name).result;
    mat=zeros(numel(t),3);
    for j=1:3,mat(:,j)=interp1(r.time_s,r.(fields(j)),t,'linear');end
    values.(name)=mat;
end
super=values.combined_rise-values.capacitive_rise-values.inductive_rise-values.shared_rise+2*values.baseline;
polarity=values.combined_rise+values.combined_fall-2*values.baseline;
rows={};
for k=1:2
    if k==1,name="Fixed-network superposition";v=super;else,name="Signed polarity reversal";v=polarity;end
    maxVoltage=max(abs(v(:,1:2)),[],'all');maxCurrent=max(abs(v(:,3)));
    rows{end+1,1}=struct('Check',name,'MaxVoltageError_V',maxVoltage, ...
        'MaxCurrentError_A',maxCurrent,'Passed',maxVoltage<=1e-4 && maxCurrent<=1e-4); %#ok<AGROW>
end
for name=["balanced_combined","zero_source","zero_coupling"]
    example=examples.(name);r=example.result;b=example.baseline;
    dm=(r.positive_V-r.negative_V)-(b.positive_V-b.negative_V);
    error=max(abs(dm));
    rows{end+1,1}=struct('Check',name,'MaxVoltageError_V',error, ...
        'MaxCurrentError_A',NaN,'Passed',error<=1e-9); %#ok<AGROW>
end
tab=struct2table(vertcat(rows{:}));
end

function tab=localPeriodComparison(rawFolder,p)
period=1/p.source.pwmFrequency_Hz;t=linspace(0,period,round(period/0.25e-9)+1).';
a=load(fullfile(rawFolder,'sc01a_pwm_10.mat'),'r','c','p');
b=load(fullfile(rawFolder,'sc01a_pwm_20.mat'),'r','c','p');
records={};
for name=["differential_V","commonMode_V","returnCurrent_A"]
    qa=min(a.r.time_s(end),max(a.r.time_s(1),a.c.stopTime_s-period+t));
    qb=min(b.r.time_s(end),max(b.r.time_s(1),b.c.stopTime_s-period+t));
    va=interp1(a.r.time_s,a.r.(name),qa,'linear');
    vb=interp1(b.r.time_s,b.r.(name),qb,'linear');
    error=max(abs(va-vb));
    gate=1e-4; % 0.1 mV for voltage; explicit 0.1 mA current comparison.
    records{end+1,1}=struct('Quantity',name,'MaxLastPeriodDifference',error, ...
        'AbsoluteGate',gate,'Passed',isfinite(error) && error<=gate); %#ok<AGROW>
end
tab=struct2table(vertcat(records{:}));
end
