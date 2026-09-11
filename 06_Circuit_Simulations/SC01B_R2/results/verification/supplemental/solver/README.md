# Portable SC-01B solver supplement

Read `Solver_Resolution.md` for the verified remedy and limits. `accepted_solver_audit.json` audits 17 final-drive runs plus 2 unchanged-driver recovery runs. All 19 complete warning-free and respect the actual TMAX. The 17 final-drive runs comprise five strict 0.125 ns cases, five strict 0.0625 ns cases, five 10 ns TSTEP sensitivity repeats, and two strict 0.03125 ns cases.

`attempt_ledger.json` and `.csv` preserve all completed local trial attempts, including rejected runs. Each ledger entry links exact deck, control, log and summary with SHA-256 hashes. Excluded early parameter-replacement attempts are marked explicitly. An interrupted process with no summary is not represented as a completed attempt. Original work folders remain untouched.

`waveforms/` retains compressed numeric data for all 19 accepted numerical runs and four supporting original-driver reference runs. Identical waveform files are stored once and referenced by multiple ledger entries. Failed and other exploratory raw waveforms are omitted here, with their original hashes retained in the ledger.

To load a retained record, resolve its `waveform_npz.path` relative to this directory, then:

```python
import numpy as np
a = np.load('waveforms/<record>.npz')['data']
```

Columns: time_s, switch_V, bus_V, highVgs_V, lowVgs_V, highVds_V, lowVds_V, highCurrent_A, lowCurrent_A, highGateCurrent_A, lowGateCurrent_A, loadCurrent_A, feedCurrent_A. These are unfiltered actual integration samples. NPZ preserves every exported floating-point value. `array_sha256` hashes the C-order float64 array bytes; `raw_waveform_sha256` hashes the original text record.

Use `reproduce.py --ngspice <path-to-ngspice.exe> --vendor-model <path-to-IAUC100N04S6L014.cir> --output <new-empty-directory>` to rerun the 19 accepted numerical records. Add `--all-attempts` to rerun every indexed deck, including expected failures. The script checks installed vendor and executable identities, retains exact settings, and refuses to overwrite run folders. Only the include path is localized. NumPy is required. No proprietary vendor model or runtime binary is distributed in this supplement.

`verify_supplement.py` checks artifact/array hashes, actual time-step limits, completeness, diagnostics, retained-array TSTEP identity and the seven final mesh comparisons directly from compressed arrays. It also regenerates source equivalence comparisons from the four supporting records. Run this for a standalone audit without invoking a simulator.
