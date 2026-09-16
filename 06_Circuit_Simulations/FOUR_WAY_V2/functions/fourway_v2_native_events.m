function result=fourway_v2_native_events(native,initialA,variant,sampleTimes)
% Independent linear interpolation of native solver points and delayed logic.
% All trip surfaces retain both directions. Grazing inside the voltage gate
% is rejected, not silently converted into an integer-count equivalence.
t=native.time_s(:);x=[native.positive_V(:),native.negative_V(:),native.returnCurrent_A(:)];
assert(all(isfinite(x),'all')&&all(isfinite(t))&&all(diff(t)>0));
assert(any(initialA==[0 1])&&isscalar(initialA));
events=zeros(0,8);grazing=false;d=x(:,1)-x(:,2);
for kind=1:7
    if kind==1,value=d;levels=[variant.fall_V variant.rise_V];
    else
        axis=mod(kind-2,3)+1;
        if axis==1,value=x(:,1);elseif axis==2,value=x(:,2);else,value=d;end
        limit=15;if kind>=5,limit=18;end
        levels=[-limit limit];
    end
    for threshold=levels
        z=value-threshold;
        extrema=(z(2:end-1)-z(1:end-2)).*(z(3:end)-z(2:end-1))<=0;
        sameSide=z(1:end-2).*z(3:end)>0;
        grazing=grazing||any(extrema&sameSide&abs(z(2:end-1))<=1e-4);
        for direction=[-1 1]
            if direction>0,index=find(z(1:end-1)<0&z(2:end)>=0);
            else,index=find(z(1:end-1)>0&z(2:end)<=0);end
            fraction=-z(index)./(z(index+1)-z(index));
            when=t(index)+fraction.*(t(index+1)-t(index));
            state=x(index,:)+fraction.*(x(index+1,:)-x(index,:));
            events=[events;when,repmat([kind threshold direction],numel(index),1),state,zeros(numel(index),1)]; %#ok<AGROW>
        end
    end
end
events=sortrows(events,[1 2 3 4]);
input=zeros(0,2);state=initialA;
for k=1:size(events,1)
    e=events(k,:);next=state;
    if e(2)==1
        if e(3)==variant.rise_V&&e(4)==1,next=1;end
        if e(3)==variant.fall_V&&e(4)==-1,next=0;end
    end
    if next~=state,input(end+1,:)=[e(1),next];state=next;end %#ok<AGROW>
end
output=localDelay(input,initialA,variant,t(end));
decoder=zeros(size(output,1),8);count=0;previous=initialA;
for k=1:size(output,1)
    value=output(k,2);increment=2*value-1;count=count+increment;
    decoder(k,:)=[output(k,1),value,0,increment,count,0,previous,0];previous=value;
end
counts=zeros(numel(sampleTimes),1);
for k=1:numel(sampleTimes)
    index=find(decoder(:,1)<=sampleTimes(k),1,'last');
    if ~isempty(index),counts(k)=decoder(index,5);end
end
if ~isempty(events)
    if isempty(output),events(:,8)=initialA;
    else,events(:,8)=interp1([0;output(:,1)],[initialA;output(:,2)],events(:,1),'previous','extrap');end
end
result=struct('thresholdEvents',events,'comparatorEvents',input,'outputEvents',output, ...
    'decoderEvents',decoder,'counts',counts,'grazingUnresolved',grazing, ...
    'linearNativeOperatingDomainPass',all(abs([x(:,1:2),d])<=15,'all'), ...
    'linearNativeStressFlag',any(abs([x(:,1:2),d])>18,'all'), ...
    'minSignedVoltages_V',min([x(:,1:2),d],[],1),'maxSignedVoltages_V',max([x(:,1:2),d],[],1), ...
    'clampCurrent_A',NaN);
end

function output=localDelay(input,initial,v,stop)
candidate=zeros(0,2);
if strcmp(v.pulseLaw,'transport')
    for k=1:size(input,1)
        latency=v.latencyFall_s;if input(k,2)==1,latency=v.latencyRise_s;end
        candidate(end+1,:)=[input(k,1)+latency,input(k,2)]; %#ok<AGROW>
    end
    assert(isempty(candidate)||all(diff(candidate(:,1))>=0),'FOURWAYV2:NativeOvertaking','Transport outputs overtake.');
elseif strcmp(v.pulseLaw,'inertial')
    pending=Inf;target=initial;state=initial;
    for k=1:size(input,1)
        if pending<=input(k,1)
            candidate(end+1,:)=[pending,target];state=target;pending=Inf; %#ok<AGROW>
        end
        if input(k,2)==state,pending=Inf;
        else
            target=input(k,2);latency=v.latencyFall_s;if target==1,latency=v.latencyRise_s;end
            pending=input(k,1)+latency;
        end
    end
    if pending<=stop,candidate(end+1,:)=[pending,target];end
else,error('FOURWAYV2:NativePulseLaw','Unknown pulse law.');end
output=zeros(0,2);state=initial;k=1;
while k<=size(candidate,1)
    last=k;while last<size(candidate,1)&&candidate(last+1,1)==candidate(k,1),last=last+1;end
    if candidate(last,1)<=stop&&candidate(last,2)~=state
        output(end+1,:)=candidate(last,:);state=candidate(last,2); %#ok<AGROW>
    end
    k=last+1;
end
end
