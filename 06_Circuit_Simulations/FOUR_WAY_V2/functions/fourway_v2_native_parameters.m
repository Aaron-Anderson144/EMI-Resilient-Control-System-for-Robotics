function [p,design,receiver]=fourway_v2_native_parameters(cp,cn,cd)
% Independent explicit mapping of the frozen V2 circuit into SC01A ports.
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
design=jsondecode(fileread(fullfile(root,'04_EMI_Models','four_way_emi_v2_configuration.json')));
receiver=jsondecode(fileread(fullfile(root,design.receiver_config_file)));
v=design.victim;
p=sc01a_parameters();
p.driver.commonMode_V=v.driver_common_mode_V;
p.driver.differential_V=v.driver_open_circuit_differential_magnitude_V;
p.driver.transitionTime_s=v.driver_transition_s;
p.driver.Rp_Ohm=v.driver_Rp_Ohm;p.driver.Rn_Ohm=v.driver_Rn_Ohm;
p.receiver.Rdiff_Ohm=v.receiver_Rdiff_Ohm;
p.receiver.Cdiff_F=cd*1e-12;
p.receiver.Cp_F=v.receiver_Cp_F;p.receiver.Cn_F=v.receiver_Cn_F;
p.receiver.RpBias_Ohm=v.receiver_Rp_bias_Ohm;p.receiver.RnBias_Ohm=v.receiver_Rn_bias_Ohm;
p.coupling.Cp_F=cp*1e-12;p.coupling.Cn_F=cn*1e-12;
p.coupling.Mp_H=0;p.coupling.Mn_H=0;
p.ground.R_Ohm=v.ground_R_Ohm;p.ground.L_H=v.ground_L_H;
assert(v.aggressor_return_current_A==0&&v.inductive_ep_V==0&&v.inductive_en_V==0);
end
