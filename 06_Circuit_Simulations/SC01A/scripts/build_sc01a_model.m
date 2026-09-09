function modelFile = build_sc01a_model(p)
%BUILD_SC01A_MODEL Build the native conserving-port SC-01A circuit.
% Sources: installed MathWorks Simscape Foundation Electrical library,
% fl_lib/Electrical/{Electrical Elements,Electrical Sources,Electrical Sensors}
% and nesl_utility. The .ssc equations were checked in MATLAB R2026a.
% Cp/Cn=0 removes the corresponding coupling branch exactly. All other
% capacitors and the return inductor must be positive. No hidden ESR,
% conductance, attenuation, voltage-to-angle conversion, or input filtering
% is added. The converter receives the exact finite-ramp dVa/dt separately.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'functions'));
if nargin == 0, p = sc01a_parameters(); end
model = 'EMI_SC01A_Finite_Edge';
modelDir = fullfile(root,'models');
if ~exist(modelDir,'dir'), mkdir(modelDir); end
modelFile = fullfile(modelDir,[model '.slx']);
if bdIsLoaded(model), close_system(model,0); end
load_system('fl_lib'); load_system('nesl_utility');
new_system(model);
set_param(model,'SolverType','Variable-step','Solver','ode23t', ...
    'RelTol','1e-6','AbsTol','1e-9','MaxStep','1e-9', ...
    'StopTime',num2str(p.simulation.singleStop_s,17),'ReturnWorkspaceOutputs','on', ...
    'SaveTime','on','TimeSaveName','tout','SaveOutput','off', ...
    'SignalLogging','off','SimulationMode','normal');
workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'sc01aTopology',struct('schema',5, ...
    'positiveCoupling',p.coupling.Cp_F>0, ...
    'negativeCoupling',p.coupling.Cn_F>0));
% Persist a nominal runnable example in the model. SimulationInput explicitly
% overrides this workspace for every test case, including topology rebuilds.
assignin(workspace,'sc01aParams',p);
defaultCase=sc01a_case("combined_rise",p);
signals=sc01a_simscape_signals(sc01a_stimulus(p,defaultCase));
names=fieldnames(signals);
for k=1:numel(names), assignin(workspace,names{k},signals.(names{k})); end

% The flat circuit deliberately exposes the receiver and return topology.
src = 'fl_lib/Electrical/Electrical Sources/';
ele = 'fl_lib/Electrical/Electrical Elements/';
sen = 'fl_lib/Electrical/Electrical Sensors/';
source('Aggressor', [src 'Controlled Voltage Source'],[430 125 490 185], ...
    'sc01aVoltageAggressor','V',true);
source('TxPositive',[src 'Controlled Voltage Source'],[365 355 415 405], ...
    'sc01aSourcePositive','V',false);
source('InducedPositive',[src 'Controlled Voltage Source'],[560 330 610 380], ...
    'sc01aInducedPositive','V',false);
source('TxNegative',[src 'Controlled Voltage Source'],[365 645 415 695], ...
    'sc01aSourceNegative','V',false);
source('InducedNegative',[src 'Controlled Voltage Source'],[560 620 610 670], ...
    'sc01aInducedNegative','V',false);
source('Commutation',[src 'Controlled Current Source'],[390 895 450 955], ...
    'sc01aCurrentCommutation','A',false);

resistor('DriverPositive',[685 330 755 360],'sc01aParams.driver.Rp_Ohm');
resistor('DriverNegative',[685 620 755 650],'sc01aParams.driver.Rn_Ohm');
resistor('DifferentialTermination',[930 420 1000 450],'sc01aParams.receiver.Rdiff_Ohm');
capacitor('DifferentialCapacitance',[1065 515 1135 545],'sc01aParams.receiver.Cdiff_F');
capacitor('PositiveInputCapacitance',[1210 330 1280 360],'sc01aParams.receiver.Cp_F');
capacitor('NegativeInputCapacitance',[1210 620 1280 650],'sc01aParams.receiver.Cn_F');
resistor('PositiveBiasReturn',[1335 420 1405 450],'sc01aParams.receiver.RpBias_Ohm');
resistor('NegativeBiasReturn',[1335 700 1405 730],'sc01aParams.receiver.RnBias_Ohm');
if p.coupling.Cp_F>0
    capacitor('PositiveCoupling',[730 180 800 210],'sc01aParams.coupling.Cp_F');
