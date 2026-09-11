function balance=sc01b_energy_balance(r,p)
%SC01B_ENERGY_BALANCE Exterior work, explicit storage and device terminal work.
% Currents are positive into device drain/gate pins; feed current flows from
% the fixed DC source. Floating high-side gate return is inside the device
% boundary. Thus Icap=Ifeed-Ihigh at the local DC-link node in this fixture.
% Device terminal work includes internal charge and heat; it is not renamed
% semiconductor dissipation. Initial stored energy is excluded from the scale.
names={'bus_V','highVds_V','lowVds_V','highVgs_V','lowVgs_V', ...
    'highCurrent_A','lowCurrent_A','highGateCurrent_A','lowGateCurrent_A', ...
    'loadCurrent_A','feedCurrent_A'};
assert(isstruct(r) && isfield(r,'time_s'),'SC01B:MissingSignal','A native time record is required.');
assert(iscolumn(r.time_s) && numel(r.time_s)>=2 && all(isfinite(r.time_s)) && all(diff(r.time_s)>0), ...
    'SC01B:InvalidTrace','Time must be a finite strictly increasing column.');
for name=names
    assert(isfield(r,name{1}),'SC01B:MissingSignal','Required energy trace is missing: %s',name{1});
    v=r.(name{1});
    assert(isnumeric(v) && isreal(v) && iscolumn(v) && numel(v)==numel(r.time_s) && all(isfinite(v)), ...
        'SC01B:InvalidTrace','Energy traces must be finite columns on the native time grid.');
end
start=max(p.validation.startTime_s,r.time_s(1));stop=min(p.simulation.stopTime_s,r.time_s(end));
assert(stop>start,'SC01B:NoValidationRecord','No energy-balance record remains after the preamble.');
g=sc01b_gate_signals(p);
% Insert command corners as well as endpoints: command voltage and observed
% current then remain piecewise linear on their common integration grid.
t=unique([start;r.time_s(r.time_s>start & r.time_s<stop); ...
    g.time_s(g.time_s>start & g.time_s<stop);stop]);
v=struct();for name=names,v.(name{1})=interp1(r.time_s,r.(name{1}),t,'linear');end
highCommand=interp1(g.time_s,g.high_V,t,'linear');
lowCommand=interp1(g.time_s,g.low_V,t,'linear');
icap=v.feedCurrent_A-v.highCurrent_A;
vcap=v.bus_V-p.bus.capacitorESR_Ohm*icap;
balance.WindowStart_s=start;balance.WindowEnd_s=stop;
balance.WindowClipped=r.time_s(1)>p.validation.startTime_s || ...
    r.time_s(end)<p.simulation.stopTime_s-1e-12;
balance.DCSourceEnergy_J=p.bus.voltage_V*trapz(t,v.feedCurrent_A);
balance.HighGateSourceEnergy_J=product(t,highCommand,v.highGateCurrent_A);
balance.LowGateSourceEnergy_J=product(t,lowCommand,v.lowGateCurrent_A);
balance.InputEnergy_J=balance.DCSourceEnergy_J+balance.HighGateSourceEnergy_J+balance.LowGateSourceEnergy_J;
balance.FeedResistorEnergy_J=p.bus.feedResistance_Ohm*product(t,v.feedCurrent_A,v.feedCurrent_A);
balance.LoadResistorEnergy_J=p.load.resistance_Ohm*product(t,v.loadCurrent_A,v.loadCurrent_A);
% Work in the passive directional gate impedance. Both command-to-gate
% voltage drop and measured current are used; its I-V law is audited
% independently instead of applying the obsolete symmetric R*I^2 formula.
balance.GateResistorEnergy_J=product(t,highCommand-v.highVgs_V,v.highGateCurrent_A)+ ...
    product(t,lowCommand-v.lowVgs_V,v.lowGateCurrent_A);
balance.CapacitorESREnergy_J=p.bus.capacitorESR_Ohm*product(t,icap,icap);
balance.ExternalResistorEnergy_J=balance.FeedResistorEnergy_J+balance.LoadResistorEnergy_J+ ...
    balance.GateResistorEnergy_J+balance.CapacitorESREnergy_J;
balance.CapacitorStorageChange_J=0.5*p.bus.capacitance_F*(vcap(end)^2-vcap(1)^2);
balance.FeedInductorStorageChange_J=0.5*p.bus.feedInductance_H*(v.feedCurrent_A(end)^2-v.feedCurrent_A(1)^2);
balance.LoadInductorStorageChange_J=0.5*p.load.inductance_H*(v.loadCurrent_A(end)^2-v.loadCurrent_A(1)^2);
balance.StoredEnergyChange_J=balance.CapacitorStorageChange_J+ ...
    balance.FeedInductorStorageChange_J+balance.LoadInductorStorageChange_J;
balance.HighDeviceTerminalEnergy_J=product(t,v.highVds_V,v.highCurrent_A)+product(t,v.highVgs_V,v.highGateCurrent_A);
balance.LowDeviceTerminalEnergy_J=product(t,v.lowVds_V,v.lowCurrent_A)+product(t,v.lowVgs_V,v.lowGateCurrent_A);
balance.DeviceTerminalEnergy_J=balance.HighDeviceTerminalEnergy_J+balance.LowDeviceTerminalEnergy_J;
balance.Residual_J=balance.InputEnergy_J-balance.ExternalResistorEnergy_J- ...
    balance.StoredEnergyChange_J-balance.DeviceTerminalEnergy_J;
balance.EnergyScale_J=sum(abs([balance.DCSourceEnergy_J,balance.HighGateSourceEnergy_J, ...
    balance.LowGateSourceEnergy_J,balance.ExternalResistorEnergy_J, ...
    balance.HighDeviceTerminalEnergy_J,balance.LowDeviceTerminalEnergy_J, ...
    balance.CapacitorStorageChange_J,balance.FeedInductorStorageChange_J,balance.LoadInductorStorageChange_J]));
balance.SemiconductorHeatKnown=false;
end

function energy=product(t,v,i)
% Exact integral of the product of two linearly interpolated signals.
energy=sum(diff(t)/6.*(2*v(1:end-1).*i(1:end-1)+v(1:end-1).*i(2:end)+ ...
    v(2:end).*i(1:end-1)+2*v(2:end).*i(2:end)));
end
