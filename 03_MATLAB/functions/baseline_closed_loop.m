function model = baseline_closed_loop(params)
%BASELINE_CLOSED_LOOP Assemble the analytical discrete baseline model.

validate_parameters(params);

model.plantContinuous = actuator_state_space(params);
model.positionPlantContinuous = model.plantContinuous(1, 1);
model.controller = design_baseline_controller(params, model.plantContinuous);

model.positionPlantDiscrete = c2d( ...
    model.positionPlantContinuous, params.control.sampleTime_s, 'zoh');

model.loopTransfer = model.controller.discrete * model.positionPlantDiscrete;
model.referenceToPosition = feedback(model.loopTransfer, 1);
model.referenceToCommand = feedback( ...
    model.controller.discrete, model.positionPlantDiscrete);

% Load is an independent physical input with the sign defined by the plant.
discreteFullPlant = c2d(model.plantContinuous,params.control.sampleTime_s,'zoh');
loadPlant = discreteFullPlant(1,2);
model.loadToPosition = feedback(tf(1,1,params.control.sampleTime_s), ...
    model.loopTransfer) * loadPlant;
model.loadToCommand = -model.referenceToCommand * loadPlant;

model.referenceToPosition.Name = 'Reference-to-position closed loop';
model.referenceToCommand.Name = 'Reference-to-voltage-command response';
end
