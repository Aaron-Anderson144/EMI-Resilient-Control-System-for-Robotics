# Simulation Test Plan

## Test Philosophy

The clean baseline is established first. Fault tests reuse the same plant, command, sample time, and initial conditions so that only the intended independent variable changes.

Phase 2B uses a matched no-fault run produced by the same sample-by-sample simulator. Whole-run tracking RMSE remains available for continuity, but it is not the primary Phase 2B comparison because the commanded step transient can dominate small fault effects. Primary comparisons use baseline-subtracted position, measurement, and command signals with pre-window, active-window, and post-window masks.

## Initial Baseline Tests

| Test ID | Purpose | Input | Pass Condition | Outputs |
|---|---|---|---|---|
| B-001 | Verify discrete stability | Linear closed-loop model | All poles have magnitude below 1 | Pole list and maximum magnitude |
| B-002 | Verify position tracking | 30 degree step at 0.1 s | Response is finite and bounded | Position, error, overshoot, settling time |
| B-003 | Verify repeatability | Repeat identical run | Signals match within numerical tolerance | Difference summary |
| B-004 | Verify parameter sanity | Parameter validation | Positive physical constants and valid limits | Validation report |

## Phase 2A Fault-Injection Evidence

The earlier combined status rows have been split so that “Verified” applies only to outputs present in the saved Phase 2A evidence.

| Test ID | Disturbance/check | Primary Variable | Pass Condition or Output | Status |
|---|---|---|---|---|
| E-001 | Gaussian encoder noise | Standard deviation and seed | Repeatable fault samples and saved time-domain RMSE | Verified |
| E-002A | Sinusoidal encoder interference, time domain | Amplitude and frequency | Windowed waveform and saved measurement RMSE | Verified |
| E-002B | Sinusoidal encoder interference, spectrum | Frequency | Spectral peak and analysis settings are saved | Draft |
| E-003A | Encoder count jump, immediate response | Jump magnitude in counts | One affected sample and saved peak command | Verified |
| E-003B | Encoder count jump, recovery | Recovery threshold and dwell | Recovery time or an explicit censored result is saved | Draft |
| E-004A | Encoder dropout, measurement response | Duration | Exact hold-last window and saved maximum measurement error | Verified |
| E-004B | Encoder dropout, supervisory response | Duration and persistence | Normal/degraded/recovery state sequence is saved | Draft; Phase 3 dependency |
| E-008 | Supply interruption | Sag magnitude and duration | Reset or safe-state outcome | Draft |

## Phase 2B Source and Channel Tests

The Phase 2B automated suite passed 16 of 16 tests on 2026-09-08. All ten Simulink scenarios also passed smoke testing and MATLAB/Simulink cross-validation. Status remains partial where the saved suite does not exercise every subclaim in a dedicated constructed edge case.

| Test ID | Mechanism/check | Primary Variable | Pass Condition | Current Status |
|---|---|---|---|---|
| E-005A | Packet-loss edge cases | Loss probability | `p=0` drops none; `p=1` drops every in-window packet; outside-window packets are unaffected | Verified |
| E-005B | Packet-loss statistical study | Loss probability and seed | Repeated trials include observed fraction and a stated confidence interval | Verified: 200 trials/case |
| E-006A | Fixed communication delay | Delay in integer samples | Arrival is causal and delay remains the configured 8 samples in-window | Verified |
| E-006B | Bounded communication jitter | Maximum jitter and seed | Same seed reproduces the schedule; all in-window delays remain within configured integer bounds | Verified |
| E-006C | Packet ordering and hold-last | Arrival timestamp | Accepted timestamps are causal and strictly increasing; no-update intervals hold the last accepted value | Verified |
| E-006D | Constructed collision and out-of-order edge cases | Arrival timestamp | Newest source wins a forced collision and an explicitly forced older arrival is rejected | Draft |
| E-007A | Ground-reference offset isolation/window | Common-mode voltage and conversion factor | Only the ground contribution is nonzero and it is restricted to its half-open window | Verified |
| E-007B | Ground-reference conversion scaling | Conversion factor | Nonzero conversion factors scale linearly in a dedicated parameterized test | Partial; zero-factor rejection verified |
| E-009 | Capacitive coupling | Line imbalance, edge rate, termination, path transfer | Calculated current/voltage have correct equation, polarity, linear scaling, and isolation | Verified |
| E-010 | Inductive coupling | Mutual-inductance imbalance and current edge rate | Calculated voltage has correct equation, polarity, linear scaling, and isolation | Verified |
| E-011 | Shared-impedance coupling | Return resistance/inductance and common-mode conversion | Combined resistive/inductive equation is exact and scales when both terms are scaled together | Verified |
| E-011B | Shared-impedance term separation | Return resistance and return inductance | Resistive and inductive terms scale independently in dedicated tests | Draft |
| E-012 | Coupling superposition | Component enable flags | Combined receiver differential voltage equals the sum of enabled component outputs | Verified |
| E-013 | Disturbance-window boundaries | Start/stop time | All configured windows are half-open `[start, stop)` with exact sample counts | Verified |
| E-014 | Phase 2B disabled-by-default identity | Scenario `none` | No-fault Phase 2B run has zero disturbance channels and matches the Phase 2A no-fault run within `1e-12` | Verified |
| E-015 | Pre-onset identity and finite execution | Combined Phase 2B scenario | Pre-onset position, received measurement, and command match within `1e-12`; all required outputs are finite | Verified |
| E-016 | Recovery metric | Threshold and dwell samples | Reports first post-window dwell satisfying the threshold or explicitly marks recovery as censored | Verified with synthetic threshold/dwell test |
| E-017 | MATLAB/Simulink consistency | All ten Phase 2B scenarios | Continuous differences are below `1e-9`; discrete profiles match exactly; each run has 1501 samples | Verified |

