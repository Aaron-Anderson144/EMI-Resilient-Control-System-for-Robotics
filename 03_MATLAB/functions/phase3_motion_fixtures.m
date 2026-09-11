function fixtures = phase3_motion_fixtures()
%PHASE3_MOTION_FIXTURES Predeclared motion-envelope study, no online truth.
% Development repeats the known rejection and its noiseless control. The
% eight new clean and eight new fault cases are evaluation; unknown load and
% model mismatch are separate diagnostics with no clean-performance claim.
% Metadata windows/deadlines are offline only. Every original request and
% non-reference disturbance is shared by governed and ungoverned runs.
ids = ["development_original_noise_reversal","development_noiseless_reversal", ...
    "clean_step_80","clean_reversal_75","clean_reversal_100", ...
    "clean_rapid_retargets","clean_known_positive_load","clean_known_negative_load", ...
    "clean_new_noise_reversal","clean_permitted_delay_jitter", ...
    "fault_count_jump_reversal","fault_out_of_range","fault_moving_freeze", ...
    "fault_short_packet_gap","fault_long_packet_gap","fault_loaded_supply_interruption", ...
    "fault_persistent_bias","fault_excessive_delay", ...
    "diagnostic_unknown_load","diagnostic_model_mismatch"];
windows = [1.4,1.9;1.4,1.9;.137,.837;1.117,1.917;1.263,2.163; ...
    .143,2.101;1.213,2.013;1.157,1.957;1.239,2.039;1.087,1.887; ...
    .997,1.527;.823,1.223;.231,.831;.547,1.057;.611,2.4;.873,2.4; ...
    .687,1.287;.733,1.533;1.173,1.973;1.293,2.093];
