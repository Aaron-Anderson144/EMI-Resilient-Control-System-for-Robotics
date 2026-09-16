function [y,dy,m2]=receiver_v2_signal(s,index,tau,row,inputRow)
% Linear output and an analytical bound on |y''| from this offset onward.
if nargin<5,inputRow=zeros(1,4);end
c=s.circuit;coeff=s.k(index,:).* (row*c.V);
z=coeff.*exp(tau.*c.lambda.');
a=s.c0(index,:)*row.'+s.u0(index,:)*inputRow.';
b=s.c1(index,:)*row.'+s.u1(index,:)*inputRow.';
y=a+b.*tau+real(sum(z,2));
dy=b+real(sum(z.*c.lambda.',2));
m2=sum(abs(z.*(c.lambda.'.^2)),2);
end
