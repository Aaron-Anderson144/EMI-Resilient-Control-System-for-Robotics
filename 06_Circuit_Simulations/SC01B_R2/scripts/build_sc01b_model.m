function modelFile=build_sc01b_model(p)
%BUILD_SC01B_MODEL Native vendor-charge-model half bridge and commutation load.
% MOSFETs are MathWorks-shipped Infineon SPICE imports, with package parasitics,
% body diode and nonlinear gate/output charge retained. Gate supplies float
% relative to each device's external source terminal through finite Rdriver+Rg.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'functions'));
if nargin==0,p=sc01b_parameters();end
settings=sc01b_local_solver_settings(p.simulation);
model='EMI_SC01B_R2_Halfbridge';folder=fullfile(root,'models');
if ~exist(folder,'dir'),mkdir(folder);end
modelFile=fullfile(folder,[model '.slx']);
load_system('ee_lib');load_system('fl_lib');load_system('nesl_utility');
if ~isfile(fullfile(root,'sc01b_driver_lib.slx'))
    previous=pwd;cd(root);restore=onCleanup(@()cd(previous));ssc_build('sc01b_driver');clear restore
end
load_system(fullfile(root,'sc01b_driver_lib.slx'));
if bdIsLoaded(model),close_system(model,0);end
if exist(modelFile,'file')
    load_system(modelFile);Simulink.BlockDiagram.deleteContents(model);
else
    new_system(model);
end
set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'RelTol',num2str(p.simulation.relativeTolerance,17), ...
    'AbsTol',num2str(p.simulation.absoluteTolerance,17), ...
    'FixedStep',num2str(p.simulation.maxStep_s,17), ...
    'MinStepSizeMsg','error','StopTime',num2str(p.simulation.stopTime_s,17), ...
    'ReturnWorkspaceOutputs','on','SaveTime','on','TimeSaveName','tout', ...
    'SaveOutput','off','SignalLogging','off');
ws=get_param(model,'ModelWorkspace');assignin(ws,'sc01bSchema',4);
assignin(ws,'sc01bParams',p);gates=sc01b_gate_signals(p);
assignin(ws,'sc01bGateHigh',gates.high);assignin(ws,'sc01bGateLow',gates.low);
ele='fl_lib/Electrical/Electrical Elements/';sen='fl_lib/Electrical/Electrical Sensors/';
add_block('fl_lib/Electrical/Electrical Sources/DC Voltage Source',[model '/Supply'], ...
    'Position',[220 125 270 185],'v0','sc01bParams.bus.voltage_V');
add_block('fl_lib/Electrical/Electrical Sources/DC Voltage Source',[model '/IsothermalTemperature'], ...
    'Position',[230 780 280 840],'v0','sc01bParams.device.temperature_C');
resistor('FeedResistance',[350 100 420 130],'sc01bParams.bus.feedResistance_Ohm');
inductor('FeedInductance',[530 100 600 130],'sc01bParams.bus.feedInductance_H','0',false);
add_block([ele 'Capacitor'],[model '/DCLinkCapacitance'],'Position',[880 90 950 120], ...
    'c','sc01bParams.bus.capacitance_F','r','sc01bParams.bus.capacitorESR_Ohm','g','0', ...
    'vc_specify','off');
mosfet('HighMOSFET',[770 250 885 385]);mosfet('LowMOSFET',[770 580 885 715]);
gate('HighGate',[310 295 370 355],'sc01bGateHigh');
gate('LowGate',[310 625 370 685],'sc01bGateLow');
splitGate('HighGateResistance',[475 280 550 310]);
splitGate('LowGateResistance',[475 610 550 640]);
inductor('LoadInductance',[1140 450 1220 480], ...
    'sc01bParams.load.inductance_H','0',false);
resistor('LoadResistance',[1370 450 1440 480],'sc01bParams.load.resistance_Ohm');
add_block([ele 'Electrical Reference'],[model '/Reference'],'Position',[1470 855 1510 895]);
add_block('nesl_utility/Solver Configuration',[model '/ElectricalSolver'], ...
    'Position',[1170 840 1270 895],'UseLocalSolver','on','DoDC','on','AutomaticFiltering','off', ...
    'LocalSolverChoice',settings.localSolverEnum, ...
    'LocalSolverSampleTime',num2str(p.simulation.maxStep_s,17), ...
    'DoFixedCost','off','ConsistencyTolSource','LOCAL', ...
    'ConsistencyAbsTol',num2str(settings.consistencyAbsoluteTolerance,17), ...
    'ConsistencyRelTol',num2str(settings.consistencyRelativeTolerance,17), ...
    'ConsistencyTolFactor',num2str(settings.consistencyToleranceFactor,17));
