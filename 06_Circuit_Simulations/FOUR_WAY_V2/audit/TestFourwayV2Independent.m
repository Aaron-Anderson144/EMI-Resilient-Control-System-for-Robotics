function tests=TestFourwayV2Independent
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(fullfile(root,'03_MATLAB')));
addpath(fullfile(root,'06_Circuit_Simulations','FOUR_WAY_V2','functions'));
t.TestData.root=root;
end
function testExternalPacketTruthIsolation(t)
for arm=["BASELINE","COMBINED"]
 f=fourway_v2_fixture('V2DEV01',arm,false,'V01');
 clean=f.run;tainted=clean;
 tainted.profiles.sourceFault(:)=true;
 tainted.profiles.encoder.additive_rad(:)=1e7;
 tainted.profiles.encoder.dropoutActive(:)=true;
 tainted.profiles.physical.equivalentEncoderError_rad(:)=-1e8;
 tainted.profiles.bias_rad(:)=1e9;
 tainted.profiles.benignNoise_rad(:)=1e10;
 tainted.profiles.nonfinite(:)=true;
 tainted.profiles.communication.acceptedSourceIndex(:)=999999;
 tainted.profiles.communication.sampleReceived(:)=false;
 a=phase3_loop_initialize(clean);b=phase3_loop_initialize(tainted);
 for k=1:250
  packet=struct('measurement_rad',round(20*sin(k/41))*2*pi/4096,'sourceIndex',k,'sampleReceived',true);
  [a,sa]=phase3_loop_step(a,[],packet);
  [b,sb]=phase3_loop_step(b,[1e12;-1e12;NaN],packet);
  verifyEqual(t,sa,sb);
 end
end
end
function testOracleFieldsCannotCrossMeasurementBoundary(t)
packet=struct('measurement_rad',0,'sourceIndex',1,'sampleReceived',true,'domain_failed',false);
verifyError(t,@()phase3_external_measurement(packet,1,0),'EMIProject:InvalidExternalMeasurement');
packet=rmfield(packet,'domain_failed');packet.trueAngle=0;
verifyError(t,@()phase3_external_measurement(packet,1,0),'EMIProject:InvalidExternalMeasurement');
end
