function [output, config] = hybrid_reference_observer(record)
%HYBRID_REFERENCE_OBSERVER Causal nominal observer for clean shadow studies.
% config = hybrid_reference_observer() returns the observer configuration.
% [trace,config] = hybrid_reference_observer(record) processes one trajectory.
% State order is [position,velocity,current]. The prior at sample k uses only
% measurements through k-1 and the applied voltage u(k-1). Correction uses y(k).
% This healthy, ungated reference observer is not a protection controller.
% Invalid, asynchronous, nonfinite, or domain-ineligible records are rejected.
% No truth, hidden load, reference trajectory, or fault label is accessed.

config = localConfiguration();
if nargin == 0, output = config; return; end
[y,u,t] = localObservations(record,config);
n = numel(t);
prior = zeros(n,3); posterior = zeros(n,3); innovation = zeros(n,1);
state = config.initialState;
for k = 1:n
    if k > 1, state = config.A*state+config.B*u(k-1); end
    prior(k,:) = state';
    innovation(k) = y(k)-config.C*state;
    state = state+config.L*innovation(k);
    posterior(k,:) = state';
end
output = struct('prior',prior,'posterior',posterior, ...
    'innovation',innovation,'valid',true(n,1));
end

function config = localConfiguration()
bundleRoot = fileparts(fileparts(mfilename('fullpath')));
referenceRoot = fullfile(bundleRoot,'reference_project','03_MATLAB');
parameterFolder = fullfile(referenceRoot,'parameters');
functionFolder = fullfile(referenceRoot,'functions');
parameterFile = fullfile(parameterFolder,'actuator_parameters.m');
plantFile = fullfile(functionFolder,'actuator_state_space.m');
assert(isfile(parameterFile) && isfile(plantFile), ...
    'EDMDHybrid:MissingReference','Bundled representative actuator sources are missing.');
previousPath = path;
restorePath = onCleanup(@() path(previousPath)); %#ok<NASGU>
addpath(parameterFolder,functionFolder,'-begin');
assert(strcmpi(which('actuator_parameters'),parameterFile) && ...
    strcmpi(which('actuator_state_space'),plantFile), ...
    'EDMDHybrid:ReferenceResolution','A different actuator source was resolved.');
params = actuator_parameters();
dt = params.control.sampleTime_s;
assert(isfinite(dt) && abs(dt-0.001) < 1e-12 && ...
    params.sensor.encoderCountsPerRevolution == 4096, ...
    'EDMDHybrid:ReferenceContract','The bundled observer assumes 1 ms and 4096 CPR.');
[continuousA,continuousB] = ssdata(actuator_state_space(params));
heldInput = expm([continuousA,continuousB(:,1);zeros(1,4)]*dt);
A = heldInput(1:3,1:3); B = heldInput(1:3,4); C = [1,0,0];
requestedPoles = exp(-[80,100,120]*dt);
% posterior(k)=(I-L*C)*(A*posterior(k-1)+B*u(k-1))+L*y(k)
L = place(A',(C*A)',requestedPoles)';
actualPoles = eig((eye(3)-L*C)*A);
assert(max(abs(sort(actualPoles)-sort(requestedPoles(:)))) < 1e-8, ...
    'EDMDHybrid:ObserverPoles','Posterior observer poles do not match their specification.');
config = struct('A',A,'B',B,'C',C,'L',L,'sampleTime',dt, ...
    'quantum',2*pi/4096,'initialState',zeros(3,1), ...
    'posteriorPoles',actualPoles,'requestedPosteriorPoles',requestedPoles(:), ...
    'sourceParameterSet',params.meta.parameterSetId, ...
    'initialStateAssumption',"Known zero position, velocity, and current at record start", ...
    'scope',"Healthy ungated nominal observer for offline shadow experimentation", ...
    'domainPolicy',"Synthetic eligibility does not establish receiver-domain validity");
end

function [y,u,t] = localObservations(record,config)
assert(isstruct(record) && isscalar(record), ...
    'EDMDHybrid:Record','Expected one record structure.');
required = {'y','u','t','valid','sampleTime','domainValid'};
assert(all(isfield(record,required)), ...
    'EDMDHybrid:Record','Required online observation or eligibility fields are missing.');
domain = record.domainValid;
assert((islogical(domain) || isnumeric(domain)) && isreal(domain) && ...
    isscalar(domain) && isfinite(domain) && domain == 1, ...
    'EDMDHybrid:Domain','The entire record must have established study eligibility.');
dt = record.sampleTime;
assert(isnumeric(dt) && isreal(dt) && isscalar(dt) && isfinite(dt) && ...
    abs(dt-config.sampleTime) < 1e-12, ...
    'EDMDHybrid:SampleTime','Only uniform 1 ms records are supported.');
for name = ["y","u","t"]
    values = record.(name);
    assert(isnumeric(values) && isreal(values) && isvector(values) && ...
        all(isfinite(values)), 'EDMDHybrid:InvalidObservation', ...
        'All online measurements, commands, and timestamps must be finite real vectors.');
end
y = double(record.y(:)); u = double(record.u(:)); t = double(record.t(:));
n = numel(t);
assert(n >= 2 && numel(y) == n && numel(u) == n, ...
    'EDMDHybrid:Record','Online observation arrays must have matching lengths of at least two.');
valid = record.valid;
assert((islogical(valid) || isnumeric(valid)) && isreal(valid) && isvector(valid) && ...
    numel(valid) == n && all(isfinite(valid)) && all(valid == 1), ...
    'EDMDHybrid:InvalidObservation', ...
    'Only fully valid records are supported; gaps require a separately validated reset policy.');
tolerance = max(1e-10,64*eps(max(1,max(abs(t)))));
assert(abs(t(1)) <= tolerance && all(diff(t) > 0) && ...
    all(abs(diff(t)-config.sampleTime) <= tolerance), ...
    'EDMDHybrid:Timestamp','Timestamps must start at zero and advance consecutively by 1 ms.');
if isfield(record,'sourceIndex')
    source = record.sourceIndex;
    assert(isnumeric(source) && isreal(source) && isvector(source) && ...
        numel(source) == n && all(isfinite(source)) && ...
        isequal(double(source(:)),(1:n)'), 'EDMDHybrid:Timestamp', ...
        'Only fresh synchronous source indices are supported.');
end
if isfield(record,'sampleReceived')
    received = record.sampleReceived;
    assert((islogical(received) || isnumeric(received)) && isreal(received) && ...
        isvector(received) && numel(received) == n && all(isfinite(received)) && ...
        all(received == 1), 'EDMDHybrid:InvalidObservation', ...
        'Missing or held packets are outside this preprocessing contract.');
end
end
