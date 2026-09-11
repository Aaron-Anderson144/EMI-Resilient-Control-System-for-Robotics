function outputFolder = sc01a_prepare_output_folder(outputFolder, defaultRoot, prefix)
%SC01A_PREPARE_OUTPUT_FOLDER Preserve previous complete or partial evidence.
% Kept within SC01A so its circuit-only runner remains self-contained.
arguments
    outputFolder (1,1) string
    defaultRoot (1,1) string
    prefix (1,1) string
end
id='SC01A:OutputFolderExists';
assert(~ismissing(outputFolder),id,'Choose a valid output folder path.');
if outputFolder==""
    stamp=string(datetime('now','TimeZone','UTC','Format','yyyyMMdd_HHmmss_SSS'));
    base=fullfile(defaultRoot,prefix+"_"+stamp);outputFolder=base;count=0;
    while isfolder(outputFolder) || isfile(outputFolder)
        count=count+1;outputFolder=base+"_"+string(count);
    end
end
assert(strlength(strtrim(outputFolder))>0,id,'Choose a nonempty output folder path.');
outputFolder=string(java.io.File(char(outputFolder)).getCanonicalPath());
assert(~isfile(outputFolder),id,'Output path is an existing file. Choose a new folder: %s',outputFolder);
if isfolder(outputFolder)
    contents=dir(outputFolder);contents=contents(~ismember({contents.name},{'.','..'}));
    assert(isempty(contents),id,'Output folder is populated. Choose a new or empty folder: %s',outputFolder);
else
    [made,message]=mkdir(outputFolder);
    assert(made,'SC01A:CannotCreateOutput','Cannot create output folder: %s',message);
end
end