end
if p.coupling.Cn_F>0
    capacitor('NegativeCoupling',[890 220 960 250],'sc01aParams.coupling.Cn_F');
end
resistor('SharedReturnResistance',[660 900 740 930],'sc01aParams.ground.R_Ohm');
b=add_block([ele 'Inductor'],[model '/SharedReturnInductance'], ...
    'Position',[850 900 930 930]);
set_param(b,'l','sc01aParams.ground.L_H','l_unit','H', ...
    'r','0','g','0','i_L_specify','off');
add_block([ele 'Electrical Reference'],[model '/ReceiverGround'], ...
    'Position',[1460 990 1500 1030]);
add_block('nesl_utility/Solver Configuration',[model '/ElectricalSolver'], ...
    'Position',[1130 1010 1210 1060],'UseLocalSolver','off','DoDC','on', ...
    'AutomaticFiltering','off');
sensor('PositiveVoltage',[sen 'Voltage Sensor'],[1550 330 1600 380], ...
    'sc01aPositiveLog','V');
sensor('NegativeVoltage',[sen 'Voltage Sensor'],[1550 620 1600 670], ...
    'sc01aNegativeLog','V');
sensor('GroundVoltage',[sen 'Voltage Sensor'],[1550 840 1600 890], ...
    'sc01aGroundLog','V');
sensor('ReturnCurrent',[sen 'Current Sensor'],[995 900 1045 950], ...
    'sc01aReturnLog','A');

% Conserving source ports: LConn1=p/head; RConn2=n/tail.
% Source RConn1 is the physical control input. Current flows tail -> head.
va=port('Aggressor','LConn',1);
vp=port('DriverPositive','RConn',1);
vn=port('DriverNegative','RConn',1);
g =port('SharedReturnResistance','LConn',1);
zero=port('ReceiverGround','LConn',1);
wire(va,port('Aggressor','LConn',1)); % no-op, documents named node
wire(zero,port('Aggressor','RConn',2));
wire(g,port('TxPositive','RConn',2));
wire(port('TxPositive','LConn',1),port('InducedPositive','RConn',2));
wire(port('InducedPositive','LConn',1),port('DriverPositive','LConn',1));
wire(g,port('TxNegative','RConn',2));
wire(port('TxNegative','LConn',1),port('InducedNegative','RConn',2));
wire(port('InducedNegative','LConn',1),port('DriverNegative','LConn',1));
wire(g,port('Commutation','LConn',1));
wire(zero,port('Commutation','RConn',2));
if p.coupling.Cp_F>0
    wire(va,port('PositiveCoupling','LConn',1));
    wire(vp,port('PositiveCoupling','RConn',1));
end
if p.coupling.Cn_F>0
    wire(va,port('NegativeCoupling','LConn',1));
    wire(vn,port('NegativeCoupling','RConn',1));
end
for name={'DifferentialTermination','DifferentialCapacitance'}
    wire(vp,port(name{1},'LConn',1)); wire(vn,port(name{1},'RConn',1));
end
for name={'PositiveInputCapacitance','PositiveBiasReturn'}
    wire(vp,port(name{1},'LConn',1)); wire(zero,port(name{1},'RConn',1));
end
for name={'NegativeInputCapacitance','NegativeBiasReturn'}
    wire(vn,port(name{1},'LConn',1)); wire(zero,port(name{1},'RConn',1));
end
wire(port('SharedReturnResistance','RConn',1),port('SharedReturnInductance','LConn',1));
wire(port('SharedReturnInductance','RConn',1),port('ReturnCurrent','LConn',1));
wire(port('ReturnCurrent','RConn',2),zero);
wire(port('ElectricalSolver','RConn',1),zero);
wire(vp,port('PositiveVoltage','LConn',1));
wire(vn,port('NegativeVoltage','LConn',1));
wire(g,port('GroundVoltage','LConn',1));
for name={'PositiveVoltage','NegativeVoltage','GroundVoltage'}
    wire(zero,port(name{1},'RConn',2));
end

