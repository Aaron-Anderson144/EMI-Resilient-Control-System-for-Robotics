function d=receiver_v2_decode(outputA,intended,initialAB)
% Gray decoder, grouped coincident A/B events, events precede same-time sample.
if nargin<3,initialAB=[0 0];end
changeB=[intended(1,3)~=initialAB(2);diff(intended(:,3))~=0];
b=intended(changeB,[1 3]);
raw=unique([outputA(:,1);b(:,1)]);times=zeros(0,1);starts=times;cursor=1;
while cursor<=numel(raw)
    first=raw(cursor);last=find(raw<=first+1e-12,1,'last');
    starts(end+1,1)=first;times(end+1,1)=raw(last);cursor=last+1; %#ok<AGROW>
end
state=initialAB;count=0;invalid=0;
rows=zeros(numel(times),6);
gray=[0 0;1 0;1 1;0 1];
for j=1:numel(times)
    next=state;ia=find(outputA(:,1)>=starts(j)&outputA(:,1)<=times(j),1,'last');
    ib=find(b(:,1)>=starts(j)&b(:,1)<=times(j),1,'last');
    if ~isempty(ia),next(1)=outputA(ia,2);end
    if ~isempty(ib),next(2)=b(ib,2);end
    old=find(all(gray==state,2));now=find(all(gray==next,2));step=mod(now-old,4);
    inc=0;bad=step==2;if step==1,inc=1;elseif step==3,inc=-1;end
    count=count+inc;invalid=invalid+bad;state=next;
    rows(j,:)=[times(j),state,inc,count,bad];
end
d=struct('events',rows,'finalCount',count,'invalidTransitions',invalid);
end
