function tests=TestFourwayV2Receiver
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'functions'));
project=fileparts(fileparts(root));addpath(fullfile(project,'06_Circuit_Simulations','RECEIVER_V2','functions'));
t.TestData.parameters=receiver_v2_parameters();fourway_v2_build_engine();
end
function testIndependentNodalEquationsAndModalStep(t)
rng(745);p=t.TestData.parameters;n=p.network;
for cp=[0 40 240]
 for cd=[100 1000]
  s=fourway_v2_receiver_init(cp,7,cd,0,false,fourway_v2_variant(1));c=s.circuit;
  x=randn(3,1);u=[0;1.5;3.5;2e8];du=[0;2e7;-2e7;0];dx=c.A*x+c.B*u;
  g=((x(1)-u(2))/47+(x(2)-u(3))/53-x(3))/(1/47+1/53);
  rhs=[(g+u(2)-x(1))/47-(x(1)-x(2))/120-x(1)/1e4+cp*1e-12*u(4); ...
      (g+u(3)-x(2))/53-(x(2)-x(1))/120-x(2)/2e4+7e-12*u(4)];
  mass=[50e-12+cp*1e-12+cd*1e-12,-cd*1e-12;-cd*1e-12,70e-12+7e-12+cd*1e-12];
  verifyEqual(t,mass*dx(1:2),rhs,'AbsTol',1e-11);
  verifyEqual(t,n.returnL_H*dx(3),g-n.returnR_Ohm*x(3),'AbsTol',1e-11);
  s.state(2:4)=x;s.state(29:34)=[x(1);x(1);x(2);x(2);x(1)-x(2);x(1)-x(2)];
  s.config.knots=[0;100e-9;50e-6];s.config.slopes=[2e8;0];s.config.origins=0;
  aug=[c.A,c.B*u,c.B*du;zeros(1,5);zeros(1,3),1,0];
  for dt=[.1 1 10 50]*1e-9
   exact=expm(aug*dt)*[x;1;0];
   [state,~,~,~]=fourway_v2_exact(s.config,s.state,dt,[0 1 0]);
   verifyEqual(t,state(2:4),exact(1:3),'AbsTol',2e-10);
  end
 end
end
end
function testIndependentWaveformAndAllSixteenHypotheses(t)
p=t.TestData.parameters;
for cd=[100 1000]
 f=receiver_v2_fixture(p,struct(),'pulse',1,40e-9);c=receiver_v2_network(p,cd,30);
 segments=receiver_v2_segments(p,c,f,true);a=receiver_v2_analyze(p,segments,.5e-9);
 for variant=fourway_v2_variant()
  s=fourway_v2_receiver_init(30,5,cd,0,true,variant);s=custom_source(s,f.sourceT,f.sourceV);
  q=linspace(0,f.stop_s,701)';
  [state,~,decoder,~,actual,logic]=fourway_v2_exact(s.config,s.state,f.stop_s,f.transitions,q);
  ii=discretize(q,segments.t);ii(end)=numel(segments.h);tau=q-segments.t(ii);reference=zeros(numel(q),3);
  for k=1:3,row=zeros(1,3);row(k)=1;reference(:,k)=receiver_v2_signal(segments,ii,tau,row);end
  verifyEqual(t,actual(:,2:4),reference,'AbsTol',2e-10);
  th=struct('rise_V',variant.rise_V,'fall_V',variant.fall_V);
  b=receiver_v2_behavior(segments,a,th,variant.latencyRise_s,char(variant.pulseLaw));
  compare_events(t,logic(logic(:,2)==1,[1 3]),b.inputEvents,2e-13);
  compare_events(t,logic(logic(:,2)==2,[1 3]),b.outputEvents,2e-13);
  compare_events(t,decoder(:,1:6),b.decoderEvents,2e-13);
  verifyEqual(t,state(11),b.finalCount);verifyFalse(t,logical(state(14)));
 end
end
end
function testWholeVsSplitPreservesPendingAndCircuitState(t)
for law=[1 2]
 s=fourway_v2_receiver_init(0,0,1000,0,false,fourway_v2_variant(law));
 tr=[1e-6 1 0;2e-6 1 1;3e-6 0 1;4e-6 0 0];
 [whole,~,~,~,~,logic]=fourway_v2_exact(s.config,s.state,5e-6,tr);
 inputTime=logic(find(logic(:,2)==1,1),1);cut=inputTime+10e-9;
 [first,~,d1,~,~,l1]=fourway_v2_exact(s.config,s.state,cut,tr(tr(:,1)<=cut,:));
 verifyGreaterThan(t,numel(first),80);verifyEqual(t,first(11),0);verifyEqual(t,first(21),1);
 [split,~,d2,~,~,l2]=fourway_v2_exact(s.config,first,5e-6,tr(tr(:,1)>cut,:));
 verifyEqual(t,split(2:4),whole(2:4),'AbsTol',2e-12);verifyEqual(t,split(11),whole(11));
 joined=[l1;l2];compare_events(t,joined(:,1:3),logic(:,1:3),2e-13);
 verifyEqual(t,joined(:,4),logic(:,4),'AbsTol',2e-13);
 verifyEqual(t,[d1;d2],fourway_v2_decode_reference(tr,s.variant), 'AbsTol',1e-6);
