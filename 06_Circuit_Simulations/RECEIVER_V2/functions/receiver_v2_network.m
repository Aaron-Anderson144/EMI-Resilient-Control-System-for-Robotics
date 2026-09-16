function c=receiver_v2_network(p,cd_pF,cp_pF)
%RECEIVER_V2_NETWORK Loaded nodal model x=[vp;vn;shared return current].
% u=[aggressor return current;positive source;negative source;dVa/dt].
% Pin voltages and shunts use quiet IC ground. Driver voltages reference g.
n=p.network; gp=1/n.driverRp_Ohm;gn=1/n.driverRn_Ohm;
cd=cd_pF*1e-12;cp=cp_pF*1e-12;cn=n.Ccn_pF*1e-12;
assert(cd>0&&cp>=0&&cn>=0,'RECEIVER_V2:Parameters','Invalid capacitance.');
C=[n.pinCp_F+cp+cd,-cd;-cd,n.pinCn_F+cn+cd];
G=[1/n.termination_Ohm+1/n.biasRp_Ohm,-1/n.termination_Ohm; ...
    -1/n.termination_Ohm,1/n.termination_Ohm+1/n.biasRn_Ohm];
gx=[gp gn -1]/(gp+gn);gu=[1 -gp -gn 0]/(gp+gn);
A=[C\([gp;gn]*gx-[gp 0 0;0 gn 0]-[G zeros(2,1)]); ...
    (gx-[0 0 n.returnR_Ohm])/n.returnL_H];
B=[C\([gp;gn]*gu+[0 gp 0 cp;0 0 gn cn]);gu/n.returnL_H];
[V,D]=eig(A);lambda=diag(D);
assert(all(real(lambda)<0)&&rcond(V)>1e-10,'RECEIVER_V2:Modes','Invalid modes.');
c=struct('A',A,'B',B,'C',C,'G',G,'gx',gx,'gu',gu, ...
    'V',V,'W',inv(V),'lambda',lambda,'cd_pF',cd_pF,'cp_pF',cp_pF);
end
