function p=receiver_v2_parameters()
%RECEIVER_V2_PARAMETERS Single versioned source of receiver study assumptions.
p=jsondecode(fileread(fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'receiver_characterization_config.json')));
end