current('FeedCurrent',[660 100 710 145]);
current('HighDrainCurrent',[930 205 980 250]);current('HighSourceCurrent',[930 380 980 425]);
current('LowDrainCurrent',[930 540 980 585]);current('LowSourceCurrent',[930 720 980 765]);
current('HighGateCurrent',[640 280 690 325]);current('LowGateCurrent',[640 610 690 655]);
current('LoadCurrent',[1290 450 1340 495]);
voltage('SwitchVoltage',[1620 450 1670 500]);voltage('BusVoltage',[1620 100 1670 150]);
voltage('HighVgs',[1830 230 1880 280]);voltage('HighVds',[1620 270 1670 320]);
voltage('LowVgs',[1830 620 1880 670]);voltage('LowVds',[1620 655 1670 705]);

zero=port('Reference','LConn',1);bus=port('FeedCurrent','RConn',2);
sw=port('HighSourceCurrent','RConn',2);
wire(port('Supply','LConn',1),port('FeedResistance','LConn',1));
wire(port('FeedResistance','RConn',1),port('FeedInductance','LConn',1));
wire(port('FeedInductance','RConn',1),port('FeedCurrent','LConn',1));
wire(bus,port('DCLinkCapacitance','LConn',1));wire(zero,port('DCLinkCapacitance','RConn',1));
wire(bus,port('HighDrainCurrent','LConn',1));
wire(port('HighDrainCurrent','RConn',2),port('HighMOSFET','RConn',1));
wire(port('HighMOSFET','RConn',4),port('HighSourceCurrent','LConn',1));
wire(sw,port('LowDrainCurrent','LConn',1));
wire(port('LowDrainCurrent','RConn',2),port('LowMOSFET','RConn',1));
wire(port('LowMOSFET','RConn',4),port('LowSourceCurrent','LConn',1));
wire(port('LowSourceCurrent','RConn',2),zero);
wire(sw,port('LoadInductance','LConn',1));
wire(port('LoadInductance','RConn',1),port('LoadCurrent','LConn',1));
wire(port('LoadCurrent','RConn',2),port('LoadResistance','LConn',1));
wire(port('LoadResistance','RConn',1),zero);
wire(port('Supply','RConn',1),zero);wire(port('IsothermalTemperature','RConn',1),zero);
wire(port('ElectricalSolver','RConn',1),zero);
for prefix={'High','Low'}
    q=prefix{1};mos=[q 'MOSFET'];drv=[q 'Gate'];
    wire(port(drv,'LConn',1),port([q 'GateResistance'],'LConn',1));
    wire(port([q 'GateResistance'],'RConn',1),port([q 'GateCurrent'],'LConn',1));
    wire(port([q 'GateCurrent'],'RConn',2),port(mos,'LConn',1));
    wire(port(drv,'RConn',2),port(mos,'RConn',4));
    wire(port('IsothermalTemperature','LConn',1),port(mos,'RConn',2));
    wire(port('IsothermalTemperature','LConn',1),port(mos,'RConn',3));
    wire(port([q 'Vgs'],'LConn',1),port(mos,'LConn',1));
    wire(port([q 'Vgs'],'RConn',2),port(mos,'RConn',4));
    wire(port([q 'Vds'],'LConn',1),port(mos,'RConn',1));
    wire(port([q 'Vds'],'RConn',2),port(mos,'RConn',4));
end
wire(port('SwitchVoltage','LConn',1),sw);wire(port('SwitchVoltage','RConn',2),zero);
wire(port('BusVoltage','LConn',1),bus);wire(port('BusVoltage','RConn',2),zero);
set_param(model,'SimscapeLogType','all','SimscapeLogName','sc01bSimlog','SimscapeLogLimitData','off');
a=Simulink.Annotation(model,sprintf(['SC-01B | VENDOR-CHARGE-MODEL HALF BRIDGE\n' ...
    'Infineon IAUC100N04S6L014: native SPICE-imported MOSFETs, body diode and package parasitics\n' ...
    'Finite gate impedance, commanded dead time, supply R-L and local DC-link capacitor; DC initialized inductive load\n' ...
    'Isothermal 25 C surrogate temperature pins; floating driver supply; actual local integration with explicit consistency tolerances\n' ...
    'Press Run for stored nominal commutation pair; run sc01b_startup, then sc01b_main for integration-step refinement.']));
