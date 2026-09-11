function validate_phase3_reference_profile(r,n)
%VALIDATE_PHASE3_REFERENCE_PROFILE Validate complete exogenous sensor arrays.
id='EMIProject:InvalidReferenceProfile';
assert(isstruct(r)&&isscalar(r),id,'Independent reference must be a scalar profile.');
for name=["sampleReceived","request"]
 assert(isfield(r,name)&&islogical(r.(name))&&isequal(size(r.(name)),[n,1]), ...
  id,'%s must be a logical column covering the full run.',name);
end
for name=["sourceIndex","error_rad","uncertainty_rad"]
 assert(isfield(r,name)&&isnumeric(r.(name))&&isreal(r.(name))&& ...
  isequal(size(r.(name)),[n,1])&&all(isfinite(r.(name))), ...
  id,'%s must be a finite real column covering the full run.',name);
end
% Negative/out-of-contract uncertainty and bad timestamps deliberately reach
% the online rejection path; shape/nonfinite fixture errors fail at setup.
end
