function [prepared, traces] = hybrid_prepare_records(records)
%HYBRID_PREPARE_RECORDS Convert clean measured records into innovation records.
% The residual target is y(k)-C*prior(k), never a truth-state discrepancy.
% The first 100 samples are invalidated as observer warmup. Downstream delay
% and target windows must reject any sample intersecting this invalid region.
% Output contains only observed innovation/input/time plus eligibility and
% identifying metadata. True states, reference, and hidden load are not copied.

assert(iscell(records) && isvector(records) && ~isempty(records), ...
    'EDMDHybrid:Records','Expected a nonempty cell vector of measured records.');
prepared = cell(1,numel(records)); traces = cell(1,numel(records));
for k = 1:numel(records)
    record = records{k};
    [trace,config] = hybrid_reference_observer(record);
    n = numel(trace.innovation);
    assert(n >= 102,'EDMDHybrid:Warmup', ...
        'A record needs at least two observations after its 100-sample warmup.');
    valid = trace.valid;
    valid(1:100) = false;
    converted = struct('y',trace.innovation,'u',double(record.u(:)), ...
        't',double(record.t(:)),'valid',valid,'sampleTime',config.sampleTime, ...
        'domainValid',true,'warmupSamples',100, ...
        'targetDescription',"Measured innovation relative to nominal observer prior", ...
        'domainScope',"Inherited study eligibility; no receiver validation is implied");
    for name = ["id","regime","seed","sourcePath"]
        if isfield(record,name), converted.(name) = record.(name); end
    end
    prepared{k} = converted;
    traces{k} = trace;
end
end
