function record = edmd_load_controller(csvPath)
%EDMD_LOAD_CONTROLLER Import synchronous four-way encoder/input observations.
% command_V(k) acts on [time_s(k), time_s(k+1)). No plant-truth or fault-label
% field enters y, u, or valid. Receiver domain is an offline eligibility gate.
% Delayed, missing, and nonfinite observations are marked invalid; callers
% must exclude every delay/target window containing an invalid observation.

csvPath = char(string(csvPath));
assert(isfile(csvPath), 'EDMD:MissingFile', 'Controller CSV does not exist.');
data = readtable(csvPath, 'VariableNamingRule', 'preserve');
required = {'time_s','receivedMeasurement_rad','command_V', ...
    'sampleReceived','sourceIndex'};
assert(all(ismember(required, data.Properties.VariableNames)), ...
    'EDMD:Columns', 'Required online observation columns are missing.');
assert(ismember('receiverDomainFailed', data.Properties.VariableNames), ...
    'EDMD:ReceiverDomain', ...
    'Four-way records require receiverDomainFailed to establish eligibility.');
for j = 1:numel(required)
    values = data.(required{j});
    assert(isnumeric(values) && isreal(values) && iscolumn(values), ...
        'EDMD:Columns', 'Required online observation columns must be numeric vectors.');
end
domain = data.receiverDomainFailed;
assert((isnumeric(domain) || islogical(domain)) && isreal(domain) && ...
    iscolumn(domain) && all(isfinite(domain)) && all(domain == 0), ...
    'EDMD:ReceiverDomain', ...
    'Receiver domain is invalid or unverified; the entire record is excluded.');

t = double(data.time_s);
y = double(data.receivedMeasurement_rad);
u = double(data.command_V);
n = numel(t);
assert(n >= 2 && all(isfinite(t)), 'EDMD:Time', ...
    'A record requires at least two finite timestamps.');
intervals = diff(t);
sampleTime = median(intervals);
tolerance = max(1e-9, 64*eps(max(1,max(abs(t)))));
assert(sampleTime > 0 && all(intervals > 0) && ...
    abs(sampleTime-0.001) <= tolerance && ...
    all(abs(intervals-sampleTime) <= tolerance), ...
    'EDMD:Time', 'Only consecutive, uniform 1 ms controller records are supported.');
received = double(data.sampleReceived);
sourceIndex = double(data.sourceIndex);
valid = isfinite(received) & received == 1 & isfinite(sourceIndex) & ...
    sourceIndex == (1:n)' & isfinite(y) & isfinite(u);
assert(all(isfinite(y(valid))) && all(isfinite(u(valid))), ...
    'EDMD:Finite', 'Valid observations must be finite.');
record = struct('y',y,'u',u,'t',t,'valid',logical(valid), ...
    'sampleTime',sampleTime,'sourcePath',string(csvPath),'domainValid',true);
end
