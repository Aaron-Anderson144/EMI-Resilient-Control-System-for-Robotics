function r=phase3_reference_profile(time_s,options)
%PHASE3_REFERENCE_PROFILE Explicit synthetic independent position sensor.
% error_rad is added only at the sensor-construction boundary. This fixture
% does not represent a selected, installed or qualified physical sensor.
arguments
 time_s (:,1) double {mustBeFinite,mustBeNonnegative}
 options (1,1) struct = struct()
end
c=struct('startTime_s',1.2,'stopTime_s',1.8,'requestTime_s',1.5, ...
 'uncertainty_rad',deg2rad(.005),'bias_rad',0,'noiseAmplitude_rad',0, ...
 'noiseFrequency_Hz',37,'timestampOffset_samples',0);
names=fieldnames(options);
assert(all(ismember(names,fieldnames(c))),'EMIProject:InvalidReferenceProfile','Unknown reference fixture option.');
for j=1:numel(names),c.(names{j})=options.(names{j});end
for name=string(fieldnames(c))'
 value=c.(name);
 assert(isnumeric(value)&&isreal(value)&&isscalar(value)&&~isnan(value), ...
  'EMIProject:InvalidReferenceProfile','Fixture options must be real numeric scalars.');
 c.(name)=double(value);
end
assert(numel(time_s)>1&&time_s(1)==0&&all(diff(time_s)>0), ...
 'EMIProject:InvalidReferenceProfile','The sample grid must start at zero and increase.');
assert(c.startTime_s>=0&&c.stopTime_s>c.startTime_s&&c.requestTime_s>=0&& ...
 all(isfinite([c.uncertainty_rad,c.bias_rad,c.noiseAmplitude_rad,c.noiseFrequency_Hz,c.timestampOffset_samples]))&& ...
 c.uncertainty_rad>=0&&c.noiseAmplitude_rad>=0&&c.noiseFrequency_Hz>=0&& ...
 c.timestampOffset_samples==fix(c.timestampOffset_samples), ...
 'EMIProject:InvalidReferenceProfile','Invalid reference times, errors or timestamp offset.');
n=numel(time_s);
r.sampleReceived=time_s>=c.startTime_s&time_s<c.stopTime_s;
r.sourceIndex=(1:n)'+c.timestampOffset_samples;
r.error_rad=c.bias_rad+c.noiseAmplitude_rad*sin(2*pi*c.noiseFrequency_Hz*time_s);
r.uncertainty_rad=repmat(c.uncertainty_rad,n,1);
r.request=false(n,1);
if isfinite(c.requestTime_s)&&c.requestTime_s<=time_s(end)
 [~,k]=min(abs(time_s-c.requestTime_s));r.request(k)=true;
end
r.assumptions="Synthetic independent, synchronized position sensor; stated deterministic error bound; independence and physical error bound require separate validation.";
validate_phase3_reference_profile(r,n);
end
