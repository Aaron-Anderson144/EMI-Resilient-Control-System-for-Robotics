# EMI Robotics · Signal Lab

## Start

Extract the **entire ZIP** into a writable local folder. Double-click
**Open EMI Workbench.lnk**. This is the main Windows launch shortcut.
Keep it beside `Start EMI Workbench.cmd`, the executable, `resources`, and
`workspace`. The shortcut uses a relative target and works when the whole folder
is moved. Opening **EMI Robotics.exe** directly is also supported. No installer,
administrator access, Codex, browser installation, Python installation, or Node.js
installation is required to open the app. The app opens in its own desktop window.

Everything the interface needs is included. It uses a private loopback connection
on this computer. It has no accounts, cloud services, telemetry, or auto-updater.
Application requests are limited to its own local service and built-in resources.

## Running research workflows

The package includes the baseline control simulation, receiver model checks, and
the 468-test main robotics suite, the conditional Receiver V2 characterization workflow, four-way v2 development, reserved evaluation, and source-return comparison, plus native run history and research documents.
Opening documents and inspecting saved results works without MATLAB.

**New simulations and tests require separately installed, licensed MATLAB and
the products used by the selected workflow. MATLAB is not bundled.** This release
is tested with Windows x64 MATLAB R2026a and the existing installed products.
MATLAB's own licensing rules and any sign-in requirements still apply.

The included Windows receiver MEX binaries match the packaged sources and avoid a C++
build on the tested configuration. A different MATLAB environment or a changed
receiver source may require a compatible compiler. The whole research archive,
external SPICE runtimes, and additional research campaigns are outside this compact
release. Seven named workbench workflows are supported. Receiver characterization reports electrical-domain checks and sensitivity to assumed threshold, latency and pulse behavior. Four-way v2 development runs 256 records across all 16 receiver assumptions and requires Parallel Computing Toolbox.

**Evaluation and source-return comparison require the original accepted local scientific project and its evidence.** Public downloads leave this private binding unset and show an explanation on both controls. Other workflows remain available. If the original accepted setup exists on this computer, configure `workspace/12_Workbench/local/accepted-science.json` following the [Workbench guide](../README.md#accepted-v2-evaluation-and-source-return-controls), then restart the app. The private file is excluded from Git and public packages.

The binding preserves the exact paths and hashes in the pinned acceptance receipt. Both controls verify acceptance before starting; missing or changed source/evidence keeps them disabled. The accepted MATLAB runner additionally requires a working local **Python 3.12 `py` launcher**. The bundled Python opens the app but does not replace that scientific prerequisite. Moving this app alone to another computer does not transfer the accepted project/evidence setup.

Evaluation runs 1,536 records and displays 768 matched comparisons plus 16 separate benefit screens. Source-return comparison runs 256 records and displays 128 comparisons. Both keep new results in this app's run folder. Full raw files stay on disk; the results show compact summary links and a complete artifact inventory. These are conditional simulations, not hardware validation.


## Your files

- **New runs:** `workspace/12_Workbench/runs` (results, metrics, logs, plots).
- **Project snapshot:** `workspace`. This is a release copy of the research project;
  it does not automatically synchronize changes with the development project.
- **Desktop settings and logs:** `local` beside the executable.
- **Open folders:** use the app's File menu.

Keep a backup of the whole folder to keep the app and its results together. Close
the app before moving it. If a run is active, closing offers to keep the window
open or let the run finish in the background before the app exits. Launching the
app again restores an existing window.

Imported evidence cards and imported history entries have been removed. Original research records remain in the source project. Native saved runs remain available. New runs save results in this packaged workspace; the two acceptance-checked workflows use the original accepted scientific sources as described above. The package includes all
16 original frozen scientific inputs and 54 frozen v2 protocol files unchanged; `workspace/bundle_manifest.json` records
their original identity. `release_manifest.json` records the release file hashes.

## Runtime provenance and notices

The Instrument edition uses bundled Barlow Condensed headings, Rajdhani Semibold
numerals, IBM Plex Sans controls, and IBM Plex Mono logs. Fonts are served directly from the app's
`workspace/12_Workbench/web/fonts` folder. Font files, original Open Font License
notices, source URLs, and SHA-256 identities are included there; the interface
does not contact a font service or require fonts to be installed in Windows.

Electron 43.7.0 is from the [official Electron release](https://github.com/electron/electron/releases/tag/v43.7.0).
CPython 3.13.15 is the [official Windows embeddable distribution](https://www.python.org/downloads/release/python-31315/).
Both downloaded archive SHA-256 hashes are pinned in `runtime-lock.json` and
verified before packaging. Third-party notices are retained in `LICENSE`,
`LICENSES.chromium.html`, and `resources/python/LICENSE.txt`.

This local build has no added publisher signing certificate. It is a portable
research application, not an installer or a MATLAB Runtime compiled application.

## Rebuilding

For a source-only checkout, first restore the six pinned inputs using the
[publication reproduction guide](../../09_Report/Publication_2026-09-11/Publication_Reproduction.md).
The builder also needs the source-named Windows receiver MEX binaries for both
`FOUR_WAY` and `FOUR_WAY_V2`. Generate them with the matching MATLAB/C++ setup,
or restore matching binaries from the verified Windows release. The builder
checks frozen inputs before copying; a missing or different input stops the build.

The reproducible builder and complete desktop source are in
`workspace/12_Workbench/desktop`. Download the two official archives named in
`runtime-lock.json` into a cache directory. From the development source, run:

```powershell
py -3.12 12_Workbench/desktop/build_portable.py --source . --runtime-cache <cache> --destination <new-release-folder>
```

The builder refuses to overwrite a non-empty folder, verifies runtime hashes,
copies only the supported scientific inputs, and records SHA-256 file manifests.
The commands `EMI Robotics.exe --smoke-test` and `EMI Robotics.exe --smoke-baseline`
write local verification records; the second also performs a real MATLAB baseline.
