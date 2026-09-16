function sensor=fourway_v2_receiver_init(Ccp_pF,Ccn_pF,Cdiff_pF,phase_s,exposed,variant,closure_s,initialA)
% Persistent V2 loaded circuit, Schmitt request, delayed output and decoder.
if nargin<7,closure_s=100e-9;end
if nargin<8,initialA=0;end
assert(ismember(initialA,[0 1])&&isfinite(phase_s)&&isfinite(closure_s)&&closure_s>0);
required={'id','rise_V','fall_V','latencyRise_s','latencyFall_s','pulseLaw'};
assert(all(isfield(variant,required)),'FOURWAY_V2:Variant','Incomplete receiver variant.');
assert(variant.rise_V>variant.fall_V&&variant.rise_V<=-.02&&variant.fall_V>=-.2 ...
    &&min([variant.latencyRise_s variant.latencyFall_s])>=0 ...
    &&any(strcmp(variant.pulseLaw,{'transport','inertial'})),'FOURWAY_V2:Variant','Invalid behavioral variant.');
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'06_Circuit_Simulations','RECEIVER_V2','functions'));
v2=receiver_v2_parameters();src=fourway_v2_replay(v2);
v2.network.Ccn_pF=Ccn_pF;c=receiver_v2_network(v2,Cdiff_pF,Ccp_pF);
config.lambda=[real(c.lambda) imag(c.lambda)];
config.V=[real(c.V) imag(c.V)];config.W=[real(c.W) imag(c.W)];
forcing=c.W*c.B*[0 0 0;2.5 1 0;2.5 -1 0;0 0 1];
config.forcing=[real(forcing) imag(forcing)];
config.ground_x=c.gx;config.ground_constant=2.5*(c.gu(2)+c.gu(3));config.ground_driver=c.gu(2)-c.gu(3);
config.knots=[src.t;src.t(end)+closure_s;50e-6];
config.volts=[src.v;src.v(1);src.v(1)];
if abs(config.knots(end)-config.knots(end-1))<1e-15
    config.knots(end-1)=[];config.volts(end-1)=[];
end
assert(all(diff(config.knots)>0),'FOURWAY_V2:Closure','Source return exceeds period.');
config.slopes=diff(config.volts)./diff(config.knots);
config.native_end_s=src.t(end);config.return_end_s=src.t(end)+closure_s;
config.origins=sort(reshape([.25;1.7]+phase_s-2.019e-6+(0:99)*50e-6,[],1));
if ~exposed,config.origins=zeros(0,1);end
config.transition_s=v2.network.driverTransition_s;
config.rise_V=variant.rise_V;config.fall_V=variant.fall_V;
config.latency_rise_s=variant.latencyRise_s;config.latency_fall_s=variant.latencyFall_s;
config.pulse_law=double(strcmp(variant.pulseLaw,'inertial'));
config.engine_function=fourway_v2_build_engine();
sgn=2*initialA-1;x=-c.A\(c.B*[0;2.5+sgn;2.5-sgn;0]);
state=zeros(80,1);state(1:20)=[0;x;sgn;0;0;initialA;0;initialA;0;initialA;0;0;0;0;0;abs((x(1)+x(2))/2);abs(x(1)-x(2));0];
state(21)=initialA;state(23)=-1;state(24)=NaN;
state(29:34)=[x(1);x(1);x(2);x(2);x(1)-x(2);x(1)-x(2)];
g=c.gx*x+c.gu*[0;2.5+sgn;2.5-sgn;0];state(35)=abs(g);
state(39:40)=[(x(1)+x(2))/2;(x(1)+x(2))/2];
state(41:68)=repmat([-1;0],14,1);state(69)=-1;state(70)=NaN;
source=rmfield(src,{'t','v'});source.phase_s=phase_s;source.exposed=logical(exposed);
source.closure_s=closure_s;source.pulse_origins_s=config.origins;
active=find(config.slopes~=0);
source.first_nonzero_dVa_dt_s=config.origins+config.knots(active(1));
source.last_nonzero_dVa_dt_s=config.origins+config.knots(active(end)+1);
% Preserve legacy parameter names for independent exported-record tooling.
n=v2.network;p=struct('coupling',struct('Cp_F',Ccp_pF*1e-12,'Cn_F',Ccn_pF*1e-12,'Mp_H',0,'Mn_H',0), ...
    'driver',struct('commonMode_V',2.5,'differential_V',2,'transitionTime_s',n.driverTransition_s,'Rp_Ohm',n.driverRp_Ohm,'Rn_Ohm',n.driverRn_Ohm), ...
    'receiver',struct('Cdiff_F',Cdiff_pF*1e-12,'Rdiff_Ohm',n.termination_Ohm,'Cp_F',n.pinCp_F,'Cn_F',n.pinCn_F,'RpBias_Ohm',n.biasRp_Ohm,'RnBias_Ohm',n.biasRn_Ohm), ...
    'ground',struct('R_Ohm',n.returnR_Ohm,'L_H',n.returnL_H));
sensor=struct('state',state,'initial_state',state,'config',config,'parameters',p,'circuit',c,'variant',variant,'source',source);
sensor.event_blocks={};sensor.decoder_blocks={};sensor.intended_blocks={};sensor.boundary_blocks={};sensor.packet_blocks={};sensor.logic_blocks={};
sensor.event_columns={'time_s','kind_1trip_2vp15_3vn15_4vd15_5vp18_6vn18_7vd18','threshold_V','direction','vp_V','vn_V','ir_A','receiver_A'};
sensor.decoder_columns={'time_s','A','B','increment','count','invalid','previous_A','previous_B'};
sensor.boundary_columns={'time_s','kind_code','vp_V','vn_V','ir_A','driver_s_V','dVa_dt_V_s'};
sensor.boundary_kind_mapping={'1=ramp_start','2=ramp_end','3=pulse_start','4=pulse_end','5=native_end','6=return_end'};
sensor.packet_columns={'time_s','count','count_rad','ideal_count','domain_failed','vp_V','vn_V','ir_A','ideal_A','ideal_B'};
sensor.logic_columns={'time_s','kind_1comparator_2output','A','dueTime_s'};
sensor.scope='Conditional behavioral continuation only after any latched domain or numerical rejection.';
end
