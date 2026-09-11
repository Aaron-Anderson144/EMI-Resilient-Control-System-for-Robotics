function state = phase3_reacquisition_initialize(config)
%PHASE3_REACQUISITION_INITIALIZE Fixed-capacity independent reference window.
arguments
    config (1,1) struct
end
id='EMIProject:InvalidReacquisitionConfiguration';
assert(isfield(config,'observerConfiguration') && isfield(config,'tunableFields') && ...
    iscell(config.tunableFields),id,'A complete reacquisition configuration is required.');
% Rebuild cached maps from declared model/tunables. This allows a scenario to
% update assumedLoadTorque_Nm, and rejects edits to dimensions or cached maps.
overrides=struct();
for k=1:numel(config.tunableFields)
    name=config.tunableFields{k};
    assert(ischar(name) && isfield(config,name),id,'All declared tunables are required.');
    overrides.(name)=config.(name);
end
expected=phase3_reacquisition_configuration(config.observerConfiguration,overrides);
derived=setdiff(fieldnames(expected),expected.tunableFields);
assert(all(isfield(config,derived)),id,'Reacquisition derived fields are incomplete.');
for k=1:numel(derived)
    name=derived{k};
    assert(isequaln(config.(name),expected.(name)),id,'Derived reacquisition field %s is inconsistent.',name);
end
state.config=expected;
state.sampleIndex=0;
state.lastSeenSourceIndex=0;
state.count=0;
state.position_rad=zeros(expected.windowSamples,1);
state.uncertainty_rad=zeros(expected.windowSamples,1);
state.inputToSample_V=zeros(expected.windowSamples,1);
end
