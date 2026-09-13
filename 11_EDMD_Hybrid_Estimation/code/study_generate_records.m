function [records, meta] = study_generate_records(projectRoot, seeds, regimes, duration_s, options)
%STUDY_GENERATE_RECORDS Fresh hypothetical closed-loop actuator trajectories.
% The source project is read only. No EMI circuit, receiver domain, packet
% fault, or physical hardware is simulated. Truth/reference/load fields are
% OFFLINE diagnostics; learning must consume only y, u, t, and valid.
% Output records is a 1-by-N cell array in the same order as seeds.
% Optional fifth-argument struct: motionScenario ("multisine" default or
% "smooth_reversal"), loadScenario ("smooth" default or "step"), and
% controllerGainScale (positive scalar, default 1). Scenario specifications
% and offlineEventTimes never become online features or receiver faults.

if nargin < 4, duration_s = 3; end
if nargin < 5, options = struct(); end
options = localOptions(options);
validateattributes(seeds,{'numeric'},{'real','finite','vector','integer','nonnegative'});
assert(all(seeds <= 2^32-1),'EDMDStudy:Seeds','Seeds must fit the MATLAB generator range.');
seeds = double(seeds(:));
regimes = string(regimes(:));
assert(numel(regimes) == numel(seeds) && ~isempty(seeds), ...
    'EDMDStudy:Regimes','Provide one regime for each seed.');
assert(all(ismember(regimes,["nominal","varied","nonlinear","stress"])), ...
    'EDMDStudy:Regimes','An unsupported study regime was requested.');
validateattributes(duration_s,{'numeric'},{'real','finite','scalar','positive'});
dt = 0.001;
assert(abs(duration_s/dt-round(duration_s/dt)) < 1e-8, ...
    'EDMDStudy:Duration','Duration must be an integer number of milliseconds.');
parameterFolder = fullfile(char(string(projectRoot)),'03_MATLAB','parameters');
parameterFile = fullfile(parameterFolder,'actuator_parameters.m');
assert(isfile(parameterFile),'EDMDStudy:Parameters','The project parameter file is missing.');
oldPath = path;
restorePath = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(parameterFolder,'-begin');
assert(strcmp(which('actuator_parameters'),parameterFile), ...
    'EDMDStudy:Parameters','MATLAB resolved a different parameter file.');
base = actuator_parameters();
assert(base.sensor.encoderCountsPerRevolution == 4096 && ...
    abs(base.control.sampleTime_s-dt) < eps && ...
    base.control.voltageLimit_V == 24, ...
    'EDMDStudy:ParameterContract','The study assumes 4096 CPR, 1 ms sampling, and +/-24 V.');
t = (0:round(duration_s/dt))'*dt;
controller = struct('Kp_V_rad',12,'Kd_V_s_rad',0.25, ...
    'derivativeFilterTime_s',0.012,'voltageLimit_V',24, ...
    'feedback',"Quantized noisy encoder position and filtered backward measurement difference only");
