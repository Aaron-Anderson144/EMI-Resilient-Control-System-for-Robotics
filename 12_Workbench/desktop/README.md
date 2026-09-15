# EMI Robotics · Signal Lab

## Start

Extract the **entire ZIP** into a writable local folder. Double-click
**Open EMI Workbench.lnk**. This is the main Windows launch shortcut.
Keep it beside `Start EMI Workbench.cmd`, the executable, `resources`, and
`workspace`. The shortcut uses a relative target and works when the whole folder
is moved. Opening **EMI Robotics.exe** directly is also supported. No installer,
administrator access, Codex, browser installation, Python installation, or Node.js
installation is required. The app opens in its own desktop window.

Everything the interface needs is included. It uses a private loopback connection
on this computer. It has no accounts, cloud services, telemetry, or auto-updater.
Application requests are limited to its own local service and built-in resources.

## Running research workflows

The package includes the baseline control simulation, receiver model checks, and
the 468-test main robotics suite, plus the saved evidence and research documents.
Opening documents and inspecting saved results works without MATLAB.

**New simulations and tests require separately installed, licensed MATLAB and
the products used by the selected workflow. MATLAB is not bundled.** This release
is tested with Windows x64 MATLAB R2026a and the existing installed products.
MATLAB's own licensing rules and any sign-in requirements still apply.

The included Windows receiver MEX matches the packaged source and avoids a C++
build on the tested configuration. A different MATLAB environment or a changed
receiver source may require a compatible compiler. The whole research archive,
external SPICE runtimes, and additional research campaigns are outside this compact
release. The three named workbench workflows are the supported execution scope.

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

Historical run records preserve their original paths and provenance. Their saved
outputs are included locally; those recorded paths do not select the new run's
working folder. New runs use this packaged workspace. The package includes all
16 frozen scientific inputs unchanged; `workspace/bundle_manifest.json` records
their original identity. `release_manifest.json` records the release file hashes.

## Runtime provenance and notices

The Instrument edition uses bundled Barlow Condensed headings, Rajdhani Semibold
numerals, IBM Plex Sans controls, and IBM Plex Mono logs. Recorded Verification highlights the main robotics
project; the separate EDMD study remains available in Research documents. They are served directly from the app's
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
