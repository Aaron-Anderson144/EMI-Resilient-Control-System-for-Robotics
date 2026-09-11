function state = phase3_control_initialize()
%PHASE3_CONTROL_INITIALIZE Zero prehistory for exact normal Tustin PIDF.
state.integral_V = 0;
state.derivative_V = 0;
state.previousError_rad = 0;
state.filteredReference_rad = 0;
state.previousCommand_V = 0;
state.previousMode = 0;
state.useDegradedGains = false;
end
