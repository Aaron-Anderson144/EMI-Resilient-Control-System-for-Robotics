function configuration = actuator_simulink_configuration(params, kind)
%ACTUATOR_SIMULINK_CONFIGURATION Exact block parameters for one actuator run.
% Keep numeric block settings and run metadata derived from the same input.
arguments
    params (1,1) struct
    kind (1,1) string {mustBeMember(kind,["baseline","phase2","phase2b"])}
end
validate_parameters(params);
plant = actuator_state_space(params);
controller = design_baseline_controller(params, plant);
[A,B,C,D] = ssdata(ss(c2d(plant,params.control.sampleTime_s,'zoh')));
[num,den] = tfdata(tf(controller.discrete),'v');
[Ac,Bc,Cc,Dc] = ssdata(ss(controller.discrete));
if kind == "phase2b"
    plantBlock = 'Three-State Actuator Plant';
else
    plantBlock = 'Actuator Plant';
    C = C(1,:);
    D = D(1,:);
end
ts = num2str(params.control.sampleTime_s,17);
configuration.kind = kind;
configuration.sampleTimeText = ts;
configuration.stopTimeText = num2str(params.simulation.stopTime_s,17);
configuration.controllerStateCount = size(Ac,1);
configuration.schema = struct('id','EMI-ACTUATOR-PARAMETERIZED-V2', ...
    'kind',char(kind),'plantInputCount',2,'supplyLogColumns',4);
configuration.blocks = {
    'Position Reference','Time',num2str(params.simulation.stepTime_s,17)
    'Position Reference','After',num2str(params.simulation.stepAmplitude_rad,17)
    'Position Reference','SampleTime',ts
    plantBlock,'A',mat2str(A,17)
    plantBlock,'B',mat2str(B,17)
    plantBlock,'C',mat2str(C,17)
    plantBlock,'D',mat2str(D,17)
    plantBlock,'InitialCondition','zeros(3,1)'
    plantBlock,'SampleTime',ts
    'Nominal Load Torque','Value',num2str(params.mechanical.nominalLoadTorque_Nm,17)
    };
if kind == "phase2b"
    prefix = 'Discrete Position Controller/';
    configuration.blocks = [configuration.blocks; {
        [prefix,'State A'],'Gain',mat2str(Ac,17)
        [prefix,'Error B'],'Gain',mat2str(Bc,17)
        [prefix,'State C'],'Gain',mat2str(Cc,17)
        [prefix,'Error D'],'Gain',mat2str(Dc,17)
        [prefix,'Controller State'],'InitialCondition',mat2str(zeros(size(Ac,1),1),17)
        [prefix,'Controller State'],'SampleTime',ts
        [prefix,'Zero State'],'Value',mat2str(zeros(size(Ac,1),1),17)
        'Last Accepted Measurement','SampleTime',ts
        'Timestamped Packet Delay','SampleTime',ts
        'Timestamped Packet Delay','DelayLengthUpperLimit',num2str(max(1, ...
            params.phase2b.communication.fixedDelay_samples + ...
            params.phase2b.communication.maximumJitter_samples),17)
        }];
else
    availableLimit_V = min(params.control.voltageLimit_V, ...
        params.electrical.nominalVoltage_V);
    configuration.blocks = [configuration.blocks; {
        'Discrete Position Controller','Numerator',mat2str(num,17)
        'Discrete Position Controller','Denominator',mat2str(den,17)
        'Discrete Position Controller','SampleTime',ts
        'Drive Voltage Limit','UpperLimit',num2str(availableLimit_V,17)
        'Drive Voltage Limit','LowerLimit',num2str(-availableLimit_V,17)
        }];
    if kind == "phase2"
        configuration.blocks(end+1,:) = {'Last Accepted Encoder','SampleTime',ts};
    end
end
end
