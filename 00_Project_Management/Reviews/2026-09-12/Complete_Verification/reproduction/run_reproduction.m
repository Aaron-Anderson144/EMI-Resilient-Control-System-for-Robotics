function run_reproduction()
project='C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics';
out='C:\Users\adand\Documents\Codex\2026-09-12\a\outputs\Project_Verification_2026-09-12';
cd(fullfile(project,'03_MATLAB'));startup_project;
a=fullfile(project,'06_Circuit_Simulations','SC01A');
addpath(fullfile(a,'functions'),fullfile(a,'scripts'));
Simulink.fileGenControl('set','CacheFolder',fullfile(fileparts(mfilename('fullpath')),'reproduction_cache'), ...
 'CodeGenFolder',fullfile(fileparts(mfilename('fullpath')),'reproduction_codegen'),'createDir',true);
frozen=fourway_verify_freeze();
rejected=fullfile(project,'00_Project_Management','Verification','Causal_Receiver_2026-09-11','rejected_acceptance.json');
guard=struct('blocked',false,'exception','','outputCreated',false,'evaluationExecuted',false);
guardOutput=fullfile(out,'evaluation_must_not_open');
try
 run_fourway_stage('evaluation',guardOutput,rejected);
catch caught
 guard.exception=caught.identifier;
 guard.blocked=strcmp(caught.identifier,'EMIProject:FourWayAcceptance');
end
guard.outputCreated=isfolder(guardOutput);
writeJson(fullfile(out,'evaluation_guard.json'),guard);
assert(guard.blocked && ~guard.outputCreated,'VERIFY:EvaluationGuard');
fprintf('EVALUATION_REJECTION_VERIFIED\n');
run_baseline(fullfile(out,'fresh_baseline'));
run_fourway_stage('development',fullfile(out,'fresh_development'));
fprintf('FRESH_DEVELOPMENT_COMPLETE\n');
native=verify_native_reproduction(fullfile(out,'fresh_native'));
writeJson(fullfile(out,'fresh_native_summary.json'),native);
fprintf('FRESH_NATIVE_COMPLETE passed=%d domainRejected=%d\n',native.passed,native.receiverDomainRejectedRuns);
writeJson(fullfile(out,'reproduction_summary.json'),struct('frozenInputs',frozen,'evaluationGuard',guard, ...
 'native',native,'physicalValidation',false));
end

function writeJson(file,value)
fid=fopen(file,'w');assert(fid>=0);c=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
