# Phase 2A sampled spectrum and count-jump recovery

Completed: 10-Sep-2026 00:09:15. All declared checks passed: 1.

E-002B: 3/3 spectral fixtures passed. E-003B: 5/5 recovery outcomes passed. MATLAB/Simulink: 8/8 complete warning-free comparisons passed.

The spectrum selects the half-open injected sinusoid window, removes its mean, applies an explicit periodic Hann window, and computes an unpadded N-point FFT. One-sided amplitude is corrected by window coherent gain; DC and Nyquist are not doubled. Frequency-bin spacing is Fs/N. The first largest non-DC bin is reported without interpolation. Only the injected signal is required to peak within half a bin of its configured frequency. The measurement-minus-matched-baseline spectrum also contains closed-loop response and is diagnostic.

The frequency fixtures are in the interior band, more than two FFT bins from DC and Nyquist. Coherent-gain-corrected spectral ordinates are not universal tone amplitudes for off-bin tones or near boundaries where image lobes overlap. Equal peak maxima choose the first bin; nearly equal peaks may exchange order with roundoff. Boundary peaks are flagged as diagnostic.

These are sampled synthetic encoder-error frequencies. No anti-alias filter is modeled, and physical frequencies above Nyquist cannot be identified. The analysis does not characterize physical EMI spectra or receiver susceptibility.

Recovery uses baseline-subtracted true position. The count jump acts on the nearest controller sample (first sample wins an exact tie); its effective interval ends one sample period later. Requested and actual onset, event end, recovery start and confirmation are retained. The first full post-fault run with absolute delta <= the threshold qualifies. The default threshold is 0.05 degree for 50 consecutive samples: a 49 ms start-to-confirmation span at 1 kHz. Delay is measured from the effective fault end to dwell start, not confirmation. The endpoint jump deliberately has no post-fault record and must remain censored even if its final position delta is zero.

| Case | Injected peak (Hz) | Bin spacing (Hz) | Measurement peak, diagnostic (Hz) |
|---|---:|---:|---:|
| sinusoid_120Hz | 120 | 2.5 | 120 |
| sinusoid_off_bin | 122.5 | 2.5 | 122.5 |
| sinusoid_faster_sampling | 120 | 2.5 | 120 |

| Case | Actual jump (s) | Fault end (s) | Recovery delay (s) | Censored |
|---|---:|---:|---:|---|
| count_jump_default | 0.45 | 0.451 | 0.09 | 0 |
| count_jump_reverse | 0.45 | 0.451 | 0.09 | 0 |
| count_jump_loaded | 0.45 | 0.451 | 0.09 | 0 |
| count_jump_off_grid | 0.45 | 0.451 | 0.09 | 0 |
| count_jump_endpoint_censored | 3 | 3.001 | NaN | 1 |

Exact settings and both spectra are in each spectral-settings/spectrum CSV. `phase2a_recovery_validation.csv` records thresholds, sample counts, origins, dwell start/confirmation and censor reasons. `phase2a_evidence_study.mat` retains each parameter/scenario, analytical result, matched baseline, Simulink record and comparison. `phase2a_case_manifest.json` and `run_manifest.json` bind fixtures and source/model identity. This is trajectory-recovery evidence; no fault detector, supervisor recovery policy or hardware experiment is implemented by this study.
