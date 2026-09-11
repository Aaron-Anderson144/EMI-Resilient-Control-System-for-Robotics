function [state, diagnostic] = phase3_observer_step(state, measurement_rad, sourceIndex, sampleReceived, previousAppliedVoltage_V)
%PHASE3_OBSERVER_STEP Timestamp-aware correction with applied-input replay.
% Call once per sample, starting at index 1. previousAppliedVoltage_V is
% u_(k-1); it is validated but ignored on the initial sample. Missing/held
% samples never update the estimate or count as credible recovery evidence.
% Only received measurement/timestamp and actual applied voltage enter the
% decision. True states, fault profiles and scenario labels are absent.
id='EMIProject:InvalidObserverInput';
assert((islogical(sampleReceived) || isnumeric(sampleReceived)) && isreal(sampleReceived) && ...
    isscalar(sampleReceived) && isfinite(sampleReceived) && any(sampleReceived==[0,1]),id, ...
    'sampleReceived must be a scalar logical flag.');
assert(isnumeric(previousAppliedVoltage_V) && isreal(previousAppliedVoltage_V) && ...
    isscalar(previousAppliedVoltage_V) && isfinite(previousAppliedVoltage_V),id, ...
    'The previously applied voltage must be finite and real.');
c=state.config;k=state.sampleIndex+1;
slot=mod(k-1,c.historyCapacity)+1;
if k>1
    state.estimatedState=c.A*state.estimatedState+c.B*[double(previousAppliedVoltage_V);c.assumedLoadTorque_Nm];
end
state.sampleIndex=k;
state.historyIndices(slot)=k;
state.historyStates(:,slot)=state.estimatedState;
state.inputToSample_V(slot)=double(previousAppliedVoltage_V);
accepted=false;credibleFresh=false;gateFailure=false;reason="none";
innovation=NaN;measuredRate=NaN;sourceAge=NaN;reportedSource=NaN;
if sampleReceived
    timestampValid=isnumeric(sourceIndex) && isreal(sourceIndex) && isscalar(sourceIndex) && ...
        isfinite(sourceIndex) && sourceIndex==fix(sourceIndex) && sourceIndex>=1 && sourceIndex<=k;
    if ~timestampValid
        gateFailure=true;reason="invalid_timestamp";
    else
        source=double(sourceIndex);reportedSource=source;sourceAge=(k-source)*c.sampleTime_s;
        sourceSlot=mod(source-1,c.historyCapacity)+1;
        if source<=state.lastSeenSourceIndex
            gateFailure=true;reason="nonincreasing_timestamp";
        else
            % A rejected value cannot later be replayed under the same timestamp.
            % Invalid future timestamps never poison this monotonic watermark.
            state.lastSeenSourceIndex=source;
            if state.historyIndices(sourceSlot)~=source
                gateFailure=true;reason="outside_history";
            elseif sourceAge>c.maxMeasurementAge_s+localTimeTolerance(c.sampleTime_s,c.maxMeasurementAge_s)
                gateFailure=true;reason="measurement_too_old";
            elseif ~(isnumeric(measurement_rad) && isreal(measurement_rad) && ...
                    isscalar(measurement_rad) && isfinite(measurement_rad))
                gateFailure=true;reason="nonfinite_measurement";
            else
                value=double(measurement_rad);
                innovation=value-c.C*state.historyStates(:,sourceSlot);
                if state.lastTrustedSourceIndex>0
                    measuredRate=(value-state.lastTrustedMeasurement_rad)/ ...
                        ((source-state.lastTrustedSourceIndex)*c.sampleTime_s);
                end
                if isfinite(innovation) && abs(innovation)>c.residualTrip_rad
                    state.residualLatched=true;
                end
                if abs(value)>c.positionLimit_rad
                    gateFailure=true;reason="position_range";
                elseif ~isfinite(innovation)
                    gateFailure=true;reason="nonfinite_innovation";
                elseif state.lastTrustedSourceIndex>0 && ...
                        (~isfinite(measuredRate) || abs(measuredRate)>c.rateLimit_rad_s)
                    gateFailure=true;reason="position_rate";
                elseif abs(innovation)>c.residualTrip_rad
                    gateFailure=true;reason="innovation_limit";
                else
                    accepted=true;
                    corrected=state.historyStates(:,sourceSlot)+c.correctionGain*innovation;
                    state.historyStates(:,sourceSlot)=corrected;
                    for replay=source+1:k
                        replaySlot=mod(replay-1,c.historyCapacity)+1;
                        corrected=c.A*corrected+c.B*[state.inputToSample_V(replaySlot);c.assumedLoadTorque_Nm];
                        state.historyStates(:,replaySlot)=corrected;
                    end
                    state.estimatedState=corrected;
                    state.lastTrustedSourceIndex=source;
                    state.lastTrustedMeasurement_rad=value;
                    if abs(innovation)<=c.residualClear_rad
                        state.residualLatched=false;
                        credibleFresh=true;
                    end
                end
            end
        end
    end
end
if state.lastTrustedSourceIndex>0
    trustedAge=(k-state.lastTrustedSourceIndex)*c.sampleTime_s;
    predictionAge=trustedAge;
else
    trustedAge=Inf;
    predictionAge=(k-1)*c.sampleTime_s;
end
stale=predictionAge>c.maxMeasurementAge_s+localTimeTolerance(c.sampleTime_s,c.maxMeasurementAge_s);
estimateUsable=all(isfinite(state.estimatedState)) && ...
    predictionAge<=c.maxPredictionTime_s+localTimeTolerance(c.sampleTime_s,c.maxPredictionTime_s);
diagnostic=struct('sampleIndex',k,'time_s',(k-1)*c.sampleTime_s, ...
    'measurementReceived',logical(sampleReceived),'sourceIndex',reportedSource,'sourceAge_s',sourceAge, ...
    'measurementAccepted',accepted,'credibleFresh',credibleFresh,'gateFailure',gateFailure, ...
    'gateReason',reason,'innovation_rad',innovation,'measurementRate_rad_s',measuredRate, ...
    'residualLatched',state.residualLatched,'lastSeenSourceIndex',state.lastSeenSourceIndex, ...
    'trustedSourceIndex',state.lastTrustedSourceIndex,'trustedAge_s',trustedAge, ...
    'predictionAge_s',predictionAge,'stale',stale, ...
    'alarm',gateFailure || stale || state.residualLatched,'estimateUsable',estimateUsable, ...
    'estimatedState',state.estimatedState,'estimatedPosition_rad',state.estimatedState(1), ...
    'predictionOnly',~accepted);
end

function tolerance=localTimeTolerance(sampleTime_s,threshold_s)
tolerance=64*eps(max(sampleTime_s,threshold_s));
end
