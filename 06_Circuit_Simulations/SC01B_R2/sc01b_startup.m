%SC01B_STARTUP Set paths for the native device-source verification workspace.
sc01bRoot=fileparts(mfilename('fullpath'));
addpath(sc01bRoot,fullfile(sc01bRoot,'functions'),fullfile(sc01bRoot,'scripts'),fullfile(sc01bRoot,'tests'));
sc01aRoot=fullfile(fileparts(sc01bRoot),'SC01A');
addpath(fullfile(sc01aRoot,'functions'),fullfile(sc01aRoot,'scripts'));
