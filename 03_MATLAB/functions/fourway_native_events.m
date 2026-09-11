function [events,decoder]=fourway_native_events(native,initialA)
%FOURWAY_NATIVE_EVENTS Independent Schmitt/Gray decoding of native trace.
% Threshold times use piecewise-linear interpolation between actual retained
% solver points. B remains zero in the frozen electrical acceptance fixtures.
% Both entry and exit threshold crossings are retained; only +0.2 upward and
% -0.2 downward crossings change A. A model-domain breach latches hold-A.
events=zeros(0,8);x=[native.positive_V,native.negative_V,native.returnCurrent_A];
assert(all(isfinite(x),'all')&&all(isfinite(native.time_s))&&all(diff(native.time_s)>0), ...
 'FOURWAY:InvalidNativeTrace','Native trace must be finite with increasing times.');
assert(isscalar(initialA)&&any(initialA==[0 1]),'FOURWAY:InvalidNativeBit','Initial A must be 0 or 1.');
for kind=1:2
 if kind==1,value=native.differential_V;thresholds=[-.2,.2];else,value=native.commonMode_V;thresholds=[-7,7];end
 for threshold=thresholds
  z=value-threshold;
  for direction=[-1 1]
   if direction==1,idx=find(z(1:end-1)<0&z(2:end)>=0);else,idx=find(z(1:end-1)>0&z(2:end)<=0);end
   fraction=-z(idx)./(z(idx+1)-z(idx));time=native.time_s(idx)+fraction.*(native.time_s(idx+1)-native.time_s(idx));
   state=x(idx,:)+fraction.*(x(idx+1,:)-x(idx,:));
   events=[events;time,repmat([kind,threshold,direction],numel(idx),1),state,zeros(numel(idx),1)]; %#ok<AGROW>
  end
 end
end
events=sortrows(events,[1 2 3 4]);a=initialA;count=0;
domainFailed=abs(native.commonMode_V(1))>7;decoder=zeros(0,8);
for k=1:size(events,1)
 e=events(k,:);
 if e(2)==2&&((e(3)>0&&e(4)>0)||(e(3)<0&&e(4)<0)),domainFailed=true;end
 if ~domainFailed&&e(2)==1
  newA=a;if e(3)>0&&e(4)>0,newA=1;elseif e(3)<0&&e(4)<0,newA=0;end
  if newA~=a
   increment=2*newA-1;count=count+increment;
   decoder(end+1,:)=[e(1),newA,0,increment,count,0,a,0]; %#ok<AGROW>
   a=newA;
  end
 end
 events(k,8)=a;
end
end
