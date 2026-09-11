function study = phase2b_main(outputFolder)
%PHASE2B_MAIN Generate Phase 2B artifacts in a fresh workflow directory.
arguments
    outputFolder (1,1) string = ""
end

matlabRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(matlabRoot,'functions'));
outputFolder=prepare_fresh_output_folder(outputFolder, ...
    fullfile(matlabRoot,'results','development'),"phase2b_workflow");
run(fullfile(matlabRoot, 'startup_project.m'));

study.outputFolder=outputFolder;
study.analytical=run_phase2b_study(fullfile(outputFolder,'analytical'));
study.packetLoss=run_phase2b_packet_loss_monte_carlo(fullfile(outputFolder,'packet_loss'));
build_phase2b_model(false);
study.smoke=smoke_test_phase2b_model(fullfile(outputFolder,'smoke'));
study.validation=validate_phase2b_simulink(fullfile(outputFolder,'validation'));

fprintf('Phase 2B study, model, smoke tests, and cross-validation completed.\n');
fprintf('Results folder: %s\n',outputFolder);
end
