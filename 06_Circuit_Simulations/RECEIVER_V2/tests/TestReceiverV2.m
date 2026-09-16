function tests=TestReceiverV2
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'functions'));
t.TestData.p=receiver_v2_parameters();
end
function testIndependentNodalEquations(t)
p=t.TestData.p;n=p.network;rng(591);
for cd=[100 1000]
 for cp=[30 300]
  c=receiver_v2_network(p,cd,cp);
  for j=1:12
   x=randn(3,1);u=[randn;randn(2,1);randn*1e9];dx=c.A*x+c.B*u;
   g=(u(1)+(x(1)-u(2))/n.driverRp_Ohm+(x(2)-u(3))/n.driverRn_Ohm-x(3)) ...
       /(1/n.driverRp_Ohm+1/n.driverRn_Ohm);
   ip=(g+u(2)-x(1))/n.driverRp_Ohm;in=(g+u(3)-x(2))/n.driverRn_Ohm;
   kclP=(n.pinCp_F+cp*1e-12+cd*1e-12)*dx(1)-cd*1e-12*dx(2) ...
       -ip+(x(1)-x(2))/n.termination_Ohm+x(1)/n.biasRp_Ohm-cp*1e-12*u(4);
   kclN=(n.pinCn_F+n.Ccn_pF*1e-12+cd*1e-12)*dx(2)-cd*1e-12*dx(1) ...
       -in+(x(2)-x(1))/n.termination_Ohm+x(2)/n.biasRn_Ohm-n.Ccn_pF*1e-12*u(4);
   verifyLessThan(t,max(abs([kclP;kclN;n.returnL_H*dx(3)-g+n.returnR_Ohm*x(3)])),1e-11);
  end
 end
