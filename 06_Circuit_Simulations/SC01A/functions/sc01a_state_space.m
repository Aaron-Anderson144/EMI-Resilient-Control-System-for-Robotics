function circuit = sc01a_state_space(p)
%SC01A_STATE_SPACE Independent loaded-network equations, x=[vp;vn;ir].
% u=[Icomm, Vsp+ep, Vsn+en, dVa/dt]. The return includes victim current.
arguments
    p (1,1) struct
end
positive=[p.driver.Rp_Ohm p.driver.Rn_Ohm p.receiver.Rdiff_Ohm ...
    p.receiver.Cdiff_F p.receiver.Cp_F p.receiver.Cn_F ...
    p.receiver.RpBias_Ohm p.receiver.RnBias_Ohm p.ground.R_Ohm p.ground.L_H];
assert(all(isfinite(positive)) && all(positive>0), ...
    'SC01A:InvalidPositiveParameter','Circuit R, L and receiver C values must be positive.');
assert(all(isfinite([p.coupling.Cp_F p.coupling.Cn_F])) && ...
    all([p.coupling.Cp_F p.coupling.Cn_F]>=0), ...
    'SC01A:InvalidCouplingCapacitance','Coupling capacitances must be nonnegative.');
gp=1/p.driver.Rp_Ohm; gn=1/p.driver.Rn_Ohm;
C=[p.receiver.Cp_F+p.coupling.Cp_F+p.receiver.Cdiff_F,-p.receiver.Cdiff_F; ...
    -p.receiver.Cdiff_F,p.receiver.Cn_F+p.coupling.Cn_F+p.receiver.Cdiff_F];
assert(all(eig(C)>0),'SC01A:NonpositiveCapacitance','Capacitance matrix must be positive definite.');
% g = gx*x + gu*u follows directly from shared-ground KCL.
gx=[gp gn -1]/(gp+gn);
gu=[1 -gp -gn 0]/(gp+gn);
driveX=[gp;gn]*gx-[gp 0 0;0 gn 0];
driveU=[gp;gn]*gu+[0 gp 0 0;0 0 gn 0];
G=[1/p.receiver.Rdiff_Ohm+1/p.receiver.RpBias_Ohm,-1/p.receiver.Rdiff_Ohm; ...
    -1/p.receiver.Rdiff_Ohm,1/p.receiver.Rdiff_Ohm+1/p.receiver.RnBias_Ohm];
A=[C\(driveX-[G zeros(2,1)]); ...
    (gx-[0 0 p.ground.R_Ohm])/p.ground.L_H];
B=[C\(driveU+[zeros(2,3) [p.coupling.Cp_F;p.coupling.Cn_F]]);gu/p.ground.L_H];
assert(all(real(eig(A))<0),'SC01A:UnstableReference','Passive circuit reference must be asymptotically stable.');
circuit.A=A; circuit.B=B; circuit.groundState=gx; circuit.groundInput=gu;
circuit.capacitance=C; circuit.conductance=G;
end
