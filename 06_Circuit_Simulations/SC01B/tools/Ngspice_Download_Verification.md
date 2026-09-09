# Official ngspice archive acquisition

Retrieved 2026-09-09. The [official ngspice download page](https://ngspice.sourceforge.io/download.html) directly links the ngspice 41 Windows x64 update archive hosted on the project website. This avoids the SourceForge release-download redirect that returned HTML or expired URLs during this session.

- Official binary source: <https://ngspice.sourceforge.io/eagle-upgrade/ngspice-Fusion360-Update.7z>
- Saved archive: `ngspice-Fusion360-Update.7z`
- Size: 4,795,471 bytes.
- Leading bytes: `37 7A BC AF 27 1C 00 04`, a 7z signature.
- Archive SHA-256: `3EA9BA44A8EB6C9B0791F5C093239E0BEE5DC5DDA334FA1C42F385CA6CEC599D`.
- Extraction directory: `ngspice41`.
- Executable: `ngspice41/Fusion360-Update/ngspice/bin/ngspice.exe`.
- Executable size: 6,990,848 bytes.
- Executable SHA-256: `EF5CE0AE623D43810B2B528B31AC3941418EACA0F9ABA802E407ABA7DF8863AC`.
- Executable headers: MZ, PE, machine `8664` (x64), subsystem `3` (Windows console).

The archive includes the executable, OpenMP runtime, XSPICE code models, initialization files, manual, and release notes. Its update instructions are attributed to ngspice maintainer Holger Vogt. The package was published for updating the ngspice copy bundled with Fusion360/EAGLE; no such installation was changed in this task. Files were only extracted to the research workspace. Standalone execution and model compatibility remain to be checked by the main implementation task.

These local hashes record acquired-file identity; they are not a claim of an independently published cryptographic signature. Provenance comes from the project's official page and direct project-hosted download. No downloaded executable was run in this acquisition task.
