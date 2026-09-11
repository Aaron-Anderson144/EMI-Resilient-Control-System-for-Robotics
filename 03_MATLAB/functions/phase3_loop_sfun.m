function phase3_loop_sfun(block)
%PHASE3_LOOP_SFUN Level-2 wrapper for the causal Phase 3 sensor/control loop.
% Plant state belongs to the separate Simulink discrete state-space block.
% Outputs evaluates a candidate transition; only Update commits loop state.
% A repeated Outputs call at the same tick reuses the same candidate, so it
% cannot consume a packet, integrate a controller or age a monitor twice.
setup(block);
end

function setup(block)
block.NumDialogPrms = 1;
block.DialogPrmsTunable = {'Nontunable'};
block.NumInputPorts = 1;
block.NumOutputPorts = 1;
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;
block.InputPort(1).Dimensions = 3;
block.InputPort(1).DatatypeID = 0;
block.InputPort(1).Complexity = 'Real';
block.InputPort(1).DirectFeedthrough = true;
[values, ~] = phase3_logged_values();
block.OutputPort(1).Dimensions = numel(values);
block.OutputPort(1).DatatypeID = 0;
block.OutputPort(1).Complexity = 'Real';
block.SampleTimes = [block.DialogPrm(1).Data.params.control.sampleTime_s, 0];
block.SimStateCompliance = 'CustomSimState';
block.RegBlockMethod('InitializeConditions', @initialize);
block.RegBlockMethod('Outputs', @outputs);
block.RegBlockMethod('Update', @update);
block.RegBlockMethod('GetSimState', @getState);
block.RegBlockMethod('SetSimState', @setState);
block.RegBlockMethod('Terminate', @terminate);
end

function initialize(block)
memory.state = phase3_loop_initialize(block.DialogPrm(1).Data);
memory.next = [];
memory.values = [];
memory.plantOutput = [];
memory.outputTime_s = NaN;
memory.committedTime_s = NaN;
set_param(block.BlockHandle, 'UserData', memory);
end

function outputs(block)
memory = get_param(block.BlockHandle, 'UserData');
plantOutput = block.InputPort(1).Data(:);
assert(numel(plantOutput) == 3 && all(isfinite(plantOutput)), ...
    'EMIProject:InvalidPhase3PlantOutput', 'The independent plant output must remain finite.');
if isequal(memory.outputTime_s, block.CurrentTime)
    assert(isequal(plantOutput, memory.plantOutput), ...
        'EMIProject:Phase3RepeatedOutputChanged', ...
        'Plant output changed during repeated evaluation of a discrete Phase 3 tick.');
else
    [memory.next, sample] = phase3_loop_step(memory.state, plantOutput);
    memory.values = phase3_logged_values(sample);
    assert(isreal(memory.values) && isequal(size(memory.values), [1, 31]) && ...
        all(isfinite(memory.values([1:7,9:31]))) && ~isinf(memory.values(8)), ...
        'EMIProject:InvalidPhase3LoopOutput', ...
        'Loop logs must be finite except for documented missing innovations.');
    memory.plantOutput = plantOutput;
    memory.outputTime_s = block.CurrentTime;
    set_param(block.BlockHandle, 'UserData', memory);
end
block.OutputPort(1).Data = memory.values(:);
end

function update(block)
memory = get_param(block.BlockHandle, 'UserData');
assert(isequal(memory.outputTime_s, block.CurrentTime), ...
    'EMIProject:Phase3UpdateWithoutOutput', 'Every loop update requires the current tick output.');
if ~isequal(memory.committedTime_s, block.CurrentTime)
    memory.state = memory.next;
    memory.committedTime_s = block.CurrentTime;
    set_param(block.BlockHandle, 'UserData', memory);
end
end

function memory = getState(block)
memory = get_param(block.BlockHandle, 'UserData');
end

function setState(block, memory)
set_param(block.BlockHandle, 'UserData', memory);
end

function terminate(block)
% Runtime state is neither persisted in the model nor reused by another run.
set_param(block.BlockHandle, 'UserData', []);
end
