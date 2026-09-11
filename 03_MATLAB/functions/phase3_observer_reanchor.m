function observer = phase3_observer_reanchor(observer, newEstimatedState)
%PHASE3_OBSERVER_REANCHOR Replace current posterior without primary trust.
% Only call after independent-reference qualification and explicit request.
% The pre-anchor replay window is discarded. Primary seen/trusted timestamps,
% trusted measurement and residual latch remain unchanged: this operation
% cannot manufacture primary freshness, accepted evidence or recovery dwell.
id='EMIProject:InvalidObserverReanchor';
assert(isstruct(observer) && isscalar(observer) && isfield(observer,'config') && ...
    isfield(observer,'sampleIndex'),id,'An initialized observer is required.');
validate_phase3_observer_configuration(observer.config);
assert(isnumeric(observer.sampleIndex) && isscalar(observer.sampleIndex) && ...
    isreal(observer.sampleIndex) && isfinite(observer.sampleIndex) && ...
    observer.sampleIndex>=1 && observer.sampleIndex==fix(observer.sampleIndex),id, ...
    'The observer must have a current sample before reanchoring.');
assert(isnumeric(newEstimatedState) && isreal(newEstimatedState) && ...
    isvector(newEstimatedState) && numel(newEstimatedState)==3 && ...
    all(isfinite(newEstimatedState)),id,'The reanchor estimate must have three finite real states.');
estimate=double(newEstimatedState(:));
assert(all(abs(estimate)<=[observer.config.positionLimit_rad;observer.config.rateLimit_rad_s;12]),id, ...
    'Reanchor position, velocity and current must meet declared observer limits and the provisional 12 A limit.');
observer.estimatedState=estimate;
observer.historyIndices(:)=0;observer.historyStates(:)=0;observer.inputToSample_V(:)=0;
slot=mod(observer.sampleIndex-1,observer.config.historyCapacity)+1;
observer.historyIndices(slot)=observer.sampleIndex;
observer.historyStates(:,slot)=estimate;
end