controller.Kp_V_rad = controller.Kp_V_rad*options.controllerGainScale;
controller.Kd_V_s_rad = controller.Kd_V_s_rad*options.controllerGainScale;
controller.gainScale = options.controllerGainScale;
noiseCounts = 0.08;
records = cell(1,numel(seeds));
stats = struct([]);
for run = 1:numel(seeds)
    stream = RandStream('mt19937ar','Seed',seeds(run));
    p = localParameters(base,regimes(run),stream);
    [reference,referenceRate,referenceSpec] = localReference(t,regimes(run),stream);
    load = localLoad(t,p,stream);
    % Preserve the original random draws, even for deterministic alternatives,
    % so paired scenarios share parameters and observation-noise realizations.
    reversalTimes = zeros(1,0);loadTimes = zeros(1,0);
    if options.motionScenario == "smooth_reversal"
        [reference,referenceRate,referenceSpec,reversalTimes] = localReversal(t);
    end
    loadSpec = struct('scenario',options.loadScenario,'bound_Nm',p.loadBound_Nm);
    if options.loadScenario == "step"
        load = zeros(size(t));
        load(t>=1) = p.loadBound_Nm;
        load(t>=2) = -p.loadBound_Nm;
        if p.loadBound_Nm > 0
            loadTimes = [1,2];loadTimes = loadTimes(loadTimes<=t(end));
        end
        loadSpec.scheduledTransitionTimes_s = [1,2];
        loadSpec.levels_Nm = [0,p.loadBound_Nm,-p.loadBound_Nm];
    end
    scenarioSpec = struct('motionScenario',options.motionScenario, ...
        'loadScenario',options.loadScenario,'controllerGainScale',options.controllerGainScale, ...
        'motion',referenceSpec,'load',loadSpec, ...
        'scope',"Offline commanded-motion and mechanical-load scenarios; no receiver faults");
    eventTimes = struct('loadTransition_s',loadTimes,'commandedReversal_s',reversalTimes);
    quantum = 2*pi/base.sensor.encoderCountsPerRevolution;
    noise = noiseCounts*quantum*randn(stream,numel(t),1);
    noise(1) = 0; % Known zero initialization; no truth is fed back later.
    truth = zeros(numel(t),3); y = zeros(numel(t),1); u = zeros(numel(t),1);
    rawCommand = zeros(numel(t),1); filteredVelocity = 0;
    derivativeDecay = exp(-dt/controller.derivativeFilterTime_s);
    x = zeros(3,1);
    for k = 1:numel(t)
        truth(k,:) = x';
        y(k) = quantum*round(x(1)/quantum)+noise(k);
        if k > 1
            measuredDerivative = (y(k)-y(k-1))/dt;
            filteredVelocity = derivativeDecay*filteredVelocity + ...
                (1-derivativeDecay)*measuredDerivative;
        end
        rawCommand(k) = controller.Kp_V_rad*(reference(k)-y(k)) - ...
            controller.Kd_V_s_rad*filteredVelocity;
        u(k) = max(-controller.voltageLimit_V,min(controller.voltageLimit_V,rawCommand(k)));
        if k < numel(t)
            x = localIntegrate(x,u(k),load(k),dt,p,4);
            assert(all(isfinite(x)),'EDMDStudy:NonfiniteState', ...
                'Integration failed; no failed trajectory is silently discarded.');
        end
    end
    currentStats = struct('seed',seeds(run),'regime',regimes(run), ...
        'maxAbsPosition_rad',max(abs(truth(:,1))), ...
        'maxAbsVelocity_rad_s',max(abs(truth(:,2))), ...
        'maxAbsCurrent_A',max(abs(truth(:,3))), ...
        'maxAbsReference_rad',max(abs(reference)), ...
        'maxAbsReferenceRate_rad_s',max(abs(referenceRate)), ...
        'maxAbsCommand_V',max(abs(u)), ...
        'saturationFraction',mean(abs(rawCommand) > controller.voltageLimit_V), ...
        'saturatedSampleCount',sum(abs(rawCommand) > controller.voltageLimit_V), ...
        'maxAbsUnknownLoad_Nm',max(abs(load)));
    records{run} = struct('y',y,'u',u,'t',t,'valid',true(numel(t),1), ...
        'sampleTime',dt,'domainValid',true, ...
        'sourcePath',"hypothetical_generated_"+regimes(run)+"_seed_"+string(seeds(run)), ...
        'truth',truth,'reference',reference,'referenceRate',referenceRate, ...
        'offlineLoadTorque_Nm',load,'parameters',p,'regime',regimes(run), ...
        'seed',seeds(run),'id',regimes(run)+"_seed_"+string(seeds(run)), ...
        'referenceSpecification',referenceSpec, ...
        'scenarioSpecification',scenarioSpec,'offlineEventTimes',eventTimes, ...
        'statistics',currentStats,'rk4Substeps',4, ...
        'domainScope',"No receiver-domain model invoked; domainValid is synthetic-data eligibility only");
    if run == 1
        stats = repmat(currentStats,numel(seeds),1);
    else
        stats(run) = currentStats;
    end
