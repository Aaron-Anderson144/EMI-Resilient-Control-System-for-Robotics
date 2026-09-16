function s=receiver_v2_segments(p,c,f,exposed)
% Exact affine input segments, persistent state across every source/driver knot.
tr=f.transitions;initialA=f.initialAB(1);changeA=[tr(1,2)~=initialA;diff(tr(:,2))~=0];ta=tr(changeA,1);aa=tr(changeA,2);
edge=p.network.driverTransition_s;
td=reshape([ta,ta+edge].',[],1);levels=reshape([1-aa,aa].',[],1);
td=[0;td;f.stop_s];levels=[initialA;levels;levels(end)];
t=unique([f.sourceT;td]);h=diff(t);
driver=interp1(td,2*levels-1,t,'linear');
va=double(exposed)*interp1(f.sourceT,f.sourceV,t,'linear');
cm=p.network.driverCommonMode_V;dm=p.network.driverDifferentialMagnitude_V/2;
u0=[zeros(numel(h),1),cm+dm*driver(1:end-1),cm-dm*driver(1:end-1),diff(va)./h];
dlevel=dm*diff(driver)./h;
u1=[zeros(numel(h),1),dlevel,-dlevel,zeros(numel(h),1)];
f0=u0*c.B.';f1=u1*c.B.';
c1=-(c.A\f1.').';c0=(c.A\(c1-f0).').';
sgn=2*initialA-1;x=-(c.A\(c.B*[0;cm+sgn*dm;cm-sgn*dm;0]));initial=x;
k=zeros(numel(h),3);xleft=k;
for j=1:numel(h)
    xleft(j,:)=x.';k(j,:)=(c.W*(x-c0(j,:).')).';
    x=c0(j,:).'+c1(j,:).'*h(j)+real(c.V*(k(j,:).'.*exp(c.lambda*h(j))));
end
s=struct('t',t,'h',h,'u0',u0,'u1',u1,'c0',c0,'c1',c1, ...
    'k',k,'initial',initial,'final',x,'leftStates',xleft,'circuit',c,'fixture',f);
end
