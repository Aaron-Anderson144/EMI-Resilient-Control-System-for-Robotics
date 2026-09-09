function [events, exposure_s, grazing] = sc01a_threshold_events( ...
    time_s, signal_V, threshold_V, grazingTolerance_V)
%SC01A_THRESHOLD_EVENTS Crossings and duration for a linear-interpolated record.
% [EVENTS, EXPOSURE_S, GRAZING] = SC01A_THRESHOLD_EVENTS(T, V, H, TOL)
% finds crossings of +H and -H. EVENTS contains Time_s, Level_V and Direction
% (+1 for an increasing voltage, -1 for a decreasing voltage). T and V must
% be finite, real numeric column vectors of equal length with at least two
% samples, and T must increase strictly. H > 0 and TOL >= 0 are scalars.
%
% A crossing at an exact-threshold sample is reported once. A threshold
% plateau has one crossing only if its nearest non-equal samples are on
% opposite sides; its time is conventionally the FIRST plateau sample.
% This convention is flagged as grazing because that time is not unique.
% A touch followed by a return to the same side is not a crossing. Equality
% at a record boundary (including a boundary plateau) is not an interior
% crossing. No event is inferred before the first or after the last sample.
%
% EXPOSURE_S integrates abs(V) > H exactly for the piecewise-linear record,
% including a record that starts or ends above threshold. Equality plateaus
% contribute zero duration. There is no extrapolation beyond the record.
% GRAZING is true if a sampled interior local extremum, or a constant-sample
% plateau anywhere in the record, lies within TOL volts of either threshold.
% TOL affects this warning only; crossing and exposure use the exact H.

narginchk(4, 4);
if ~isnumeric(time_s) || ~isreal(time_s) || ~iscolumn(time_s) || ...
        numel(time_s) < 2 || any(~isfinite(time_s)) || ...
        ~isnumeric(signal_V) || ~isreal(signal_V) || ~iscolumn(signal_V) || ...
        numel(signal_V) ~= numel(time_s) || any(~isfinite(signal_V))
    error('SC01A:ThresholdInput', ...
        'Time and signal must be finite real numeric columns of equal length >= 2.');
end
if ~isnumeric(threshold_V) || ~isreal(threshold_V) || ...
        ~isscalar(threshold_V) || ~isfinite(threshold_V) || threshold_V <= 0 || ...
        ~isnumeric(grazingTolerance_V) || ~isreal(grazingTolerance_V) || ...
        ~isscalar(grazingTolerance_V) || ~isfinite(grazingTolerance_V) || ...
        grazingTolerance_V < 0
    error('SC01A:ThresholdInput', ...
        'Threshold must be a positive finite scalar and tolerance a nonnegative finite scalar.');
end
time_s = double(time_s);
signal_V = double(signal_V);
threshold_V = double(threshold_V);
grazingTolerance_V = double(grazingTolerance_V);
dt = diff(time_s);
if any(dt <= 0)
    error('SC01A:ThresholdInput', 'Time must increase strictly.');
end

% Removing exact equalities lets nearest non-equal neighbors distinguish a
% true crossing from a touch, without double counting sampled crossings.
eventRows = zeros(0, 3);
for level = [-threshold_V, threshold_V]
    offset = signal_V - level;
    nonzero = find(offset ~= 0);
    left = nonzero(1:end-1);
    right = nonzero(2:end);
    crossed = sign(offset(left)) ~= sign(offset(right));
    left = left(crossed);
    right = right(crossed);
    crossingTime = time_s(left);
    adjacent = right == left + 1;
    crossingTime(adjacent) = time_s(left(adjacent)) + ...
        (time_s(right(adjacent)) - time_s(left(adjacent))) .* ...
        (-offset(left(adjacent))) ./ ...
        (offset(right(adjacent)) - offset(left(adjacent)));
    crossingTime(~adjacent) = time_s(left(~adjacent) + 1);
    direction = sign(offset(right));
    eventRows = [eventRows; crossingTime, ...
        repmat(level, numel(left), 1), direction]; %#ok<AGROW>
end
eventRows = sortrows(eventRows, [1 2]);
events = array2table(eventRows, ...
    'VariableNames', {'Time_s', 'Level_V', 'Direction'});

% Integrating above +H and below -H separately is equivalent to splitting
% each linear segment at both roots, including a segment crossing both.
exposure_s = durationAbove(signal_V, threshold_V, dt) + ...
    durationAbove(-signal_V, threshold_V, dt);

nearThreshold = abs(abs(signal_V) - threshold_V) <= grazingTolerance_V;
middle = signal_V(2:end-1);
before = signal_V(1:end-2);
after = signal_V(3:end);
localMaximum = middle >= before & middle >= after & ...
    (middle > before | middle > after);
localMinimum = middle <= before & middle <= after & ...
    (middle < before | middle < after);
nearExtremum = any(nearThreshold(2:end-1) & (localMaximum | localMinimum));
nearPlateau = any(diff(signal_V) == 0 & nearThreshold(1:end-1));
grazing = nearExtremum || nearPlateau;
end

function duration_s = durationAbove(values, level, dt)
% Positive portions of each linear segment; equality itself has zero measure.
left = values(1:end-1) - level;
right = values(2:end) - level;
fraction = zeros(size(dt));
fraction(left > 0 & right > 0) = 1;
rising = left <= 0 & right > 0;
fraction(rising) = right(rising) ./ (right(rising) - left(rising));
falling = left > 0 & right <= 0;
fraction(falling) = left(falling) ./ (left(falling) - right(falling));
duration_s = sum(dt .* fraction);
end
