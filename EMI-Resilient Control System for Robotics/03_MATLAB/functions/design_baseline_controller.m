function controller = design_baseline_controller(params, plant)
%DESIGN_BASELINE_CONTROLLER Tune and discretize the baseline position PID.

validate_parameters(params);

if nargin < 2
    plant = actuator_state_space(params);
end

positionPlant = plant(1, 1);
controller.continuous = pidtune( ...
    positionPlant, 'PIDF', params.control.targetBandwidth_rad_s);
controller.discrete = c2d( ...
    controller.continuous, params.control.sampleTime_s, 'tustin');

controller.continuous.Name = 'Continuous baseline position controller';
controller.discrete.Name = 'Discrete baseline position controller';
end

