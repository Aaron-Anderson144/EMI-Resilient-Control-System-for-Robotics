function state = phase3_observer_initialize(config)
%PHASE3_OBSERVER_INITIALIZE Bounded replay state; no plant truth is supplied.
validate_phase3_observer_configuration(config);
names=fieldnames(config);
for k=1:numel(names)
    if isnumeric(config.(names{k})),config.(names{k})=double(config.(names{k}));end
end
state.config=config;
state.sampleIndex=0;
state.estimatedState=double(config.initialEstimate(:));
state.historyIndices=zeros(1,config.historyCapacity);
state.historyStates=zeros(3,config.historyCapacity);
% At index k this stores u_(k-1), the actual voltage entering state x_k.
state.inputToSample_V=zeros(1,config.historyCapacity);
state.lastSeenSourceIndex=0;
state.lastTrustedSourceIndex=0;
state.lastTrustedMeasurement_rad=NaN;
state.residualLatched=false;
end
