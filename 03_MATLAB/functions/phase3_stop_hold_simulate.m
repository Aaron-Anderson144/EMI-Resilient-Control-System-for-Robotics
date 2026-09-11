function [trace,metric]=phase3_stop_hold_simulate(params,fixture,mechanism,h,design)
%PHASE3_STOP_HOLD_SIMULATE Separate passive plant harness, drive isolated.
n=round(fixture.duration_s/h);stride=round(design.exportInterval_s/h);
assert(abs(n*h-fixture.duration_s)<1e-12 && mod(n,stride)==0);
t=(0:n)'*h;load=zeros(n+1,1);
for j=1:numel(fixture.loadTimes_s),load(t>=fixture.loadTimes_s(j)-1e-12)=fixture.loadValues_Nm(j);end
capacity=phase3_stop_hold_capacity(t,fixture,mechanism);
columns={'Time_s','Position_rad','Velocity_rad_s','Current_A','LoadTorque_Nm', ...
 'Capacity_Nm','BrakeTorque_Nm','MotorTerminalVoltage_V','StoredEnergy_J', ...
 'LoadWork_J','CopperLoss_J','ResistorLoss_J','ViscousLoss_J','BrakeLoss_J','NumericalLoss_J','EnergyResidual_J'};
data=zeros(n/stride+1,numel(columns));x=fixture.x0(:);J=params.mechanical.inertia_kg_m2;L=params.electrical.inductance_H;
E0=.5*J*x(2)^2+.5*L*x(3)^2;sumLedger=zeros(1,6);
data(1,:)=[0,x',load(1),capacity(1),0,-mechanism.externalResistance_Ohm*x(3),E0,sumLedger,0];
maxClosure=0;peakCurrent=abs(x(3));travel=0;maxExcess=0;lastMotion=NaN;
if abs(x(2))>design.gates.holdingVelocity_rad_s,lastMotion=0;end
for k=1:n
 % Every discontinuous load event is a grid boundary: the left value is
 % the interval midpoint value. Capacity is continuous and right-sampled.
 [x,e]=phase3_stop_hold_step(x,h,params,load(k),capacity(k+1),mechanism.externalResistance_Ohm);
 sumLedger=sumLedger+[e.loadWork_J,e.copperLoss_J,e.resistorLoss_J,e.viscousLoss_J,e.brakeLoss_J,e.numericalLoss_J];
 E=.5*J*x(2)^2+.5*L*x(3)^2;closure=E-E0-sumLedger(1)+sum(sumLedger(2:end));
 maxClosure=max(maxClosure,abs(closure));peakCurrent=max(peakCurrent,abs(x(3)));travel=travel+h*abs(x(2));
 maxExcess=max(maxExcess,abs(e.brakeTorque_Nm)-capacity(k+1));
 if abs(x(2))>design.gates.holdingVelocity_rad_s,lastMotion=t(k+1);end
 if mod(k,stride)==0,data(k/stride+1,:)=[t(k+1),x',load(k+1),capacity(k+1),e.brakeTorque_Nm,e.motorTerminalVoltage_V,E,sumLedger,closure];end
end
trace=array2table(data,'VariableNames',columns);
tail=trace.Time_s>=fixture.duration_s-design.gates.holdingTail_s-1e-12;
held=all(abs(trace.Velocity_rad_s(tail))<=design.gates.holdingVelocity_rad_s);
capture=NaN;if held,if isnan(lastMotion),capture=0;else,capture=lastMotion+h;end,end
metric=struct('Fixture',string(fixture.id),'Mechanism',string(mechanism.id),'Step_s',h, ...
 'Duration_s',fixture.duration_s,'NetTravel_deg',rad2deg(x(1)-fixture.x0(1)), ...
 'AbsoluteTravel_deg',rad2deg(travel),'CaptureTime_s',capture,'TailHeld',held, ...
 'TailDrift_deg',rad2deg(max(trace.Position_rad(tail))-min(trace.Position_rad(tail))), ...
 'FinalVelocity_rad_s',x(2),'PeakCurrent_A',peakCurrent,'LoadWork_J',sumLedger(1), ...
 'CopperLoss_J',sumLedger(2),'ResistorLoss_J',sumLedger(3),'ViscousLoss_J',sumLedger(4), ...
 'BrakeLoss_J',sumLedger(5),'NumericalLoss_J',sumLedger(6), ...
 'NumericalLossFraction',sumLedger(6)/max(design.gates.energyScaleFloor_J,E0+abs(sumLedger(1))), ...
 'MaxEnergyResidual_J',maxClosure,'MaxCapacityExcess_Nm',maxExcess);
end
