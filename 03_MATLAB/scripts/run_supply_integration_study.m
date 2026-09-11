function study=run_supply_integration_study(outputFolder)
%RUN_SUPPLY_INTEGRATION_STUDY Verify averaged supply faults and loaded motion.
% Writes a new timestamped directory by default and refuses populated output.
arguments
    outputFolder (1,1) string = ""
end
root=fileparts(fileparts(mfilename('fullpath')));run(fullfile(root,'startup_project.m'));
if outputFolder==""
    outputFolder=fullfile(root,'results','development', ...
        "supply_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
end
assert(~isfolder(outputFolder) || numel(dir(outputFolder))<=2, ...
    'EMIProject:OutputExists','Use a new output folder to preserve earlier evidence.');
if ~isfolder(outputFolder),mkdir(outputFolder);end
model='EMI_Resilient_Actuator_Phase2B';load_system(fullfile(root,'models',[model '.slx']));
cleanup=onCleanup(@()close_system(model,0));
p=actuator_parameters();p.simulation.stopTime_s=3;p.mechanical.nominalLoadTorque_Nm=.01;
names=["loaded_reference","sag_loaded","interruption_hold","interruption_reset", ...
    "combined_supply","one_sample","startup_interruption","end_interruption", ...
    "off_grid_window","reverse_load","zero_load","mild_sag","command_saturation"];
scenarios=["none","supply_sag","supply_interruption","supply_interruption_reset", ...
    "combined_supply","supply_interruption","supply_interruption","supply_interruption", ...
    "supply_interruption","supply_sag","supply_interruption","supply_sag","supply_sag"];
study.startedUTC=string(datetime('now','TimeZone','UTC'));
study.matlabVersion=string(version);study.scope="Averaged motor-bus voltage; control/sensor rails powered; assumed parameters";
study.cases=struct();rows={};metricsRows={};channelTables={};
for k=1:numel(names)
    pp=p;pp.supply.sagVoltage_V=.05;
    switch names(k)
        case "one_sample",pp.supply.startTime_s=.900;pp.supply.stopTime_s=.901;
        case "startup_interruption",pp.supply.startTime_s=0;pp.supply.stopTime_s=.100;
        case "end_interruption",pp.supply.startTime_s=2.5;pp.supply.stopTime_s=3;
        case "off_grid_window",pp.supply.startTime_s=.8505;pp.supply.stopTime_s=1.1005;
        case "reverse_load",pp.mechanical.nominalLoadTorque_Nm=-.01;
        case "zero_load",pp.mechanical.nominalLoadTorque_Nm=0;
        case "mild_sag",pp.supply.sagVoltage_V=12;
        case "command_saturation",pp.control.voltageLimit_V=.1;
    end
    scenario=phase2b_scenario(scenarios(k),pp);
    r=simulate_phase2b_actuator(pp,scenario);
    baseline=simulate_phase2b_actuator(pp,phase2b_scenario("none",pp));
    [input,signals]=create_phase2b_simulation_input(model,pp,scenario);
    simulation=sim(input);logged=simulation.get('phase2bSimout');
    expected=[r.reference_rad,r.position_rad,r.velocity_rad_s,r.current_A, ...
        r.sensorSideMeasurement_rad,r.receivedMeasurement_rad,r.trackingError_rad, ...
        r.unsaturatedCommand_V,r.command_V,signals.phase2bDiagnostics.Data];
    columns=["reference","position","velocity","current","sensor","received", ...
        "controller_error","raw_command","applied_command","diagnostic_"+(1:20)];
    [check,detail]=compare_logged_arrays(logged.time,logged.signals.values, ...
        r.time_s,expected,columns,1e-9,18:29,numel(r.time_s));
    supplyLog=simulation.get('supplySimout');
    expectedSupply=[r.supply.voltage_V,r.supply.commandLimit_V, ...
        double(r.supply.driveAvailable),double(r.supply.configuredWindowActive)];
    [supplyCheck,supplyDetail]=compare_logged_arrays(supplyLog.time,supplyLog.signals.values, ...
        r.time_s,expectedSupply,["bus_voltage","command_limit","available","window"], ...
        1e-9,1:4,numel(r.time_s));
    stateLog=simulation.get('controllerStateSimout');
    [stateCheck,stateDetail]=compare_logged_arrays(stateLog.time,stateLog.signals.values, ...
        r.time_s,r.controllerState_log,"state_"+(1:size(r.controllerState_log,2)), ...
        1e-9,[],numel(r.time_s));
    inhibited=~r.supply.driveAvailable;
    bounded=all(abs(r.command_V)<=r.supply.commandLimit_V+1e-12);
    zeroDrive=all(r.command_V(inhibited)==0);
    if isfinite(scenario.analysisStartTime_s)
        pre=r.time_s<scenario.analysisStartTime_s;
    else
        pre=true(size(r.time_s));
    end
    preDifference=max([0;abs(r.position_rad(pre)-baseline.position_rad(pre))]);
    [m,~]=phase2b_metrics(r,baseline,pp);m.caseName=names(k);metricsRows{end+1}=m;
    row=struct('Case',names(k),'Samples',numel(r.time_s),'AllFinite',check.AllFinite && supplyCheck.AllFinite && stateCheck.AllFinite, ...
        'MainChannelsPassed',check.Passed,'SupplyChannelsPassed',supplyCheck.Passed, ...
        'ControllerStatePassed',stateCheck.Passed,'BoundedDrive',bounded,'ZeroDriveDuringInterruption',zeroDrive, ...
        'PreWindowDifference_rad',preDifference,'MaxMainDifference',max(check.MaxDifferences), ...
        'MaxControllerStateDifference',max(stateCheck.MaxDifferences), ...
        'InterruptionSamples',nnz(inhibited),'RecoveryTime_s',m.recoveryTime_s, ...
        'RecoveryCensored',m.recoveryCensored,'SimulationWarnings',numel(simulation.SimulationMetadata.ExecutionInfo.WarningDiagnostics), ...
        'Completed',strcmp(simulation.SimulationMetadata.ExecutionInfo.StopEvent,'ReachedStopTime'));
    row.Passed=row.AllFinite && check.Passed && supplyCheck.Passed && stateCheck.Passed && bounded && ...
        zeroDrive && preDifference<=1e-12 && row.SimulationWarnings==0 && row.Completed;
    rows{end+1}=row;
    detail=[detail;supplyDetail;stateDetail];detail.Case=repmat(names(k),height(detail),1);channelTables{end+1}=detail;
    study.cases.(names(k))=struct('parameters',pp,'scenario',scenario,'result',r,'baseline',baseline);
    writetable([r.timeSeries,r.supplyTimeSeries(:,2:end)],fullfile(outputFolder,names(k)+"_timeseries.csv"));
    fprintf('Supply check %s: pass %d, samples %d, max difference %.3g, recovery censored %d\n', ...
        names(k),row.Passed,row.Samples,row.MaxMainDifference,row.RecoveryCensored);
end
study.validation=struct2table(vertcat(rows{:}));study.metrics=struct2table(vertcat(metricsRows{:}));
study.channels=vertcat(channelTables{:});study.completedUTC=string(datetime('now','TimeZone','UTC'));
writetable(study.validation,fullfile(outputFolder,'supply_validation.csv'));
writetable(study.metrics,fullfile(outputFolder,'supply_metrics.csv'));
writetable(study.channels,fullfile(outputFolder,'supply_channel_comparisons.csv'));
save(fullfile(outputFolder,'supply_study.mat'),'study','-v7');
caseManifest=cell(numel(names),1);
for k=1:numel(names)
    item=study.cases.(names(k));
    caseManifest{k}=struct('name',names(k),'parameters',item.parameters,'scenario',item.scenario);
end
fid=fopen(fullfile(outputFolder,'supply_case_manifest.json'),'w');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(vertcat(caseManifest{:}),'PrettyPrint',true));fclose(fid);
write_run_manifest(outputFolder,root,struct('workflow',"supply_integration", ...
    'caseNames',names,'startedUTC',study.startedUTC,'completedUTC',study.completedUTC, ...
    'allPassed',all(study.validation.Passed)));
assert(all(study.validation.Passed),'EMIProject:SupplyValidationFailed', ...
    'Supply integration failed; inspect the saved validation table.');
end
