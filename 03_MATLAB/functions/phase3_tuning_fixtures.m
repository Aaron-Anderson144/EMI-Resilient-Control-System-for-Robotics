function fixtures = phase3_tuning_fixtures()
%PHASE3_TUNING_FIXTURES Fixed controller-tuning and evaluation declarations.
% These deterministic software fixtures are declared before policy results.
% Partition and targetWindow_s are offline study metadata, never controller
% inputs. Evaluation cases must not be used to revise the selected policy.
% The assumed actuator and zero-voltage stop are not hardware validation.

f = base("freeze_during_motion","tuning",[.13,.70]);
f.scenario.encoder = encoder_fault_scenario("dropout",f.params);
f.scenario.encoder.dropout.startTime_s = .13;
f.scenario.encoder.dropout.stopTime_s = .45;
f.description = "Historical positive 30-degree motion freeze; includes response before the latched stop.";
fixtures = f;

f = base("encoder_count_jump","tuning",[.45,.85]);
f.scenario.encoder = encoder_fault_scenario("count_jump",f.params);
f.scenario.expectation = "observe";
f.description = "Historical 128-count encoder jump at 0.45 s; matched reference and plant remain unchanged.";
fixtures(end+1) = f;

f = base("out_of_range_measurement","tuning",[.45,.85]);
f.scenario.biasStartTime_s = .45;
f.scenario.biasStopTime_s = .451;
f.scenario.bias_rad = 4;
f.description = "Historical one-sample 4-radian additive measurement error; tests rejection and mode transfer.";
fixtures(end+1) = f;

f = base("short_packet_burst","tuning",[.25,.75]);
f.scenario = packetBurst(f.scenario,.25,.34);
f.description = "Ninety-millisecond missing-packet burst during positive motion; freshness and subsequent recovery.";
fixtures(end+1) = f;

f = base("reversal_during_recovery","tuning",[.45,.90]);
f.scenario.encoder = encoder_fault_scenario("count_jump",f.params);
f.scenario.expectation = "observe";
f.scenario.referenceTimes_s = [0;.1;.48];
f.scenario.referenceValues_rad = deg2rad([0;30;-30]);
f.description = "128-count jump at 0.45 s and commanded reversal at 0.48 s during the nominal recovery interval.";
fixtures(end+1) = f;

f = base("capped_reversal","tuning",[.24,.85],2);
f.scenario.referenceTimes_s = [0;.1;.28];
f.scenario.referenceValues_rad = deg2rad([0;60;-60]);
f.scenario = packetBurst(f.scenario,.24,.34);
f.description = "Synthetic command-limiting stress: 2 V software limit, +60 to -60 degrees during a packet burst; not a hardware operating point.";
fixtures(end+1) = f;

f = base("loaded_supply_interruption","tuning",[2.0,2.4]);
f.scenario.phase2b = phase2b_scenario("supply_interruption",f.params);
f.scenario.loadTorque_Nm = .01;
f.scenario.assumedLoadTorque_Nm = .01;
f.description = "Historical loaded supply interruption; target window follows the fixed reset. Full-record loaded drift remains a separate stop/hold limitation.";
fixtures(end+1) = f;

f = base("clean_reference_reversal","tuning",[1.6,2.1]);
f.expectClean = true;
f.scenario.expectation = "clean";
f.scenario.referenceTimes_s = [0;.1;1.6];
f.scenario.referenceValues_rad = deg2rad([0;30;-15]);
f.description = "Historical clean reference reversal; guard against nuisance mode changes and ordinary tracking regression.";
fixtures(end+1) = f;

f = base("eval_negative_freeze","evaluation",[.14,.70]);
f.scenario.referenceValues_rad = deg2rad([0;-30]);
f.scenario.encoder = encoder_fault_scenario("dropout",f.params);
f.scenario.encoder.dropout.startTime_s = .14;
f.scenario.encoder.dropout.stopTime_s = .42;
f.description = "Predeclared evaluation: negative 30-degree motion freeze with changed onset and duration.";
fixtures(end+1) = f;

f = base("eval_short_freeze","evaluation",[.16,.65]);
f.scenario.referenceValues_rad = deg2rad([0;45]);
f.scenario.encoder = encoder_fault_scenario("dropout",f.params);
f.scenario.encoder.dropout.startTime_s = .16;
f.scenario.encoder.dropout.stopTime_s = .23;
f.description = "Predeclared evaluation: positive 45-degree motion and a shorter 70 ms encoder freeze.";
fixtures(end+1) = f;

