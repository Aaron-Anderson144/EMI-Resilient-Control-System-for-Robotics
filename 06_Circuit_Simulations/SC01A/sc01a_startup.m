%SC01A_STARTUP Add the self-contained finite-edge circuit workspace.
sc01aRoot = fileparts(mfilename('fullpath'));
addpath(sc01aRoot,fullfile(sc01aRoot,'functions'), ...
    fullfile(sc01aRoot,'scripts'),fullfile(sc01aRoot,'tests'));
fprintf('SC-01A finite-edge circuit workspace: %s\n',sc01aRoot);
