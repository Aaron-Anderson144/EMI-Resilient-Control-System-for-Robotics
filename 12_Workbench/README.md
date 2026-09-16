# EMI Robotics · Signal Lab

A local interface for the existing EMI robotics project. It brings experiment launch, live logs, and run artifacts together. The MATLAB models remain the source of the calculations.

## Portable desktop edition

Download the [Windows desktop release](https://github.com/Aaron-Anderson144/EMI-Resilient-Control-System-for-Robotics/releases/latest), extract the entire ZIP, and double-click **Open EMI Workbench.lnk**. This shortcut is the main way to launch the workbench. Keep it with the rest of the extracted folder.

The desktop edition includes its own Python and browser runtimes and a compact project snapshot. Its results are saved in that copy's `workspace/12_Workbench/runs`. New workflows still use separately installed MATLAB. See the release's top-level **START HERE.md**, or [desktop packaging guide](desktop/README.md) in the development source.

The instructions below describe the source checkout and first integration checks. The same shortcut name is used in both distributions: the portable release opens its desktop window, while the source checkout opens the browser interface. The desktop edition selects an available local port automatically.

## Start from the development project

On Windows, clone or download and extract the entire repository. Double-click **Open EMI Workbench.lnk** in the project root. Its relative target calls `Start EMI Workbench.cmd`, which opens the workbench in your browser and reuses it when it is already running. Downloading the shortcut alone is insufficient.

The default port is 8765; the Windows launcher remembers a different port when one is selected. The source checkout needs Python 3.10 or newer, with no additional Python packages or internet services. MATLAB is required to launch experiments; saved evidence remains available without MATLAB. The portable desktop release includes Python.

If Python is installed elsewhere, set `EMI_PYTHON` to its executable path before launching. The launcher also recognizes the bundled local Codex Python runtime. Set `MATLAB_EXECUTABLE` to a MATLAB executable to override automatic discovery.

For direct startup from a terminal:

```powershell
python 12_Workbench/server.py
```

Use `--port 8766` for a different port, `--no-browser` to start without opening a browser, or `--matlab "C:\Program Files\MATLAB\R2026a\bin\matlab.exe"` to select MATLAB. The Windows launcher accepts `-Port 8766` and `-NoBrowser` through `12_Workbench/Start-Workbench.ps1`.

## What you can do

- Run the clean baseline and inspect its position response, command voltage, metrics, and data.
- Run **Receiver v2 characterization** to inspect matched clean/disturbed fixtures, circuit capacitance, receiver assumptions, voltage limits, and encoder errors.
- Run **Four-way v2 development** to compare the four control arms on the two declared development fixtures under all 16 receiver assumptions.
- Run **Four-way v2 evaluation** to inspect all 1,536 records, 768 matched comparisons, and 16 independent benefit screens.
- Run **Source-return comparison** to inspect 256 diagnostic records and 128 comparisons.
- Run the focused circuit and receiver checks.
- Run the robotics test suite.
- Follow a run's log, revisit saved runs, and open their artifacts.
- Reach the roadmap, receiver revision brief, and research documentation.

The workflows use declared experiment settings. Receiver characterization uses a reproducible sweep defined by the [receiver v2 contract](../04_EMI_Models/Receiver_V2_Contract.md). The [next four-way experiment plan](../04_EMI_Models/Four_Way_EMI_Experiment_V2.md) records how the characterization informs the next comparison. General parameter editing remains a future integration step.

## How to read the results

Imported evidence cards and imported run entries are omitted from the app. The original project evidence remains saved. A completed run means its selected workflow finished successfully. It does not establish hardware validity or demonstrate a combined mitigation benefit.

Receiver characterization is conditional simulation evidence. A completed sweep can contain out-of-domain cases, unresolved cases, clean errors, or no suitable comparison candidate. Read its findings, interpretation limits, case table, and report before interpreting the declared comparison; retain failing cases and the reserved evaluation cells. A candidate under a behavioral assumption is not measured receiver validation. The historical PLAN-V1 rejection is unchanged. PLAN-V2 evaluation and source-return controls verify the accepted v2 setup before each launch. The EDMD study remains a separate estimation study and is not connected to motor control by this interface.

## Receiver characterization workflow

Select **Receiver v2 characterization**, then **Run experiment**. The adapter invokes `run_receiver_characterization` in a fresh `output/receiver_characterization` folder and retains the runner's findings in the workbench result. The run detail shows domain counts, persistent count errors, pulse-model sensitivity, interpretation limits, and the case table. A scrollable table keeps clean and disturbed cases visible together. Saved outputs include:

- `report.md`: findings and interpretation.
- `summary.json`: machine-readable findings and case records.
- `cases.csv`: voltage extrema, domain violations, errors, timing, and convergence for the full sweep.
- `characterization.png`: the saved characterization plot.
- `details/`: per-case traces and event timing, grouped separately in the interface.

The **Completed** badge describes execution success. The runner's `suitableForFourWay` field covers only the clean-case numerical prerequisite; every disturbed control case still requires its own domain and behavior checks. Neither changes the historical acceptance record. **Receiver model checks** remains the existing causal-receiver regression workflow.

## Stored runs

### Four-way v2 development

The development workflow invokes `run_fourway_v2_stage("development", ...)` in a fresh output folder. It runs 256 clean/disturbed records and reports 128 matched comparisons separately by receiver assumption and control arm. It requires the project's licensed MATLAB products, including Parallel Computing Toolbox; the runner uses up to eight workers and may take several minutes.

The result table shows domain and numerical checks, clean and execution guards, paired motion error, current, encoder-count error, and task success. Full `metrics.csv`, `record_index.csv`, recovery and episode tables, execution identity, and individual traces remain available as artifacts. Failed records stay indexed; an incomplete campaign is a failed workflow. A completed campaign can still have failed research guards and does not establish mitigation benefit or physical validity. Reserved evaluation has a separate launcher and requires the accepted local source and evidence binding described below.

### Accepted v2 evaluation and source-return controls

Select **Four-way v2 evaluation** or **Source-return comparison**, then **Run experiment**. Signal Lab verifies the original accepted source, protocol, test, native-circuit, and development evidence before creating a run. MATLAB repeats its unchanged scientific acceptance check. Missing or changed evidence disables these two controls with an explanation; other workflows remain available.

Those two workflows require a local binding to the original accepted scientific project and receipt. Public source checkouts and downloadable releases leave this binding unset, so both controls explain that the accepted setup is not configured. The other workflows remain available. Exact source and evidence paths are part of the pinned receipt; moving the app alone does not transfer that accepted setup. The accepted runner also requires the installed `py -3.12` launcher, MATLAB, and Parallel Computing Toolbox.

If the original accepted source and full evidence archive are available on this computer, create `12_Workbench/local/accepted-science.json` in the source checkout, or `workspace/12_Workbench/local/accepted-science.json` in the extracted desktop app, then restart the app. Supply the absolute locations of the original accepted source and receipt:

```json
{
  "scientific_project_root": "C:/Research/OriginalAcceptedProject",
  "acceptance_path": "C:/Research/OriginalEvidence/implementation_acceptance.json"
}
```

These are placeholders, not locations to which accepted files can simply be moved. The original paths recorded throughout the receipt and evidence must still resolve. This private configuration is excluded from Git and public app packages. It selects locations only: it cannot replace the pinned receipt, verifier, or scientific checks. Changing the scientific implementation or rebuilding its acceptance is a separate research acceptance process.

Both workflows save fresh results in the app's own run folder. Evaluation displays all 768 matched comparisons and the 16 benefit screens separately. Source-return comparison displays all 128 comparisons. Successful execution does not imply a passing benefit screen. Full raw records remain on disk; summary files and `output/artifact_index.csv` provide a compact downloadable inventory.

The completed research milestone is independent of readiness for a new run. The saved study passed its simulation guards but did not meet the declared combined-benefit criterion under any of the 16 assumptions. It does not establish hardware validity.

New workbench records are stored in `12_Workbench/runs/<run-id>/`, including the launch record, log, result summary, and `output/` artifacts. Run folders and local server logs are excluded from source control. Existing test workflows may also use their normal temporary or compiled-cache folders.

One MATLAB job runs at a time. Keep the workbench available while a job runs. If the server restarts, a still-running recorded process blocks a second run. When that orphaned process ends, the run is marked interrupted because its exit code was not observed; review its retained log and artifacts before rerunning. A crash during the small interval between process launch and saving its identity requires local recovery: first confirm that MATLAB has ended, then move that run folder into an archive outside `runs/` and restart the workbench. This release has no cancel button.

The service listens only on the loopback address. It accepts a fixed list of workflows, checks requests from the interface, and restricts file serving to the workbench's published evidence and artifacts. It is intended for local research use.

## Development checks

```powershell
python -m unittest discover -s 12_Workbench/tests -v
```

The integration tests exercise workflow selection, isolated output, failures, job serialization, restart behavior, and HTTP/file boundaries. MATLAB workflow checks require the project's installed products and retained fixtures; see `00_Project_Management/Local_Reproduction.md` for those dependencies.

## First integration verification — 15 September 2026

- Two real baseline runs completed, with identical summary metrics and byte-identical time-series CSVs. Their comparison was checked in the browser.
- The focused receiver workflow passed 11/11 tests.
- The project workflow passed the established 468/468 robotics tests across `03_MATLAB/tests`, `SC01A/tests`, `SC01B_R2/tests`, and `FOUR_WAY/tests`. An earlier 394-test main-folder smoke run is retained in history; its recorded count reflects that initial scope.
- Backend checks passed 30/30, and MATLAB adapter checks passed 6/6. These cover different integration scopes and should not be summed with the robotics suite.
- Run launch, disabled duplicate submission, saved history, plot loading, expandable logs, comparison selection, and narrow-window layout were checked in the browser. All 27 distinct published evidence/document/output links checked returned their files.
- All 16 frozen experiment files retained their recorded hashes. Of the 569 pre-existing tracked files checked, only the root README changed, to add the workbench entry points.

These checks verify the interface and its integration with existing workflows. Those initial checks predate the added v2 controls. Scientific source, protocol, and acceptance records remain unchanged by this interface update.
