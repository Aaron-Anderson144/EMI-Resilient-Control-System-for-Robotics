function study = phase2_main(outputFolder)
%PHASE2_MAIN Run the encoder-fault study in a fresh evidence directory.
arguments
    outputFolder (1,1) string = ""
end

matlabRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(matlabRoot,'scripts'));
study=run_phase2_fault_study(outputFolder);

fprintf('\nPhase 2 analytical study completed.\n');
fprintf('Next: run build_phase2_model to generate the Simulink model.\n');
end
