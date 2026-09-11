function [state, diagnostic] = phase3_reacquisition_step(state, input)
%PHASE3_REACQUISITION_STEP Qualify a contiguous independent-reference window.
% Call on every tick, from currentIndex=1. A request is evaluated only on its
% current tick; it is never queued. Stopped means commanded drive is stopped,
% not that physical velocity/current are zero. No primary encoder or truth
% enters this interface. previousAppliedVoltage_V is the actual u_(k-1).
id='EMIProject:InvalidReacquisitionInput';
assert(isstruct(input) && isscalar(input),id,'Input must be a scalar structure.');
required={'currentIndex','stopped','request','sampleReceived','previousAppliedVoltage_V'};
assert(all(isfield(input,required)),id,'Scheduling, flags and previous applied voltage are required.');
assert(localScalar(input.currentIndex) && input.currentIndex==fix(input.currentIndex) && ...
    input.currentIndex==state.sampleIndex+1 && input.currentIndex<=flintmax,id, ...
    'currentIndex must advance by exactly one on every call.');
for name={'stopped','request','sampleReceived'}
    flag=input.(name{1});
    assert((islogical(flag) || isnumeric(flag)) && isreal(flag) && isscalar(flag) && ...
        isfinite(flag) && any(flag==[0,1]),id,'%s must be a scalar logical flag.',name{1});
end
assert(localScalar(input.previousAppliedVoltage_V),id,'Previous applied voltage must be finite and real.');
state.sampleIndex=double(input.currentIndex);c=state.config;
diagnostic=struct('qualified',false,'committed',false,'estimatedState',zeros(3,1), ...
    'stateUncertainty',zeros(3,1),'fitResidual_rad',0,'reason',"none");
if ~input.stopped
    [state,diagnostic]=localReject(state,diagnostic,"not_stopped");return
end
if ~input.sampleReceived
    [state,diagnostic]=localReject(state,diagnostic,"missing_sample");return
end
if ~all(isfield(input,{'position_rad','sourceIndex','uncertainty_rad'}))
    [state,diagnostic]=localReject(state,diagnostic,"missing_reference_fields");return
end
if ~localScalar(input.sourceIndex) || input.sourceIndex~=fix(input.sourceIndex) || input.sourceIndex<1
    [state,diagnostic]=localReject(state,diagnostic,"invalid_timestamp");return
end
source=double(input.sourceIndex);
if source<=state.lastSeenSourceIndex
    [state,diagnostic]=localReject(state,diagnostic,"nonincreasing_timestamp");return
elseif source>state.sampleIndex
    [state,diagnostic]=localReject(state,diagnostic,"future_timestamp");return
elseif source<state.sampleIndex
    [state,diagnostic]=localReject(state,diagnostic,"late_timestamp");return
end
% A synchronized rejected reference cannot be reused as later evidence.
state.lastSeenSourceIndex=source;
if ~localScalar(input.position_rad)
    [state,diagnostic]=localReject(state,diagnostic,"invalid_position");return
end
if ~localScalar(input.uncertainty_rad) || input.uncertainty_rad<c.minReferenceUncertainty_rad || ...
        input.uncertainty_rad>c.maxReferenceUncertainty_rad
    [state,diagnostic]=localReject(state,diagnostic,"invalid_uncertainty");return
end
if abs(double(input.position_rad))+double(input.uncertainty_rad)>c.positionLimit_rad
    [state,diagnostic]=localReject(state,diagnostic,"position_range");return
end
if state.count==c.windowSamples
    state.position_rad(1:end-1)=state.position_rad(2:end);
    state.uncertainty_rad(1:end-1)=state.uncertainty_rad(2:end);
    state.inputToSample_V(1:end-1)=state.inputToSample_V(2:end);
else
    state.count=state.count+1;
end
j=state.count;state.position_rad(j)=double(input.position_rad);
state.uncertainty_rad(j)=double(input.uncertainty_rad);
state.inputToSample_V(j)=double(input.previousAppliedVoltage_V);
if state.count<c.windowSamples,diagnostic.reason="collecting";return;end
if ~c.modelQualified,diagnostic.reason="unobservable_window";return;end
% Separate known forced response from the unknown state at the window start.
forced=zeros(c.windowSamples,1);forcedState=zeros(3,1);
for j=2:c.windowSamples
    forcedState=c.A*forcedState+c.B*[state.inputToSample_V(j);c.assumedLoadTorque_Nm];
    forced(j)=c.C*forcedState;
end
observed=state.position_rad-forced;
initial=c.initialStateMap*observed;
estimate=c.currentStateMap*observed+forcedState;
residual=c.observability*initial-observed;
uncertainty=abs(c.currentStateMap)*state.uncertainty_rad;
if ~all(isfinite([estimate;residual;uncertainty]))
    diagnostic.reason="nonfinite_reconstruction";return
end
diagnostic.estimatedState=estimate;diagnostic.stateUncertainty=uncertainty;
diagnostic.fitResidual_rad=max(abs(residual));
% Roundoff tolerance is numerical slack only, not a physical model bound.
tolerance=256*eps(max([1;abs(observed);abs(c.observability*initial)]));
if diagnostic.fitResidual_rad>c.maxFitResidual_rad+tolerance
    diagnostic.reason="dynamic_fit";return
end
if any(abs(residual)>c.residualUncertaintyMap*state.uncertainty_rad+tolerance)
    diagnostic.reason="inconsistent_uncertainty";return
end
if any(uncertainty>c.maxStateUncertainty)
    diagnostic.reason="state_uncertainty";return
end
% Require the whole declared current-state uncertainty interval inside limits.
if any(abs(estimate)+uncertainty>c.stateLimits)
    diagnostic.reason="state_range";return
end
diagnostic.qualified=true;diagnostic.reason="qualified";
if input.request
    diagnostic.committed=true;diagnostic.reason="committed";
    state=localClear(state);
end
end

function valid=localScalar(value)
valid=isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
end

function [state,diagnostic]=localReject(state,diagnostic,reason)
state=localClear(state);diagnostic.reason=reason;
end

function state=localClear(state)
state.count=0;state.position_rad(:)=0;state.uncertainty_rad(:)=0;state.inputToSample_V(:)=0;
end
