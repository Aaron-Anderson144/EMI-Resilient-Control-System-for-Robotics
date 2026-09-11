function require_empty_phase3_output_folder(outputFolder)
%REQUIRE_EMPTY_PHASE3_OUTPUT_FOLDER Nonwriting guard for complete/partial runs.
arguments
    outputFolder (1,1) string
end
id = 'EMIProject:Phase3OutputExists';
if ismissing(outputFolder) || strlength(strtrim(outputFolder)) == 0
    error(id,'Choose a nonempty output folder path.');
end
if isfile(outputFolder)
    error(id,'The output path is an existing file. Choose a new folder.');
end
if isfolder(outputFolder)
    contents = dir(outputFolder);
    contents = contents(~ismember({contents.name},{'.','..'}));
    if ~isempty(contents)
        error(id,'Choose a new or empty folder to preserve complete and partial evidence.');
    end
end
end
