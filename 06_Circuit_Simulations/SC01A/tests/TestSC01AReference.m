classdef TestSC01AReference < matlab.unittest.TestCase
    methods(Test)
        function dcMatchesIndependentNodalSolve(testCase)
            p=sc01a_parameters(); c=sc01a_case("combined_rise",p);
            s=sc01a_stimulus(p,c);
            testCase.verifyEqual(s.initialState,[3.060288841272846;1.974371354072314;-0.000404747451831], ...
                'AbsTol',2e-12);
            r=sc01a_reference(p,s,[0;0.5e-6;4.9e-6]);
            testCase.verifyEqual(r.differential_V(1),1.085917487200532,'AbsTol',2e-12);
            testCase.verifyEqual(r.ground_V(1),-10.118686295773e-6,'AbsTol',2e-12);
            testCase.verifyEqual(r.differential_V(end),1.085834100374249,'AbsTol',1e-10);
        end
        function physicalKCLAndInductorLawHold(testCase)
            p=sc01a_parameters(); c=sc01a_case("combined_rise",p);
            s=sc01a_stimulus(p,c); t=(0:1e-9:5e-6).';
            r=sc01a_reference(p,s,t);
            ip=(r.ground_V+r.inputs(:,2)-r.positive_V)/p.driver.Rp_Ohm;
            in=(r.ground_V+r.inputs(:,3)-r.negative_V)/p.driver.Rn_Ohm;
            vpDot=r.derivative(:,1); vnDot=r.derivative(:,2);
            kp=p.receiver.Cp_F*vpDot+p.receiver.Cdiff_F*(vpDot-vnDot)+ ...
                p.coupling.Cp_F*(vpDot-r.inputs(:,4))+ ...
                r.positive_V/p.receiver.RpBias_Ohm+ ...
                r.differential_V/p.receiver.Rdiff_Ohm-ip;
            kn=p.receiver.Cn_F*vnDot+p.receiver.Cdiff_F*(vnDot-vpDot)+ ...
                p.coupling.Cn_F*(vnDot-r.inputs(:,4))+ ...
                r.negative_V/p.receiver.RnBias_Ohm- ...
                r.differential_V/p.receiver.Rdiff_Ohm-in;
            testCase.verifyLessThan(max(abs([kp;kn])),2e-12);
            testCase.verifyLessThan(max(abs(r.returnCurrent_A+ip+in-r.inputs(:,1))),2e-12);
            testCase.verifyLessThan(max(abs(p.ground.L_H*r.derivative(:,3)- ...
                r.ground_V+p.ground.R_Ohm*r.returnCurrent_A)),2e-10);
        end
        function fixedNetworkSuperposition(testCase)
            p=sc01a_parameters();t=(0:1e-9:5e-6).';
            names=["baseline","capacitive_rise","inductive_rise","shared_rise","combined_rise"];
            outputs=cell(1,5);
            for k=1:5
                c=sc01a_case(names(k),p);
                r=sc01a_reference(p,sc01a_stimulus(p,c),t);
                outputs{k}=[r.positive_V r.negative_V r.ground_V r.returnCurrent_A];
            end
            testCase.verifyEqual(outputs{5}-outputs{1}, ...
                outputs{2}+outputs{3}+outputs{4}-3*outputs{1},'AbsTol',5e-12);
        end
        function bothPolaritiesAreAntisymmetricPerturbations(testCase)
            p=sc01a_parameters();t=(0:1e-9:5e-6).';
            c0=sc01a_case("baseline",p); c1=sc01a_case("combined_rise",p); c2=sc01a_case("combined_fall",p);
            base=sc01a_reference(p,sc01a_stimulus(p,c0),t);
            pos=sc01a_reference(p,sc01a_stimulus(p,c1),t);
            neg=sc01a_reference(p,sc01a_stimulus(p,c2),t);
            testCase.verifyEqual(pos.state-base.state,-(neg.state-base.state),'AbsTol',5e-12);
            testCase.verifyEqual(pos.ground_V-base.ground_V,-(neg.ground_V-base.ground_V),'AbsTol',5e-12);
        end
        function completeSymmetryRejectsDifferentialCoupling(testCase)
            c=sc01a_case("balanced_combined",sc01a_parameters());p=c.params;
            t=(0:1e-9:5e-6).';r=sc01a_reference(p,sc01a_stimulus(p,c),t);
            testCase.verifyEqual(r.differential_V,ones(size(t))*1.088929219600726,'AbsTol',5e-12);
        end
        function balancedDifferentialPulseMatchesScalarClosedForm(testCase)
            c=sc01a_case("balanced_combined",sc01a_parameters());p=c.params;
            p.coupling.Mp_H=1.5e-9;p.coupling.Mn_H=-1.5e-9;
            c.params=p;c.capacitive=false;c.shared=false;
            t=(0:1e-9:5e-6).';r=sc01a_reference(p,sc01a_stimulus(p,c),t);
            gain=0.544464609800363;tau=7.336660617059891e-9;
            a=max(t-p.source.edgeTime_s,0);
            b=max(t-p.source.edgeTime_s-p.source.currentRise_s,0);
            expected=1.088929219600726+gain*0.045*(exp(-b/tau)-exp(-a/tau));
            testCase.verifyEqual(r.differential_V,expected,'AbsTol',1e-11);
        end
        function zeroSourceAndZeroCouplingHaveNoDisturbance(testCase)
            for name=["zero_source","zero_coupling"]
                c=sc01a_case(name,sc01a_parameters());p=c.params;
                t=(0:2e-9:5e-6).';r=sc01a_reference(p,sc01a_stimulus(p,c),t);
                testCase.verifyEqual(r.state,repmat(r.state(1,:),numel(t),1),'AbsTol',5e-12);
            end
        end
        function invalidTopologyAndCaseMismatchRejected(testCase)
            p=sc01a_parameters();bad=p;bad.coupling.Cp_F=-1;
            testCase.verifyError(@()sc01a_state_space(bad),'SC01A:InvalidCouplingCapacitance');
            c=sc01a_case("balanced_combined",p);
            testCase.verifyError(@()sc01a_stimulus(p,c),'SC01A:CaseParameterMismatch');
        end
    end
end