a.Position=[40 0 1940 85];a.FontSize=13;
set_param(model,'Location',[40 40 1850 1050],'ZoomFactor','FitSystem');save_system(model,modelFile);
try,print(['-s' model],'-dpng','-r140',fullfile(folder,[model '.png']));
catch err,warning('SC01B:DiagramExport','Diagram export failed: %s',err.message);end

    function mosfet(name,pos)
        b=add_block('ee_lib/Semiconductors & Converters/SPICE-Imported MOSFET', ...
            [model '/' name],'Position',pos);
        set_param(b,'SeriesChoice',char(p.device.series));set_param(b,'DeviceChoice',char(p.device.name));
    end
    function resistor(name,pos,value)
        add_block([ele 'Resistor'],[model '/' name],'Position',pos,'R',value);
    end
    function splitGate(name,pos)
        add_block('sc01b_driver_lib/Split gate impedance',[model '/' name], ...
            'Position',pos, ...
            'Ron','sc01bParams.driver.outputResistance_Ohm+sc01bParams.driver.externalResistance_Ohm+sc01bParams.driver.additionalTurnOnResistance_Ohm', ...
            'Roff','sc01bParams.driver.turnOffResistance_Ohm');
    end
    function inductor(name,pos,value,initial,high)
        b=add_block([ele 'Inductor'],[model '/' name],'Position',pos,'l',value,'r','0','g','0','i_L_specify','off');
        if high,set_param(b,'i_L_specify','on','i_L_priority','High','i_L',initial);end
    end
    function gate(name,pos,variable)
        add_block('fl_lib/Electrical/Electrical Sources/Controlled Voltage Source',[model '/' name],'Position',pos);
        x=pos(1)-260;y=pos(2)+70;
        add_block('simulink/Sources/From Workspace',[model '/' name 'Input'], ...
            'Position',[x y x+145 y+25],'VariableName',variable,'Interpolate','on', ...
            'SampleTime','0','ZeroCross','on','OutputAfterFinalValue','Holding final value','ShowName','off');
        add_block('nesl_utility/Simulink-PS Converter',[model '/' name 'ToPhysical'], ...
            'Position',[x+190 y x+230 y+25],'Unit','V', ...
            'FilteringAndDerivatives','provide','UdotUserProvided','0','ShowName','off');
        add_line(model,[name 'Input/1'],[name 'ToPhysical/1'],'autorouting','on');
        wire(port([name 'ToPhysical'],'RConn',1),port(name,'RConn',1));
    end
    function current(name,pos),sensor(name,'Current Sensor','A',pos);end
    function voltage(name,pos),sensor(name,'Voltage Sensor','V',pos);end
    function sensor(name,type,unit,pos)
        add_block([sen type],[model '/' name],'Position',pos,'ShowName','off');
        label=Simulink.Annotation(model,name);label.Position=[pos(1)-15 pos(2)-25 pos(3)+100 pos(2)-5];
        x=pos(3)+30;y=pos(2)+25;
        % Place gate-current readout branches in the open area below each
        % driver so logging blocks never cover the MOSFET symbols.
        if endsWith(name,'GateCurrent'),x=pos(1)-220;y=pos(2)+130;end
        if any(strcmp(name,{'FeedCurrent','LoadCurrent'})),y=pos(2)+80;end
        add_block('nesl_utility/PS-Simulink Converter',[model '/' name 'ToSignal'], ...
            'Position',[x y x+35 y+22],'Unit',unit,'ShowName','off');
        add_block('simulink/Sinks/To Workspace',[model '/' name 'Log'], ...
            'Position',[x+60 y x+190 y+22],'VariableName',['sc01b' name], ...
            'SaveFormat','Timeseries','MaxDataPoints','inf','Decimation','1','SampleTime','-1','ShowName','off');
        wire(port(name,'RConn',1),port([name 'ToSignal'],'LConn',1));
        add_line(model,[name 'ToSignal/1'],[name 'Log/1'],'autorouting','on');
    end
    function h=port(name,side,k),v=get_param([model '/' name],'PortHandles');h=v.(side)(k);end
    function wire(from,to),add_line(model,from,to,'autorouting','on');end
end
