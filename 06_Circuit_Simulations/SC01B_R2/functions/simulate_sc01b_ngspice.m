function r=simulate_sc01b_ngspice(p,outputFolder,executable)
%SIMULATE_SC01B_NGSPICE Run original vendor equations in an independent engine.
arguments
    p (1,1) struct
    outputFolder (1,1) string
    executable (1,1) string
end
assert(isfile(executable),'SC01B:MissingNgspice','ngspice executable is missing: %s',executable);
p=sc01b_spice_normalize_parameters(p);
if ~isfolder(outputFolder),mkdir(outputFolder);end
[ok,details]=fileattrib(outputFolder);assert(ok);outputFolder=string(details.Name);
[ok,details]=fileattrib(executable);assert(ok);executable=string(details.Name);
% A fresh attempt must not inherit contradictory evidence from an earlier
% success/rejection in the same explicitly selected output folder.
for artifact=["result.mat","rejected.json","waveform.dat","ngspice.log","source_manifest.json"]
    stale=fullfile(outputFolder,artifact);if isfile(stale),delete(stale);end
end
vendor=fullfile(matlabroot,'toolbox','physmod','elec','supporting_files','IAUC100N04S6L014.cir');
assert(isfile(vendor),'SC01B:MissingVendorSource','Installed original vendor model is unavailable.');
g=sc01b_gate_signals(p);
deck=fullfile(outputFolder,'halfbridge.cir');
fid=fopen(deck,'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'SC01B original vendor equations - %s\n',p.meta.case);
fprintf(fid,'.include "%s"\n',strrep(vendor,'\','/'));
fprintf(fid,'.options reltol=%.17g abstol=%.17g vntol=%.17g method=trap gminsteps=0 srcsteps=1\n', ...
    p.simulation.relativeTolerance,p.simulation.absoluteTolerance,p.simulation.voltageTolerance);
fprintf(fid,'Vdc vin 0 %.17g\nRfeed vin f1 %.17g\nLfeed f1 bus %.17g\n', ...
    p.bus.voltage_V,p.bus.feedResistance_Ohm,p.bus.feedInductance_H);
fprintf(fid,'Rcap bus bc %.17g\nCbus bc 0 %.17g\n',p.bus.capacitorESR_Ohm,p.bus.capacitance_F);
fprintf(fid,['Vh bus hd 0\nXhigh hd hg sw temp temp IAUC100N04S6L014\n', ...
    'Vl sw ld 0\nXlow ld lg 0 temp temp IAUC100N04S6L014\nVtemp temp 0 %.17g\n'],p.device.temperature_C);
% Exact PWL function expressed as a sum of clipped linear ramps. The circuit
% waveform is unchanged; this avoids the PWL source's breakpoint scheduling.
fprintf(fid,'Bhcmd gh0 sw V=%s\n',sc01b_spice_pwl_expression(g.time_s,g.high_V));
fprintf(fid,'Blcmd gl0 0 V=%s\n',sc01b_spice_pwl_expression(g.time_s,g.low_V));
gateR=p.driver.outputResistance_Ohm+p.driver.externalResistance_Ohm+p.driver.additionalTurnOnResistance_Ohm;
offR=p.driver.turnOffResistance_Ohm;
fprintf(fid,'Bhgate gh0 gh1 I=if(v(gh0,gh1)>=0,v(gh0,gh1)/%.17g,v(gh0,gh1)/%.17g)\nVhg gh1 hg 0\n',gateR,offR);
fprintf(fid,'Blgate gl0 gl1 I=if(v(gl0,gl1)>=0,v(gl0,gl1)/%.17g,v(gl0,gl1)/%.17g)\nVlg gl1 lg 0\n',gateR,offR);
fprintf(fid,'Lload sw lr %.17g\nRload lr 0 %.17g\n.end\n',p.load.inductance_H,p.load.resistance_Ohm);
clear cleanup
control=fullfile(outputFolder,'run.cir');
dataFile=fullfile(outputFolder,'waveform.dat');logFile=fullfile(outputFolder,'ngspice.log');
fid=fopen(control,'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'SC01B independent engine control\n.control\nset ngbehavior=ps\nset numdgt=17\nset wr_singlescale\nset wr_vecnames\n');
fprintf(fid,'source halfbridge.cir\n');
% Keep the requested print interval separate from the actual maximum
% integration step. wrdata retains the solver's native times (no linearize).
% This prevents refinement from also changing ngspice's initial-step setup.
outputStep=p.simulation.spiceOutputStep_s;
fprintf(fid,'tran %.17g %.17g 0 %.17g\n',outputStep,p.simulation.stopTime_s,p.simulation.maxStep_s);
fprintf(fid,'wrdata waveform.dat v(sw) v(bus) v(hg,sw) v(lg) v(hd,sw) v(ld) i(Vh) i(Vl) i(Vhg) i(Vlg) i(Lload) i(Lfeed)\n');
fprintf(fid,'quit\n.endc\n.end\n');clear cleanup
% Capture dependency and generated-deck identities before invocation so a
% rejected numerical attempt has the same provenance as a completed one.
identity=sc01b_spice_source_identity(executable);
manifest=struct('schema',"SC01B-R2-spice-attempt-v1",'source',identity, ...
    'parameters',p,'startedUTC',string(datetime('now','TimeZone','UTC')),'completed',false, ...
    'artifacts',artifactRows(outputFolder,["halfbridge.cir","run.cir"]));
writeManifest(outputFolder,manifest);
clock=tic;
previous=pwd;cd(outputFolder);restore=onCleanup(@()cd(previous));
[status,console]=system(sprintf('"%s" -b -o "%s" "%s"',executable,logFile,control));
clear restore
runtime=toc(clock);
manifest.runtime_s=runtime;manifest.processExitStatus=status;
manifest.artifacts=artifactRows(outputFolder,["halfbridge.cir","run.cir","ngspice.log"]);
writeManifest(outputFolder,manifest);
assert(status==0 && isfile(logFile),'SC01B:NgspiceExecution','ngspice failed: %s',console);
log=fileread(logFile);
% Start with documented source stepping; no failed gmin trials are accepted.
assert(isempty(regexpi(log,'aborted|timestep too small|fatal|warning:|error:','once')), ...
    'SC01B:NgspiceDiagnostic','ngspice diagnostic prevents accepting this run. Inspect %s',logFile);
assert(isfile(dataFile),'SC01B:MissingNgspiceData','ngspice did not export a waveform.');
a=readmatrix(dataFile,'FileType','text','NumHeaderLines',1);
assert(size(a,2)==13 && size(a,1)>=2 && all(isfinite(a),'all'),'SC01B:InvalidSpiceData','Invalid SPICE waveform.');
assert(all(diff(a(:,1))>0),'SC01B:InvalidSpiceTime','Raw SPICE time must increase strictly; no sorting or deduplication is permitted.');
observedMaxStep=max(diff(a(:,1)));
assert(observedMaxStep<=p.simulation.maxStep_s+2e-20,'SC01B:SpiceStepExceeded','Observed SPICE integration step exceeds the declared maximum.');
assert(abs(a(end,1)-p.simulation.stopTime_s)<1e-14,'SC01B:IncompleteSpiceRun','SPICE did not reach stop time.');
t=a(:,1);
names=["switch_V","bus_V","highVgs_V","lowVgs_V","highVds_V","lowVds_V", ...
    "highCurrent_A","lowCurrent_A","highGateCurrent_A","lowGateCurrent_A","loadCurrent_A","feedCurrent_A"];
r.time_s=t;
for k=1:numel(names),r.(names(k))=a(:,k+1);end
r.warningCount=0;r.reviewedInitializationWarnings=0;
r.transientWarningCount=0;r.stopEvent="ReachedStopTime";r.runtime_s=runtime;
r.engine="ngspice original Infineon equations";r.settings=p.simulation;
r.settings.spiceOutputStep_s=outputStep;
r.parameters=p;r.logFile=logFile;
r.sourceIdentity=identity;
r.observedMaxStep_s=observedMaxStep;
save(fullfile(outputFolder,'result.mat'),'r','p','-v7');
manifest.completed=true;manifest.completedUTC=string(datetime('now','TimeZone','UTC'));
manifest.artifacts=artifactRows(outputFolder,["halfbridge.cir","run.cir","ngspice.log","result.mat"]);
writeManifest(outputFolder,manifest);
end

function rows=artifactRows(folder,names)
values={};
for name=names
    path=fullfile(folder,name);if ~isfile(path),continue;end
    fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
    hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
    values{end+1}=struct('name',name,'sha256',string(hash),'bytes',numel(bytes));
end
rows=vertcat(values{:});
end

function writeManifest(folder,manifest)
fid=fopen(fullfile(folder,'source_manifest.json'),'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(manifest,'PrettyPrint',true));
end
