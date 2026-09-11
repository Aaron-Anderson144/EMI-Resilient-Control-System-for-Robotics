classdef TestPhase3Scenario < matlab.unittest.TestCase
    %TESTPHASE3SCENARIO Fail-closed fixture values and explicit exposure scope.
    methods (Test)
        function everyDeclaredCampaignCaseIsValid(testCase)
            p=actuator_parameters();p.simulation.stopTime_s=3;
            cases=phase3_test_scenarios(p);
            testCase.verifyGreaterThanOrEqual(numel(cases),28);
            testCase.verifyEqual(numel(unique(string({cases.name}))),numel(cases));
            for k=1:numel(cases)
                testCase.verifyWarningFree(@()validate_phase3_scenario(cases(k),p));
            end
        end

        function numericScalarFixtureFieldsRejectMalformedValues(testCase)
            p=actuator_parameters();s=phase3_scenario("fixture",p);
            fields=["loadTorque_Nm","assumedLoadTorque_Nm","benignNoiseStandardDeviation_rad", ...
                "noiseSeed","bias_rad","rampRate_rad_s","biasStartTime_s","biasStopTime_s"];
            invalid={NaN,Inf,-Inf,[],[1,2],1+1i,'1',"1",true,{1}};
            for field=fields
                for k=1:numel(invalid)
                    changed=s;changed.(field)=invalid{k};
                    testCase.verifyError(@()validate_phase3_scenario(changed,p), ...
                        'EMIProject:InvalidPhase3Scenario',sprintf('%s, invalid case%d',field,k));
                end
            end
        end

        function signedPhysicalValuesAndSeedEndpointsAreSupported(testCase)
            p=actuator_parameters();s=phase3_scenario("signed_fixture",p);
            s.loadTorque_Nm=-.01;s.assumedLoadTorque_Nm=-.02;
            s.bias_rad=-.01;s.rampRate_rad_s=-.1;s.benignNoiseStandardDeviation_rad=0;
            for seed=[0,2^32-1]
                s.noiseSeed=seed;
                testCase.verifyWarningFree(@()validate_phase3_scenario(s,p));
            end
            invalid={"noiseSeed",-1;"noiseSeed",.5;"noiseSeed",2^32; ...
                "benignNoiseStandardDeviation_rad",-.001};
            for k=1:size(invalid,1)
                changed=s;changed.(invalid{k,1})=invalid{k,2};
                testCase.verifyError(@()validate_phase3_scenario(changed,p),'EMIProject:InvalidPhase3Scenario');
            end
        end

        function windowsPermitCensoringButRejectMalformedOrHalfDisabledBounds(testCase)
            p=actuator_parameters();s=phase3_scenario("window_fixture",p);
            s.biasStartTime_s=p.simulation.stopTime_s-.01;s.biasStopTime_s=p.simulation.stopTime_s+1;
            s.packetDropStartTime_s=p.simulation.stopTime_s+1;s.packetDropStopTime_s=p.simulation.stopTime_s+2;
            testCase.verifyWarningFree(@()validate_phase3_scenario(s,p));
            s.packetDropStartTime_s=Inf;s.packetDropStopTime_s=Inf;
            testCase.verifyWarningFree(@()validate_phase3_scenario(s,p));
            invalid={"biasStartTime_s",-.1;"biasStopTime_s",s.biasStartTime_s; ...
                "biasStopTime_s",Inf;"packetDropStartTime_s",NaN; ...
                "packetDropStartTime_s",-Inf;"packetDropStartTime_s",-.1; ...
                "packetDropStartTime_s",.1;"packetDropStopTime_s",.2; ...
                "packetDropStartTime_s",true;"packetDropStopTime_s",[Inf,Inf]};
            for k=1:size(invalid,1)
                changed=s;changed.(invalid{k,1})=invalid{k,2};
                testCase.verifyError(@()validate_phase3_scenario(changed,p),'EMIProject:InvalidPhase3Scenario');
            end
            s.packetDropStartTime_s=.4;s.packetDropStopTime_s=.4;
            testCase.verifyError(@()validate_phase3_scenario(s,p),'EMIProject:InvalidPhase3Scenario');
        end

        function pointTimesAllowFutureExposureAndPositiveInfinityOnly(testCase)
            p=actuator_parameters();s=phase3_scenario("point_fixture",p);
            for field=["nonfiniteSampleTime_s","resetRequestTime_s"]
                for value=[0,p.simulation.stopTime_s,p.simulation.stopTime_s+1,Inf]
                    changed=s;changed.(field)=value;
                    testCase.verifyWarningFree(@()validate_phase3_scenario(changed,p));
                end
                invalid={-.001,-Inf,NaN,[],[0,1],1+1i,'1',true};
                for k=1:numel(invalid)
                    changed=s;changed.(field)=invalid{k};
                    testCase.verifyError(@()validate_phase3_scenario(changed,p),'EMIProject:InvalidPhase3Scenario');
                end
            end
        end

        function futurePointEventsNeverSnapToRecordEndpoints(testCase)
            p=actuator_parameters();s=phase3_scenario("future_point_fixture",p);
            for value=[p.simulation.stopTime_s+1,Inf]
                s.nonfiniteSampleTime_s=value;s.resetRequestTime_s=value;
                f=phase3_fault_profiles(p,s);
                testCase.verifyFalse(any(f.nonfinite) || any(f.resetRequest));
            end
            s.nonfiniteSampleTime_s=p.simulation.stopTime_s;s.resetRequestTime_s=0;
            f=phase3_fault_profiles(p,s);
            testCase.verifyEqual(find(f.nonfinite),numel(f.time_s));
            testCase.verifyEqual(find(f.resetRequest),1);
        end

        function referenceAndInitialStateShapesAreValidated(testCase)
            p=actuator_parameters();s=phase3_scenario("reference_fixture",p);
            invalid={"referenceTimes_s",[];"referenceTimes_s",0; ...
                "referenceTimes_s",[0;0];"referenceTimes_s",[.1;.2]; ...
                "referenceTimes_s",[0;-.1];"referenceTimes_s",[0;Inf]; ...
                "referenceTimes_s",[0;NaN];"referenceTimes_s",[0,.1;.2,.3]; ...
                "referenceTimes_s",[0;.1+1i];"referenceTimes_s","0 .1"; ...
                "referenceValues_rad",[0;Inf];"referenceValues_rad",[0;NaN]; ...
                "referenceValues_rad",[0;1;2];"referenceValues_rad",[false;true]; ...
                "initialPlantState",[0,0,0];"initialPlantState",[0;0]; ...
                "initialPlantState",[0;Inf;0];"initialPlantState",[0;1i;0]; ...
                "initialPlantState",[false;false;false]};
            for k=1:size(invalid,1)
                changed=s;changed.(invalid{k,1})=invalid{k,2};
                testCase.verifyError(@()validate_phase3_scenario(changed,p),'EMIProject:InvalidPhase3Scenario');
            end
            s.referenceTimes_s=[0,.1,2];s.referenceValues_rad=[0,-.3,.4];
            s.initialPlantState=[-.1;.2;-.3];
            testCase.verifyWarningFree(@()validate_phase3_scenario(s,p));
        end

        function metadataAndRequiredFieldsCannotBeAmbiguous(testCase)
            p=actuator_parameters();s=phase3_scenario("metadata_fixture",p);
            invalid={"name","";"name","  ";"name",["a","b"];"name",NaN; ...
                "description",[];"description",["a","b"];"expectation","unknown"; ...
                "expectation",["clean","detect"];"actualParameters",[];"actualParameters",[p,p]};
            for k=1:size(invalid,1)
                changed=s;changed.(invalid{k,1})=invalid{k,2};
                testCase.verifyError(@()validate_phase3_scenario(changed,p),'EMIProject:InvalidPhase3Scenario');
            end
            names=fieldnames(s);
            for k=1:numel(names)
                testCase.verifyError(@()validate_phase3_scenario(rmfield(s,names{k}),p), ...
                    'EMIProject:InvalidPhase3Scenario');
            end
            testCase.verifyError(@()validate_phase3_scenario([s,s],p),'EMIProject:InvalidPhase3Scenario');
            s.name='char_fixture';s.description='';s.expectation='observe';
            testCase.verifyWarningFree(@()validate_phase3_scenario(s,p));
        end

        function actualParametersAndExistingFaultValidatorsRemainEnforced(testCase)
            p=actuator_parameters();s=phase3_scenario("nested_fixture",p);
            changed=s;changed.actualParameters.control.sampleTime_s=.0005;
            testCase.verifyError(@()validate_phase3_scenario(changed,p),'EMIProject:InvalidPhase3Scenario');
            changed=s;changed.actualParameters.electrical.resistance_Ohm=-1;
            testCase.verifyError(@()validate_phase3_scenario(changed,p),'EMIProject:InvalidPositiveParameter');
            changed=s;changed.encoder.dropout.stopTime_s=Inf;
            testCase.verifyError(@()validate_phase3_scenario(changed,p),'EMIProject:InvalidFaultWindow');
            changed=s;changed.phase2b.communication.jitterEnabled=true;
            testCase.verifyError(@()validate_phase3_scenario(changed,p),'EMIProject:InvalidPhase2BScenario');
        end
    end
end
