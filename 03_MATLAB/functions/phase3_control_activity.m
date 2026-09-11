function activity = phase3_control_activity(result)
%PHASE3_CONTROL_ACTIVITY Recover actual controller constraints from loop logs.
% Applies only to protected results produced by the standard Phase 3 loop.
% This reconstructs its constraint/transfer branches, not an alternative PID
% trajectory. A zero hard-stop raw command contains no counterfactual demand.
% AW updates the next integral state; it is not another same-tick actuator
% correction. Per-sample signed AW contributions can cancel.
id='EMIProject:InvalidPhase3ControlActivity';tolerance=1e-10;
assert(isstruct(result) && isscalar(result) && isfield(result,'run') && ...
    isstruct(result.run) && isscalar(result.run) && isfield(result.run,'protectionEnabled'),id, ...
    'A saved Phase 3 result with explicit protection applicability is required.');
enabled=result.run.protectionEnabled;
assert(islogical(enabled) && isscalar(enabled),id,'Protection applicability must be a scalar logical flag.');
assert(enabled,'EMIProject:Phase3ControlActivityNotApplicable', ...
    'Protected-controller activity does not apply to legacy unprotected results.');
assert(isfield(result,'timeSeries') && istable(result.timeSeries) && ...
    isfield(result.run,'configuration') && isstruct(result.run.configuration) && ...
    isscalar(result.run.configuration) && isfield(result.run,'profiles'),id, ...
    'The result must retain its time series, configuration and exogenous profiles.');
a=result.timeSeries;cfg=result.run.configuration;n=height(a);
required={'time_s','mode','command_V','unsaturatedCommand_V','commandLimit_V'};
assert(n>=1 && all(ismember(required,a.Properties.VariableNames)),id,'Required controller trace columns are missing.');
for k=1:numel(required)
    assert(localVector(a.(required{k}),n),id,'%s must contain finite real floating-point samples.',required{k});
end
assert(isfield(cfg,'control') && isfield(cfg,'supervisor'),id,'Saved controller and supervisor configurations are required.');
% Reuse the production validators; never accept a partially specified
% configuration merely because a particular trace does not exercise it.
try
    healthy=struct('alarm',false,'credibleFresh',true,'supplyHealthy',true, ...
        'estimateUsable',true,'resetRequest',false);
    [~,settings]=phase3_supervisor_step(phase3_supervisor_initialize(),healthy,cfg.supervisor);
    input=struct('reference_rad',0,'feedback_rad',0,'availableLimit_V',1);
    phase3_control_step(phase3_control_initialize(),input,settings,cfg.control);
catch caught
    error(id,'Invalid saved controller policy: %s',caught.message);
end
assert(cfg.control.sampleTime_s==cfg.supervisor.sampleTime_s,id,'Saved controller sample times disagree.');
Ts=double(cfg.control.sampleTime_s);
grid=(0:n-1)'*Ts;timeTolerance=64*eps(max([1;abs(grid)]));
assert(all(abs(double(a.time_s)-grid)<=timeTolerance),id,'Trace must start at zero on the configured sample grid.');
assert(isstruct(result.run.profiles) && isscalar(result.run.profiles) && ...
    isfield(result.run.profiles,'supply') && isstruct(result.run.profiles.supply) && ...
    isscalar(result.run.profiles.supply) && isfield(result.run.profiles.supply,'commandLimit_V'),id, ...
    'The saved supply command-limit profile is required.');
bus=result.run.profiles.supply.commandLimit_V;
assert(localVector(bus,n) && all(bus>=0),id,'Supply command limits must be finite, nonnegative and aligned.');
bus=double(bus);mode=double(a.mode);raw=double(a.unsaturatedCommand_V);applied=double(a.command_V);
assert(all(mode==fix(mode) & mode>=0 & mode<=4),id,'Logged modes must be integers from zero through four.');
previous=[0;applied(1:end-1)];transition=mode~=[0;mode(1:end-1)];
HardStop=mode==4 | bus==0;Rebased=transition | HardStop;
assert(all(raw(HardStop)==0 & applied(HardStop)==0),id,'Hard-stop raw and applied commands must be exactly zero.');
assert(all(abs(raw(transition & ~HardStop)-previous(transition & ~HardStop))<=tolerance),id, ...
    'An active mode transfer must request the preceding applied command.');
scale=repmat(double(cfg.supervisor.degradedVoltageLimitScale),n,1);
scale(mode==0)=double(cfg.supervisor.normalVoltageLimitScale);
scale(mode==1)=double(cfg.supervisor.suspectedVoltageLimitScale);scale(mode==4)=0;
modeCap=double(cfg.control.nominalCommandLimit_V)*scale;
limit=min(bus,modeCap);
assert(all(a.commandLimit_V>=0) && all(abs(double(a.commandLimit_V)-limit)<=tolerance),id, ...
    'Logged command limits disagree with the saved bus/mode policy.');
slewRate=repmat(double(cfg.supervisor.nonNormalSlewRate_V_s),n,1);
slewRate(mode==0)=double(cfg.supervisor.normalSlewRate_V_s);
SlewCommand_V=raw;regular=~Rebased;
SlewCommand_V(regular)=min(max(raw(regular),previous(regular)-slewRate(regular)*Ts), ...
    previous(regular)+slewRate(regular)*Ts);
predicted=min(max(SlewCommand_V,-limit),limit);
assert(all(isfinite(predicted)) && all(abs(predicted-applied)<=tolerance),id, ...
    'Applied commands disagree with reconstructed slew/amplitude constraints.');
AmplitudeCorrection_V=applied-SlewCommand_V;
AntiWindupCorrection_V=double(cfg.control.antiWindupGain)*(applied-raw);
assert(all(isfinite([SlewCommand_V;AmplitudeCorrection_V;AntiWindupCorrection_V])),id, ...
    'Reconstructed controller corrections must be finite.');
SlewClipped=abs(SlewCommand_V-raw)>tolerance;
AmplitudeClipped=abs(AmplitudeCorrection_V)>tolerance;
ModeCapClipped=AmplitudeClipped & modeCap<bus-tolerance;
BusCapClipped=AmplitudeClipped & bus<modeCap-tolerance;
CoincidentCapClipped=AmplitudeClipped & abs(modeCap-bus)<=tolerance;
activity=table(SlewClipped,AmplitudeClipped,ModeCapClipped,BusCapClipped, ...
    CoincidentCapClipped,HardStop,Rebased,SlewCommand_V,AmplitudeCorrection_V,AntiWindupCorrection_V);
end

function valid=localVector(value,n)
valid=isfloat(value) && isreal(value) && isequal(size(value),[n,1]) && all(isfinite(value));
end
