# Reproducing the September 2026 publication

This guide accompanies the [progress report](EMI_Robotics_Progress_Report.pdf) and the [causal receiver checkpoint](../../00_Project_Management/Causal_Receiver_Checkpoint.md). It separates the evidence included in source history from the files and licensed tools needed for new executions.

The reported numerical checkpoint is local source commit `a288d344deddd19b5f2fb5abb2b247a04168c972`, tagged `causal-receiver-checkpoint-2026-09-11` in the original project history. A publication commit may have a different identifier because it also contains documentation and publication assets. Use the per-campaign manifests and hashes to identify numerical inputs; publication alone does not revalidate modified code.

## Three levels of reproduction

| Level | What you can do | What you need |
|---|---|---|
| 1. Read source and recorded evidence | Inspect implementation, frozen design, published figures and compact acceptance records | This repository and a document viewer; no MATLAB execution required |
| 2. Run the analytical baseline | Generate a new clean actuator response and metrics | MATLAB and Control System Toolbox; source files |
| 3. Repeat the full suite or campaigns | Execute regression fixtures, native comparisons, development records or historical studies | Tested MathWorks products, C++ compiler where applicable, pinned data/runtimes and the records required by the selected workflow |

The publication also supplies [Public_Reproduction_Inputs.zip](Public_Reproduction_Inputs.zip), containing the six project-generated pinned inputs for regression, motion history and source replay. The source tree, compact evidence and these six inputs are not a backup of every historical dataset or runtime. Missing input files must remain an explicit reproduction gap; do not substitute new data and call it an exact historical reproduction. Historical Markdown reports are copied unchanged for traceability; some embedded figures and links into deep time-series or native-run folders still require the retained full project archive.

## Level 1 Inspect the publication

Start with these records:

- [Research question and objectives](../../00_Project_Management/Research_Charter.md)
- [Current numerical checkpoint](../../00_Project_Management/Causal_Receiver_Checkpoint.md)
- [Full test result table](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/all_project_tests.csv)
- [Legacy record identity](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/legacy_equivalence.json)
- [Native comparisons](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/native_final_acceptance.csv) and [refinements](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/native_final_refinements.csv)
- [Independent exported-record audit](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/independent_audit.json)
- [Development domain and clean-decoder checks](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/domain_and_clean_decoder_summary.csv)
- [Rejected acceptance manifest](../../00_Project_Management/Verification/Causal_Receiver_2026-09-11/rejected_acceptance.json)

The manifest deliberately records rejection. It cannot authorize evaluation. Compact CSV/JSON records support inspection of the reported outcome; the complete event and time-series records are required to repeat the independent reconstruction.

## Level 2 Run the clean analytical baseline

In MATLAB, set the current folder to this checkout's `03_MATLAB` folder and run:

```matlab
startup_project
study = run_baseline;
```

The entrypoint creates a fresh timestamped results folder. An explicit new or empty destination is also supported:

```matlab
study = run_baseline(fullfile(tempdir, "emi_baseline_" + ...
    string(datetime("now", "Format", "yyyyMMdd_HHmmss_SSS"))));
```

This run exercises the representative clean analytical actuator. It does not reproduce the 468-test suite, circuit campaigns or EMI treatment comparison.

## Level 3 Restore inputs and execute the full suite

The tested environment was MATLAB **R2026a Update 3** with MATLAB, Simulink, Control System Toolbox, Simscape and Simscape Electrical. A MATLAB-supported C++ compiler must be configured for the receiver extension. Python 3.10 or later is sufficient for the standard-library-only dependency bootstrap. The independent exported-record audit additionally uses NumPy.

The original [dependency manifest](../../00_Project_Management/Local_Dependencies.json) contains 40 pinned files in four groups: regression inputs, motion history, experiment source and circuit runtimes. It is preserved unchanged. Its September 10 description of a then-design-only experiment is historical metadata; the September 11 implementation and rejected development outcome are documented separately.

To restore the six included inputs, extract the ZIP to a separate new evidence folder and run the bootstrap with the three relevant groups. From the repository root in PowerShell:

```powershell
$publicationInputs = Join-Path $env:TEMP ('emi_publication_inputs_' + [guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath '.\09_Report\Publication_2026-09-11\Public_Reproduction_Inputs.zip' -DestinationPath $publicationInputs
python .\00_Project_Management\scripts\bootstrap_local_dependencies.py --evidence-root $publicationInputs --group regression_inputs --group motion_history --group experiment_source --dry-run
python .\00_Project_Management\scripts\bootstrap_local_dependencies.py --evidence-root $publicationInputs --group regression_inputs --group motion_history --group experiment_source
```

