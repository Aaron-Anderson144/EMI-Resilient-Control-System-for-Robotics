function results = run_checks()
%RUN_CHECKS Verify the self-contained hybrid research prototype.
root=fileparts(mfilename('fullpath'));
oldPath=path; restore=onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(fullfile(root,'code'),fullfile(root,'tests'));
results=runtests(fullfile(root,'tests'));
if ~isfolder(fullfile(root,'results')),mkdir(fullfile(root,'results'));end
writetable(table(results),fullfile(root,'results','test_results.csv'));
assert(all([results.Passed]),'Hybrid:TestsFailed','One or more prototype checks failed.');
fprintf('%d tests passed.\n',numel(results));
end
