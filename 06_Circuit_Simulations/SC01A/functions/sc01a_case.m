function c = sc01a_case(name,p)
%SC01A_CASE Fixed deterministic test matrix; mechanisms disable sources.
arguments
    name (1,1) string
    p (1,1) struct
end
c.name=name;
c.params=p;
c.capacitive=false; c.inductive=false; c.shared=false;
c.polarity=1; c.logicSign=1; c.logicTransitionOffset_s=NaN;
c.periods=0; c.stopTime_s=p.simulation.singleStop_s;
switch name
    case "baseline"
    case "capacitive_rise"
        c.capacitive=true;
    case "inductive_rise"
        c.inductive=true;
    case "shared_rise"
        c.shared=true;
    case {"combined_rise","combined_fall","logic_low","transition_leads", ...
            "transition_coincident","transition_lags","stress_fall", ...
            "balanced_combined","zero_coupling","zero_source","pwm_10","pwm_20"}
        c.capacitive=true; c.inductive=true; c.shared=true;
    otherwise
        error('SC01A:UnknownCase','Unknown case: %s',name);
end
switch name
    case {"combined_fall","stress_fall"}
        c.polarity=-1;
    case "logic_low"
        c.logicSign=-1;
    case "transition_leads"
        c.logicTransitionOffset_s=-100e-9;
    case "transition_coincident"
        c.logicTransitionOffset_s=0;
    case "transition_lags"
        c.logicTransitionOffset_s=100e-9;
    case "balanced_combined"
        c.params.driver.Rp_Ohm=50; c.params.driver.Rn_Ohm=50;
        c.params.receiver.Cp_F=60e-12; c.params.receiver.Cn_F=60e-12;
        c.params.receiver.RpBias_Ohm=15e3; c.params.receiver.RnBias_Ohm=15e3;
        c.params.coupling.Cp_F=9.5e-12; c.params.coupling.Cn_F=9.5e-12;
        c.params.coupling.Mp_H=18.5e-9; c.params.coupling.Mn_H=18.5e-9;
    case "zero_coupling"
        c.params.coupling.Cp_F=0; c.params.coupling.Cn_F=0;
        c.params.coupling.Mp_H=0; c.params.coupling.Mn_H=0;
        c.shared=false;
    case "zero_source"
        c.params.source.voltageStep_V=0; c.params.source.currentStep_A=0;
    case "pwm_10"
        c.periods=10; c.stopTime_s=10/p.source.pwmFrequency_Hz;
    case "pwm_20"
        c.periods=20; c.stopTime_s=20/p.source.pwmFrequency_Hz;
end
if name=="stress_fall"
    c.params.coupling.Cp_F=300e-12;
    c.params.coupling.Cn_F=5e-12;
end
end
