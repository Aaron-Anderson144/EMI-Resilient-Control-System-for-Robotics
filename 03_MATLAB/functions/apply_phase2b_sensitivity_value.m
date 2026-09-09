function params = apply_phase2b_sensitivity_value(params, definition, value)
%APPLY_PHASE2B_SENSITIVITY_VALUE Apply a catalog value in its displayed unit.
arguments
    params (1,1) struct
    definition table
    value (1,1) double {mustBeFinite}
end
assert(height(definition)==1, 'EMIProject:SensitivityDefinitionRows', ...
    'Exactly one catalog row is required.');
assert(value >= definition.Low && value <= definition.High, ...
    'EMIProject:SensitivityOutsideRange', 'Value is outside its declared range.');
x = value * definition.SIConversion;
switch definition.Key
    case "cap_imbalance"
        pair = params.phase2b.coupling.capacitive;
        center = (pair.linePositive_F + pair.lineNegative_F)/2;
        params.phase2b.coupling.capacitive.linePositive_F = center+x/2;
        params.phase2b.coupling.capacitive.lineNegative_F = center-x/2;
    case "ind_imbalance"
        pair = params.phase2b.coupling.inductive;
        center = (pair.linePositive_H + pair.lineNegative_H)/2;
        params.phase2b.coupling.inductive.linePositive_H = center+x/2;
        params.phase2b.coupling.inductive.lineNegative_H = center-x/2;
    case "cap_mean"
        pair = params.phase2b.coupling.capacitive;
        delta = pair.linePositive_F-pair.lineNegative_F;
        params.phase2b.coupling.capacitive.linePositive_F = x+delta/2;
        params.phase2b.coupling.capacitive.lineNegative_F = x-delta/2;
    case "ind_mean"
        pair = params.phase2b.coupling.inductive;
        delta = pair.linePositive_H-pair.lineNegative_H;
        params.phase2b.coupling.inductive.linePositive_H = x+delta/2;
        params.phase2b.coupling.inductive.lineNegative_H = x-delta/2;
    otherwise
        parts = cellstr(split(definition.ParameterPath, '.'));
        params.phase2b = setfield(params.phase2b, parts{:}, x);
end
validate_parameters(params);
end
