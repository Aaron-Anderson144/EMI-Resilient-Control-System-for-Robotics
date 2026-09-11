function tests=TestFourwayReceiver
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'03_MATLAB','functions'));
t.TestData.root=root;
fourway_build_engine;
end
function testPinnedReplayAndClosures(t)
r=fourway_replay;
verifyEqual(t,r.original_points,40001);
verifyEqual(t,r.sha256,'1ecdd83ee4f4846b70e2d40ba04f4b3188e737c94f08300a5bbbfcc36acb9cd5');
for closure=[100e-9 45e-6]
 s=fourway_receiver_init(30,5,100,0,true,closure);
 verifyEqual(t,s.config.volts(1),s.config.volts(end));
 verifyEqual(t,s.config.knots(end),50e-6);
 verifyEqual(t,s.config.knots(1:40001),r.time_s);
 verifyEqual(t,s.config.volts(1:40001),r.switch_V);
 verifySize(t,s.config.origins,[200 1]);
 verifyEqual(t,s.source.pulse_origins_s([1 101]),[.25;1.7]-2.019e-6,'AbsTol',1e-16);
end
end
function testIndependentKCL(t)
rng(773);
for cp=[0 30 300]
 for cd=[100 1000]
  s=fourway_receiver_init(cp,5,cd,0,false);p=s.parameters;c=s.circuit;
  for k=1:20
   x=[2.5+randn(2,1);randn*.1];u=[0;1+3*rand;1+3*rand;1e9*randn];dx=c.A*x+c.B*u;
   gp=1/p.driver.Rp_Ohm;gn=1/p.driver.Rn_Ohm;
   g=(u(1)+gp*x(1)+gn*x(2)-gp*u(2)-gn*u(3)-x(3))/(gp+gn);
   capP=(p.receiver.Cp_F+p.coupling.Cp_F+p.receiver.Cdiff_F)*dx(1)-p.receiver.Cdiff_F*dx(2);
   capN=(p.receiver.Cn_F+p.coupling.Cn_F+p.receiver.Cdiff_F)*dx(2)-p.receiver.Cdiff_F*dx(1);
   rhsP=(g+u(2)-x(1))/p.driver.Rp_Ohm-(x(1)-x(2))/p.receiver.Rdiff_Ohm-x(1)/p.receiver.RpBias_Ohm+p.coupling.Cp_F*u(4);
   rhsN=(g+u(3)-x(2))/p.driver.Rn_Ohm-(x(2)-x(1))/p.receiver.Rdiff_Ohm-x(2)/p.receiver.RnBias_Ohm+p.coupling.Cn_F*u(4);
   verifyLessThan(t,max(abs([capP-rhsP;capN-rhsN;p.ground.L_H*dx(3)-g+p.ground.R_Ohm*x(3)])),1e-12);
  end
 end
end
end
function testIndependentAugmentedExponential(t)
for cp=[0 30 300]
 for cd=[100 1000]
  s=fourway_receiver_init(cp,5,cd,0,false);s.config.origins=0;
  s.config.knots=[0;100e-9;50e-6];s.config.slopes=[2e8;0];
  x0=s.state(2:4);u0=[0;1.5;3.5;2e8];u1=[0;2e7;-2e7;0];
  aug=[s.circuit.A,s.circuit.B*u0,s.circuit.B*u1;zeros(1,5);zeros(1,3),1,0];
  for dt=[.1 1 10 50 100]*1e-9
   exact=expm(aug*dt)*[x0;1;0];
   [st,~,~,~]=fourway_exact(s.config,s.state,dt,[0 1 0]);
   verifyEqual(t,st(2:4),exact(1:3),'AbsTol',1e-12);
  end
 end
end
end
function testCleanBothDirectionsAndZeroCoupling(t)
for cd=[100 1000]
 for sign=[-1 1]
  s=fourway_receiver_init(0,0,cd,0,false);
  q=sign*(1:12)';ab=gray(q);tr=[(1:12)'*10e-6 ab];
  [s,p]=fourway_receiver_advance(s,130e-6,tr);r=fourway_receiver_export(s);
  verifyEqual(t,p.count,12*sign);verifyEqual(t,p.ideal_count,12*sign);
  verifyEqual(t,r.decoder(:,4),repmat(sign,12,1));
  verifyFalse(t,p.domain_failed);
  verifyLessThan(t,max(r.decoder(:,1)-tr(:,1)),1e-6);
 end
