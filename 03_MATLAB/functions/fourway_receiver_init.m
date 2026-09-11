function sensor = fourway_receiver_init(Ccp_pF,Ccn_pF,Cdiff_pF,phase_s,exposed,closure_s,initialA)
%FOURWAY_RECEIVER_INIT Frozen PLAN-V1 circuit and persistent decoder state.
% No circuit state is reset at any pulse, return, burst or packet boundary.
if nargin<6, closure_s=100e-9; end
if nargin<7, initialA=0; end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'06_Circuit_Simulations','SC01A','functions'));
engine=fourway_build_engine();
src=fourway_replay();
p=sc01a_parameters();
p.coupling.Cp_F=Ccp_pF*1e-12; p.coupling.Cn_F=Ccn_pF*1e-12;
p.coupling.Mp_H=0;p.coupling.Mn_H=0;
p.receiver.Cdiff_F=Cdiff_pF*1e-12;
c=sc01a_state_space(p);
[V,D]=eig(c.A); lam=diag(D); W=inv(V);
assert(rcond(V)>1e-10,'FOURWAY:Modes','Ill-conditioned circuit modes.');
forcing=W*c.B*[0 0 0;2.5 1 0;2.5 -1 0;0 0 1];
config.lambda=[real(lam) imag(lam)];
config.engine_function=engine;
config.V=[real(V) imag(V)]; config.W=[real(W) imag(W)];
config.forcing=[real(forcing) imag(forcing)];
config.knots=[src.time_s;src.time_s(end)+closure_s;50e-6];
config.volts=[src.switch_V;src.switch_V(1);src.switch_V(1)];
% The long-return diagnostic ends exactly at the period boundary.
if abs(config.knots(end)-config.knots(end-1))<1e-15
    config.knots(end-1)=[];config.volts(end-1)=[];
end
assert(all(diff(config.knots)>0),'FOURWAY:Closure','Invalid source closure duration.');
config.slopes=diff(config.volts)./diff(config.knots);
config.native_end_s=src.time_s(end);
config.return_end_s=config.knots(end-1);
if closure_s>1e-6,config.return_end_s=config.knots(end);end
config.origins=sort(reshape([0.25;1.7]+phase_s-2.019e-6+(0:99)*50e-6,[],1));
if ~exposed, config.origins=zeros(0,1); end
config.transition_s=100e-9;
sgn=2*initialA-1;
x=-c.A\(c.B*[0;2.5+sgn;2.5-sgn;0]);
% t,x(1:3),driver level/slope/ramp end,intended A/B,receiver A,
% decoder count/previous A/B,domain failure,source pulse/knot,ideal count.
sensor.state=[0;x;sgn;0;0;initialA;0;initialA;0;initialA;0;0;0;0;0;abs((x(1)+x(2))/2);abs(x(1)-x(2));0;repmat([-1;0],4,1);-1];
sensor.config=config; sensor.parameters=p; sensor.circuit=c;
sensor.source=rmfield(src,{'time_s','switch_V'});
sensor.source.phase_s=phase_s; sensor.source.exposed=logical(exposed);
sensor.source.closure_s=closure_s;sensor.source.pulse_origins_s=config.origins;
active=find(config.slopes~=0);
if exposed
    sensor.source.first_nonzero_dVa_dt_s=config.origins+config.knots(active(1));
    sensor.source.last_nonzero_dVa_dt_s=config.origins+config.knots(active(end)+1);
else
    sensor.source.first_nonzero_dVa_dt_s=[];sensor.source.last_nonzero_dVa_dt_s=[];
end
sensor.event_blocks={}; sensor.decoder_blocks={};sensor.intended_blocks={};
sensor.boundary_blocks={}; sensor.packet_blocks={};
sensor.event_columns={'time_s','kind_1diff_2common','threshold_V','direction','vp_V','vn_V','ir_A','receiver_A'};
sensor.decoder_columns={'time_s','A','B','increment','count','invalid','previous_A','previous_B'};
sensor.boundary_columns={'time_s','kind_code','vp_V','vn_V','ir_A','driver_s_V','dVa_dt_V_s'};
sensor.boundary_kind_mapping={'1=ramp_start','2=ramp_end','3=pulse_start','4=pulse_end','5=native_end','6=return_end'};
sensor.packet_columns={'time_s','count','count_rad','ideal_count','domain_failed','vp_V','vn_V','ir_A','ideal_A','ideal_B'};
sensor.initial_state=sensor.state;
end