a=Simulink.Annotation(model, sprintf([ ...
    'SC-01A | FINITE-EDGE PHYSICAL COUPLING CIRCUIT\n' ...
    'Native Simscape Foundation Electrical conserving network | prescribed finite ramps\n' ...
    'vp / vn: loaded differential receiver | g: shared transmitter return | 0: receiver reference\n' ...
    'Capacitive Va coupling + series M di/dt sources + loaded R-L common return\n' ...
    'Variable-step ode23t, explicit source derivative, no local solver or input filtering\n' ...
    'Press Run for the stored nominal combined-rise example; use run_sc01a for the campaign.']));
a.Position=[45 15 1560 105]; a.FontSize=13;
set_param(model,'Location',[50 50 1800 1150],'ZoomFactor','FitSystem');
save_system(model,modelFile);
try
    print(['-s' model],'-dpng','-r140',fullfile(modelDir,'EMI_SC01A_Finite_Edge.png'));
catch err
    warning('SC01A:DiagramExport','Diagram export skipped: %s',err.message);
end

    function source(name,library,pos,var,unit,needsDerivative)
        add_block(library,[model '/' name],'Position',pos,'ShowName','off');
        label=Simulink.Annotation(model,name);
        label.Position=[pos(1)-15 pos(2)-25 pos(3)+80 pos(2)-5];
        x=pos(1)-310; y=pos(2)+65;
        % Rectangular induced inputs use duplicate-time left/right samples,
        % so linear interpolation + zero-crossing detection schedules exact
        % discontinuities. Clearing Interpolate disables this event handling.
        add_block('simulink/Sources/From Workspace',[model '/' name 'Input'], ...
            'Position',[x y x+130 y+25],'VariableName',var, ...
            'Interpolate','on','OutputAfterFinalValue','Holding final value', ...
            'SampleTime','0','ZeroCross','on','ShowName','off');
        converter=[model '/' name 'ToPhysical'];
        add_block('nesl_utility/Simulink-PS Converter',converter, ...
            'Position',[x+170 y x+210 y+25],'Unit',unit, ...
            'FilteringAndDerivatives','provide','UdotUserProvided','0','ShowName','off');
        if needsDerivative
            set_param(converter,'UdotUserProvided','1');
            add_block('simulink/Sources/From Workspace',[model '/' name 'Derivative'], ...
                'Position',[x y+45 x+130 y+70], ...
                'VariableName','sc01aVoltageAggressorDerivative','Interpolate','on', ...
                'OutputAfterFinalValue','Holding final value','SampleTime','0','ZeroCross','on','ShowName','off');
            add_line(model,[name 'Derivative/1'],[name 'ToPhysical/2'],'autorouting','on');
        end
        add_line(model,[name 'Input/1'],[name 'ToPhysical/1'],'autorouting','on');
        wire(port([name 'ToPhysical'],'RConn',1),port(name,'RConn',1));
    end
    function resistor(name,pos,value)
        add_block([ele 'Resistor'],[model '/' name],'Position',pos, ...
            'R',value,'R_unit','Ohm');
    end
    function capacitor(name,pos,value)
        add_block([ele 'Capacitor'],[model '/' name],'Position',pos, ...
            'c',value,'c_unit','F','r','0','g','0','vc_specify','off');
    end
    function sensor(name,library,pos,var,unit)
        add_block(library,[model '/' name],'Position',pos,'ShowName','off');
        label=Simulink.Annotation(model,name);
        label.Position=[pos(1)-10 pos(2)-25 pos(3)+70 pos(2)-5];
        x=pos(3)+35; y=pos(2)+15;
        add_block('nesl_utility/PS-Simulink Converter',[model '/' name 'ToSignal'], ...
            'Position',[x y x+45 y+25],'Unit',unit,'ShowName','off');
        add_block('simulink/Sinks/To Workspace',[model '/' name 'Log'], ...
            'Position',[x+75 y x+200 y+25],'VariableName',var, ...
            'SaveFormat','Timeseries','MaxDataPoints','inf','Decimation','1','SampleTime','-1','ShowName','off');
        wire(port(name,'RConn',1),port([name 'ToSignal'],'LConn',1));
        add_line(model,[name 'ToSignal/1'],[name 'Log/1'],'autorouting','on');
    end
    function h=port(name,kind,index)
        handles=get_param([model '/' name],'PortHandles'); h=handles.(kind)(index);
    end
    function wire(from,to)
        if from~=to, add_line(model,from,to,'autorouting','on'); end
    end
end