end
meta = struct('studyScope',"Hypothetical representative actuator study; no hardware evidence or EMI exposure", ...
    'parameterSource',string(parameterFile),'sourceParameterSet',base.meta.parameterSetId, ...
    'parameterProvenance',base.meta.provenance,'sampleTime_s',dt, ...
    'duration_s',duration_s,'seeds',seeds','regimes',regimes', ...
    'integration',"RK4 with four substeps per 1 ms held-command and held-load interval", ...
    'observation',"4096 CPR nearest-count position plus seeded Gaussian observation noise", ...
    'noiseStandardDeviation_counts',noiseCounts,'controller',controller, ...
    'scenarioOptions',options, ...
    'domainValidMeaning',"No receiver model or exposure is invoked; not a receiver-domain validation result", ...
    'onlineFeatureContract',"Only y/u/t/valid enter learned predictors; truth/reference/load/scenarioSpecification/offlineEventTimes are offline only", ...
    'regimeAssumptions',struct( ...
        'nominal',"Original assumed project parameters, zero unknown load, zero Coulomb friction", ...
        'varied',"R and J +/-20%; b 0.5 to 1.5 times nominal; varying load bounded by 0.005 Nm", ...
        'nonlinear',"Varied parameters plus 0.003 to 0.008 Nm smooth Coulomb friction tanh(omega/0.15)", ...
        'stress',"R and J +/-35%; b 0.5 to 1.5 nominal; friction 0.012 Nm; load <=0.012 Nm; faster references"), ...
    'runStatistics',stats);
end

function options = localOptions(options)
assert(isstruct(options) && isscalar(options),'EDMDStudy:Options', ...
    'Scenario options must be a scalar struct.');
defaults = struct('motionScenario',"multisine",'loadScenario',"smooth",'controllerGainScale',1);
assert(all(ismember(fieldnames(options),fieldnames(defaults))), ...
    'EDMDStudy:Options','An unsupported scenario option was requested.');
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options,names{k}),options.(names{k}) = defaults.(names{k});end
end
for name = ["motionScenario","loadScenario"]
    value = options.(name);
    assert((isstring(value) && isscalar(value)) || (ischar(value) && isrow(value)), ...
        'EDMDStudy:Options','Scenario names must be scalar strings or character rows.');
    options.(name) = string(value);
end
assert(ismember(options.motionScenario,["multisine","smooth_reversal"]) && ...
    ismember(options.loadScenario,["smooth","step"]), ...
    'EDMDStudy:Options','An unsupported motion or load scenario was requested.');
scale = options.controllerGainScale;
assert(isnumeric(scale) && isreal(scale) && isscalar(scale) && isfinite(scale) && scale>0, ...
    'EDMDStudy:Options','Controller gain scale must be a finite positive scalar.');
options.controllerGainScale = double(scale);
% Canonical field order makes explicit defaults and omitted options identical.
options = orderfields(options,defaults);
end

