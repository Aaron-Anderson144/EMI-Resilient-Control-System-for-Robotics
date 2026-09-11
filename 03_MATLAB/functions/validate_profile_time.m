function validate_profile_time(time_s,params,requireUniform)
%VALIDATE_PROFILE_TIME Guard sampled profile coordinates before reshaping.
if nargin < 3, requireUniform = false; end
if ~isnumeric(time_s) || ~isreal(time_s) || ~isvector(time_s) || ...
        isempty(time_s) || any(~isfinite(time_s(:))) || ...
        any(time_s(:) < 0) || any(diff(time_s(:)) <= 0)
    error('EMIProject:InvalidTimeVector', ...
        'Time must be a nonempty finite real numeric vector with nonnegative, strictly increasing values.');
end
if requireUniform && numel(time_s) > 1
    tolerance = 64*eps(max(1,max(abs(double(time_s(:))))));
    if any(abs(diff(double(time_s(:)))-params.control.sampleTime_s) > tolerance)
        error('EMIProject:InvalidTimeVector', ...
            'Packet schedules require uniform controller-sample spacing.');
    end
end
end
