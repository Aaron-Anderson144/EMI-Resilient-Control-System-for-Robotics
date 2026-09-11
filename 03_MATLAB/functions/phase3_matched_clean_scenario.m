function clean=phase3_matched_clean_scenario(s,p)
%PHASE3_MATCHED_CLEAN_SCENARIO Preserve plant, load, reference and benign noise.
clean=s;clean.name=s.name+"_matched_clean";clean.expectation="clean";
clean.encoder=encoder_fault_scenario("none",p);clean.phase2b=phase2b_scenario("none",p);
clean.bias_rad=0;clean.rampRate_rad_s=0;
clean.packetDropStartTime_s=Inf;clean.packetDropStopTime_s=Inf;clean.nonfiniteSampleTime_s=Inf;
end
