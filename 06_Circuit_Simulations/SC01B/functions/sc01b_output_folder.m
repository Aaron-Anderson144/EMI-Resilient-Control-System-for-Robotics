function folder=sc01b_output_folder(root,requestedFolder,reuseCompletedRuns)
%SC01B_OUTPUT_FOLDER Select a fresh campaign destination without writing it.
% A populated explicit destination requires deliberate resume/rewrite consent.
arguments
    root (1,1) string
    requestedFolder (1,1) string = ""
    reuseCompletedRuns (1,1) logical = false
end
folder=requestedFolder;
if folder==""
    stamp=string(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS'));
    baseFolder=fullfile(root,'results','verification_'+stamp);
    folder=baseFolder;suffix=0;
    while isfolder(folder) || isfile(folder)
        suffix=suffix+1;folder=baseFolder+'_'+string(suffix);
    end
end
assert(~isfile(folder),'SC01B:OutputFolderExists', ...
    'Output path is an existing file: %s',folder);
if isfolder(folder) && ~reuseCompletedRuns
    entries=dir(folder);entries=entries(~ismember({entries.name},{'.','..'}));
    assert(isempty(entries),'SC01B:OutputFolderNotEmpty', ...
        ['Output folder is populated: %s. Choose a fresh folder, or explicitly ', ...
        'set ReuseCompletedRuns=true to resume/rewrite this campaign.'],folder);
end
end
