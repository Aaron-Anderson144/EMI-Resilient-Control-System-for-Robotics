function report=fourway_v2_native_kcl(p,circuit)
% Branch-by-branch KCL and return constitutive law, independent of assembly.
old=rng;cleanup=onCleanup(@()rng(old));rng(97231); %#ok<NASGU>
peak=zeros(1,3);n=80;
for k=1:n
    x=[2.5+4*randn(2,1);.2*randn];u=[0;1+3*rand;1+3*rand;1e9*randn];
    dx=circuit.A*x+circuit.B*u;gp=1/p.driver.Rp_Ohm;gn=1/p.driver.Rn_Ohm;
    g=(u(1)+gp*x(1)+gn*x(2)-gp*u(2)-gn*u(3)-x(3))/(gp+gn);
    driverP=(g+u(2)-x(1))/p.driver.Rp_Ohm;driverN=(g+u(3)-x(2))/p.driver.Rn_Ohm;
    capP=p.receiver.Cp_F*dx(1)+p.receiver.Cdiff_F*(dx(1)-dx(2))+p.coupling.Cp_F*(dx(1)-u(4));
    capN=p.receiver.Cn_F*dx(2)+p.receiver.Cdiff_F*(dx(2)-dx(1))+p.coupling.Cn_F*(dx(2)-u(4));
    r=[capP-driverP+(x(1)-x(2))/p.receiver.Rdiff_Ohm+x(1)/p.receiver.RpBias_Ohm, ...
       capN-driverN+(x(2)-x(1))/p.receiver.Rdiff_Ohm+x(2)/p.receiver.RnBias_Ohm, ...
       p.ground.L_H*dx(3)-g+p.ground.R_Ohm*x(3)];
    peak=max(peak,abs(r));
end
report=struct('randomStates',n,'positiveKCLPeak_A',peak(1),'negativeKCLPeak_A',peak(2), ...
    'returnLawPeak_V',peak(3),'allowance',1e-12,'passed',all(peak<=1e-12));
end
