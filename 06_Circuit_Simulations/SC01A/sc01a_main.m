%SC01A_MAIN Execute original regressions, circuit tests and native campaign.
sc01aRoot=fileparts(mfilename('fullpath'));
sc01aProjectRoot=fileparts(fileparts(sc01aRoot));
run(fullfile(sc01aProjectRoot,'03_MATLAB','startup_project.m'));
sc01aLegacyTests=runtests(fullfile(sc01aProjectRoot,'03_MATLAB','tests'));
run(fullfile(sc01aRoot,'sc01a_startup.m'));
sc01aCircuitTests=runtests(fullfile(sc01aRoot,'tests'));
sc01aTests=[sc01aLegacyTests(:);sc01aCircuitTests(:)];
sc01aOutput=fullfile(sc01aRoot,'results');
if ~isfolder(sc01aOutput),mkdir(sc01aOutput);end
writetable(table(sc01aTests),fullfile(sc01aOutput,'sc01a_tests.csv'));
assert(all([sc01aTests.Passed]),'SC01A:TestsFailed','Project and circuit tests must pass.');
study=run_sc01a(sc01aOutput);
study.tests=table(sc01aTests);
save(fullfile(sc01aOutput,'sc01a_study.mat'),'study','-v7');
write_sc01a_summary(study,sc01aOutput);
fprintf('SC-01A workflow completed. Results: %s\n',sc01aOutput);
