function [next, ledger] = phase3_stop_hold_step(x, h, params, loadTorque, capacity, externalResistance)
%PHASE3_STOP_HOLD_STEP Passive stop/hold step with bounded brake torque.
% Backward Euler resolves Coulomb/static friction as one implicit inclusion.
% State: [position_rad; velocity_rad_s; current_A]. No external voltage source
% is applied. A passive series resistor gives terminal voltage -Rext*i_next.
% Capacity is the symmetric brake torque bound, not an instantaneous reset.
% Reciprocal SI motor constants Kt==Ke are required for the energy ledger.
inputId='EMIProject:InvalidStopHoldInput';
assert(isnumeric(x) && isreal(x) && isvector(x) && numel(x)==3 && all(isfinite(x)),inputId, ...
    'The state must contain three finite real numeric values.');
assert(localScalar(h) && h>0,inputId,'The integration step must be a positive finite real scalar.');
assert(localScalar(loadTorque),inputId,'Applied load torque must be a finite real scalar.');
assert(localScalar(capacity) && capacity>=0,inputId,'Brake torque capacity must be finite and nonnegative.');
assert(localScalar(externalResistance) && externalResistance>=0,inputId, ...
    'External resistance must be finite and nonnegative.');
R=localParameter(params,'electrical','resistance_Ohm',false);
L=localParameter(params,'electrical','inductance_H',false);
J=localParameter(params,'mechanical','inertia_kg_m2',false);
b=localParameter(params,'mechanical','viscousDamping_Nm_s_rad',true);
Kt=localParameter(params,'motor','torqueConstant_Nm_A',false);
Ke=localParameter(params,'motor','backEmfConstant_V_s_rad',false);
assert(Kt==Ke,'EMIProject:NonreciprocalStopHoldModel', ...
    'The passive energy ledger requires numerically equal SI torque and back-emf constants.');
x=double(x(:));h=double(h);loadTorque=double(loadTorque);
capacity=double(capacity);externalResistance=double(externalResistance);
Rtotal=R+externalResistance;
decayDenominator=1+h*Rtotal/L;
fluxDenominator=L+h*Rtotal;
i0=x(3)/decayDenominator;
g=h*Ke/fluxDenominator;
D=J/h+b+Kt*g;
F=J*x(2)/h+Kt*i0-loadTorque;
overflowId='EMIProject:StopHoldOverflow';
assert(all(isfinite([Rtotal,decayDenominator,fluxDenominator,i0,g,D,F])) && ...
    decayDenominator>0 && fluxDenominator>0 && D>0,overflowId, ...
    'The implicit stop/hold coefficients must remain finite and representable.');
velocity=sign(F)*max(abs(F)-capacity,0)/D;
brakeTorque=min(max(F,-capacity),capacity);
current=i0-g*velocity;
next=[x(1)+h*velocity;velocity;current];
deltaVelocity=velocity-x(2);deltaCurrent=current-x(3);
ledger.brakeTorque_Nm=brakeTorque;
ledger.motorTerminalVoltage_V=-externalResistance*current;
ledger.loadWork_J=-loadTorque*velocity*h;
ledger.copperLoss_J=R*current^2*h;
ledger.resistorLoss_J=externalResistance*current^2*h;
ledger.viscousLoss_J=b*velocity^2*h;
ledger.brakeLoss_J=brakeTorque*velocity*h;
ledger.numericalLoss_J=.5*J*deltaVelocity^2+.5*L*deltaCurrent^2;
% Factoring differences of squares reduces cancellation for small steps.
ledger.energyChange_J=.5*J*deltaVelocity*(velocity+x(2))+.5*L*deltaCurrent*(current+x(3));
ledger.energyResidual_J=ledger.energyChange_J-ledger.loadWork_J+ ...
    ledger.copperLoss_J+ledger.resistorLoss_J+ledger.viscousLoss_J+ ...
    ledger.brakeLoss_J+ledger.numericalLoss_J;
assert(all(isfinite([next;cell2mat(struct2cell(ledger))])),overflowId, ...
    'Stop/hold state and energy-ledger arithmetic must remain finite.');
end

function value=localParameter(params,group,name,allowZero)
id='EMIProject:InvalidStopHoldParameters';
assert(isstruct(params) && isscalar(params) && isfield(params,group) && ...
    isstruct(params.(group)) && isscalar(params.(group)) && isfield(params.(group),name),id, ...
    'A complete scalar physical parameter structure is required (%s.%s).',group,name);
value=params.(group).(name);
assert(localScalar(value) && (value>0 || (allowZero && value==0)),id, ...
    'Physical parameter %s.%s must be finite and positive (damping may be zero).',group,name);
value=double(value);
end

function valid=localScalar(value)
valid=isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
end
