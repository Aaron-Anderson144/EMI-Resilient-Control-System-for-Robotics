%STARTUP_PROJECT Add the portable project folders to the MATLAB path.

matlabRoot = fileparts(mfilename('fullpath'));

addpath(matlabRoot);
addpath(fullfile(matlabRoot, 'parameters'));
addpath(fullfile(matlabRoot, 'functions'));
addpath(fullfile(matlabRoot, 'scripts'));
addpath(fullfile(matlabRoot, 'tests'));

resultsFolder = fullfile(matlabRoot, 'results');
modelsFolder = fullfile(matlabRoot, 'models');

if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

if ~isfolder(modelsFolder)
    mkdir(modelsFolder);
end

params = actuator_parameters();
rng(params.simulation.randomSeed, 'twister');

fprintf('EMI-resilient actuator workspace initialized.\n');
fprintf('MATLAB root: %s\n', matlabRoot);
fprintf('Parameter set: %s\n', params.meta.parameterSetId);

clear params resultsFolder modelsFolder