end
end
function testReversalAndPersistentState(t)
s=fourway_receiver_init(30,5,100,0,true);s.config.origins=[0;50e-6;1e-3];
q=[1;2;1;0;-1;-2;-1;0];tr=[(1:8)'*10e-6 gray(q)];
[whole,pw]=fourway_receiver_advance(s,1.1e-3,tr);
split=s;edges=unique([0;2.019e-6;5e-6;5.1e-6;50e-6;80e-6;1e-3;1.005e-3;1.0051e-3;1.05e-3;1.1e-3]);
used=false(size(tr,1),1);
for k=1:numel(edges)
 mask=tr(:,1)<=edges(k)&~used;[split,ps]=fourway_receiver_advance(split,edges(k),tr(mask,:));used=used|mask;
end
verifyEqual(t,ps.count,pw.count);verifyEqual(t,ps.ideal_count,0);
verifyEqual(t,split.state(2:4),whole.state(2:4),'AbsTol',1e-12);
a=fourway_receiver_export(whole);b=fourway_receiver_export(split);
verifyEqual(t,b.decoder(:,2:8),a.decoder(:,2:8));verifyEqual(t,b.decoder(:,1),a.decoder(:,1),'AbsTol',1e-12);
end
function testGlitchCancelsAndPersistentOffset(t)
s=glitch();[s,p]=fourway_receiver_advance(s,1e-6,[]);r=fourway_receiver_export(s);
verifyGreaterThanOrEqual(t,height(r.decoder),2);verifyEqual(t,p.count,0);
verifyTrue(t,any(r.decoder(:,4)==1)&&any(r.decoder(:,4)==-1));
between=mean(r.decoder(1:2,1));s=glitch();[s,p]=fourway_receiver_advance(s,1e-6,[between 0 1]);
verifyNotEqual(t,p.count,p.ideal_count);
end
function testJointIllegalAndCoincidentSampling(t)
s=fourway_receiver_init(30,5,100,0,false);[r,~]=fourway_receiver_advance(s,1e-6,[0 1 0]);e=fourway_receiver_export(r);when=e.decoder(1,1);
[s,p]=fourway_receiver_advance(s,when,[0 1 0;when 1 1]);r=fourway_receiver_export(s);
verifyEqual(t,p.count,0);verifyEqual(t,r.decoder(end,2:3),[1 1]);verifyEqual(t,r.decoder(end,6),1);
[s,p]=fourway_receiver_advance(s,2e-6,[1e-6 0 1]);verifyEqual(t,p.count,1);
end
function testShadowOwnTrajectory(t)
s=glitch();[probe,~]=fourway_receiver_advance(s,1e-6,[]);pr=fourway_receiver_export(probe);
between=mean(pr.decoder(1:2,1));[s,~]=fourway_receiver_advance(s,1e-6,[between 0 1]);r=fourway_receiver_export(s);
shadow=fourway_receiver_init(300,5,100,0,false);
[shadow,p]=fourway_receiver_advance(shadow,1e-6,r.intended);
verifyEqual(t,p.count,p.ideal_count);verifyEqual(t,p.count,-1);
verifyNotEqual(t,s.state(11),shadow.state(11));
end
function testThresholdAtPacketBoundaryHasSingleRecord(t)
s=fourway_receiver_init(30,5,100,0,false);[whole,~]=fourway_receiver_advance(s,1e-6,[0 1 0]);w=fourway_receiver_export(whole);
when=w.decoder(1,1);[s,p]=fourway_receiver_advance(s,when,[0 1 0]);verifyEqual(t,p.count,1);
[s,p]=fourway_receiver_advance(s,1e-6,[]);r=fourway_receiver_export(s);
verifyEqual(t,p.count,1);verifyEqual(t,r.events(:,2:4),w.events(:,2:4));
verifyEqual(t,r.events(:,1),w.events(:,1),'AbsTol',1e-12);
end
function testCrossPacketJointAmbiguityIsRejected(t)
s=fourway_receiver_init(30,5,100,0,false);[whole,~]=fourway_receiver_advance(s,1e-6,[0 1 0]);w=fourway_receiver_export(whole);when=w.decoder(1,1);
[s,~]=fourway_receiver_advance(s,when,[0 1 0]);
verifyError(t,@()fourway_receiver_advance(s,1e-6,[when+.5e-12 1 1]),'FOURWAY:CrossPacketJointAmbiguity');
end
function testDomainFailureHoldsReceiverAndRetainsEvents(t)
s=fourway_receiver_init(300,5,100,0,true);s.config.origins=0;
[s,p]=fourway_receiver_advance(s,50e-6,[2.019e-6 1 0]);r=fourway_receiver_export(s);
verifyTrue(t,p.domain_failed);verifyGreaterThan(t,p.max_abs_common_mode_V,7);
domainEvents=r.events(r.events(:,2)==2,:);verifyNotEmpty(t,domainEvents);
first=domainEvents(1,1);held=r.events(r.events(:,1)>=first,8);
verifyEqual(t,held,repmat(held(1),size(held)));
end
function s=glitch()
s=fourway_receiver_init(300,5,100,0,false);s.config.origins=0;
s.config.knots=[0;100e-9;200e-9;300e-9;1e-6];s.config.slopes=[2.4e8;0;-2.4e8;0];
end
function ab=gray(q)
states=[0 0;1 0;1 1;0 1];ab=states(mod(q,4)+1,:);
end
