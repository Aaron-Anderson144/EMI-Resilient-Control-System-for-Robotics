# Causal receiver and decoder implementation

This implementation follows the unchanged **FOUR-WAY-EMI-PLAN-V1** contract. The existing default controller, observer, source waveform, task, network assumptions, exposure levels and benefit criteria retain their frozen identities. Development and numerical acceptance are separate from research acceptance. A passing software test cannot make a receiver-domain rejection usable for a comparative immunity claim.

## Causal path

At a control sample, the persistent decoded count supplies the only primary position measurement. The controller produces the held voltage for the next 1 ms interval. The exact affine motor trajectory under that held voltage and known load determines every intended quantization-boundary crossing in that interval, including an interior reversal. A changes its differential driver over 100 ns; B is ideal. The circuit integrates the original piecewise-linear aggressor record and specified continuous return with its state preserved. Schmitt events and joint A/B changes update a persistent quadrature count before the next coincident packet.

The added measurement boundary accepts exactly a finite decoded position, a causal source index and a receipt flag. Source index 1 is time zero. No ideal count, plant state, source exposure, domain flag, or scoring annotation enters the observer or controller. An external packet call rejects enabled independent-reference reconstruction. The unused legacy boundary retains its original behavior.

## Numerical implementation

The circuit uses the frozen SC01A mass matrix and shared-return equations. A compiled local MATLAB extension propagates the three circuit modes exactly on each interval of affine input. It retains every written replay knot; it does not normalize, compress, periodically reset or replace the source waveform. Threshold roots are isolated using interval bounds and refined before decoding. The driver and source state continue through pulse ends, synthetic returns, DC holds and control samples.

The compiled engine is identified by the SHA-256 of its C++ source. Its generated binary stays outside source history. MATLAB and a configured supported C++ compiler are required to rebuild it. The same saved numerical state can be passed between calls; there are no opaque process handles in the saved records.

The motor helper isolates all extrema permitted by the frozen two real velocity/current poles, then searches monotone angle intervals for count boundaries. Exact modal propagation determines continuous speed/current maxima; 16-point Gaussian quadrature on each at-most-1-ms interval evaluates the current-squared integral. Independent matrix-exponential, extrema and quadrature fixtures verify these quantities.

Numerically unresolved threshold grazing is rejected. If distinct events within the 1 ps grouping allowance straddle an already sampled packet, the implementation rejects that alignment; it cannot repair the earlier count using a later event. This is an explicit numerical limitation that must be retained if encountered, and cannot be counted as a successful physical receiver response.

## Offline attribution and scoring

After each complete closed-loop run, a second receiver replays that run's intended A/B trajectory with constant aggressor voltage. This shadow has the same electrical treatment and normal propagation delay. It never feeds the controller. The exported ideal count, exposed decoded count and shadow count remain distinct.

Each exposed arm is compared with its own clean actuator trajectory. Fixed scoring windows, separate original-request and shaped-command errors, both burst recovery clocks, corruption episodes, pre-existing alarms and burst-specific pre-existing corruption follow the frozen contract. Clean companions must also pass continuous transition sequence/delay and sampled-count guards.

Extra and missing decoder transitions use a disclosed descriptive alignment: identical directed A/B state changes are matched greedily one-to-one within 1 microsecond on the same intended trajectory. This is not a minimal edit-distance estimate and does not determine task success or the combined-benefit hypothesis. Invalid transitions and persistent sampled count error are reported separately.

## Evidence and entrypoints

`simulate_fourway_actuator` produces a complete causal record. `run_fourway_stage("development", newFolder)` runs the two development fixtures with four arms and clean companions, for 16 records. Evaluation requires a separate saved accepting implementation freeze and rejects a changed source hash. `run_fourway_closure` likewise requires that freeze before the 16 separate closure diagnostics.

`run_fourway_native_acceptance(newFolder)` creates an isolated copy of the native SC01A circuit, preserving the historical model. It records the eight event fixtures at the three specified maximum steps and retains native grids, exact references, threshold/decoder events, virtual packet counts and refinement evidence. Model-domain usability is recorded separately from agreement between numerical implementations.

Each record includes controller CSVs, intended A/B transitions, continuous motor interval metrics, circuit boundaries, threshold events, decoder events, receiver/shadow packets, source identity and a MATLAB reconstruction record. The original source knots are preserved once in the hash-pinned replay rather than redundantly copied into every pulse record.

The implementation has no physical validation. A common-mode excursion beyond the assumed 7 V domain holds A only to finish rejected diagnostic recording. No performance improvement after that fallback may be credited as an actual receiver response. Evaluation remains gated by the saved development and native acceptance reports.
