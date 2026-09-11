function cases=phase3_test_scenarios(p)
%PHASE3_TEST_SCENARIOS Declared fixtures include expected misses, not only wins.
cases=phase3_scenario("clean_step",p);
s=phase3_scenario("clean_positive_load",p);s.loadTorque_Nm=0.01;s.assumedLoadTorque_Nm=0.01;cases(end+1)=s;
s=phase3_scenario("clean_negative_load",p);s.loadTorque_Nm=-0.01;s.assumedLoadTorque_Nm=-0.01;cases(end+1)=s;
s=phase3_scenario("clean_reference_reversal",p);s.referenceTimes_s=[0;.1;1.6];s.referenceValues_rad=[0;pi/6;-pi/12];cases(end+1)=s;
s=phase3_scenario("benign_noise",p);s.benignNoiseStandardDeviation_rad=deg2rad(.005);cases(end+1)=s;
s=phase3_scenario("permitted_delay",p);s.phase2b=phase2b_scenario("communication_delay",p);cases(end+1)=s;
s=phase3_scenario("permitted_delay_jitter",p);s.phase2b=phase2b_scenario("communication_delay",p);s.phase2b.communication.jitterEnabled=true;cases(end+1)=s;
s=phase3_scenario("mild_model_mismatch",p);s.actualParameters.electrical.resistance_Ohm=p.electrical.resistance_Ohm*1.02;s.actualParameters.mechanical.inertia_kg_m2=p.mechanical.inertia_kg_m2*1.02;cases(end+1)=s;
s=phase3_scenario("unmodelled_small_load",p);s.loadTorque_Nm=.001;cases(end+1)=s;
for name=["count_jump","gaussian","sinusoidal","dropout","combined"]
 s=phase3_scenario("encoder_"+name,p);s.encoder=encoder_fault_scenario(name,p);s.expectation="observe";cases(end+1)=s;
end
s=phase3_scenario("negative_count_jump",p);s.encoder=encoder_fault_scenario("count_jump",p);s.encoder.countJump.magnitude_counts=-128;s.expectation="detect";cases(end+1)=s;
s=phase3_scenario("freeze_during_motion",p);s.encoder=encoder_fault_scenario("dropout",p);s.encoder.dropout.startTime_s=.13;s.encoder.dropout.stopTime_s=.45;s.expectation="detect";cases(end+1)=s;
s=phase3_scenario("freeze_at_rest",p);s.referenceValues_rad(:)=0;s.encoder=encoder_fault_scenario("dropout",p);s.encoder.dropout.startTime_s=.2;s.encoder.dropout.stopTime_s=.8;s.expectation="unobservable";cases(end+1)=s;
s=phase3_scenario("large_bias",p);s.bias_rad=deg2rad(5);s.expectation="detect";cases(end+1)=s;
s=phase3_scenario("subthreshold_bias",p);s.bias_rad=deg2rad(.1);s.expectation="observe";cases(end+1)=s;
s=phase3_scenario("slow_bias_ramp",p);s.rampRate_rad_s=deg2rad(.5);s.biasStopTime_s=1.2;s.expectation="observe";cases(end+1)=s;
s=phase3_scenario("missing_packet_burst",p);s.packetDropStartTime_s=.4;s.packetDropStopTime_s=.75;s.expectation="detect";cases(end+1)=s;
s=phase3_scenario("out_of_range_measurement",p);s.biasStartTime_s=.45;s.biasStopTime_s=.451;s.bias_rad=4;s.expectation="detect";cases(end+1)=s;
for name=["supply_sag","supply_interruption","combined_phase2b","combined_supply"]
 s=phase3_scenario(name,p);s.phase2b=phase2b_scenario(name,p);s.expectation="detect";cases(end+1)=s;
end
s=phase3_scenario("loaded_supply_interruption",p);s.loadTorque_Nm=.01;s.assumedLoadTorque_Nm=.01;s.phase2b=phase2b_scenario("supply_interruption",p);s.expectation="detect";cases(end+1)=s;
s=phase3_scenario("late_fault_censored",p);s.biasStartTime_s=p.simulation.stopTime_s-.01;s.biasStopTime_s=p.simulation.stopTime_s+1;s.bias_rad=deg2rad(5);s.expectation="detect";cases(end+1)=s;
s=phase3_scenario("late_missing_packets",p);s.packetDropStartTime_s=p.simulation.stopTime_s-.01;s.packetDropStopTime_s=p.simulation.stopTime_s+1;s.expectation="observe";cases(end+1)=s;
end
