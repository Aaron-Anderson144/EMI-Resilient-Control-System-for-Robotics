# SC-01B R2: revised switching drive

R2 addresses the original SC01B gate recrossing, simultaneous channel conduction and 47 Ω current spike with a separately identified circuit revision. The original `SC01B` campaign and its failed evidence remain intact. Actual R2 acceptance is generated from the collected run records; completing a simulation or agreeing with SPICE does not alone resolve the switching failures.

The revised behavioral driver commands **+12 V on / −1.5 V off**, retains the original 10/22/47 Ω external **turn-on** resistance cases, and uses **3 Ω total discharge resistance**. The original 300 ns dead time, 20 ns linear ramps and 20/19 ns delays remain. The directional gate impedance and negative rail are new assumptions; this is not an unchanged UCC27211A driver implementation. MOSFET equations and package parasitics are unchanged.

## Reproduce locally

MATLAB R2026a, Simulink, Simscape and Simscape Electrical are required. Place this `SC01B_R2` folder within the existing project's `06_Circuit_Simulations` folder; the complete regression suite also requires that project's `03_MATLAB` and sibling `SC01A` folders. The original vendor file must remain installed at `<matlabroot>/toolbox/physmod/elec/supporting_files/IAUC100N04S6L014.cir`; it is not redistributed here. The bundled portable ngspice runtime and supporting files are under `SC01B_R2/tools/ngspice`.

From the project root:

```matlab
run(fullfile('06_Circuit_Simulations','SC01B_R2','sc01b_startup.m'));
study = sc01b_main;
```

For a separately installed runtime or another output folder:

```matlab
study = sc01b_main(NgspiceExecutable="C:\path\to\ngspice\bin\ngspice.exe", ...
    OutputFolder="C:\path\to\R2-results");
```

The default output is a unique `SC01B_R2/results/verification_<UTC stamp>` folder; `results/verification` retains the archived campaign. An explicit populated output folder is rejected unless `ReuseCompletedRuns=true` is requested. The command builds/loads the R2 native model, runs the five cases and all declared refinements, executes regression tests and generates the report. Failed required strict-SPICE attempts remain rejected records and fail full numerical acceptance; they do not prevent the other cases from being evaluated.

The refinement values and consistency cases come from `functions/sc01b_criteria.m` and are saved in `criteria.json`. The current campaign workflow uses **three native steps and two SPICE steps**; changing sequence lengths requires a new implementation and separately identified campaign. Report labels and acceptance expectations derive from recorded criteria, so changing the step values does not leave obsolete finest-step captions. Never combine records with different criteria as though they were one campaign.

For local parallel work, assign disjoint case lists using `Cases=[...]`, separate `OutputFolder` values and `Finalize=false`. `sc01b_collect_workers(partFolders,outputFolder)` requires the complete unique matrix and matching source/settings provenance before finalization. `ReuseCompletedRuns=true` reuses only exact parameter/settings and source-identity matches; the default runs fresh. Keep the native implementation and model fixed while workers execute.

Regenerate the report from a finalized study without rerunning simulations:

```matlab
folder = fullfile(sc01bRoot,'results','verification');
saved = load(fullfile(folder,'study.mat'),'study');
sc01b_make_report(saved.study,folder);
```

## Acceptance and interpretation

The generated report and `status.json` distinguish:

| Flag | Meaning |
|---|---|
| `executionPassed` | Every required run reached its requested stop with the declared step and no warnings |
| `numericalCampaignPassed` | Required execution, waveform, initial-state, event, current-timing, energy and closure checks pass |
| `modeledChannelOverlapPassed` | Every native refinement/consistency run has zero simultaneous positive channel conduction above its declared current floor |
| `operatingPointsPassed` | Complete finite records, resolved events, terminal voltage limits and modeled channel-overlap checks pass |
| `switchingFailuresResolved` | Both the full numerical and operating-point gates pass |
| `physicalSourceValidated` | Remains false; matching the same vendor equations is not hardware validation |

The channel floor is max(1 mA, 0.1% of peak load current). Terminal-current coincidence and gate midpoint overlap are diagnostics, not substitutes for internal channel currents. Gate diagnostic levels remain **1.2, 6 and 10.8 V**, referenced to the original +12 V level; they are not fractions of the bipolar excursion. Original −0.1 to +0.5 µs command windows and strict crossing rules remain.

The nominal fixture is 24 V with an 8 Ω / 2.5 mH load, initialized consistently with the high-side device on. One off/on pair is recorded over 5 µs, with comparisons starting at 1 µs. Supply, load and turn-on gate resistance vary across the same five case names. R2 drive settings were selected using these local screens, so the cases are regression/operating-point checks, not blinded holdouts.

The SPICE remedy combines algebraically equivalent clipped-linear behavioral command sources with **fixed 1 ns TSTEP, separate from integration maximum TMAX**. With `wrdata` and no `interp`, exported samples retain actual integration times, and the adapter checks each completed record against TMAX. Ramp durations, timing and strict tolerances remain unchanged. Source conversion alone was insufficient at finer steps. The [solver resolution](results/verification/supplemental/solver/Solver_Resolution.md) and [portable solver supplement](results/verification/supplemental/solver/README.md) retain 19 accepted strict checks and 132 signal comparisons, including all five cases at 0.0625 ns and nominal/combined cases at 0.03125 ns. These supplement the declared campaign; they do not replace required failed checks or establish a particular internal simulator defect.

## Evidence

| Artifact | Purpose |
|---|---|
| [Device_Source_and_Assumptions.md](Device_Source_and_Assumptions.md) | Device provenance, bipolar drive assumptions, limitations and primary references |
| [references/SC01B_Baseline_Summary.json](references/SC01B_Baseline_Summary.json) | Original finest native metrics and source hashes for portable before/after reporting |
| `models/EMI_SC01B_R2_Halfbridge.slx` | R2 native half-bridge model |
| `+sc01b_driver/` | Passive directional gate-impedance component |
| `results/verification/SC01B_Validation_Summary.md` | Generated review, computed acceptance and before/after table |
| `Overview.png`, `Switching_Overlay.png` in the results folder | Original/R2 current peaks, comparison ratios and native/SPICE voltage/gate overlays |
| `study.mat`, `status.json`, `criteria.json` | Final study, status gates and criteria |
| `runs.csv`, `comparisons.csv`, `waveforms.csv` | Execution, rejection and numerical-comparison evidence |
| `metrics.csv`, `events.csv`, `balance.csv` | Operating quantities, strict event flags and signed energy accounting |
| Per-case result folders | Parameters, source decks, logs, all refinements and finest exports |

The [portable driver investigation](results/verification/supplemental/driver/README.md) retains all 48 screen attempts, their exact decks/controls/logs, six numerical failures and selected fine compressed samples. Its reproduction script takes explicit runtime/vendor paths and a new output directory. An independent exported-data audit complements the MATLAB campaign; its results do not replace the complete acceptance helper. Signed MOSFET terminal energy includes stored-charge transfer and is not identified as semiconductor heat.

After the declared switching gates pass, the next source-validation step is to identify a realizable bipolar drive and characterize commutation, negative-rail generation, parasitics and tolerances. Bootstrap behavior, complete driver dynamics, temperature variation, physical layout and measured robot commutation remain outside R2.
