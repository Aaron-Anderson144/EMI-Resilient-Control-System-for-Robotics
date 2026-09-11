function packetLossMonteCarlo = run_phase2b_packet_loss_monte_carlo(outputFolder)
%RUN_PHASE2B_PACKET_LOSS_MONTE_CARLO Verify seeded loss statistics.
% Three aggregate cases are recorded: the configured probability and the
% exact deterministic edge cases p = 0 and p = 1.
arguments
    outputFolder (1,1) string = ""
end

scriptPath = mfilename('fullpath');
matlabRoot = fileparts(fileparts(scriptPath));
addpath(fullfile(matlabRoot,'functions'));
outputFolder = prepare_fresh_output_folder(outputFolder, ...
    fullfile(matlabRoot,'results','development'),"phase2b_packet_loss");
run(fullfile(matlabRoot, 'startup_project.m'));
resultsFolder=outputFolder;

params = actuator_parameters();
trialCount = 200;
probabilities = [ ...
    0.0; ...
    params.phase2b.communication.packetLossProbability; ...
    1.0];
caseNames = ["zero_probability"; "configured_probability"; "one_probability"];
baseSeed = double(params.phase2b.communication.packetLossRandomSeed) + 10000;

Ts = params.control.sampleTime_s;
sampleCount = round(params.simulation.stopTime_s / Ts) + 1;
time_s = (0:sampleCount - 1)' .* Ts;
records = repmat(struct(), numel(probabilities), 1);

for caseIndex = 1:numel(probabilities)
    probability = probabilities(caseIndex);
    totalOpportunities = 0;
    totalDrops = 0;

    for trialIndex = 1:trialCount
        trialParams = params;
        trialParams.phase2b.communication.packetLossProbability = probability;
        trialParams.phase2b.communication.packetLossRandomSeed = ...
            baseSeed + (caseIndex - 1) * trialCount + trialIndex - 1;
        scenario = phase2b_scenario("packet_loss", trialParams);
        profile = communication_channel_profile( ...
            time_s, trialParams, scenario);
        totalOpportunities = totalOpportunities + ...
            profile.packetSummary.faultWindow.transmittedPacketCount;
        totalDrops = totalDrops + profile.packetSummary.faultWindow.droppedPacketCount;
    end

    observedFraction = totalDrops / totalOpportunities;
    [wilsonLower95, wilsonUpper95] = localWilsonInterval( ...
        totalDrops, totalOpportunities, 1.95996398454005);
    isExactEdgeCase = probability == 0 || probability == 1;
    exactEdgeCasePass = ~isExactEdgeCase || observedFraction == probability;

    records(caseIndex).caseName = caseNames(caseIndex);
    records(caseIndex).configuredProbability = probability;
    records(caseIndex).trialCount = trialCount;
    records(caseIndex).firstRandomSeed = ...
        baseSeed + (caseIndex - 1) * trialCount;
    records(caseIndex).lastRandomSeed = ...
        baseSeed + caseIndex * trialCount - 1;
    records(caseIndex).packetOpportunityCount = totalOpportunities;
    records(caseIndex).observedDropCount = totalDrops;
    records(caseIndex).observedDropFraction = observedFraction;
    records(caseIndex).wilsonLower95 = wilsonLower95;
    records(caseIndex).wilsonUpper95 = wilsonUpper95;
    records(caseIndex).configuredProbabilityWithinWilson95 = ...
        probability >= wilsonLower95 && probability <= wilsonUpper95;
    records(caseIndex).exactEdgeCasePass = exactEdgeCasePass;
end

packetLossMonteCarlo = struct2table(records);
assert(all(packetLossMonteCarlo.exactEdgeCasePass), ...
    'EMIProject:PacketLossEdgeCaseFailed', ...
    'The seeded packet-loss generator failed an exact p=0 or p=1 check.');
writetable(packetLossMonteCarlo, fullfile(resultsFolder, ...
    'phase2b_packet_loss_monte_carlo.csv'));

disp(packetLossMonteCarlo);
fprintf('Phase 2B packet-loss Monte Carlo completed (%d trials per case).\n', ...
    trialCount);
fprintf('Results folder: %s\n',resultsFolder);
end

function [lower, upper] = localWilsonInterval(successes, trials, z)
if trials <= 0
    lower = NaN;
    upper = NaN;
    return
end

fraction = successes / trials;
denominator = 1 + z^2 / trials;
center = (fraction + z^2 / (2 * trials)) / denominator;
halfWidth = z / denominator * sqrt( ...
    fraction * (1 - fraction) / trials + z^2 / (4 * trials^2));
lower = max(0, center - halfWidth);
upper = min(1, center + halfWidth);
if successes == 0
    lower = 0;
end
if successes == trials
    upper = 1;
end
end
