# EMI Robotics · Signal Lab

A local interface for the existing EMI robotics project. It brings the saved research checkpoint, experiment launch, live logs, and run artifacts together. The MATLAB models remain the source of the calculations.

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

- Read the saved verification checkpoint with links to its evidence.
- Run the clean baseline and inspect its position response, command voltage, metrics, and data.
- Run the focused circuit and receiver checks.
- Run the robotics test suite.
- Follow a run's log, revisit saved runs, and open their artifacts.
- Reach the roadmap, receiver revision brief, and research documentation.

The first release uses the existing experiment settings. Parameter editing and a revised receiver experiment are future integration steps.

## How to read the results

Historical evidence cards describe the saved checkpoints and include their source links. They are not checks performed when the page opens. A completed run means its selected workflow finished successfully. It does not establish hardware validity or demonstrate a combined mitigation benefit.

Receiver characterization is still the next research milestone. The original four-way evaluation remains blocked by its rejected receiver-domain acceptance. This workbench exposes no command to bypass that gate or launch the reserved evaluation. The EDMD study remains a separate estimation study and is not connected to motor control by this interface.

## Stored runs

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

These checks verify the interface and its integration with existing workflows. Research acceptance, hardware validation, and the reserved four-way evaluation remain unchanged.
