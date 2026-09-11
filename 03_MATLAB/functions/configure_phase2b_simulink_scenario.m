function [scenario, signals] = configure_phase2b_simulink_scenario( ...
        scenarioName, params)
%CONFIGURE_PHASE2B_SIMULINK_SCENARIO Configure an interactive model run.
% Batch studies should prefer create_phase2b_simulation_input so each run
% owns its parameters and cannot inherit stale base-workspace profiles.

arguments
    scenarioName (1,1) string = "none"
    params (1,1) struct = actuator_parameters()
end

scenario = phase2b_scenario(scenarioName, params);
signals = phase2b_simulink_signals(params, scenario);
modelName = "EMI_Resilient_Actuator_Phase2B";
configure_actuator_simulink_parameters(modelName,params,"phase2b");
set_param(char(modelName + "/Supply Controller Reset Policy"),'Value', ...
    num2str(double(string(signals.supply.controllerStatePolicy) == "reset")));

assignin('base', 'phase2bEquivalentEncoderError', ...
    signals.phase2bEquivalentEncoderError);
assignin('base', 'phase2bAcceptedDelay', signals.phase2bAcceptedDelay);
assignin('base', 'phase2bSampleReceived', signals.phase2bSampleReceived);
assignin('base', 'phase2bDiagnostics', signals.phase2bDiagnostics);
assignin('base', 'phase2bSupplyProfile', signals.phase2bSupplyProfile);
assignin('base', 'phase2bScenario', scenario);
assignin('base', 'phase2bParameters', params);

fprintf('Configured Phase 2B Simulink scenario: %s\n', scenario.name);
end
