function out=receiver_v2_logic(input,latencyRise,latencyFall,law,initial,stopTime)
% Input/output event arrays [time,state]. Equality accepts a pending event
% before a new input event. Transport schedules every input event; inertial
% requires that each input state persist for its assumed post-trip latency.
assert(all(diff(input(:,1))>=0)&&all(ismember(input(:,2),[0 1])));
assert(any(strcmp(law,{'transport','inertial'}))&&min([latencyRise latencyFall])>=0);
if isempty(input),out=zeros(0,2);return,end
if strcmp(law,'transport')
    latency=latencyFall+(latencyRise-latencyFall)*input(:,2);
    due=input(:,1)+latency;
    assert(all(diff(due)>=0),'RECEIVER_V2:TransportOvertaking', ...
        'Asymmetric assumed delays caused event overtaking; this behavior is unresolved.');
    candidate=[due,input(:,2)];
    % Coalesce coincident due events in original input order, keeping the
    % final requested state; sorting by output value would invent an edge.
    keep=[diff(due)~=0;true];candidate=candidate(keep,:);
else
    candidate=zeros(0,2);pendingTime=Inf;pendingState=initial;outputState=initial;
    for j=1:size(input,1)
        if pendingTime<=input(j,1)
            candidate(end+1,:)=[pendingTime,pendingState]; %#ok<AGROW>
            outputState=pendingState;pendingTime=Inf;
        end
        if input(j,2)==outputState,pendingTime=Inf;
        else
            pendingState=input(j,2);
            pendingTime=input(j,1)+latencyFall+(latencyRise-latencyFall)*pendingState;
        end
    end
    if pendingTime<=stopTime,candidate(end+1,:)=[pendingTime,pendingState];end
end
candidate=candidate(candidate(:,1)<=stopTime,:);out=zeros(0,2);state=initial;
for j=1:size(candidate,1)
    if candidate(j,2)~=state,out(end+1,:)=candidate(j,:);state=candidate(j,2);end %#ok<AGROW>
end
end
