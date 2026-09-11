# Portable driver investigation evidence

Read Driver_Investigation.md for the selected fixed drive and its limitations. The evidence is driver screening, separate from complete R2 acceptance and the solver supplement.

All seven screen configurations and 48 attempted-run decks, controls and logs are preserved. attempt_ledger.json records 42 complete runs and six solver failures, exact artifact hashes and original raw-waveform hashes. The five screen6 attempts failed at the first command corner; their exporter also stopped before producing screen6_results.json. No absent summary is represented as a success.

The five selected screen7 cases include waveform.npz under their trial folders. Load with NumPy: `np.load(path)['data']`. Columns are time, switch_V, bus_V, highVgs_V, lowVgs_V, highVds_V, lowVds_V, highCurrent_A, lowCurrent_A, highGateCurrent_A, lowGateCurrent_A, loadCurrent_A, feedCurrent_A, highChannelCurrent_A, lowChannelCurrent_A, internalHighVgs_V, internalLowVgs_V. Values are unchanged float64 integration samples. Other exploratory raw data remain in the original work archive and have hashes in the ledger.

To rerun a screen, provide explicit installed dependencies and a new output directory:

```powershell
python screen.py screen7.json --ngspice "C:\path\ngspice.exe" --vendor-model "C:\path\IAUC100N04S6L014.cir" --output "C:\new\driver-screen7"
```

The script requires NumPy, checks the original executable/vendor SHA-256 identities and refuses a nonempty output directory. It recreates the declared drive cases; no vendor model or executable is distributed. Preserved decks retain their original include path as provenance; regenerated decks localize the supplied vendor path. These trials retain their original TSTEP=TMAX controls; production R2 uses the separately verified fixed 1 ns TSTEP, documented in the sibling solver supplement.