previous = phase3_tuning_fixtures();
known = previous(string({previous.id})=="eval_benign_noise_reversal");
assert(isscalar(known),'EMIProject:InvalidMotionFixtures','The historical development fixture must be unique.');
fixtures = repmat(base(ids(1),"development","clean",windows(1,:)),1,numel(ids));
for k = 1:numel(ids)
    partition = "evaluation";kind = "clean";
    if k<=2,partition="development";end
    if k>=11&&k<=18,kind="fault";end
    if k>=19,partition="diagnostic";kind="diagnostic";end
    f = base(ids(k),partition,kind,windows(k,:));
    switch k
        case 1
            % Preserve even the old scenario name/description: this is the
            % exact previously observed fixture, not new evaluation data.
            f.params=known.params;f.scenario=known.scenario;
            f.description="Development replay of the exact prior +45 to -45 degree reversal with 0.005-degree noise, seed 260921; historical rate-check rejection.";
        case 2
            f.params=known.params;f.scenario=known.scenario;
            f.scenario.name=f.id;f.scenario.benignNoiseStandardDeviation_rad=0;
            f.description="Development noiseless control: the same original reference/plant/seed/timing, with benign noise amplitude set to zero.";
        case 3
            f.scenario=reference(f.scenario,[0;.137],[0;80]);
            f.description="New nominal clean evaluation: 80-degree step requested at 0.137 s.";
        case 4
            f.scenario=reference(f.scenario,[0;.159;1.117],[0;75;-75]);
            f.description="New nominal clean evaluation: +75 to -75 degree reversal at 1.117 s.";
        case 5
            f.scenario=reference(f.scenario,[0;.183;1.263],[0;-100;100]);
            f.description="New nominal clean evaluation: -100 to +100 degree reversal, within the declared +/-120-degree request envelope.";
        case 6
            f.scenario=reference(f.scenario,[0;.143;.237;.331;.449;.587;1.401], ...
                [0;75;-80;110;-65;95;-30]);
            f.description="New nominal clean evaluation: repeated retargeting while the causal governor is moving; no preview of future request knots.";
        case 7
            f.scenario=reference(f.scenario,[0;.193;1.213],[0;70;-50]);
            f.scenario.loadTorque_Nm=.008;f.scenario.assumedLoadTorque_Nm=.008;
            f.description="New known-load clean evaluation: +0.008 Nm supplied consistently to plant and assumed observer; no unknown external-load claim.";
        case 8
            f.scenario=reference(f.scenario,[0;.171;1.157],[0;-85;60]);
            f.scenario.loadTorque_Nm=-.006;f.scenario.assumedLoadTorque_Nm=-.006;
            f.description="New known-load clean evaluation: -0.006 Nm supplied consistently to plant and assumed observer, with reversed motion.";
        case 9
            f.scenario=reference(f.scenario,[0;.167;1.239],[0;85;-65]);
            f.scenario.benignNoiseStandardDeviation_rad=deg2rad(.005);
            f.scenario.noiseSeed=260932;
            f.description="New clean-noise evaluation: +85 to -65 degree reversal with 0.005-degree Gaussian standard deviation and new fixed seed 260932; not a bounded-noise guarantee.";
        case 10
            f.scenario=reference(f.scenario,[0;.179;1.087],[0;90;-90]);
            f.params.phase2b.communication.startTime_s=.613;
            f.params.phase2b.communication.stopTime_s=1.413;
            f.params.phase2b.communication.jitterRandomSeed=260933;
            f.scenario.actualParameters=f.params;
            f.scenario.phase2b=phase2b_scenario("communication_delay",f.params);
            f.scenario.phase2b.communication.jitterEnabled=true;
            f.description="New permitted-channel clean evaluation: +/-90-degree request, 8 ms fixed delay plus up to 8 ms jitter, shifted window and new jitter seed 260933.";
        case 11
            f.scenario=reference(f.scenario,[0;.131;.997],[0;55;-65]);
            f.scenario.encoder=encoder_fault_scenario("count_jump",f.params);
            f.scenario.encoder.countJump.time_s=1.027;
            f.alarmDeadline_s=1.028;
            f.description="New corruption evaluation: 128-count primary-encoder impulse at 1.027 s during reversal; an earlier unrelated response receives no detection credit.";
        case 12
            f.scenario=reference(f.scenario,[0;.163],[0;70]);
            f.scenario.bias_rad=4;f.scenario.biasStartTime_s=.823;f.scenario.biasStopTime_s=.824;
            f.alarmDeadline_s=.824;
            f.description="New corruption evaluation: one-sample +4 rad primary measurement error at 0.823 s; retain the original range/rate/residual checks.";
        case 13
            f.scenario=reference(f.scenario,[0;.151],[0;95]);
            f.scenario.encoder=encoder_fault_scenario("dropout",f.params);
            f.scenario.encoder.dropout.startTime_s=.231;
            f.scenario.encoder.dropout.stopTime_s=.381;
            f.alarmDeadline_s=.281;
            f.description="New motion-freeze evaluation: fresh timestamps with a held primary position from 0.231 to 0.381 s during governed motion; no universal stationary-freeze claim.";
        case 14
            f.scenario=reference(f.scenario,[0;.149;1.187],[0;60;-40]);
            f.scenario.packetDropStartTime_s=.547;f.scenario.packetDropStopTime_s=.657;
            f.alarmDeadline_s=.572;
            f.description="New communication evaluation: 110 ms missing-packet gap from 0.547 s; observe the unchanged freshness deadline.";
        case 15
            f.scenario=reference(f.scenario,[0;.173],[0;35]);
            f.scenario.packetDropStartTime_s=.611;f.scenario.packetDropStopTime_s=1.001;
            f.alarmDeadline_s=.636;f.requireStop=true;f.requireResetRelease=true;
            f.description="New long-gap evaluation: missing primary packets for 390 ms, prediction expiry and latched stop; exact nominal prediction plus returned fresh packets must support the separate fixed reset at 2 s.";
        case 16
            f.scenario=reference(f.scenario,[0;.181],[0;40]);
            f.params.supply.startTime_s=.873;f.params.supply.stopTime_s=1.139;
            f.scenario.actualParameters=f.params;
            f.scenario.phase2b=phase2b_scenario("supply_interruption",f.params);
            f.scenario.loadTorque_Nm=.008;f.scenario.assumedLoadTorque_Nm=.008;
            f.alarmDeadline_s=.874;f.responseKind="stop";f.requireStop=true;
            f.description="New loaded-supply evaluation: interruption 0.873 to 1.139 s with known +0.008 Nm load; required response is stop, not an observer alarm. Loaded zero-voltage drift remains unresolved.";
        case 17
            f.scenario=reference(f.scenario,[0;.139],[0;40]);
            f.scenario.bias_rad=deg2rad(5);f.scenario.biasStartTime_s=.687;f.scenario.biasStopTime_s=3.1;
            f.alarmDeadline_s=.737;f.requireStop=true;
            f.description="New persistent-corruption evaluation: 5-degree primary bias from 0.687 s through record end; reset cannot establish credibility by itself.";
        case 18
            f.scenario=reference(f.scenario,[0;.157;1.287],[0;65;-45]);
            f.params.phase2b.communication.startTime_s=.733;
            f.params.phase2b.communication.stopTime_s=1.133;
            f.params.phase2b.communication.fixedDelay_samples=35;
            f.scenario.actualParameters=f.params;
            f.scenario.phase2b=phase2b_scenario("communication_delay",f.params);
            f.alarmDeadline_s=.758;
            f.description="New excessive-delay evaluation: 35 ms source age exceeds the unchanged 20 ms admission limit; reference shaping cannot make stale measurements credible.";
        case 19
            f.scenario=reference(f.scenario,[0;.197;1.173],[0;70;-60]);
            f.scenario.loadTorque_Nm=.001;f.scenario.assumedLoadTorque_Nm=0;
            f.description="Separate diagnostic: unknown +0.001 Nm plant load with shaped reversal and unchanged zero assumed load; no clean-motion performance pass claim.";
        case 20
            f.scenario=reference(f.scenario,[0;.211;1.293],[0;80;-70]);
            f.scenario.actualParameters.electrical.resistance_Ohm=1.10*f.params.electrical.resistance_Ohm;
            f.scenario.actualParameters.mechanical.inertia_kg_m2=1.15*f.params.mechanical.inertia_kg_m2;
            f.description="Separate diagnostic: actual resistance +10% and inertia +15% against the nominal observer, with clean requested reversal; no calibrated mismatch-envelope claim.";
    end
    if k~=1,f.scenario.description=f.description;end
    validateFixture(f);
    fixtures(k)=f;
