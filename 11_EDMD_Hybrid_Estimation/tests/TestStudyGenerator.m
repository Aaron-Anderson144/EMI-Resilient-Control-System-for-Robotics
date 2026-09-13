classdef TestStudyGenerator < matlab.unittest.TestCase
    % Tests exercise deterministic trajectories, online data isolation,
    % parameter assumptions, and independent integration accuracy.
    properties
        ProjectRoot
    end
    methods (TestMethodSetup)
        function locateProject(testCase)
            testCase.ProjectRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))),'reference_project');
        end
    end
    methods (Test)
        function deterministicAndScoped(testCase)
            rngBefore = rng;
            [first,meta] = study_generate_records(testCase.ProjectRoot,[1201,1202], ...
                ["nominal","nonlinear"],0.15);
            second = study_generate_records(testCase.ProjectRoot,[1201,1202], ...
                ["nominal","nonlinear"],0.15);
            testCase.verifyEqual(first,second);
            testCase.verifyEqual(rng,rngBefore);
            testCase.verifyTrue(contains(meta.studyScope,'no hardware evidence or EMI exposure'));
            testCase.verifyLessThanOrEqual(meta.noiseStandardDeviation_counts,0.1);
            for run = 1:numel(first)
                record = first{run};
                testCase.verifySize(record.truth,[151,3]);
                testCase.verifyEqual(record.truth(1,:),[0,0,0]);
                testCase.verifyTrue(all(record.valid));
                testCase.verifyLessThanOrEqual(max(abs(record.u)),24);
                testCase.verifyLessThanOrEqual(max(abs(record.referenceRate)),10+eps(10));
                testCase.verifyLessThanOrEqual(max(abs(record.reference)),pi/3+eps);
            end
        end
        function commandUsesMeasurementsOnly(testCase)
            [records,meta] = study_generate_records(testCase.ProjectRoot,9107,"stress",0.30);
            record = records{1};
            c = meta.controller;
            alpha = exp(-record.sampleTime/c.derivativeFilterTime_s);
            velocity = 0;
            reconstructed = zeros(size(record.u));
            for k = 1:numel(record.y)
                if k > 1
                    velocity = alpha*velocity+(1-alpha)*(record.y(k)-record.y(k-1))/record.sampleTime;
                end
                raw = c.Kp_V_rad*(record.reference(k)-record.y(k))-c.Kd_V_s_rad*velocity;
                reconstructed(k) = max(-24,min(24,raw));
            end
            testCase.verifyEqual(record.u,reconstructed,'AbsTol',1e-13);
        end
        function nominalMatchesExactZoh(testCase)
            records = study_generate_records(testCase.ProjectRoot,501,"nominal",0.40);
            record = records{1};
            p = record.parameters;
            A = [0,1,0;0,-p.b_Nm_s_rad/p.J_kg_m2,p.Kt_Nm_A/p.J_kg_m2; ...
                0,-p.Ke_V_s_rad/p.L_H,-p.R_Ohm/p.L_H];
            B = [0,0;0,-1/p.J_kg_m2;1/p.L_H,0];
            discrete = expm([A,B;zeros(2,5)]*record.sampleTime);
            exact = zeros(size(record.truth));
            for k = 1:numel(record.t)-1
                exact(k+1,:) = (discrete(1:3,1:3)*exact(k,:)' + ...
                    discrete(1:3,4:5)*[record.u(k);record.offlineLoadTorque_Nm(k)])';
            end
            error = max(abs(record.truth-exact),[],1);
            fprintf('Nominal RK4 vs exact ZOH max [rad, rad/s, A]: %.4g %.4g %.4g\n',error);
            testCase.verifyLessThan(error,[2e-7,2e-5,2e-5]);
        end
        function nonlinearSubstepConvergence(testCase)
            records = study_generate_records(testCase.ProjectRoot,[610,611], ...
                ["nonlinear","stress"],0.40);
            for run = 1:numel(records)
                record = records{run};
                fine = TestStudyGenerator.independentReplay(record,8);
                finer = TestStudyGenerator.independentReplay(record,16);
                error = max(abs(record.truth-fine),[],1);
                fineError = max(abs(fine-finer),[],1);
                fprintf('%s RK4 four vs eight max [rad, rad/s, A]: %.4g %.4g %.4g\n', ...
                    record.regime,error);
                testCase.verifyLessThan(error,[2e-7,3e-5,3e-5]);
                testCase.verifyLessThanOrEqual(fineError,error/5+1e-12);
            end
        end
        function fullTransientIntegrationConvergesAcrossLoadSteps(testCase)
            options = struct('motionScenario',"smooth_reversal", ...
                'loadScenario',"step",'controllerGainScale',.75);
            records = study_generate_records(testCase.ProjectRoot,[621,622], ...
                ["nonlinear","stress"],3,options);
            for run = 1:numel(records)
                record = records{run};
                testCase.verifyEqual(record.offlineEventTimes.loadTransition_s,[1,2]);
                testCase.verifyGreaterThanOrEqual(numel(record.offlineEventTimes.commandedReversal_s),3);
                % Independently replay the exact held commands and loads.
                % Keeping them fixed isolates numerical plant integration
                % from changes in noisy closed-loop acquisition feedback.
                fine = TestStudyGenerator.independentReplay(record,8);
                finer = TestStudyGenerator.independentReplay(record,16);
                error = max(abs(record.truth-fine),[],1);
                fineError = max(abs(fine-finer),[],1);
                fprintf('%s full transient RK4 four vs eight max [rad, rad/s, A]: %.4g %.4g %.4g\n', ...
                    record.regime,error);
                testCase.verifyLessThan(error,[2e-7,3e-5,3e-5]);
                testCase.verifyLessThanOrEqual(fineError,error/5+1e-12);
                testCase.verifyLessThan(error(1),.01*2*pi/4096);
            end
        end
        function rejectUnknownRegime(testCase)
            testCase.verifyError(@() study_generate_records(testCase.ProjectRoot,1,"hardware",0.1), ...
                'EDMDStudy:Regimes');
        end
    end
    methods (Static, Access=private)
        function truth = independentReplay(record,substeps)
            p = record.parameters;
            truth = zeros(size(record.truth));
            h = record.sampleTime/substeps;
            state = zeros(3,1);
            for k = 1:numel(record.t)-1
                command = record.u(k); load = record.offlineLoadTorque_Nm(k);
                rhs = @(x) [x(2); ...
                    (p.Kt_Nm_A*x(3)-p.b_Nm_s_rad*x(2)-load - ...
                    p.coulombFriction_Nm*tanh(x(2)/p.frictionSmoothing_rad_s))/p.J_kg_m2; ...
                    (command-p.R_Ohm*x(3)-p.Ke_V_s_rad*x(2))/p.L_H];
                for j = 1:substeps
                    slope1 = rhs(state);
                    slope2 = rhs(state+h*slope1/2);
                    slope3 = rhs(state+h*slope2/2);
                    slope4 = rhs(state+h*slope3);
                    state = state+h*(slope1+2*slope2+2*slope3+slope4)/6;
                end
                truth(k+1,:) = state';
            end
        end
    end
end
