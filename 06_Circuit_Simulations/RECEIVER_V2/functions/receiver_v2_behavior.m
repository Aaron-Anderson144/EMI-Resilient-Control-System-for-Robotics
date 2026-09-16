function b=receiver_v2_behavior(s,a,threshold,latency,law)
ev=a.events;keep=ev(:,2)==3 & ...
    ((ev(:,3)==threshold.rise_V & ev(:,4)>0)|(ev(:,3)==threshold.fall_V & ev(:,4)<0));
ev=ev(keep,:);input=zeros(0,2);state=s.fixture.initialAB(1);
for j=1:size(ev,1)
    next=double(ev(j,4)>0);
    if next~=state,input(end+1,:)=[ev(j,1),next];state=next;end %#ok<AGROW>
end
out=receiver_v2_logic(input,latency,latency,law,s.fixture.initialAB(1),s.t(end));
decoded=receiver_v2_decode(out,s.fixture.transitions,s.fixture.initialAB);
tr=s.fixture.transitions;changeA=[tr(1,2)~=s.fixture.initialAB(1);diff(tr(:,2))~=0];expected=tr(changeA,[1 2]);
ideal=receiver_v2_decode(expected,tr,s.fixture.initialAB);
delay=NaN;
if isequal(size(out),size(expected))&&isequal(out(:,2),expected(:,2))
    delay=max(out(:,1)-expected(:,1));
end
b=struct('inputEvents',input,'outputEvents',out,'decoderEvents',decoded.events, ...
    'finalCount',decoded.finalCount,'idealCount',ideal.finalCount,'finalCountError',decoded.finalCount-ideal.finalCount, ...
    'invalidTransitions',decoded.invalidTransitions,'inputEdges',size(input,1), ...
    'outputEdges',size(out,1),'extraEdges',max(0,size(out,1)-size(expected,1)), ...
    'missedEdges',max(0,size(expected,1)-size(out,1)),'maxTransitionDelay_s',delay, ...
    'inputPulseWidths_s',diff(input(:,1)),'outputPulseWidths_s',diff(out(:,1)));
end
