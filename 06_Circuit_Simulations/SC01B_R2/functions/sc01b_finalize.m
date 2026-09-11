function study=sc01b_finalize(study,folder)
%SC01B_FINALIZE Finalize only a complete, uniquely represented frozen matrix.
root=fileparts(fileparts(mfilename('fullpath')));project=fileparts(fileparts(root));
c=sc01b_criteria();status=sc01b_campaign_acceptance(study,c);
suite=matlab.unittest.TestSuite.fromFolder(fullfile(project,'03_MATLAB','tests'));
suite=[suite,matlab.unittest.TestSuite.fromFolder(fullfile(fileparts(root),'SC01A','tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(root,'tests'))];
run(fullfile(project,'03_MATLAB','startup_project.m'));
testResults=run(suite);study.tests=struct('Total',numel(testResults),'Passed',sum([testResults.Passed]), ...
    'Failed',sum([testResults.Failed]),'Incomplete',sum([testResults.Incomplete]));
save(fullfile(folder,'test_results.mat'),'testResults');assertSuccess(testResults);
study.completedUTC=string(datetime('now','TimeZone','UTC'));
for field=string(fieldnames(status)).',study.(field)=status.(field);end
for field=["metrics","events","balance","comparisons","waveforms","runs"]
    writetable(study.(field),fullfile(folder,field+'.csv'));
end

save(fullfile(folder,'study.mat'),'study','-v7');
fid=fopen(fullfile(folder,'status.json'),'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
status.tests=study.tests;
fprintf(fid,'%s\n',jsonencode(status,'PrettyPrint',true));
clear cleanup
sc01b_make_report(study,folder);
fprintf('SC01B campaign complete: %d runs, %d comparisons, %d/%d tests passed. Numerical pass %d; operating point pass %d.\n', ...
    height(study.runs),height(study.comparisons),study.tests.Passed,study.tests.Total,study.numericalCampaignPassed,study.operatingPointsPassed);
end