function [reference,rate,spec,reversalTimes] = localReversal(t)
% Quintic rest-to-rest transitions have continuous position, velocity and
% acceleration, with maximum speed 1.875*abs(deltaPosition)/segmentTime.
segmentTime = 0.75;amplitude = deg2rad(40);
waypointCount = ceil(t(end)/segmentTime)+2;
waypointTimes = (0:waypointCount-1)*segmentTime;
waypointPositions = [0,amplitude*(-1).^(0:waypointCount-2)];
segment = floor(t/segmentTime)+1;
phase = (t-waypointTimes(segment)')/segmentTime;
startPosition = waypointPositions(segment)';
delta = waypointPositions(segment+1)'-startPosition;
shape = phase.^3.*(10-15*phase+6*phase.^2);
shapeRate = 30*phase.^2.*(1-phase).^2/segmentTime;
reference = startPosition+delta.*shape;
rate = delta.*shapeRate;
reversalTimes = waypointTimes(2:end-1);
reversalTimes = reversalTimes(reversalTimes<=t(end));
spec = struct('profile',"Piecewise quintic rest-to-rest alternating position waypoints", ...
    'waypointTimes_s',waypointTimes,'waypointPositions_rad',waypointPositions, ...
    'segmentDuration_s',segmentTime,'amplitude_rad',amplitude, ...
    'normalizedPolynomialCoefficients',[0,0,0,10,-15,6], ...
    'maximumRate_rad_s',1.875*(2*amplitude)/segmentTime, ...
    'rateLimit_rad_s',10,'positionLimit_rad',deg2rad(60));
end

function p = localParameters(base,regime,stream)
p = struct('R_Ohm',base.electrical.resistance_Ohm, ...
    'L_H',base.electrical.inductance_H, ...
    'Kt_Nm_A',base.motor.torqueConstant_Nm_A, ...
    'Ke_V_s_rad',base.motor.backEmfConstant_V_s_rad, ...
    'J_kg_m2',base.mechanical.inertia_kg_m2, ...
    'b_Nm_s_rad',base.mechanical.viscousDamping_Nm_s_rad, ...
    'coulombFriction_Nm',0,'frictionSmoothing_rad_s',0.15, ...
    'loadBound_Nm',0);
if regime ~= "nominal"
    spread = 0.20;
    if regime == "stress", spread = 0.35; end
    p.R_Ohm = p.R_Ohm*(1+spread*(2*rand(stream)-1));
    p.J_kg_m2 = p.J_kg_m2*(1+spread*(2*rand(stream)-1));
    p.b_Nm_s_rad = p.b_Nm_s_rad*(0.5+rand(stream));
    p.loadBound_Nm = 0.005;
end
if regime == "nonlinear", p.coulombFriction_Nm = 0.003+0.005*rand(stream); end
if regime == "stress"
    p.coulombFriction_Nm = 0.012;
    p.loadBound_Nm = 0.012;
end
end

function [reference,rate,spec] = localReference(t,regime,stream)
frequencies = [0.25,0.70,1.25,1.80]+[0.15,0.25,0.35,0.45].*rand(stream,1,4);
if regime == "stress", frequencies = frequencies*1.6; end
phases = 2*pi*rand(stream,1,4);
weights = [1,0.65,0.40,0.25].*(0.6+0.8*rand(stream,1,4));
amplitudes = deg2rad(40+20*rand(stream))*weights/sum(weights);
arguments = 2*pi*t*frequencies+phases;
raw = sin(arguments)*amplitudes';
rawRate = cos(arguments)*(2*pi*frequencies.*amplitudes)';
envelope = 1-exp(-(t/0.25).^2);
envelopeRate = 2*t/(0.25^2).*exp(-(t/0.25).^2);
reference = envelope.*raw;
rate = envelopeRate.*raw+envelope.*rawRate;
scale = min([1,10/max(max(abs(rate)),eps),deg2rad(60)/max(max(abs(reference)),eps)]);
reference = scale*reference; rate = scale*rate;
spec = struct('frequencies_Hz',frequencies,'phases_rad',phases, ...
    'amplitudes_rad',scale*amplitudes,'envelopeTime_s',0.25, ...
    'rateLimit_rad_s',10,'positionLimit_rad',deg2rad(60));
end

function load = localLoad(t,p,stream)
if p.loadBound_Nm == 0, load = zeros(size(t)); return; end
frequencies = [0.35+0.35*rand(stream),1.1+0.8*rand(stream)];
phases = 2*pi*rand(stream,1,2);
load = p.loadBound_Nm*(0.65*sin(2*pi*frequencies(1)*t+phases(1)) + ...
    0.35*sin(2*pi*frequencies(2)*t+phases(2))).*(1-exp(-(t/0.15).^2));
end

function x = localIntegrate(x,u,load,dt,p,substeps)
h = dt/substeps;
for substep = 1:substeps
    a = localDerivative(x,u,load,p);
    b = localDerivative(x+0.5*h*a,u,load,p);
    c = localDerivative(x+0.5*h*b,u,load,p);
    d = localDerivative(x+h*c,u,load,p);
    x = x+(h/6)*(a+2*b+2*c+d);
end
end

function derivative = localDerivative(x,u,load,p)
friction = p.coulombFriction_Nm*tanh(x(2)/p.frictionSmoothing_rad_s);
derivative = [x(2); ...
    (p.Kt_Nm_A*x(3)-p.b_Nm_s_rad*x(2)-friction-load)/p.J_kg_m2; ...
    (u-p.R_Ohm*x(3)-p.Ke_V_s_rad*x(2))/p.L_H];
end
