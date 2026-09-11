function [events,xNext,intervalStats] = fourway_plant_events(x,voltage_V,load_Nm,dt,params,initialCount)
%FOURWAY_PLANT_EVENTS All quantization transitions in a held-input interval.
% [events,xNext] = fourway_plant_events(x,V,load,dt,params[,initialCount])
% events is a table: time_s (local), newCount, A, B, direction. The endpoint
% dt is included, so its transitions precede a coincident control sample.
% The fixed x4 resolution is delta=2*pi/4096. Gray order is 00,10,11,01.
% Supply the persistent intended initialCount when chaining intervals. A
% time-zero event is emitted only if it differs from the trajectory's right
% limit (e.g. a new load reverses motion at a boundary). Without it, the
% initial count is already taken as that right limit. Tangencies do not
% change count. Root times within 1 ps are represented by a joint change;
% direction is the sign of its net count change, zero for a canceled pair.
validateattributes(dt,{'numeric'},{'real','finite','positive','scalar'});
assert(params.sensor.encoderCountsPerRevolution == 4096, ...
    'EMIProject:FourWayEncoderResolution','PLAN-V1 requires 4096 x4 counts.');
segment = fourway_plant_segment(x,voltage_V,load_Nm,params);
delta = 2*pi/4096;
timeTolerance = 1e-12;
turns = segment.stationaryTimes(dt);
points = [0,turns,dt];
counts = zeros(size(points));
for n = 1:numel(points)
    counts(n) = rightCount(points(n),n>1 && n<numel(points));
end
if nargin < 6
    initialCount = counts(1);
else
    validateattributes(initialCount,{'numeric'},{'real','finite','scalar','integer'});
    assert(abs(initialCount-counts(1)) <= 1, ...
        'EMIProject:FourWayInitialCount','Initial intended count is inconsistent with plant state.');
end
times = zeros(0,1); newCounts = zeros(0,1);
if initialCount ~= counts(1)
    times(end+1,1) = 0;
    newCounts(end+1,1) = counts(1);
end
for n = 1:numel(points)-1
    qa = counts(n); qb = counts(n+1);
    direction = sign(qb-qa);
    if direction == 0, continue; end
    for q = qa+direction:direction:qb
        if direction > 0, boundary = (q-0.5)*delta;
        else, boundary = (q+0.5)*delta; end
        left = points(n); right = points(n+1);
        fl = segment.thetaAt(left)-boundary;
        fr = segment.thetaAt(right)-boundary;
        angleTolerance = 16*eps(max([abs(boundary),delta]));
        if abs(fr) <= angleTolerance
            root = right;
        elseif abs(fl) <= angleTolerance
            root = left;
        else
            assert(fl*fr < 0,'EMIProject:FourWayUnbracketedBoundary', ...
                'A quantization boundary lacks a monotone crossing bracket.');
            root = fzero(@(t) segment.thetaAt(t)-boundary,[left,right], ...
                optimset('TolX',1e-15,'Display','off'));
        end
        times(end+1,1) = root; %#ok<AGROW>
        newCounts(end+1,1) = q; %#ok<AGROW>
    end
end
% Keep the first root's timestamp and the final right-limit state for a
% joint group. No artificial sequence/order is assigned inside 1 ps.
outTimes = zeros(0,1); outCounts = zeros(0,1);
for n = 1:numel(times)
    if ~isempty(outTimes) && times(n)-outTimes(end) <= timeTolerance
        outCounts(end) = newCounts(n);
    else
        outTimes(end+1,1) = times(n); %#ok<AGROW>
        outCounts(end+1,1) = newCounts(n); %#ok<AGROW>
    end
end
directions = sign(diff([double(initialCount);outCounts]));
gray = [0,0;1,0;1,1;0,1];
bits = gray(mod(outCounts,4)+1,:);
events = table(outTimes,outCounts,logical(bits(:,1)),logical(bits(:,2)), ...
    directions,'VariableNames',{'time_s','newCount','A','B','direction'});
xNext = segment.stateAt(dt);
if nargout >= 3, intervalStats = segment.intervalStats(dt); end

    function q = rightCount(t,isStationary)
        theta = segment.thetaAt(t);
        scaled = theta/delta+0.5;
        nearest = round(scaled);
        if abs(theta-(nearest-0.5)*delta) > 16*eps(max([abs(theta),delta]))
            q = floor(scaled);
            return
        end
        velocity = segment.velocityAt(t);
        if isStationary || abs(velocity) <= 32*eps(segment.velocityScale)
            direction = sign(segment.accelerationAt(t));
            if direction == 0, direction = 1; end
        else
            direction = sign(velocity);
        end
        q = nearest-(direction < 0);
    end
end
