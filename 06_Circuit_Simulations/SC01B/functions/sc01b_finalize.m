function study=sc01b_finalize(study,folder)
%SC01B_FINALIZE Finalize only a complete, uniquely represented frozen matrix.
root=fileparts(fileparts(mfilename('fullpath')));project=fileparts(fileparts(root));
c=sc01b_criteria();assert(isequaln(study.criteria,c),'SC01B:CriteriaMismatch','Frozen criteria differ.');
assert(isequal(sort(string(fieldnames(study.cases))).',sort(c.caseNames)), ...
    'SC01B:IncompleteCampaign','All five cases must be present before finalization.');
runKeys=strings(0,1);comparisonKeys=runKeys;engineKeys=runKeys;eventKeys=runKeys;
for name=c.caseNames
    frozen=sc01b_case(name);
    assert(isequaln(study.cases.(name).parameters,frozen), ...
        'SC01B:CaseParameters','Stored parameters differ from frozen case %s.',name);
    tags=["native_0.5_ns","native_0.25_ns","native_0.125_ns","spice_0.25_ns","spice_0.125_ns"];
    labels=["native_0.5_to_0.125ns","native_0.25_to_0.125ns", ...
        "spice_0.25_to_0.125ns","native_to_original_spice_0.125ns"];
    if ismember(name,c.consistencyCases)
        tags=[tags,"native_tight_consistency","spice_tight_tolerance"];
        labels=[labels,"native_consistency_10x","spice_tolerances_10x"];
    end
    runKeys=[runKeys;reshape(name+"|"+tags,[],1)];
    comparisonKeys=[comparisonKeys;reshape(name+"|"+labels,[],1)];
    for engine=["native","spice"]
        engineKeys(end+1,1)=name+"|"+engine;
        for pulse=1:numel(frozen.control.highOn_s)
            for kind=["high_on","high_off"]
                eventKeys(end+1,1)=name+"|"+engine+"|pulse_"+pulse+"_"+kind;
            end
        end
    end
end
exactKeys(study.runs,["Case","Run"],runKeys,'runs');
exactKeys(study.comparisons,["Case","Comparison"],comparisonKeys,'comparisons');
exactKeys(study.metrics,["Case","Engine"],engineKeys,'metrics');
exactKeys(study.balance,["Case","Engine"],engineKeys,'balance');
exactKeys(study.events,["Case","Engine","EventId"],eventKeys,'events');
suite=matlab.unittest.TestSuite.fromFolder(fullfile(project,'03_MATLAB','tests'));
suite=[suite,matlab.unittest.TestSuite.fromFolder(fullfile(fileparts(root),'SC01A','tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(root,'tests'))];
run(fullfile(project,'03_MATLAB','startup_project.m'));
testResults=run(suite);study.tests=struct('Total',numel(testResults),'Passed',sum([testResults.Passed]), ...
    'Failed',sum([testResults.Failed]),'Incomplete',sum([testResults.Incomplete]));
save(fullfile(folder,'test_results.mat'),'testResults');assertSuccess(testResults);
study.completedUTC=string(datetime('now','TimeZone','UTC'));
study.numericalCampaignPassed=all(study.comparisons.Pass) && all(study.balance.Pass);
study.operatingPointsPassed=all(study.metrics.DeviceVoltageLimitsPassed & study.metrics.GateVoltageLimitsPassed & ...
    study.metrics.UnresolvedEventCount==0 & study.metrics.VoltageRecrossingCount==0);
study.physicalSourceValidated=false;
for field=["metrics","events","balance","comparisons","waveforms","runs"]
    writetable(study.(field),fullfile(folder,field+'.csv'));
end

save(fullfile(folder,'study.mat'),'study','-v7');
fid=fopen(fullfile(folder,'status.json'),'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(struct('numericalCampaignPassed',study.numericalCampaignPassed, ...
    'operatingPointsPassed',study.operatingPointsPassed,'physicalSourceValidated',false,'tests',study.tests),'PrettyPrint',true));
clear cleanup
sc01b_make_report(study,folder);
fprintf('SC01B campaign complete: %d runs, %d comparisons, %d/%d tests passed. Numerical pass %d; operating point pass %d.\n', ...
    height(study.runs),height(study.comparisons),study.tests.Passed,study.tests.Total,study.numericalCampaignPassed,study.operatingPointsPassed);
end

function exactKeys(rows,fields,expected,label)
assert(istable(rows) && all(ismember(fields,string(rows.Properties.VariableNames))), ...
    'SC01B:CampaignShape','Missing %s key columns.',label);
keys=string(rows.(fields(1)));
for field=fields(2:end),keys=keys+"|"+string(rows.(field));end
assert(numel(unique(keys))==numel(keys) && isequal(sort(keys(:)),sort(expected(:))), ...
    'SC01B:CampaignShape','The %s rows do not contain the exact unique frozen keyset.',label);
end
