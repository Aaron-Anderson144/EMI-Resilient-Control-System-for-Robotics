function state = phase3_supervisor_initialize()
%PHASE3_SUPERVISOR_INITIALIZE Start with normal mode and no fault evidence.
% Stable mode IDs: 0 normal, 1 suspected, 2 degraded, 3 recovery, 4 safe_stop.
state.mode = 0;
state.badCount = 0;
state.goodCount = 0;
state.nonNormalCount = 0;
end
