function p=sc01b_case(name)
%SC01B_CASE Frozen operating-point tests; no transistor model fitting.
arguments
    name (1,1) string
end
p=sc01b_parameters();p.meta.case=name;
switch name
    case "nominal"
        p.meta.role="integration reference";
    case "holdout_bus18"
        p.bus.voltage_V=18;
    case "holdout_load4ohm"
        p.load.resistance_Ohm=4;
    case "holdout_gate47"
        p.driver.externalResistance_Ohm=47;
    case "holdout_bus30_load16_gate10"
        p.bus.voltage_V=30;p.load.resistance_Ohm=16;p.driver.externalResistance_Ohm=10;
    otherwise
        error('SC01B:UnknownCase','Unknown source case: %s',name);
end
if name~="nominal",p.meta.role="withheld operating point; no model tuning";end
p.load.referenceCurrent_A=p.bus.voltage_V/p.load.resistance_Ohm;
end