end
end
function testPendingOutputAtSampleAndJointAmbiguity(t)
s=fourway_v2_receiver_init(0,0,100,0,false,fourway_v2_variant(1));
% A queued output is an independently declared persistent digital fixture.
s.state=[s.state;1e-6;1];s.state(21)=1;s.state(73)=1;
[st,~,dec,~]=fourway_v2_exact(s.config,s.state,1e-6,zeros(0,3));
verifyEqual(t,st(11),1);verifyEqual(t,dec(1,1),1e-6);verifyEqual(t,numel(st),80);
verifyError(t,@()call_exact(s.config,st,2e-6,[1e-6+.5e-12,0,1]),'FOURWAY_V2:CrossPacketJointAmbiguity');
[st2,~,dec2,~]=fourway_v2_exact(s.config,s.state,2e-6,[1e-6+.5e-12,0,1]);
verifyEqual(t,st2(11),0);verifyEqual(t,dec2(1,6),1);verifyEqual(t,dec2(1,1),1e-6+.5e-12);
end
function testInertialCancellationAcrossCalls(t)
s=fourway_v2_receiver_init(0,0,100,0,false,fourway_v2_variant(2));
% Exact affine differential ramp: rises across -.1V then falls across -.13V.
s=analytic_ramp(s,-.2,1e8,20e-9);s.config.latency_rise_s=25e-9;s.config.latency_fall_s=25e-9;
[st,~,~,~,~,logic]=fourway_v2_exact(s.config,s.state,2e-9,zeros(0,3));
verifyEqual(t,st(21),1);verifyEqual(t,st(10),0);verifyGreaterThan(t,numel(st),80);
% Switch to negative affine slew using a new independent exact coefficient.
fall=analytic_ramp(s,st(2)-st(3),-1e8,100e-9);fall.state=st;fall.state(6)=-1e8/2;
[out,~,~,~,~,logic2]=fourway_v2_exact(fall.config,fall.state,40e-9,zeros(0,3));
verifyEqual(t,out(10),0);verifyEmpty(t,[logic(logic(:,2)==2,:);logic2(logic2(:,2)==2,:)]);
end
function testExactPendingEqualityTransportCollisionAndOvertaking(t)
s=fourway_v2_receiver_init(0,0,100,0,false,fourway_v2_variant(2));
s=analytic_ramp(s,-.12,-2e6,1e-6);s.state(21)=1;
[~,~,~,~,~,probe]=fourway_v2_exact(s.config,s.state,10e-9,zeros(0,3));
fall=probe(find(probe(:,2)==1,1),1);verifyGreaterThan(t,fall,0);
% A request persists through its due time exactly: output comes first.
s.state=[s.state;fall;1];s.state(73)=1;
[st,~,~,~,~,logic]=fourway_v2_exact(s.config,s.state,10e-9,zeros(0,3));
output=logic(logic(:,2)==2,:);verifyEqual(t,output(:,[1 3]),[fall 1]);verifyEqual(t,st(10),1);
[st,~,~,~,~,logic]=fourway_v2_exact(s.config,st,fall+25e-9,zeros(0,3));
verifyEqual(t,st(10),0);verifyEqual(t,logic(logic(:,2)==2,[1 3]),[fall+25e-9 0]);
% Under transport, coincident opposite outputs coalesce in causal input order.
s.config.pulse_law=0;s.state(81)=fall+25e-9;s.state(69)=s.state(81);
[st,~,~,~,~,logic]=fourway_v2_exact(s.config,s.state,40e-9,zeros(0,3));
verifyEqual(t,st(10),0);verifyEmpty(t,logic(logic(:,2)==2,:));
s.state(81)=fall+40e-9;s.state(69)=s.state(81);
verifyError(t,@()call_exact(s.config,s.state,40e-9,zeros(0,3)),'FOURWAY_V2:TransportOvertaking');
end
function testSignedDomainsStressAndContinuousThreeRoots(t)
s=fourway_v2_receiver_init(0,0,100,0,false,fourway_v2_variant(1));
for x=[16 8 -19;12 -8 0;0 0 0]
 a=constant_state(s,x);[st,~,~,~]=fourway_v2_exact(a.config,a.state,1e-9,zeros(0,3));
 verifyTrue(t,logical(st(14)));verifyEqual(t,st(25),1e-9,'AbsTol',1e-20);verifyEqual(t,st(24),0);
 verifyEqual(t,logical(st(22)),any(abs([x(1:2);x(1)-x(2)])>18));
