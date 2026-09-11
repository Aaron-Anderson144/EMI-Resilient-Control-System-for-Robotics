function s=phase3_scenario(name,params)
%PHASE3_SCENARIO Base fixture; modifiers describe injections, never FDI inputs.
arguments
 name (1,1) string
 params (1,1) struct
end
validate_parameters(params);
s.name=name;s.description="";s.expectation="clean";
s.encoder=encoder_fault_scenario("none",params);
s.phase2b=phase2b_scenario("none",params);
s.actualParameters=params;s.initialPlantState=zeros(3,1);
s.referenceTimes_s=[0;params.simulation.stepTime_s];
s.referenceValues_rad=[0;params.simulation.stepAmplitude_rad];
if params.simulation.stepTime_s==0
 s.referenceTimes_s=[0;params.control.sampleTime_s];
 s.referenceValues_rad(:)=params.simulation.stepAmplitude_rad;
end
s.loadTorque_Nm=params.mechanical.nominalLoadTorque_Nm;
s.assumedLoadTorque_Nm=params.mechanical.nominalLoadTorque_Nm;
s.benignNoiseStandardDeviation_rad=0;s.noiseSeed=260912;
s.bias_rad=0;s.biasStartTime_s=0.4;s.biasStopTime_s=0.7;
s.rampRate_rad_s=0;
s.packetDropStartTime_s=Inf;s.packetDropStopTime_s=Inf;
s.nonfiniteSampleTime_s=Inf;
s.resetRequestTime_s=2.0; % Fixed operator protocol, not triggered by fault truth.
end