f = base("eval_reversed_burst","evaluation",[.54,1.0]);
f.scenario.referenceTimes_s = [0;.1;.60];
f.scenario.referenceValues_rad = deg2rad([0;45;-45]);
f.scenario = packetBurst(f.scenario,.54,.65);
f.description = "Predeclared evaluation: +45 to -45 degree reversal during a later missing-packet burst.";
fixtures(end+1) = f;

f = base("eval_known_positive_load","evaluation",[.27,.80]);
f.scenario.loadTorque_Nm = .01;
f.scenario.assumedLoadTorque_Nm = .01;
f.scenario = packetBurst(f.scenario,.27,.36);
f.description = "Predeclared evaluation: known +0.01 Nm load and packet burst; model and plant receive the same declared load.";
fixtures(end+1) = f;

f = base("eval_known_negative_load","evaluation",[.27,.80]);
f.scenario.loadTorque_Nm = -.01;
f.scenario.assumedLoadTorque_Nm = -.01;
f.scenario.referenceValues_rad = deg2rad([0;-30]);
f.scenario = packetBurst(f.scenario,.27,.36);
f.description = "Predeclared evaluation: known -0.01 Nm load, negative reference and the same declared packet burst.";
fixtures(end+1) = f;

f = base("eval_unknown_load_freeze","evaluation",[.16,.75]);
f.scenario.loadTorque_Nm = .001;
f.scenario.assumedLoadTorque_Nm = 0;
f.scenario.encoder = encoder_fault_scenario("dropout",f.params);
f.scenario.encoder.dropout.startTime_s = .16;
f.scenario.encoder.dropout.stopTime_s = .27;
f.scenario.expectation = "observe";
f.description = "Predeclared evaluation: +0.001 Nm actual load omitted from the observer model, with encoder freeze; no clean/detection guarantee.";
fixtures(end+1) = f;

f = base("eval_model_mismatch_burst","evaluation",[.30,.85]);
f.scenario.actualParameters.electrical.resistance_Ohm = ...
    1.05*f.params.electrical.resistance_Ohm;
f.scenario.actualParameters.mechanical.inertia_kg_m2 = ...
    1.10*f.params.mechanical.inertia_kg_m2;
f.scenario = packetBurst(f.scenario,.30,.38);
f.scenario.expectation = "observe";
f.description = "Predeclared evaluation: actual resistance +5% and inertia +10% with nominal observer parameters and a short packet burst; model-mismatch diagnostic.";
fixtures(end+1) = f;

f = base("eval_permitted_delay_jitter","evaluation",[.70,1.30]);
f.expectClean = true;
f.scenario.expectation = "clean";
f.scenario.phase2b = phase2b_scenario("communication_delay",f.params);
f.scenario.phase2b.communication.jitterEnabled = true;
f.scenario.referenceTimes_s = [0;.1;.9];
f.scenario.referenceValues_rad = deg2rad([0;30;-30]);
f.description = "Predeclared permitted-condition evaluation: 8 ms fixed delay with bounded seeded jitter and reversal at 0.9 s.";
fixtures(end+1) = f;

f = base("eval_benign_noise_reversal","evaluation",[1.4,1.9]);
f.expectClean = true;
f.scenario.expectation = "clean";
f.scenario.benignNoiseStandardDeviation_rad = deg2rad(.005);
f.scenario.noiseSeed = 260921;
f.scenario.referenceTimes_s = [0;.1;1.4];
f.scenario.referenceValues_rad = deg2rad([0;45;-45]);
f.description = "Predeclared benign-condition evaluation: 0.005-degree noise standard deviation, new fixed seed 260921 and a later 45-degree reversal.";
fixtures(end+1) = f;

f = base("eval_opposite_capped_reversal","evaluation",[.27,.90],2);
f.scenario.referenceTimes_s = [0;.1;.31];
f.scenario.referenceValues_rad = deg2rad([0;-60;60]);
f.scenario = packetBurst(f.scenario,.27,.38);
f.description = "Predeclared synthetic command-limiting evaluation: 2 V software limit and opposite -60 to +60 degree reversal during a shifted packet burst; not hardware qualification.";
fixtures(end+1) = f;

f = base("eval_independent_reference_recovery","evaluation",[2.0,2.4]);
f.scenario.encoder = encoder_fault_scenario("dropout",f.params);
f.scenario.expectation = "observe";
f.useIndependentReference = true;
f.referenceOptions = struct('startTime_s',1.2,'stopTime_s',1.8, ...
    'requestTime_s',1.5,'uncertainty_rad',deg2rad(.005));
