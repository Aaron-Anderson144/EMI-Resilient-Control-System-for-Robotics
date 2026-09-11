classdef TestSupplyAndLoad < matlab.unittest.TestCase
    methods (Test)
        function nonzeroLoadChangesMotionAndMatchesLinearOracle(testCase)
            p=actuator_parameters(); p.mechanical.nominalLoadTorque_Nm=0.01;
            a=simulate_faulted_actuator(p,encoder_fault_scenario("none",p));
            b=simulate_phase2b_actuator(p,phase2b_scenario("none",p));
            z=p;z.mechanical.nominalLoadTorque_Nm=0;
            clean=simulate_phase2b_actuator(z,phase2b_scenario("none",z));
            testCase.verifyLessThan(b.velocity_rad_s(2),0);
            testCase.verifyGreaterThan(max(abs(b.position_rad-clean.position_rad)),1e-3);
            testCase.verifyEqual(a.timeSeries.theta_rad,b.position_rad,'AbsTol',1e-11);
            model=baseline_closed_loop(p);
            expected=lsim(model.referenceToPosition,b.reference_rad,b.time_s)+ ...
                lsim(model.loadToPosition,repmat(p.mechanical.nominalLoadTorque_Nm,size(b.time_s)),b.time_s);
            testCase.verifyLessThan(max(abs(b.command_V)),p.control.voltageLimit_V);
            testCase.verifyEqual(b.position_rad,expected,'AbsTol',1e-9);
        end
        function supplyDisabledPreservesNominalModel(testCase)
            p=actuator_parameters();s=phase2b_scenario("none",p);
            a=simulate_phase2b_actuator(p,s);s=rmfield(s,'supply');
            b=simulate_phase2b_actuator(p,s);
            testCase.verifyEqual(a.position_rad,b.position_rad);
            testCase.verifyEqual(a.command_V,b.command_V);
            testCase.verifyEqual(a.supply.voltage_V,repmat(24,numel(a.time_s),1));
        end
        function windowsAreHalfOpenAndUsePhysicalTimestamps(testCase)
            p=actuator_parameters();s=phase2b_scenario("supply_sag",p);
            t=[0;s.supply.startTime_s-1e-8;s.supply.startTime_s; ...
                s.supply.stopTime_s-1e-8;s.supply.stopTime_s;p.simulation.stopTime_s];
            f=supply_fault_profile(t,p,s);
            testCase.verifyEqual(f.configuredWindowActive,logical([0;0;1;1;0;0]));
            testCase.verifyEqual(f.voltage_V,[24;24;.5;.5;24;24]);
        end
        function sagClipsBothPolaritiesWithoutResettingState(testCase)
            p=actuator_parameters();p.mechanical.nominalLoadTorque_Nm=.01;
            p.supply.sagVoltage_V=.05;
            for loadSign=[-1,1]
                p.mechanical.nominalLoadTorque_Nm=loadSign*.01;
                r=simulate_phase2b_actuator(p,phase2b_scenario("supply_sag",p));
                active=r.supply.configuredWindowActive;
                testCase.verifyGreaterThan(nnz(abs(r.unsaturatedCommand_V(active))>.05),0);
                testCase.verifyLessThanOrEqual(max(abs(r.command_V(active))),.05);
                testCase.verifyTrue(all(r.supply.driveAvailable));
                testCase.verifyTrue(any(abs(r.controllerState_log(active,:))>0,'all'));
            end
        end
        function interruptionInhibitsDriveAndHoldsController(testCase)
            p=actuator_parameters();p.mechanical.nominalLoadTorque_Nm=.01;
            r=simulate_phase2b_actuator(p,phase2b_scenario("supply_interruption",p));
            active=find(r.supply.configuredWindowActive);
            testCase.verifyEqual(r.command_V(active),zeros(size(active)));
            testCase.verifyFalse(any(r.supply.driveAvailable(active)));
            testCase.verifyEqual(r.controllerState_log(active(1):active(end)+1,:), ...
                repmat(r.controllerState_log(active(1),:),numel(active)+1,1));
            testCase.verifyGreaterThan(max(abs(diff(r.position_rad(active)))),1e-5);
            testCase.verifyGreaterThan(max(abs(r.current_A(active))),0);
            testCase.verifyTrue(all(isfinite(r.state),'all'));
        end
        function resetPolicyClearsNextStateAndRetainsPlant(testCase)
            p=actuator_parameters();p.mechanical.nominalLoadTorque_Nm=.01;
            holdRun=simulate_phase2b_actuator(p,phase2b_scenario("supply_interruption",p));
            resetRun=simulate_phase2b_actuator(p,phase2b_scenario("supply_interruption_reset",p));
            active=find(resetRun.supply.configuredWindowActive);
            testCase.verifyEqual(resetRun.controllerState_log(active(1)+1:active(end)+1,:), ...
                zeros(numel(active),size(resetRun.controllerState_log,2)));
            testCase.verifyEqual(resetRun.state(1:active(end)+1,:),holdRun.state(1:active(end)+1,:));
            testCase.verifyGreaterThan(max(abs(resetRun.command_V(active(end)+1:end)- ...
                holdRun.command_V(active(end)+1:end))),1e-6);
        end
        function oneSampleAndWholeRunInterruptionsHaveNoOffByOne(testCase)
            p=actuator_parameters();p.mechanical.nominalLoadTorque_Nm=.01;
            p.supply.startTime_s=.5;p.supply.stopTime_s=.501;
            r=simulate_phase2b_actuator(p,phase2b_scenario("supply_interruption",p));
            testCase.verifyEqual(nnz(~r.supply.driveAvailable),1);
            p.supply.startTime_s=0;p.supply.stopTime_s=p.simulation.stopTime_s;
            r=simulate_phase2b_actuator(p,phase2b_scenario("supply_interruption",p));
            testCase.verifyEqual(r.command_V(1:end-1),zeros(numel(r.time_s)-1,1));
            testCase.verifyTrue(r.supply.driveAvailable(end));
            testCase.verifyLessThan(r.position_rad(end),0);
        end
        function restoredSupplyReenablesBoundedControl(testCase)
            p=actuator_parameters();p.mechanical.nominalLoadTorque_Nm=.01;
            p.simulation.stopTime_s=3.0;
            base=simulate_phase2b_actuator(p,phase2b_scenario("none",p));
            for name=["supply_interruption","supply_interruption_reset"]
                r=simulate_phase2b_actuator(p,phase2b_scenario(name,p));
                post=r.time_s>=p.supply.stopTime_s;
                testCase.verifyTrue(all(r.supply.driveAvailable(post)));
                testCase.verifyGreaterThan(max(abs(r.command_V(post))),0);
                testCase.verifyLessThanOrEqual(abs(r.command_V),r.supply.commandLimit_V);
                [m,~]=phase2b_metrics(r,base,p);
                testCase.verifyFalse(m.recoveryCensored);
                testCase.verifyGreaterThanOrEqual(m.recoveryTime_s,0);
            end
        end
        function supplyIsolationAndCombinationPreserveOtherProfiles(testCase)
            p=actuator_parameters();p.mechanical.nominalLoadTorque_Nm=.01;
            base=simulate_phase2b_actuator(p,phase2b_scenario("none",p));
            only=simulate_phase2b_actuator(p,phase2b_scenario("supply_interruption",p));
            combined=simulate_phase2b_actuator(p,phase2b_scenario("combined_supply",p));
            emi=simulate_phase2b_actuator(p,phase2b_scenario("combined_phase2b",p));
            testCase.verifyEqual(only.physical,base.physical);
            testCase.verifyEqual(only.communication,base.communication);
            testCase.verifyEqual(combined.physical,emi.physical);
            testCase.verifyEqual(combined.communication,emi.communication);
            pre=only.time_s<p.supply.startTime_s;
            testCase.verifyEqual(only.state(pre,:),base.state(pre,:));
            testCase.verifyEqual(only.command_V(pre),base.command_V(pre));
            testCase.verifyEqual(combined.command_V(~combined.supply.driveAvailable), ...
                zeros(nnz(~combined.supply.driveAvailable),1));
        end
        function repeatabilityAndVoltageLimitAreExplicit(testCase)
            p=actuator_parameters();p.control.voltageLimit_V=.1;
            s=phase2b_scenario("combined_supply",p);
            first=simulate_phase2b_actuator(p,s);second=simulate_phase2b_actuator(p,s);
            testCase.verifyEqual(first.timeSeries,second.timeSeries);
            testCase.verifyEqual(first.controllerState_log,second.controllerState_log);
            testCase.verifyLessThanOrEqual(max(abs(first.command_V)),.1);
            testCase.verifyGreaterThan(nnz(abs(first.unsaturatedCommand_V)>.1),0);
        end
    end
end