Equation and scaling checks shall perturb one parameter at a time. Tests shall include zero-coupling coefficients, sign reversal of differential imbalance, and linear scaling of `deltaC`, `deltaM`, return resistance, return inductance, and common-mode-to-differential conversion.

The current suite covers exact peak equations, `deltaC` and `deltaM` polarity/scaling, combined shared-return scaling, mechanism isolation, exact superposition, and zero transfer/conversion factors. Separate nonzero scaling tests for return resistance, return inductance, and ground conversion remain open as E-007B and E-011B.

## Comparison Configurations

1. Baseline: no mitigation and no resilient-control feature
2. Electromagnetic mitigation only
3. Fault-tolerant control only
4. Combined electromagnetic and control mitigation

## Required Metadata

- Test ID and timestamp
- Model version
- Parameter-set identifier
- Random seed
- Solver and sample time
- Enabled mitigation configuration
- Disturbance definition
- Pass/fail outcome
- Parameter provenance and fidelity level
- Fault-window convention
- Packet count, drop count, collision count, and out-of-order count for communication cases

## Analysis Outputs

- Time histories
- Error spectra when a spectral claim is made
- True tracking error and controller-visible measurement error
- Baseline-subtracted position, measurement, and command histories
- Active-window incremental RMSE and maximum absolute delta
- Post-window maximum absolute delta
- Overshoot and settling time
- Fault-detection delay
- Recovery time with threshold, dwell, and censoring flag
- Failure probability and confidence interval
- Stable/unstable operating-region map

## Phase 2B Evidence Artifacts

The intended evidence package is:

- scenario manifest with enabled mechanisms and parameter-set identifier;
- one time-series CSV per isolated scenario plus the matched no-fault case;
- one metrics CSV containing pre/active/post incremental measures;
- a MAT study archive and a fault-window comparison figure;
- automated-test summary;
- packet-loss Monte Carlo table with confidence interval;
- Simulink smoke-test and MATLAB/Simulink cross-validation tables when the Phase 2B model exists;
- validation summary that distinguishes calculated, simulated, and measured quantities.

## Phase 2B Recorded Result

- MATLAB tests: 28 passed of 28 total; Phase 2B contributed 16 passed of 16.
- Simulink smoke tests: 10 passed of 10, with 1501 finite samples per scenario.
- MATLAB/Simulink comparison: all ten scenarios below the `1e-9` numerical gate; maximum continuous-signal difference approximately `2.2751e-12`; discrete profiles exact.
- Packet-loss study at `p=0.20`: 15,934 drops in 80,000 opportunities (`0.199175`), Wilson 95% interval `[0.19642, 0.20196]`.
- Packet-loss endpoints: `p=0` produced 0 of 80,000 drops; `p=1` produced 80,000 of 80,000 drops.

These results verify the implementation against its specified equations and scheduling semantics. They do not verify the assumed physical parameter values, real receiver susceptibility, closed-loop safety, fault detection, or mitigation performance.
