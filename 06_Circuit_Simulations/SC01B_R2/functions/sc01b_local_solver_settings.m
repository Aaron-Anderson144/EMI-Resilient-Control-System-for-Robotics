function s=sc01b_local_solver_settings(s)
%SC01B_LOCAL_SOLVER_SETTINGS Explicit physical-network integration controls.
% Local consistency values govern nonlinear initialization/reinitialization;
% they do not turn fixed-step integration into adaptive error control.
% Factor=1 makes the stated absolute/relative values the effective values.
if ~isfield(s,'localSolver'),s.localSolver='trapezoidal';end
if ~isfield(s,'consistencyAbsoluteTolerance'),s.consistencyAbsoluteTolerance=1e-12;end
if ~isfield(s,'consistencyRelativeTolerance'),s.consistencyRelativeTolerance=1e-8;end
if ~isfield(s,'consistencyToleranceFactor'),s.consistencyToleranceFactor=1;end
switch string(s.localSolver)
    case {"trapezoidal","NE_TRAPEZOIDAL_ADVANCER"}
        s.localSolver='trapezoidal';s.localSolverEnum='NE_TRAPEZOIDAL_ADVANCER';
        s.localSolverDescription='Simscape local trapezoidal rule';
    case {"backward_euler","NE_BACKWARD_EULER_ADVANCER"}
        s.localSolver='backward_euler';s.localSolverEnum='NE_BACKWARD_EULER_ADVANCER';
        s.localSolverDescription='Simscape local backward Euler';
    otherwise
        error('SC01B:LocalSolver','Supported local solvers are trapezoidal and backward_euler.');
end
assert(s.consistencyAbsoluteTolerance>0 && s.consistencyRelativeTolerance>0 && ...
    s.consistencyToleranceFactor>0 && s.consistencyToleranceFactor<=1, ...
    'SC01B:ConsistencyTolerance','Consistency tolerances must be positive; factor must lie in (0,1].');
end