end
end
function testAffinePropagationAgainstAugmentedExponential(t)
p=t.TestData.p;c=receiver_v2_network(p,1000,300);
f=receiver_v2_fixture(p,struct(),'pulse',1,40e-9);s=receiver_v2_segments(p,c,f,true);
for j=[1 3 6 10 15]
 if j>numel(s.h),continue,end
 dt=s.h(j)*.63;
 aug=[c.A,c.B*s.u0(j,:).',c.B*s.u1(j,:).';zeros(1,5);zeros(1,3),1,0];
 independent=expm(aug*dt)*[s.leftStates(j,:).';1;0];
 actual=s.c0(j,:).'+s.c1(j,:).'*dt+real(c.V*(s.k(j,:).'.*exp(c.lambda*dt)));
 verifyEqual(t,actual,independent(1:3),'AbsTol',1e-10);
end
end
function testPulseHypothesesAndBoundary(t)
u=[0 1;10e-9 0];
verifyEqual(t,receiver_v2_logic(u,25e-9,25e-9,'transport',0,1e-6),[25e-9 1;35e-9 0],'AbsTol',1e-20);
verifyEmpty(t,receiver_v2_logic(u,25e-9,25e-9,'inertial',0,1e-6));
u=[0 1;25e-9 0];
verifyEqual(t,receiver_v2_logic(u,25e-9,25e-9,'inertial',0,1e-6),[25e-9 1;50e-9 0],'AbsTol',1e-20);
u=[0 1;100e-9 0];
verifyEqual(t,receiver_v2_logic(u,25e-9,28.5e-9,'transport',0,1e-6),[25e-9 1;128.5e-9 0],'AbsTol',1e-20);
verifyEmpty(t,receiver_v2_logic([0 1;15e-9 0],40e-9,25e-9,'transport',0,1e-6));
verifyError(t,@()receiver_v2_logic([0 1;10e-9 0],40e-9,25e-9,'transport',0,1e-6),'RECEIVER_V2:TransportOvertaking');
end
function testGrayCoincidenceAndCount(t)
tr=[1 1 0;2 1 1;3 0 1;4 0 0];
d=receiver_v2_decode([1 1;3 0],tr);verifyEqual(t,d.finalCount,4);verifyEqual(t,d.invalidTransitions,0);
d=receiver_v2_decode([2 1;3 0],tr);verifyEqual(t,d.invalidTransitions,1);
tr=[1e-6 1 0;2e-6 1 1;3e-6 0 1;4e-6 0 0];
d=receiver_v2_decode([2e-6-.5e-12 1;3e-6 0],tr);verifyEqual(t,d.invalidTransitions,1);
end
function testCleanBothCapacitancesAndSourcePolarities(t)
p=t.TestData.p;
for cd=[100 1000]
 for polarity=[-1 1]
  f=receiver_v2_fixture(p,struct(),'pulse',polarity,40e-9);c=receiver_v2_network(p,cd,30);
  s=receiver_v2_segments(p,c,f,false);a=receiver_v2_analyze(p,s,1e-9);
  b=receiver_v2_behavior(s,a,p.receiver.thresholdPairs(1),25e-9,'transport');
  verifyEqual(t,b.finalCountError,0);verifyEqual(t,b.outputEdges,4);
  verifyEqual(t,a.domainStatus,'inside');verifyFalse(t,a.unresolved);
  verifyLessThan(t,b.maxTransitionDelay_s,1e-6);
 end
end
end
function testInitiallyHighAndReverseClean(t)
p=t.TestData.p;c=receiver_v2_network(p,1000,30);
for direction=[-1 1]
 f=receiver_v2_fixture(p,struct(),'pulse',1,40e-9);f.initialAB=[1 0];
 gray=[0 0;1 0;1 1;0 1];indices=mod(1+direction*(1:8),4)+1;
 f.transitions(:,2:3)=gray(indices,:);
 s=receiver_v2_segments(p,c,f,false);a=receiver_v2_analyze(p,s,1e-9);
 b=receiver_v2_behavior(s,a,p.receiver.thresholdPairs(1),25e-9,'transport');
 verifyEqual(t,b.finalCount,8*direction);verifyEqual(t,b.finalCountError,0);
 verifyEqual(t,b.invalidTransitions,0);
end
end
function testIndependentMultipleRootsAndDomainOccupation(t)
p=t.TestData.p;scale=1e-5;tau=1e-9;roots=[.2 .5 .8];coeff=poly(exp(-roots));
c=receiver_v2_network(p,100,30);c.lambda=-(1:3)'/tau;c.V=[1 1 1;0 0 0;0 0 0];
% Synthetic analytic modal signal, independent of circuit equation assembly.
s=struct('t',[0;tau],'h',tau,'c0',[15+scale*coeff(4),0,0], ...
 'c1',[0 0 0],'k',scale*[coeff(3),coeff(2),coeff(1)],'circuit',c, ...
 'u0',zeros(1,4),'u1',zeros(1,4),'fixture',struct('transitions',zeros(0,3)));
a=receiver_v2_analyze(p,s,tau);
ev=a.events(a.events(:,2)==1&a.events(:,3)==15,1);
verifyEqual(t,numel(ev),3);verifyEqual(t,ev,roots'*tau,'AbsTol',2e-12);
verifyFalse(t,a.unresolved);verifyEqual(t,a.domainStatus,'outside');
verifyEqual(t,a.timeOutsideDomain_s,.5*tau,'AbsTol',2e-12);
end
function testSignedPinPredicateAndDifferentialBoundary(t)
% One pin16 V with vcm14 and vd4 violates even though |vcm|<15.
p=t.TestData.p;c=receiver_v2_network(p,100,30);
s=struct('t',[0;1e-9],'h',1e-9,'c0',[16 12 0],'c1',[0 0 0], ...
 'k',zeros(1,3),'circuit',c,'u0',zeros(1,4),'u1',zeros(1,4), ...
 'fixture',struct('transitions',zeros(0,3)));
a=receiver_v2_analyze(p,s,1e-9);verifyEqual(t,a.domainStatus,'outside');
verifyEqual(t,a.timeOutsidePin_s,1e-9,'AbsTol',1e-20);verifyEqual(t,a.firstViolation_s,0);
s.c0=[8 -8 0];a=receiver_v2_analyze(p,s,1e-9);
verifyEqual(t,a.domainStatus,'outside');verifyEqual(t,a.timeOutsidePin_s,0);verifyEqual(t,a.timeOutsideDifferential_s,1e-9,'AbsTol',1e-20);
s.c0=[-15 0 0];a=receiver_v2_analyze(p,s,1e-9);verifyEqual(t,a.domainStatus,'inside');
end
function testGrazingDomainRemainsUnresolved(t)
p=t.TestData.p;tau=1e-9;scale=1e-5;z=exp(-.5);
c=receiver_v2_network(p,100,30);c.lambda=-(1:3)'/tau;c.V=[1 1 1;0 0 0;0 0 0];
% vp(t)=15-scale*(exp(-t/tau)-exp(-.5))^2 touches the bound.
s=struct('t',[0;tau],'h',tau,'c0',[15-scale*z^2,0,0], ...
 'c1',[0 0 0],'k',scale*[2*z,-1,0],'circuit',c, ...
 'u0',zeros(1,4),'u1',zeros(1,4),'fixture',struct('transitions',zeros(0,3)));
a=receiver_v2_analyze(p,s,tau);verifyTrue(t,a.unresolved);
verifyNotEqual(t,a.domainStatus,'inside');
end
