% PHASE3_STOP_HOLD_MAIN Standalone passive braking comparison, local only.
startup_project;
stopHoldStudy=run_phase3_stop_hold_study();
fprintf('Local physics checks complete. Independent audit is still required: %s\n',stopHoldStudy.outputFolder);