end
% Independent vp(t)=15+scale*prod(exp(-t/tau)-exp(-[.2,.5,.8])).
scale=1e-5;tau=1e-9;polycoef=poly(exp(-[.2 .5 .8]));
a=s;V=[1 1 1;0 1 0;0 0 1];lambda=-(1:3)'/tau;
c0=[15+scale*polycoef(4);0;0];z=scale*[polycoef(3);polycoef(2);polycoef(1)];
a.config.V=[V zeros(3)];a.config.W=[inv(V) zeros(3)];a.config.lambda=[lambda zeros(3,1)];
a.config.forcing=[-lambda.*c0,zeros(3,5)];a.state(2:4)=V*(c0+z);
a.state(5:7)=0;a.config.origins=zeros(0,1);
[st,events,~,~]=fourway_v2_exact(a.config,a.state,tau,zeros(0,3));
roots=events(events(:,2)==2&events(:,3)==15,1);
verifyEqual(t,numel(roots),3);verifyEqual(t,roots,[.2;.5;.8]*tau,'AbsTol',2e-12);
verifyEqual(t,st(26),.5*tau,'AbsTol',2e-12);
verifyLessThanOrEqual(t,st(29),min([15+scale*polycoef(4),15+scale*polyval(polycoef,1)]));
end
function testSubresolutionGrazingRejects(t)
s=fourway_v2_receiver_init(0,0,100,0,false,fourway_v2_variant(1));
scale=1e-5;tau=1e-9;u=exp(-.5);V=[1 1 1;0 1 0;0 0 1];lambda=-(1:3)'/tau;
c0=[15-scale*u*u;0;0];z=scale*[2*u;-1;0];
s.config.V=[V zeros(3)];s.config.W=[inv(V) zeros(3)];s.config.lambda=[lambda zeros(3,1)];
s.config.forcing=[-lambda.*c0,zeros(3,5)];s.state(2:4)=V*(c0+z);s.state(5:7)=0;s.config.origins=zeros(0,1);
verifyError(t,@()call_exact(s.config,s.state,tau,zeros(0,3)),'FOURWAY_V2:UnresolvedGrazing');
end
function testCleanInitialHighReverseAndZeroCoupling(t)
gray=[0 0;1 0;1 1;0 1];
for cd=[100 1000]
 for initial=[0 1]
  for direction=[-1 1]
   s=fourway_v2_receiver_init(0,0,cd,0,true,fourway_v2_variant(16),100e-9,initial);s.config.origins=0;
   initialIndex=initial;ab=gray(mod(initialIndex+direction*(1:8),4)+1,:);tr=[(1:8)'*1e-6,ab];
   [s,p]=fourway_v2_receiver_advance(s,10e-6,tr);r=fourway_v2_receiver_export(s);
   verifyEqual(t,p.count,8*direction);verifyEqual(t,p.ideal_count,8*direction);verifyFalse(t,p.domain_failed);
   verifyEqual(t,r.decoder(:,4),repmat(direction,8,1));
  end
 end
end
end
function compare_events(t,a,b,tol)
verifyEqual(t,size(a),size(b));if ~isequal(size(a),size(b))||isempty(a),return,end
verifyEqual(t,a(:,2:end),b(:,2:end));verifyEqual(t,a(:,1),b(:,1),'AbsTol',tol);
end
function s=custom_source(s,knots,volts)
s.config.knots=knots;s.config.volts=volts;s.config.slopes=diff(volts)./diff(knots);s.config.origins=0;
s.config.native_end_s=knots(end);s.config.return_end_s=knots(end);
end
function call_exact(varargin)
[~,~,~,~]=fourway_v2_exact(varargin{:});
end
function expected=fourway_v2_decode_reference(tr,variant)
% Analytical Gray counts and directional source ramps for cleanfixture.
expected=[tr(:,1),tr(:,2:3),ones(size(tr,1),1),(1:size(tr,1))',zeros(size(tr,1),1),[0;tr(1:end-1,2)],[0;tr(1:end-1,3)]];
end
function s=analytic_ramp(s,vd0,slew,stop)
% x=[vp,vn,ir] with identity modal basis and exact affine forcing.
s.config.lambda=[-ones(3,1),zeros(3,1)];s.config.V=[eye(3),zeros(3)];s.config.W=s.config.V;
s.config.forcing=[zeros(3),zeros(3)];s.config.forcing(1,1)=slew/2+vd0/2;s.config.forcing(2,1)=-slew/2-vd0/2;
s.config.forcing(1,2)=1;s.config.forcing(2,2)=-1;
s.state(2:4)=[vd0/2;-vd0/2;0];s.state(5)=0;s.state(6)=slew/2;s.state(7)=stop;
s.config.origins=zeros(0,1);
end
function s=constant_state(s,x)
s.config.lambda=[-ones(3,1),zeros(3,1)];s.config.V=[eye(3) zeros(3)];s.config.W=s.config.V;
s.config.forcing=[x,zeros(3,5)];s.state(2:4)=x;s.state(5:7)=0;s.config.origins=zeros(0,1);
end