end
assert(numel(unique(string({fixtures.id})))==numel(fixtures), ...
    'EMIProject:InvalidMotionFixtures','Motion-study ids must be unique.');
end

function f=base(id,partition,kind,window_s)
p=actuator_parameters();p.simulation.stopTime_s=3;
s=phase3_scenario(id,p);
responseKind="none";
if kind=="fault",s.expectation="detect";responseKind="alarm";end
if kind=="diagnostic",s.expectation="observe";end
f=struct('id',id,'partition',partition,'kind',kind,'params',p,'scenario',s, ...
    'window_s',window_s,'alarmDeadline_s',NaN,'responseKind',responseKind, ...
    'requireStop',false,'requireResetRelease',false,'description',"");
end

function s=reference(s,times,values_deg)
s.referenceTimes_s=times;s.referenceValues_rad=deg2rad(values_deg);
end

function validateFixture(f)
id='EMIProject:InvalidMotionFixtures';
assert(isstring(f.id)&&isscalar(f.id)&&strlength(f.id)>0&& ...
    isstring(f.description)&&isscalar(f.description)&&strlength(f.description)>0,id, ...
    'Fixture identity and assumptions must be nonempty scalar strings.');
assert(any(f.partition==["development","evaluation","diagnostic"])&& ...
    any(f.kind==["clean","fault","diagnostic"])&& ...
    any(f.responseKind==["none","alarm","stop"]),id,'Invalid fixture classification.');
validate_parameters(f.params);validate_phase3_scenario(f.scenario,f.params);
assert(f.params.simulation.stopTime_s==3&&f.params.control.sampleTime_s==.001,id, ...
    'Motion fixtures require three seconds at a one-millisecond sample interval.');
w=f.window_s;
assert(isfloat(w)&&isreal(w)&&isequal(size(w),[1,2])&&all(isfinite(w))&& ...
    w(1)>=0&&w(2)>w(1)&&w(2)<=3,id,'Scoring window must lie within the complete record.');
assert(all(abs(f.scenario.referenceValues_rad)<=deg2rad(120)+1e-12)&& ...
    all(f.scenario.referenceTimes_s<=3),id,'Requests must stay within the declared +/-120-degree envelope and record.');
assert(islogical(f.requireStop)&&isscalar(f.requireStop)&& ...
    islogical(f.requireResetRelease)&&isscalar(f.requireResetRelease),id,'Response requirements must be logical scalars.');
deadline=f.alarmDeadline_s;
assert(isfloat(deadline)&&isreal(deadline)&&isscalar(deadline)&& ...
    (isnan(deadline)||(isfinite(deadline)&&deadline>=w(1)&&deadline<=3)),id,'Invalid absolute response deadline.');
if f.kind=="fault"
    assert(isfinite(deadline)&&f.responseKind~="none",id,'Fault fixtures need a declared response kind and deadline.');
    profile=phase3_fault_profiles(f.params,f.scenario);
    first=find(profile.receiverFault,1);
    assert(~isempty(first)&&deadline>=profile.time_s(first),id,'A fault deadline cannot precede its first receiver exposure.');
else
    assert(isnan(deadline)&&f.responseKind=="none"&&~f.requireStop&&~f.requireResetRelease, ...
        id,'Clean/diagnostic fixtures cannot carry fault-response requirements.');
end
if f.requireResetRelease
    assert(f.requireStop&&isfinite(f.scenario.resetRequestTime_s)&& ...
        f.scenario.packetDropStopTime_s+.05<f.scenario.resetRequestTime_s,id, ...
        'Qualified reset release requires a separate reset after returned primary evidence.');
end
end
