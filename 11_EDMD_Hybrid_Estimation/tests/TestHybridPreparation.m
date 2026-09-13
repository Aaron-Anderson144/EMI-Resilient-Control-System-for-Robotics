classdef TestHybridPreparation < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addBundledCode(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'code')));
        end
    end
    methods (Test)
        function posteriorConventionAndRecursion(testCase)
            config = hybrid_reference_observer();
            testCase.verifySize(config.A,[3,3]);
            testCase.verifySize(config.B,[3,1]);
            testCase.verifySize(config.C,[1,3]);
            testCase.verifySize(config.L,[3,1]);
            testCase.verifyEqual(sort(eig((eye(3)-config.L*config.C)*config.A)), ...
                sort(exp(-[80;100;120]*0.001)),'AbsTol',1e-8);
            record = TestHybridPreparation.record();
            trace = hybrid_reference_observer(record);
            state = zeros(3,1);
            for k = 1:numel(record.y)
                if k > 1, state = config.A*state+config.B*record.u(k-1); end
                testCase.verifyEqual(trace.prior(k,:),state','AbsTol',1e-12);
                residual = record.y(k)-config.C*state;
                testCase.verifyEqual(trace.innovation(k),residual,'AbsTol',1e-12);
                state = state+config.L*residual;
                testCase.verifyEqual(trace.posterior(k,:),state','AbsTol',1e-12);
            end
        end
        function futureDataCannotChangeHistory(testCase)
            record = TestHybridPreparation.record();
            original = hybrid_reference_observer(record);
            changed = record;
            changed.y(151:end) = changed.y(151:end)+0.03;
            changed.u(150:end) = changed.u(150:end)-2;
            altered = hybrid_reference_observer(changed);
            testCase.verifyEqual(altered.prior(1:150,:),original.prior(1:150,:));
            testCase.verifyEqual(altered.posterior(1:150,:),original.posterior(1:150,:));
            testCase.verifyEqual(altered.innovation(1:150),original.innovation(1:150));
        end
        function offlineFieldsNeverEnterPreparation(testCase)
            record = TestHybridPreparation.record();
            [baseline,baselineTrace] = hybrid_prepare_records({record});
            record.truth = nan(numel(record.y),3);
            record.offlineLoadTorque_Nm = inf(size(record.y));
            record.reference = -1e6*ones(size(record.y));
            record.parameters = struct('hypothetical','changed');
            [changed,changedTrace] = hybrid_prepare_records({record});
            testCase.verifyEqual(changed,baseline);
            testCase.verifyEqual(changedTrace,baselineTrace);
            testCase.verifyFalse(any(isfield(changed{1},{'truth','reference','offlineLoadTorque_Nm'})));
        end
        function warmupAndResidualContract(testCase)
            record = TestHybridPreparation.record();
            [prepared,traces] = hybrid_prepare_records({record,record});
            testCase.verifySize(prepared,[1,2]);
            testCase.verifyEqual(prepared{1}.y,traces{1}.innovation);
            testCase.verifyEqual(prepared{1}.u,record.u);
            testCase.verifyFalse(any(prepared{1}.valid(1:100)));
            testCase.verifyTrue(all(prepared{1}.valid(101:end)));
            testCase.verifyEqual(prepared{1}.id,record.id);
            testCase.verifyEqual(prepared{1},prepared{2});
        end
        function rejectInvalidDomainOrObservations(testCase)
            record = TestHybridPreparation.record();
            invalid = record; invalid.domainValid = false;
            testCase.verifyError(@() hybrid_reference_observer(invalid),'EDMDHybrid:Domain');
            invalid = record; invalid.valid(110) = false;
            testCase.verifyError(@() hybrid_prepare_records({invalid}),'EDMDHybrid:InvalidObservation');
            invalid = record; invalid.y(110) = NaN;
            testCase.verifyError(@() hybrid_reference_observer(invalid),'EDMDHybrid:InvalidObservation');
            invalid = record; invalid.u(110) = Inf;
            testCase.verifyError(@() hybrid_reference_observer(invalid),'EDMDHybrid:InvalidObservation');
        end
        function rejectAsynchronousTiming(testCase)
            record = TestHybridPreparation.record();
            invalid = record; invalid.sampleTime = 0.002;
            testCase.verifyError(@() hybrid_reference_observer(invalid),'EDMDHybrid:SampleTime');
            invalid = record; invalid.t(110:end) = invalid.t(110:end)+0.001;
            testCase.verifyError(@() hybrid_reference_observer(invalid),'EDMDHybrid:Timestamp');
            invalid = record; invalid.sourceIndex = (1:numel(record.y))';
            invalid.sourceIndex(110) = 109;
            testCase.verifyError(@() hybrid_reference_observer(invalid),'EDMDHybrid:Timestamp');
            invalid = record; invalid.sampleReceived = true(size(record.y));
            invalid.sampleReceived(110) = false;
            testCase.verifyError(@() hybrid_reference_observer(invalid),'EDMDHybrid:InvalidObservation');
        end
    end
    methods (Static, Access=private)
        function record = record()
            t = (0:219)'*0.001;
            record = struct('y',0.02*sin(2*pi*2*t),'u',0.5*sin(2*pi*3*t), ...
                't',t,'valid',true(size(t)),'sampleTime',0.001,'domainValid',true, ...
                'id',"unit_measured_record",'regime',"unit",'seed',0);
        end
    end
end
