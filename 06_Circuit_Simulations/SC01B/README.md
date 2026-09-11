# SC-01B: circuit-derived MOSFET switching source

SC-01B compares a native Simscape half-bridge with the unchanged original Infineon MOSFET equations in ngspice. It keeps a fixed five-case experiment, numerical refinements, diagnostic records and failed operating points. Numerical agreement is separate from suitability of the modeled switching behavior and from physical source validation.

The 47 Ω gate-resistance screen exposed a large current spike and unresolved switching events. The final campaign retains this case and computes its status from the recorded evidence. Do not interpret a waveform-comparison pass, successful simulation completion or passing software tests as acceptance of every operating point.

## Run the complete campaign

MATLAB R2026a with Simulink, Simscape and Simscape Electrical is required. The original `IAUC100N04S6L014.cir` must remain available under the installed MATLAB `toolbox/physmod/elec/supporting_files` directory. It is an external dependency and is not redistributed here.

The default portable ngspice runtime is expected at `SC01B/tools/ngspice/bin/ngspice.exe`, with its supporting runtime files. The tested runtime is the official ngspice 41 Windows x64 package; its source and hashes are recorded in [Device_Source_and_Assumptions.md](Device_Source_and_Assumptions.md). An alternate executable path can be supplied explicitly.

From the **project root**, run this single MATLAB command:

```matlab
run(fullfile('06_Circuit_Simulations','SC01B','sc01b_startup.m')); study = sc01b_main;
```

For a separately stored portable runtime or a separate output folder:

```matlab
study = sc01b_main(NgspiceExecutable="C:\path\to\ngspice\bin\ngspice.exe", ...
    OutputFolder="C:\path\to\SC01B-results");
```

The command builds or loads the native model, runs all five cases and declared refinements, performs the test suite, exports the evidence, and generates the report and figures. It does not fit transistor parameters. The script records failed numerical/operating-point checks rather than replacing them with a successful overall claim. Simulation diagnostics, incomplete execution or failing automated tests can stop the run; a completed campaign's status remains in `status.json` and `study.mat`.

Each default run selects a fresh `results/verification_<UTC timestamp>` directory, adding a suffix if that name already exists. An explicit output folder must be empty unless `ReuseCompletedRuns=true` is supplied; populated destinations are rejected before any campaign output is written. The preserved `results/verification` directory is historical evidence. The output safeguard changes run orchestration only; the original circuit equations, acceptance criteria and historical evidence remain unchanged.

The explicitly requested stricter SPICE check may fail to complete. That attempt is recorded as rejected, with its log and `rejected.json`; its partial waveform is never admitted as a completed reference. Such a rejection fails the full numerical gate. It does not stop the remaining frozen cases from being evaluated.

To resume completed native records from the same output folder, pass `ReuseCompletedRuns=true` with that explicit `OutputFolder`. This authorizes updating that campaign's output files. Reuse requires exact parameter/settings agreement and a matching SHA-256 over the saved model, relevant source files, vendor implementation and MATLAB version. The default is to run fresh. The final local execution used three isolated workers and `sc01b_collect_workers`; the collector requires all five unique cases, all 29 attempted-run records and 24 comparisons before running the full regression suite. A reused record has zero new runtime and `Reused=true` in `runs.csv`.

To regenerate the report and plots from an existing completed study without rerunning simulations:

```matlab
folder = fullfile(sc01bRoot,'results','verification');
saved = load(fullfile(folder,'study.mat'),'study');
sc01b_make_report(saved.study,folder);
```

## Independent exported-data audit

`scripts/audit_sc01b_exports.py` requires Python with NumPy and runs without MATLAB. From the project root, audit the nominal CSV exports with:

```powershell
python .\06_Circuit_Simulations\SC01B\scripts\audit_sc01b_exports.py nominal
```

Supply all five case names to audit the complete collected campaign: `nominal holdout_bus18 holdout_load4ohm holdout_gate47 holdout_bus30_load16_gate10`. The helper independently checks current/voltage identities, reconstructed gate commands, external energy closure, waveform differences and native modeled channel overlap. It preserves source-file hashes and does not replace event or complete-campaign acceptance checks.

By default, inputs come from `SC01B/results/verification`, and the JSON audit is written to its `supplemental/independent_csv_audit.json`. Use `--results "C:\path\to\worker-results"` and, optionally, `--output "C:\path\to\audit.json"` to audit another output folder. Without `--output`, the report is saved under the selected results folder. Repeated calls update the selected cases in the existing JSON record.

## Model and comparison scope

The nominal fixture uses a 24 V source, an 8 Ω / 2.5 mH load, a consistent initially-on high-side state, and one off/on commutation pair over 5 µs. The five cases vary supply voltage, load resistance and external gate resistance. The driver is a 12 V datasheet-informed approximation with a fixed 3 Ω output resistance, 22 Ω nominal external gate resistance, assumed 20 ns internal ramp and typical 20/19 ns propagation delays. It is not the complete UCC27211A IC model.

Native trapezoidal physical-network steps are 0.5, 0.25 and 0.125 ns; original-SPICE maximum steps are 0.25 and 0.125 ns. Nominal and combined-extension cases receive additional tolerance checks. Comparisons cover 1–5 µs and preserve the time origin. The allowance is the **larger** of an absolute allowance and a relative allowance: waveform 0.01 V or 0.01 A versus 1% of reference peak absolute amplitude; signed energy 1 nJ versus 1%; closure 0.1 nJ versus 0.1%. Matched event timing must be within 1 ns, with required events resolved and classifications matched.

The final report distinguishes waveform comparisons, full numerical acceptance, event/terminal-voltage checks, modeled channel overlap, energy closure and automated tests. Signed device terminal energy includes stored-charge transfer and is not semiconductor heat. An unfitted operating point is not blinded physical validation data. The fixed criteria were recorded after exploratory solver selection and the first SPICE screen.

## Files and evidence

| File or folder | Purpose |
|---|---|
| [Device_Source_and_Assumptions.md](Device_Source_and_Assumptions.md) | Device provenance, fixture assumptions, initialization and scope |
| [references/Source_Manifest.json](references/Source_Manifest.json) | Official manufacturer PDF sources, revisions and verified hashes |
| `functions/sc01b_parameters.m`, `sc01b_case.m`, `sc01b_criteria.m` | Frozen nominal fixture, five cases and acceptance criteria |
| `scripts/sc01b_main.m` | Complete reproduction campaign |
| `models/EMI_SC01B_Device_Halfbridge.slx` | Native Simscape model |
| `tests/` | Analytic metric and campaign-helper tests |
| `results/verification/SC01B_Validation_Summary.md` | Generated human-readable result and limitations |
| `results/verification/Overview.png`, `Switching_Overlay.png` | Campaign overview and native/original-SPICE overlays |
| `results/verification/study.mat`, `status.json`, `criteria.json` | Complete study, status flags and frozen criteria |
| `results/verification/runs.csv`, `comparisons.csv`, `waveforms.csv` | Simulation diagnostics and numerical comparison evidence |
| `results/verification/metrics.csv`, `events.csv`, `balance.csv` | Physical quantities, event classification and energy accounting |
| `results/verification/test_results.mat` | Individual automated-test results |
| Per-case output folders | Parameters, all integration/tolerance records, original-SPICE decks/logs and finest trace CSVs |

The next design work is to investigate gate drive, dead time and clamp assumptions under the retained stress case, then run a separately identified revision of the campaign. Physical parameter identification and measured commutation evidence follow before the source is treated as representative of the robot hardware. Keep the current evidence and its failures intact.
