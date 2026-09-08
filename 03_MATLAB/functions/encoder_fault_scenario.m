function scenario = encoder_fault_scenario(scenarioName, params)
%ENCODER_FAULT_SCENARIO Build one named Phase 2 encoder-fault scenario.

if nargin < 2
    params = actuator_parameters();
end

if nargin < 1 || isempty(scenarioName) || ...
        strlength(string(scenarioName)) == 0
    scenarioName = params.faults.defaultScenario;
end

validate_parameters(params);
scenarioName = lower(string(scenarioName));

scenario.name = scenarioName;
scenario.gaussian.enabled = false;
scenario.gaussian.standardDeviation_rad = ...
    params.faults.encoder.gaussian.standardDeviation_rad;
scenario.gaussian.startTime_s = ...
    params.faults.encoder.gaussian.startTime_s;
scenario.gaussian.stopTime_s = ...
    params.faults.encoder.gaussian.stopTime_s;
scenario.gaussian.randomSeed = ...
    params.faults.encoder.gaussian.randomSeed;

scenario.sinusoid.enabled = false;
scenario.sinusoid.amplitude_rad = ...
    params.faults.encoder.sinusoid.amplitude_rad;
scenario.sinusoid.frequency_Hz = ...
    params.faults.encoder.sinusoid.frequency_Hz;
scenario.sinusoid.phase_rad = ...
    params.faults.encoder.sinusoid.phase_rad;
scenario.sinusoid.startTime_s = ...
    params.faults.encoder.sinusoid.startTime_s;
scenario.sinusoid.stopTime_s = ...
    params.faults.encoder.sinusoid.stopTime_s;

scenario.countJump.enabled = false;
scenario.countJump.magnitude_counts = ...
    params.faults.encoder.countJump.magnitude_counts;
scenario.countJump.time_s = ...
    params.faults.encoder.countJump.time_s;

scenario.dropout.enabled = false;
scenario.dropout.startTime_s = ...
    params.faults.encoder.dropout.startTime_s;
scenario.dropout.stopTime_s = ...
    params.faults.encoder.dropout.stopTime_s;
scenario.dropout.behavior = ...
    params.faults.encoder.dropout.behavior;

switch scenarioName
    case "none"
        % All faults remain disabled.
    case "gaussian"
        scenario.gaussian.enabled = true;
    case "sinusoidal"
        scenario.sinusoid.enabled = true;
    case "count_jump"
        scenario.countJump.enabled = true;
    case "dropout"
        scenario.dropout.enabled = true;
    case "combined"
        scenario.gaussian.enabled = true;
        scenario.sinusoid.enabled = true;
        scenario.countJump.enabled = true;
        scenario.dropout.enabled = true;
    otherwise
        error('EMIProject:UnknownFaultScenario', ...
            'Unknown encoder-fault scenario: %s', scenarioName);
end
end