The bootstrap tool copies from an evidence folder; it does not download missing files. The remaining 34 pinned entries are circuit runtimes and their documentation. For the complete 40-file set, use a retained project archive containing those exact files. The public repository may retain some runtime files from earlier publication history; their presence is not a claim that both pinned distributions are complete. Replace the example path below with the retained archive:

```powershell
$retainedEvidence = 'D:\ResearchArchives\EMI-retained-project'
python .\00_Project_Management\scripts\bootstrap_local_dependencies.py --evidence-root $retainedEvidence --dry-run
python .\00_Project_Management\scripts\bootstrap_local_dependencies.py --evidence-root $retainedEvidence
```

The tool checks the full selected set before copying and refuses missing inputs, changed hashes or differing destination files. The runtime group preserves the original and R2 ngspice distributions and their provenance. The R2 vendor model comes from the tested MATLAB installation and is not supplied by the bootstrap.

In MATLAB, open the checkout's root folder, configure a supported C++ compiler if necessary (`mex -setup C++`), then use the complete suite below. The fourth test folder is essential: it includes the 11 causal receiver tests and was absent from the older consolidation-only example.

```matlab
projectRoot = pwd;
cd(fullfile(projectRoot, '03_MATLAB'));
startup_project;

checkOutput = tempname;
mkdir(checkOutput);
Simulink.fileGenControl('set', ...
    'CacheFolder', fullfile(checkOutput, 'cache'), ...
    'CodeGenFolder', fullfile(checkOutput, 'codegen'), ...
    'createDir', true);

a = fullfile(projectRoot, '06_Circuit_Simulations', 'SC01A');
b = fullfile(projectRoot, '06_Circuit_Simulations', 'SC01B_R2');
fw = fullfile(projectRoot, '06_Circuit_Simulations', 'FOUR_WAY');
addpath(fullfile(a, 'functions'), fullfile(a, 'scripts'), ...
    fullfile(b, 'functions'), fullfile(b, 'scripts'), b);

suite = [ ...
    matlab.unittest.TestSuite.fromFolder(fullfile(projectRoot, '03_MATLAB', 'tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(a, 'tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(b, 'tests')), ...
    matlab.unittest.TestSuite.fromFolder(fullfile(fw, 'tests'))];
results = run(suite);
writetable(table(results), fullfile(checkOutput, 'all_project_tests.csv'));
save(fullfile(checkOutput, 'results.mat'), 'results', '-v7');
assertSuccess(results);
```

At the recorded checkpoint this suite contained 468 tests and all passed. A new run must report its own test count, failures and incomplete tests. A successful regression is numerical software evidence, not evidence that all historical research campaigns have been rerun or that a receiver-domain failure has become usable.

The receiver helper builds a source-hash-named extension under `06_Circuit_Simulations/FOUR_WAY/work`. A compiler/platform change can change the binary hash even when source bytes match. Save the new runtime and implementation identity; do not bypass the evaluation gate's exact inventory checks.

## Repeat a selected research campaign

After `startup_project`, the causal entrypoints are:

```matlab
receiverOutput = tempname;
receiverReport = run_fourway_receiver_tests(receiverOutput);

developmentOutput = tempname;
development = run_fourway_stage("development", developmentOutput);

nativeOutput = tempname;
nativeReport = run_fourway_native_acceptance(nativeOutput);
```

Use distinct new destinations for every run. The focused receiver suite, 16-record development run and native comparison are separate operations with different costs. Retain failures and their original settings. The published final native comparison set also includes six documented tighter-tolerance reruns; the initial entrypoint alone must not be described as reproducing those final 24 accepted numerical comparisons. See the [checkpoint](../../00_Project_Management/Causal_Receiver_Checkpoint.md) for the original and final record distinction.

The development command reproduces the frozen PLAN-V1 task. It does not authorize the planned 96 evaluation or 16 closure-production records. At this checkpoint, both development-domain and strict native-usability acceptance are false. No evaluation or closure run should be opened using the saved rejection manifest.

Historical entrypoints and their required datasets are recorded in [Local Reproduction](../../00_Project_Management/Local_Reproduction.md), the individual design notes and retained study reports. The original 116-record controller identity is a separate historical comparison: repeating the unit suite alone does not recreate that assertion. Likewise, the 352-check audit requires the full 16 exported records and eight paired scores, not only the compact audit JSON.

## Preserve provenance

Record the source revision, products and compiler, input hashes, settings, exact output destination and every failure. Keep frozen PLAN-V1 input files unchanged. If a receiver/topology decision requires different assumptions, create a new reviewed experiment version and retain the original negative outcome. New numerical agreement or a document update does not establish physical immunity, safety or compliance.
