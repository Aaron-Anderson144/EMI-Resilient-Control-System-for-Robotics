# Phase 3: recovery using an independent position reference

Implemented 10 September 2026 as the optional `PHASE3-PROTOTYPE-V1.1` extension. The original primary-encoder observer and supervisor thresholds are retained. `reacquisitionEnabled` defaults to **false**. This path needs an additional position reference; it cannot resolve a single-sensor observability problem by itself.

## Signal boundary and assumptions

The recovery helper receives only a scalar independent position measurement, its source index and declared absolute error bound, the current sample index, prior actual applied voltage, stopped status and an explicit re-anchor request. It receives no plant-state vector, encoder-fault mask, scenario name, true load or fault timing. A separate fixture constructs synthetic reference position from the simulated plant position plus an explicitly declared error. No physical reference sensor has been selected or measured.

The reference uses the controller's synchronized sample clock. This first implementation accepts only a sample whose source index equals the current index. Missing, duplicate, late, future or invalid samples clear the contiguous window. A future timestamp never advances its watermark. There is no pending request: an early request expires on that tick.

The state-error calculation assumes the configured discrete actuator model, supplied applied-voltage history and constant assumed load are exact. Its bounds cover declared reference-position error only. Unknown plant, load, input and timestamp errors are outside those bounds. The dynamic-fit check can reject some inconsistent data; passing it does not prove those assumptions. In particular, a constant reference bias can fit these dynamics.

## Reconstruction and uncertainty

While the supervisor is already latched stopped, collect at least 51 consecutive independent samples over at least 50 ms. At 1 ms the window is 51 samples; at 0.5 ms it is 101; at 2 ms it remains 51 samples and spans 100 ms. An asserted stop means zero commanded terminal voltage, not zero physical velocity or current.

For window samples numbered `j = 0 ... N-1`, subtract the known forced response from measured position. The observation matrix has rows `C A^j`. A full-rank, scaled singular-value decomposition reconstructs the initial state by least squares and propagates it to the current sample using the recorded applied voltages. The normalization uses the declared state limits to compare the mixed physical units.

If `G = A^(N-1) pinv(O)` is the current-state measurement map and `e` is the vector of declared per-sample absolute position errors, the componentwise current-state error bound is `abs(G) e`. The implementation also compares each fit residual with `abs(I - O pinv(O)) e`, allowing only numerical roundoff. Tests construct worst-sign measurement errors that attain each component of the propagated bound.

| Provisional configuration | Default |
|---|---:|
| Minimum observation duration / samples | 50 ms / 51 |
| Allowed reference error declaration | 1e-8 rad through 0.01 deg |
| Maximum state-error bounds: position / velocity / current | 0.05 deg / 0.10 rad/s / 0.05 A |
| Maximum absolute fit residual | 0.02 deg |
| State limits: position / velocity / current | pi rad / 25 rad/s / 12 A |
| Maximum normalized condition number | 1e6 |
| Minimum normalized singular value | 1e-8 |

The full estimated-state error interval must remain inside the state limits. These limits are software assumptions, not identified hardware ratings. The active observer and reconstruction must have identical sample time and plant matrices. The fixture's assumed load overrides both consistently.

For the default 51-sample model, the normalized condition number is approximately 814.10. A 0.01-degree reference error bound propagates to approximately `[0.000254595 rad, 0.004360163 rad/s, 0.000316672 A]`. The default study declares 0.005 degree and therefore has half those bounds under the exact-model assumptions.

## Re-anchor and release are separate events

1. Reconstruction may commit only while already latched stopped, with a complete qualified window and an explicit request on the current tick.
2. The commit replaces the current observer posterior and discards pre-anchor replay history. It preserves the primary encoder's timestamp watermark and trust bookkeeping. Rejected old encoder packets cannot be reused.
3. On the commit tick, the supervisor is forced to remain stopped; primary credible evidence is suppressed and a coincident reset cannot release or queue a release.
4. The reference does not refresh primary-encoder trust or count toward its release dwell. Subsequent real primary packets must pass the existing timestamp, range, rate and residual checks against the rebuilt observer. Re-anchoring leaves primary trust age unchanged; an already-expired age remains expired until an actual primary acceptance occurs.
5. Stop release needs consecutive fresh, credible primary samples spanning 50 ms (51 samples at the default 1 ms), healthy supply and a separate explicit reset. Recovery then requires its own existing 50 ms credible dwell before normal mode. These supervisor sample counts are derived from the configured sample time.

Missing reference data or a request after the window becomes invalid cannot commit. A successful commit consumes the window. Re-anchoring with a still-corrupt primary encoder does not authorize drive release. The existing explicit operator reset remains mandatory even after a correct reference reconstructs the state.

## Reproduction and recorded evidence

From `03_MATLAB`, run `startup_project` then `phase3_reacquisition_main`. It uses a fresh timestamped evidence directory, runs the new reconstruction/integration tests, 15 numerical fixtures and their 15 independent-plant Simulink comparisons, and exports the response figure. The 31-channel model retains the original first 20 loop channels and adds reference inputs, qualification/commit flags, propagated state bounds and fit residual. MATLAB additionally records the rejection reason.

The declared fixtures include no reference, no request, early/missing reset, interrupted data, old timestamps, bounded error, understated noise, excess declared uncertainty, continued primary corruption, loaded motion, unknown load, undeclared constant reference bias, and delayed returning primary data. An undeclared constant reference bias deliberately demonstrates an integrity limit: it may pass the reference model fit, while disagreement with the primary encoder prevents drive release in that fixture. The software cannot establish independence or truth of the reference-error declaration.

MATLAB and Simulink share the tested decision helpers and construct their measurements at the sensor boundary. Their plants evolve independently. This verifies scheduling, plant integration and exported channels, not an independently implemented detector or physical hardware.

Derating/recovery tuning, physical stop/hold under load, measured sensor selection, independence/common-mode failure assessment, timestamp behavior and broader plant/load uncertainty remain open. The broader Phase 3 gate is not closed by this extension.
