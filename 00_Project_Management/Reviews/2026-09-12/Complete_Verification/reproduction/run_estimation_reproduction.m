function run_estimation_reproduction()
out='C:\Users\adand\Documents\Codex\2026-09-12\a\outputs\Project_Verification_2026-09-12';
work=fileparts(mfilename('fullpath'));
run(fullfile(work,'verify_legacy.m'));
addpath('C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics\11_EDMD_Hybrid_Estimation','-begin');
hybrid=run_experiment(fullfile(out,'fresh_edmd'));
fid=fopen(fullfile(out,'fresh_edmd_execution.json'),'w');fprintf(fid,'%s\n',jsonencode(hybrid,PrettyPrint=true));fclose(fid);
fprintf('ESTIMATION_REPRODUCTION_COMPLETE\n');
end