f.description = "Predeclared evaluation: historical low-motion dropout with an assumed independent synchronized position reference, 1.5 s re-anchor request and separate 2 s reset.";
fixtures(end+1) = f;

f = base("eval_independent_reference_no_reset","evaluation",[2.0,2.4]);
f.scenario.encoder = encoder_fault_scenario("dropout",f.params);
f.scenario.expectation = "observe";
f.scenario.resetRequestTime_s = Inf;
f.useIndependentReference = true;
f.referenceOptions = struct('startTime_s',1.2,'stopTime_s',1.8, ...
    'requestTime_s',1.5,'uncertainty_rad',deg2rad(.005));
f.description = "Predeclared latch guard: same assumed independent-reference dropout reconstruction, with operator reset explicitly disabled; zero voltage still does not imply zero motion.";
fixtures(end+1) = f;

% Validate each complete declaration before returning anything to a study.
ids = strings(1,numel(fixtures));
for k = 1:numel(fixtures)
    fixtures(k).scenario.description = fixtures(k).description;
    validateFixture(fixtures(k));
    ids(k) = fixtures(k).id;
end
assert(numel(unique(ids))==numel(ids),'EMIProject:InvalidTuningFixtures', ...
    'Every tuning/evaluation fixture must have a unique id.');
assert(nnz(string({fixtures.partition})=="tuning")==8 && ...
    nnz(string({fixtures.partition})=="evaluation")==12, ...
    'EMIProject:InvalidTuningFixtures','The predeclared study has eight tuning and twelve evaluation fixtures.');
end

function f = base(id,partition,targetWindow_s,voltageLimit_V)
p = actuator_parameters();
p.simulation.stopTime_s = 3;
if nargin==4,p.control.voltageLimit_V=voltageLimit_V;end
s = phase3_scenario(id,p);
s.expectation = "detect";
f = struct('id',id,'partition',partition,'description',"", ...
    'params',p,'scenario',s,'targetWindow_s',targetWindow_s, ...
    'expectClean',false,'useIndependentReference',false,'referenceOptions',struct());
end

function s = packetBurst(s,startTime_s,stopTime_s)
s.packetDropStartTime_s = startTime_s;
s.packetDropStopTime_s = stopTime_s;
end

function validateFixture(f)
id = 'EMIProject:InvalidTuningFixtures';
assert(isstring(f.id)&&isscalar(f.id)&&strlength(f.id)>0 && ...
    isstring(f.partition)&&isscalar(f.partition)&& ...
    any(f.partition==["tuning","evaluation"]),id,'Fixture id and partition must be declared scalar strings.');
assert(isstring(f.description)&&isscalar(f.description)&&strlength(f.description)>0, ...
    id,'Every fixture needs an explicit description.');
validate_parameters(f.params);
validate_phase3_scenario(f.scenario,f.params);
assert(f.params.simulation.stopTime_s==3 && f.params.control.sampleTime_s==.001, ...
    id,'The study requires a three-second record with a one-millisecond sample time.');
w = f.targetWindow_s;
assert(isfloat(w)&&isreal(w)&&isequal(size(w),[1,2])&&all(isfinite(w))&& ...
    w(1)>=0&&w(2)>w(1)&&w(2)<=f.params.simulation.stopTime_s, ...
    id,'Each target window must be finite, increasing and inside its record.');
assert(all(abs(w/f.params.control.sampleTime_s-round(w/f.params.control.sampleTime_s))<1e-9), ...
    id,'Target windows must lie on the declared sample grid.');
assert(islogical(f.expectClean)&&isscalar(f.expectClean)&& ...
    islogical(f.useIndependentReference)&&isscalar(f.useIndependentReference), ...
    id,'Fixture clean/reference flags must be logical scalars.');
assert(f.expectClean==(f.scenario.expectation=="clean"),id,'Clean metadata must agree with the scenario expectation.');
assert(isstruct(f.referenceOptions)&&isscalar(f.referenceOptions),id,'Reference options must be a scalar structure.');
if f.useIndependentReference
    time_s = (0:3000)'*f.params.control.sampleTime_s;
    phase3_reference_profile(time_s,f.referenceOptions);
else
    assert(isempty(fieldnames(f.referenceOptions)),id,'Non-reference fixtures cannot carry active reference options.');
end
end
