classdef TestInputValidation < matlab.unittest.TestCase
    %TESTINPUTVALIDATION Reject bad inputs before they can change a run.
    methods (Test)
        function nominalAndLegacyParametersRemainValid(testCase)
            p = actuator_parameters();
            testCase.verifyWarningFree(@() validate_parameters(p));
            if isfield(p,'supply'), p = rmfield(p,'supply'); end
            testCase.verifyWarningFree(@() validate_parameters(p));
            p.mechanical.nominalLoadTorque_Nm = -0.1;
            p.faults.encoder.countJump.magnitude_counts = -128;
            p.faults.encoder.sinusoid.phase_rad = -pi;
            p.phase2b.groundOffset.voltage_V = -0.1;
            testCase.verifyWarningFree(@() validate_parameters(p));
        end

        function everyNumericParameterRejectsMalformedValues(testCase)
            % This traverses the public parameter set, so new numeric fields
            % must also gain a validator before this test can pass.
            p = actuator_parameters();
            paths = localNumericPaths(p,"");
            invalid = {NaN,Inf,-Inf,[],[1 2],1+1i,'1',"1",true,{1}};
            for path = paths
                for k = 1:numel(invalid)
                    changed = localSet(p,path,invalid{k});
                    identifier = localError(@() validate_parameters(changed));
                    context = sprintf('%s, invalid value index %d',path,k);
                    testCase.verifyNotEqual(identifier,"",context);
                    testCase.verifyTrue(startsWith(identifier,"EMIProject:"),context);
                end
            end
        end

        function previouslySilentNanValuesHaveSpecificErrors(testCase)
            p = actuator_parameters();
            paths = ["simulation.stepTime_s","faults.encoder.gaussian.standardDeviation_rad", ...
                "faults.encoder.sinusoid.frequency_Hz","faults.encoder.countJump.time_s"];
            ids = ["InvalidStepTime","InvalidFaultMagnitude","InvalidFaultMagnitude","InvalidCountJumpTime"];
            for k = 1:numel(paths)
                changed = localSet(p,paths(k),NaN);
                testCase.verifyError(@() validate_parameters(changed),char("EMIProject:"+ids(k)));
            end
            changed = localSet(p,"simulation.stepTime_s",NaN);
            scenario = phase2b_scenario("none",p);
            testCase.verifyError(@() simulate_phase2b_actuator(changed,scenario), ...
                'EMIProject:InvalidStepTime');
        end

        function seedsAndCountsRequireSupportedIntegers(testCase)
            p = actuator_parameters();
            seeds = ["simulation.randomSeed","faults.encoder.gaussian.randomSeed", ...
                "phase2b.communication.jitterRandomSeed","phase2b.communication.packetLossRandomSeed"];
            for path = seeds
                for value = [-1,0.5,2^32]
                    changed = localSet(p,path,value);
                    testCase.verifyNotEqual(localError(@() validate_parameters(changed)),"",char(path));
                end
                for value = [0,2^32-1]
                    changed = localSet(p,path,value);
                    testCase.verifyWarningFree(@() validate_parameters(changed));
                end
            end
            counts = ["sensor.encoderCountsPerRevolution", ...
                "faults.encoder.countJump.magnitude_counts", ...
                "phase2b.receiver.maxSpuriousCountsPerSample", ...
                "phase2b.communication.fixedDelay_samples", ...
                "phase2b.communication.maximumJitter_samples", ...
                "phase2b.metrics.recoveryDwellSamples"];
            for path = counts
                changed = localSet(p,path,1.5);
                testCase.verifyNotEqual(localError(@() validate_parameters(changed)),"",char(path));
            end
        end

        function invalidWindowsAreRejected(testCase)
            p = actuator_parameters();
            groups = ["faults.encoder.gaussian","faults.encoder.sinusoid", ...
                "faults.encoder.dropout","phase2b.source", ...
                "phase2b.groundOffset","phase2b.communication"];
            for group = groups
                changed = localSet(p,group+".startTime_s",-0.01);
                testCase.verifyNotEqual(localError(@() validate_parameters(changed)),"",char(group));
                changed = localSet(p,group+".stopTime_s",p.simulation.stopTime_s+0.01);
                testCase.verifyNotEqual(localError(@() validate_parameters(changed)),"",char(group));
                changed = localSet(p,group+".stopTime_s",localGet(p,group+".startTime_s"));
                testCase.verifyNotEqual(localError(@() validate_parameters(changed)),"",char(group));
            end
        end

        function stopTimeMustAgreeWithDiscreteSimulationGrid(testCase)
            p = actuator_parameters();
            p.simulation.stopTime_s = 1.5001;
            testCase.verifyError(@() validate_parameters(p),'EMIProject:InvalidSimulationTimeGrid');
            p.simulation.stopTime_s = 1.5+eps(1.5);
            testCase.verifyWarningFree(@() validate_parameters(p));
            p.simulation.stopTime_s = 1.6;
            testCase.verifyWarningFree(@() validate_parameters(p));
        end

        function callerMutatedEncoderScenariosAreValidated(testCase)
            p = actuator_parameters();
            s = encoder_fault_scenario("combined",p);
            t = (0:p.control.sampleTime_s:p.simulation.stopTime_s).';
            changes = {
                "gaussian.standardDeviation_rad",NaN,'EMIProject:InvalidFaultMagnitude'
                "sinusoid.phase_rad",Inf,'EMIProject:InvalidFaultPhase'
                "gaussian.randomSeed",2^32,'EMIProject:InvalidRandomSeed'
                "countJump.magnitude_counts",2.5,'EMIProject:InvalidCountJumpMagnitude'
                "countJump.time_s",NaN,'EMIProject:InvalidCountJumpTime'
                "dropout.stopTime_s",2,'EMIProject:InvalidFaultWindow'
                "dropout.behavior","zero-fill",'EMIProject:UnsupportedDropoutBehavior'
                "sinusoid.enabled",NaN,'EMIProject:InvalidEncoderScenario'
            };
            for k = 1:size(changes,1)
                changed = localSet(s,changes{k,1},changes{k,2});
                testCase.verifyError(@() encoder_fault_profile(t,p,changed),changes{k,3});
            end
        end

        function numericScenarioFieldsRejectMalformedValues(testCase)
            p = actuator_parameters();
            scenarios = {encoder_fault_scenario("combined",p),phase2b_scenario("combined_phase2b",p)};
            validators = {@validate_encoder_scenario,@validate_phase2b_scenario};
            invalid = {NaN,Inf,[1 2],[],1+1i,'1',true};
            for sIndex = 1:numel(scenarios)
                s = scenarios{sIndex};
                validator = validators{sIndex};
                paths = localNumericPaths(s,"");
                for path = paths
                    for k = 1:numel(invalid)
                        changed = localSet(s,path,invalid{k});
                        identifier = localError(@() validator(changed,p));
                        testCase.verifyTrue(startsWith(identifier,"EMIProject:"), ...
                            sprintf('Scenario %d: %s, invalid value %d',sIndex,path,k));
                    end
                end
            end
        end

        function callerMutatedPhase2BScenariosAreValidated(testCase)
            p = actuator_parameters();
            s = phase2b_scenario("combined_phase2b",p);
            t = (0:p.control.sampleTime_s:p.simulation.stopTime_s).';
            changes = {
                "communication.jitterEnabled",NaN
                "coupling.capacitiveEnabled",[true false]
                "physicalEnabled",false
                "analysisStartTime_s",NaN
                "analysisStopTime_s",Inf
                "analysisStartTime_s",0.9
                "analysisStopTime_s",0.8
            };
            for k = 1:size(changes,1)
                changed = localSet(s,changes{k,1},changes{k,2});
                testCase.verifyError(@() physical_coupling_profile(t,p,changed), ...
                    'EMIProject:InvalidPhase2BScenario');
                testCase.verifyError(@() communication_channel_profile(t,p,changed), ...
                    'EMIProject:InvalidPhase2BScenario');
            end
            clean = phase2b_scenario("none",p);
            testCase.verifyWarningFree(@() validate_phase2b_scenario(clean,p));
            clean.analysisStopTime_s = 1;
            testCase.verifyError(@() validate_phase2b_scenario(clean,p), ...
                'EMIProject:InvalidPhase2BScenario');
        end

        function widerPhysicalOnlyMetricWindowRemainsSupported(testCase)
            p = actuator_parameters();
            s = phase2b_scenario("combined_phase2b",p);
            s.communication.fixedDelayEnabled = false;
            s.communication.jitterEnabled = false;
            s.communication.packetLossEnabled = false;
            s.communicationEnabled = false;
            s.name = "physical_only";
            testCase.verifyWarningFree(@() validate_phase2b_scenario(s,p));
        end

        function profileTimeRejectsMalformedOrNoncausalCoordinates(testCase)
            p = actuator_parameters();
            a = encoder_fault_scenario("none",p);
            b = phase2b_scenario("none",p);
            invalid = {[],[0;NaN],[0;Inf],[0;1+1i],[-1;0],[0;0],[0.1;0], ...
                [0 1;2 3],'01',"01",{0,1}};
            for k = 1:numel(invalid)
                t = invalid{k};
                testCase.verifyError(@() encoder_fault_profile(t,p,a),'EMIProject:InvalidTimeVector');
                testCase.verifyError(@() physical_coupling_profile(t,p,b),'EMIProject:InvalidTimeVector');
                testCase.verifyError(@() communication_channel_profile(t,p,b),'EMIProject:InvalidTimeVector');
            end
            testCase.verifyError(@() communication_channel_profile([0;0.001;0.003],p,b), ...
                'EMIProject:InvalidTimeVector');
            testCase.verifyWarningFree(@() communication_channel_profile([0;0.001;0.002],p,b));
        end

        function supplyConfigurationValidatesValuesWindowsAndPolicy(testCase)
            p = actuator_parameters();
            supply = struct('enabled',true,'voltage_V',0,'startTime_s',0.85, ...
                'stopTime_s',1.10,'controllerStatePolicy',"hold");
            testCase.verifyWarningFree(@() validate_supply_scenario(supply,p));
            supply.controllerStatePolicy = "reset";
            testCase.verifyWarningFree(@() validate_supply_scenario(supply,p));
            changes = {
                "enabled",1,'EMIProject:InvalidSupplyScenario'
                "voltage_V",NaN,'EMIProject:InvalidSupplyVoltage'
                "voltage_V",-1,'EMIProject:InvalidSupplyVoltage'
                "voltage_V",25,'EMIProject:InvalidSupplyVoltage'
                "startTime_s",[0.8 0.9],'EMIProject:InvalidSupplyWindow'
                "stopTime_s",0.85,'EMIProject:InvalidSupplyWindow'
                "controllerStatePolicy","continue",'EMIProject:InvalidSupplyStatePolicy'
            };
            for k = 1:size(changes,1)
                changed = localSet(supply,changes{k,1},changes{k,2});
                testCase.verifyError(@() validate_supply_scenario(changed,p),changes{k,3});
            end
            s = phase2b_scenario("none",p);
            s.supply = supply;
            s.supply.voltage_V = NaN;
            t = (0:p.control.sampleTime_s:p.simulation.stopTime_s).';
            testCase.verifyError(@() physical_coupling_profile(t,p,s),'EMIProject:InvalidSupplyVoltage');
            p.supply = struct('startTime_s',0.85,'stopTime_s',1.1, ...
                'sagVoltage_V',0.5,'interruptionVoltage_V',0,'controllerStatePolicy',"hold");
            testCase.verifyWarningFree(@() validate_parameters(p));
            p.supply.sagVoltage_V = NaN;
            testCase.verifyError(@() validate_parameters(p),'EMIProject:InvalidSupplyVoltage');
        end
    end
end

function paths = localNumericPaths(value,prefix)
paths = strings(1,0);
names = fieldnames(value);
for k = 1:numel(names)
    name = string(names{k});
    if prefix == "", path = name; else, path = prefix+"."+name; end
    child = value.(name);
    if isstruct(child)
        paths = [paths,localNumericPaths(child,path)]; %#ok<AGROW>
    elseif isnumeric(child)
        paths(end+1) = path; %#ok<AGROW>
    end
end
end

function result = localSet(value,path,newValue)
parts = cellstr(split(string(path),'.'));
result = setfield(value,parts{:},newValue);
end

function value = localGet(value,path)
parts = split(path,'.');
for k = 1:numel(parts), value = value.(parts(k)); end
end

function identifier = localError(callback)
identifier = "";
try
    callback();
catch err
    identifier = string(err.identifier);
end
end
