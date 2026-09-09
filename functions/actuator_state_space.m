function plant = actuator_state_space(params)
%ACTUATOR_STATE_SPACE Create the continuous three-state actuator model.
%
% State order: [position_rad; velocity_rad_s; current_A]
% Input order: [drive_voltage_V; load_torque_Nm]

validate_parameters(params);

R = params.electrical.resistance_Ohm;
L = params.electrical.inductance_H;
Kt = params.motor.torqueConstant_Nm_A;
Ke = params.motor.backEmfConstant_V_s_rad;
J = params.mechanical.inertia_kg_m2;
b = params.mechanical.viscousDamping_Nm_s_rad;

A = [
    0,       1,       0
    0,    -b/J,    Kt/J
    0,   -Ke/L,    -R/L
];

B = [
      0,      0
      0,   -1/J
    1/L,      0
];

C = eye(3);
D = zeros(3, 2);

plant = ss(A, B, C, D);
plant.StateName = {'position_rad', 'velocity_rad_s', 'current_A'};
plant.InputName = {'drive_voltage_V', 'load_torque_Nm'};
plant.OutputName = plant.StateName;
plant.Name = 'Three-state DC-equivalent robotic actuator';
end

