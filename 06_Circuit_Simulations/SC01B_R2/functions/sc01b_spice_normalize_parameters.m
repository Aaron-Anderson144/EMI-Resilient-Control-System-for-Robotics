function p=sc01b_spice_normalize_parameters(p)
%SC01B_SPICE_NORMALIZE_PARAMETERS Make independent-engine defaults explicit.
if ~isfield(p.simulation,'voltageTolerance'),p.simulation.voltageTolerance=1e-7;end
if ~isfield(p.simulation,'spiceOutputStep_s'),p.simulation.spiceOutputStep_s=1e-9;end
assert(isfinite(p.simulation.voltageTolerance) && p.simulation.voltageTolerance>0 && ...
    isfinite(p.simulation.spiceOutputStep_s) && p.simulation.spiceOutputStep_s>0, ...
    'SC01B:SpiceSettings','SPICE voltage tolerance and output step must be positive and finite.');
end
