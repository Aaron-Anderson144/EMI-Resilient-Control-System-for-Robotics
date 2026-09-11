function study=run_phase3_stop_hold_study(outputFolder)
%RUN_PHASE3_STOP_HOLD_STUDY Freeze and run 20 cases x 3 mechanisms x 3 grids.
if nargin<1,outputFolder=fullfile(pwd,'results','development',['phase3_stop_hold_',char(datetime('now','Format','yyyyMMdd_HHmmss'))]);end
if isfolder(outputFolder)
 entries=dir(outputFolder);entries=entries(~ismember({entries.name},{'.','..'}));
 assert(isempty(entries),'EMIProject:StopHoldOutputExists','Choose a new or empty output folder to preserve prior evidence.');
else,mkdir(outputFolder);end
mkdir(fullfile(outputFolder,'traces'));mkdir(fullfile(outputFolder,'design_source_identity'));
matlabRoot=fileparts(fileparts(mfilename('fullpath')));p=actuator_parameters();
design=phase3_stop_hold_configuration();design.fixtures=phase3_stop_hold_fixtures(design,matlabRoot);
fid=fopen(fullfile(outputFolder,'frozen_design.json'),'w');fprintf(fid,'%s\n',jsonencode(design,'PrettyPrint',true));fclose(fid);
write_run_manifest(fullfile(outputFolder,'design_source_identity'),matlabRoot,struct('stage',"frozen_before_stop_hold_campaign"));
rows={};
for j=1:numel(design.fixtures)
 for m=1:numel(design.mechanisms)
  for h=design.steps_s
   f=design.fixtures(j);mechanism=design.mechanisms(m);
   [trace,metric]=phase3_stop_hold_simulate(p,f,mechanism,h,design);
   name=sprintf('%s__%s__h%d.csv',f.id,mechanism.id,round(h*1e6));
   writetable(trace,fullfile(outputFolder,'traces',name));rows{end+1}=metric;
  end
 end
 fprintf('STOP/HOLD: %d/%d fixtures complete: %s\n',j,numel(design.fixtures),f.id);
end
metrics=struct2table(vertcat(rows{:}));writetable(metrics,fullfile(outputFolder,'stop_hold_metrics.csv'));
fine=metrics.Step_s==min(design.steps_s);mechanical=metrics.Mechanism=="mechanical";
expect=[design.fixtures.expectedMechanicalHold]';actual=metrics.TailHeld(fine & mechanical);
assert(isequal(actual,expect),'Mechanical expected holding/slip outcomes did not match frozen fixtures.');
assert(all(metrics.MaxEnergyResidual_J<=design.gates.energyClosure_J));
assert(all(metrics.MaxCapacityExcess_Nm<1e-12));
assert(all(metrics.NumericalLossFraction(fine)<=design.gates.fineNumericalLossFraction));
study=struct('outputFolder',string(outputFolder),'design',design,'metrics',metrics, ...
 'numericalRuns',height(metrics),'localChecksPassed',true,'independentAuditRequired',true, ...
 'controllerChanged',false,'physicalValidation',false);
save(fullfile(outputFolder,'study.mat'),'study','-v7');
end
