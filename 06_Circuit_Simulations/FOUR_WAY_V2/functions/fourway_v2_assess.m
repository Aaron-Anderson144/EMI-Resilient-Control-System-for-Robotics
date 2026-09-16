function assessment=fourway_v2_assess(metrics)
% Each finite receiver hypothesis receives a separate 12-cell screen.
variants=fourway_v2_variant();assert(height(metrics)==768,'EMIProject:V2Coverage','768 paired evaluation rows are required.');
items=struct([]);
for k=1:16
 m=metrics(metrics.Variant==variants(k).id,:);a=fourway_assess(m);
 a.design_id="FOUR-WAY-EMI-PLAN-V2";a.variant=variants(k);if k==1,items=a;else,items(k)=a;end %#ok<AGROW>
end
assessment=struct('design_id',"FOUR-WAY-EMI-PLAN-V2",'hypotheses',items, ...
 'all_hypotheses_pass',all([items.combined_benefit_demonstrated]), ...
 'passing_hypotheses',sum([items.combined_benefit_demonstrated]), ...
 'probability_interpretation',false,'physical_validation',false);
end
