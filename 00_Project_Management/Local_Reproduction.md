# Local source history and fresh-checkout reproduction

For the current public package, use the [September 2026 publication reproduction guide](../09_Report/Publication_2026-09-11/Publication_Reproduction.md). It covers the included six-input ZIP, portable path examples, the complete 468-test suite and retained historical data/runtime requirements. The local-history and original-machine examples below remain as checkpoint context.

The project now has local Git history. The `audit-baseline-2026-09-10` tag preserves the 293 source, model, documentation, reference and configuration files whose bytes matched the full audit, before consolidation edits. Its commit is `7b55eb55ff04b6f3908115e26b092a84025a1d44`. Agent-created commits use the explicit **Codex Local Checkpoint** identity; they do not assert user authorship. No remote repository is configured or required.

## What belongs in history

Track implementation, tests, saved source models, assumptions, experiment contracts, compact provenance manifests and research records. Keep generated results, the dated audit packages, runtime distributions and compilation caches on disk outside Git. The [.gitignore](../.gitignore) records those boundaries; ignoring a file does not delete it.

The [.gitattributes](../.gitattributes) file disables automatic line-ending conversion so a checkout preserves the source bytes used by numerical provenance fingerprints. Source files retain their existing line endings; this milestone does not reformat the project.

Keep the complete original project evidence and local runtimes backed up separately. Historical reports still link into those retained trees. A source-only clone is not a full archive of every previous campaign. The [full audit](Audits/2026-09-10_Full_Project_Audit/Full_Project_Audit.md) records the older checkpoint restoration chain and its verified scope.

## Pinned local inputs

[Local_Dependencies.json](Local_Dependencies.json) pins each dependency by project-relative path, byte count and SHA-256:

- `regression_inputs`: the frozen Phase 2B profiles and loaded-stop response used by the tests.
- `motion_history`: the original tuning reversal used for the optional motion study's historical identity check.
- `circuit_runtimes`: the retained original/R2 ngspice distributions and provenance records.
- `experiment_source`: the nominal native R2 waveform, parameters and source-identity record prescribed by the next experiment's design. Copying them does not execute that experiment.

The [bootstrap tool](scripts/bootstrap_local_dependencies.py) copies these from a retained local project folder into its own checkout. It checks the whole selected set before writing, rejects altered inputs and differing existing destinations, and checks every copied file. It never downloads dependencies or overwrites a different file. Use a current Python 3.10+ interpreter; the tool needs only Python's standard library.

## Reproduce in a separate checkout

From PowerShell, choose a new checkout directory and use the existing project as the local source. These variables are examples for this computer; change the destination if it already exists.

```powershell
$sourceProject = 'C:\Users\adand\OneDrive\Desktop\Projects\EMI-Resilient Control System for Robotics'
$freshCheckout = 'C:\Users\adand\Documents\EMI-local-checkout'
git clone --local $sourceProject $freshCheckout
python "$freshCheckout\00_Project_Management\scripts\bootstrap_local_dependencies.py" --evidence-root $sourceProject --dry-run
python "$freshCheckout\00_Project_Management\scripts\bootstrap_local_dependencies.py" --evidence-root $sourceProject
```

The dependency manifest records the tested MATLAB version and required products. Installations are not copied into Git. The R2 vendor component is the model supplied with that MATLAB installation; native and SPICE source-identity checks record the actual dependencies. Changing a runtime or pinned input is a new validation scope, not a reason to bypass a hash mismatch.

In MATLAB, set `projectRoot` to the fresh checkout. Keep generated files in a new temporary location and add only the selected circuit paths:

```matlab
projectRoot = 'C:/Users/adand/Documents/EMI-local-checkout';
cd(fullfile(projectRoot,'03_MATLAB')); startup_project;
checkOutput = tempname; mkdir(checkOutput);
Simulink.fileGenControl('set','CacheFolder',fullfile(checkOutput,'cache'), ...
    'CodeGenFolder',fullfile(checkOutput,'codegen'),'createDir',true);
a = fullfile(projectRoot,'06_Circuit_Simulations','SC01A');
b = fullfile(projectRoot,'06_Circuit_Simulations','SC01B_R2');
fw = fullfile(projectRoot,'06_Circuit_Simulations','FOUR_WAY');
addpath(fullfile(a,'functions'),fullfile(a,'scripts'), ...
    fullfile(b,'functions'),fullfile(b,'scripts'),b);
suite = [matlab.unittest.TestSuite.fromFolder(fullfile(projectRoot,'03_MATLAB','tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(a,'tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(b,'tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(fw,'tests'))];
results = run(suite);
writetable(table(results),fullfile(checkOutput,'tests.csv'));
assertSuccess(results);
```

This is the regression suite, not all historical research campaigns. Use the documented entrypoints for additional studies. Default baseline/Phase 2B/SC01A runs now create fresh destinations; an explicit populated destination is rejected. Keep the historical datasets when reproducing an old comparison and check its manifest, scope and settings. A missing optional historical input must not be reported as an executed comparison.

## Record a new milestone

Inspect `git status` and `git diff` before staging. Add intended sources/documents explicitly, run checks appropriate to the change, and create a local commit. Keep a dated result report with the commit identifier, source/runtime manifests, dependencies, test outcome and unchanged/failing historical comparisons. A tracked experiment contract records design choices; it is not evidence that the experiment already ran.

For restoration, make another local clone or inspect an earlier tag in a separate worktree. Do not reset the active project or extract an old snapshot over it to inspect history.


## Causal receiver checkpoint (2026-09-11)

The four-way engine additionally requires a locally configured MATLAB-supported C++ compiler. Run startup_project, then run_fourway_receiver_tests with a new output folder. The wrapper builds a source-hash-named MATLAB extension in 06_Circuit_Simulations/FOUR_WAY/work; generated binaries stay outside Git. The original pinned dependency manifest remains unchanged. New acceptance inventory hashes bind the actual compiled binary, engine source, current helpers/tests, frozen design and selected native model.

Use run_fourway_stage("development",newFolder) to reproduce all 16 development records. PLAN-V1 currently fails its receiver-domain acceptance gate. The saved rejected acceptance manifest cannot enable evaluation. Complete native traces and tightened reruns are retained under 06_Circuit_Simulations/FOUR_WAY/results/native_checkpoint_20260911 with original-to-project path mappings and SHA-256 verification. The original waveform inputs are still required; the source ZIP does not replace those data/runtime backups.
