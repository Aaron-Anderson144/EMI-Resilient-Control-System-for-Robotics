function segment = fourway_plant_segment(x,voltage_V,load_Nm,params)
%FOURWAY_PLANT_SEGMENT Exact affine solution on one held-input interval.
% This helper uses actuator_state_space, with no future command information.
% PLAN-V1's motor has two distinct real stable velocity/current poles. The
% explicit restriction below prevents silently applying its root-isolation
% argument to a different, oscillatory motor model.
validateattributes(x,{'numeric'},{'real','finite','numel',3});
validateattributes(voltage_V,{'numeric'},{'real','finite','scalar'});
validateattributes(load_Nm,{'numeric'},{'real','finite','scalar'});
x = double(x(:));
persistent lastKey cachedA cachedB cachedLambda
key = [params.electrical.resistance_Ohm, params.electrical.inductance_H, ...
    params.motor.torqueConstant_Nm_A, params.motor.backEmfConstant_V_s_rad, ...
    params.mechanical.inertia_kg_m2, params.mechanical.viscousDamping_Nm_s_rad];
if isempty(lastKey) || ~isequal(key,lastKey)
    [cachedA,cachedB] = ssdata(actuator_state_space(params));
    cachedLambda = sort(eig(cachedA(2:3,2:3)),'descend');
    assert(isreal(cachedLambda) && all(cachedLambda < 0) && ...
        abs(diff(cachedLambda)) > 1e-8*max(abs(cachedLambda)), ...
        'EMIProject:FourWayPlantPoles', ...
        'The frozen event isolator requires two distinct real stable poles.');
    lastKey = key;
end
A = cachedA;
B = cachedB;
lambda = cachedLambda;
forcing = B*[double(voltage_V);double(load_Nm)];
steady = -(A(2:3,2:3)\forcing(2:3));
wSteady = steady(1);
derivative0 = A*x+forcing;
a0 = derivative0(2);
wDifference = x(2)-wSteady;
c = [(a0-lambda(2)*wDifference)/(lambda(1)-lambda(2)); ...
    (lambda(1)*wDifference-a0)/(lambda(1)-lambda(2))];
currentModes = c.*(lambda-A(2,2))/A(2,3);
segment.stateAt = @stateAt;
segment.thetaAt = @thetaAt;
segment.velocityAt = @velocityAt;
segment.accelerationAt = @accelerationAt;
segment.stationaryTimes = @stationaryTimes;
segment.intervalStats = @intervalStats;
segment.velocityScale = max([abs(x(2)),abs(wSteady),abs(c.'),realmin]);
segment.initialState = x;

    function theta = thetaAt(t)
        t = double(t(:).');
        z = lambda*t;
        theta = x(1)+x(2)*t+(c./lambda).'*(expm1(z)-z);
    end

    function w = velocityAt(t)
        t = double(t(:).');
        % Increment form preserves the supplied velocity exactly at zero.
        w = x(2)+c.'*expm1(lambda*t);
    end

    function acceleration = accelerationAt(t)
        t = double(t(:).');
        acceleration = a0+(c.*lambda).'*expm1(lambda*t);
    end

    function state = stateAt(t)
        t = double(t(:).');
        increments = expm1(lambda*t);
        velocity = x(2)+c.'*increments;
        current = x(3)+currentModes.'*increments;
        state = [thetaAt(t);velocity;current];
    end

    function roots_s = stationaryTimes(dt)
        % Acceleration is a sum of two exponentials, hence has at most one
        % root. Splitting there makes velocity monotone on every bracket;
        % this finds all velocity roots without a time-grid assumption.
        brackets = [0,exponentialRoot(c.*lambda,dt),dt];
        roots_s = [];
        for n = 1:numel(brackets)-1
            left = brackets(n); right = brackets(n+1);
            vl = velocityAt(left); vr = velocityAt(right);
            if vl == 0 && left > 0, roots_s(end+1) = left; end %#ok<AGROW>
            if vl*vr < 0
                roots_s(end+1) = fzero(@velocityAt,[left,right], ...
                    optimset('TolX',1e-15,'Display','off')); %#ok<AGROW>
            end
            if vr == 0 && right < dt, roots_s(end+1) = right; end %#ok<AGROW>
        end
        roots_s = unique(roots_s);
    end

    function root = exponentialRoot(weights,dt)
        root = [];
        if weights(1)*weights(2) < 0
            candidate = log(-weights(2)/weights(1))/(lambda(1)-lambda(2));
            if candidate > 0 && candidate < dt, root = candidate; end
        end
    end

    function stats = intervalStats(dt)
        speedTimes = [0,exponentialRoot(c.*lambda,dt),dt];
        currentTimes = [0,exponentialRoot(currentModes.*lambda,dt),dt];
        currentStates = stateAt(currentTimes);
        stats.peakAbsVelocity_rad_s = max(abs(velocityAt(speedTimes)));
        stats.peakAbsCurrent_A = max(abs(currentStates(3,:)));
        % Gaussian quadrature avoids cancellation of large opposing terms
        % in the analytic squared-exponential antiderivative. Sixteen nodes
        % per <=1 ms panel resolve the frozen motor poles to roundoff.
        persistent nodes weights
        if isempty(nodes)
            indices = (1:15).';
            offDiagonal = indices./sqrt(4*indices.^2-1);
            [vectors,values] = eig(diag(offDiagonal,1)+diag(offDiagonal,-1));
            [nodes,order] = sort(diag(values));
            weights = 2*(vectors(1,order).^2).';
        end
        panels = max(1,ceil(dt/1e-3));
        width = dt/panels;
        integralValue = 0;
        for panel = 1:panels
            times = ((panel-0.5)*width+0.5*width*nodes).';
            currents = x(3)+currentModes.'*expm1(lambda*times);
            integralValue = integralValue+0.5*width*(currents.^2)*weights;
        end
        stats.currentSquaredIntegral_A2s = integralValue;
    end
end
