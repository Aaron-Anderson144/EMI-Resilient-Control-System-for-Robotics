function f=receiver_v2_fixture(p,source,kind,polarity,width)
% Native replay and separately declared finite-edge diagnostic source pulses.
if nargin<5,width=0;end
if strcmp(kind,'native')
    t=[source.t;source.t(end)+p.source.syntheticReturn_s;p.source.nativeStop_s];
    v=[source.v;source.v(1);source.v(1)];v=polarity*(v-v(1));
    id=sprintf('native_%+d',polarity);
else
    a=p.source.syntheticStart_s;e=p.source.syntheticEdge_s;
    t=[0;a;a+e;a+e+width;a+2*e+width;p.source.syntheticStop_s];
    v=polarity*p.source.syntheticAmplitude_V*[0;0;1;1;0;0];
    id=sprintf('pulse_%gns_%+d',width*1e9,polarity);
end
% A single physical A channel, ideal B companion, two forward Gray cycles.
tt=[.8;1.3;2.019;2.519;3.2;3.7;4.4;4.9]*1e-6;
ab=[1 0;1 1;0 1;0 0;1 0;1 1;0 1;0 0];
f=struct('id',id,'kind',kind,'polarity',polarity,'width_s',width, ...
    'sourceT',t,'sourceV',v,'transitions',[tt ab],'initialAB',[0 0],'stop_s',t(end));
end
