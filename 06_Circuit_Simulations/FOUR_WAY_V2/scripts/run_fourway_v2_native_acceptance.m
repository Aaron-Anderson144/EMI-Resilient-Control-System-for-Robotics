function summary=run_fourway_v2_native_acceptance(outputFolder,options)
% Generate fresh independent native traces, then apply frozen Gate C.
arguments
    outputFolder (1,1) string
    options (1,1) struct=struct()
end
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'03_MATLAB','functions'),fullfile(root,'06_Circuit_Simulations','SC01A','functions'), ...
    fullfile(root,'06_Circuit_Simulations','FOUR_WAY_V2','functions'));
assert(~isfolder(outputFolder)&&~isfile(outputFolder),'FOURWAYV2:NativeOutputExists','Use a fresh Gate C directory.');
mkdir(outputFolder);
fourway_v2_native_generate(fullfile(outputFolder,'raw'),options);
summary=fourway_v2_native_audit(fullfile(outputFolder,'raw'),fullfile(outputFolder,'audit'));
end
