# Phase 2C: Motor supply and mechanical load

## Implemented scope

This extension adds independent motor-bus sag and interruption to the sampled actuator model. The controller, encoder and communication electronics retain power. It is an assumed averaged terminal-voltage fixture, not a switching converter, negative-rail model, MCU brownout, energy-storage or hardware safety validation.

`params.mechanical.nominalLoadTorque_Nm` now drives the second physical plant input in the analytical baseline, Phase 2A, Phase 2B and their Simulink realizations. Positive torque opposes positive motion. Load remains applied during a motor-supply fault. The plant position, velocity and winding-current states are never reset by a supply event.

The default parameter set is `REPRESENTATIVE-ACTUATOR-V0.3`. Earlier v0.2 archived parameters without a supply group retain their nominal no-supply behavior. All values remain assumptions rather than identified hardware parameters.

## Supply contract

| Quantity | Unit | Default / meaning |
|---|---|---|
| Nominal motor bus | V | `electrical.nominalVoltage_V`, initially 24 |
| Sag voltage | V | `supply.sagVoltage_V`, initially 0.5 |
| Interrupted voltage | V | `supply.interruptionVoltage_V`, initially 0 |
| Start / stop | s | 0.85 / 1.10; active on `[start, stop)` |
| Controller-state policy | text | `hold`, or explicitly selected `reset` |
| Nominal mechanical load | N m | Signed constant; initially zero |

At sample k, available command magnitude is `min(control.voltageLimit_V, supplyVoltage(k))`. The applied motor voltage is the raw controller command clipped symmetrically to that limit. A zero supply forces exactly zero applied terminal voltage. This is a zero-voltage motor-terminal condition with the existing winding equation, not a high-impedance disconnect; back-EMF, winding resistance/inductance and load continue to determine current and motion. No claim of physically holding or stopping the mechanism follows from commanding zero voltage.

For controller state x and measured tracking error e, the raw command remains `C*x + D*e`. With available supply, the next state is `A*x + B*e`. During zero supply:

- `hold`: the next state equals the current state.
- `reset`: the next state is zero, starting with the update following the first interrupted sample.

This is a software policy applied to the independently powered controller. It does not model a microcontroller reset. On restoration, ordinary control resumes at the first sample outside the fault window, subject to the restored voltage limit. Sag above zero continues ordinary controller updates; baseline anti-windup and supervisory fault handling remain Phase 3 work.

## Scenarios and outputs

`phase2b_scenario` supports `supply_sag`, `supply_interruption`, `supply_interruption_reset` and `combined_supply`. Existing Phase 2B scenarios leave the supply fault disabled. A caller can override a scenario's voltage, window and state policy; all values are validated before use.

The original 29 Phase 2B Simulink columns retain their meaning. `supplySimout` separately records bus voltage, command limit, availability and the active supply window. `controllerStateSimout` records x_k before the update. Analytical results expose the same state history and supply profile. The supply campaign exports both plant/control signals and supply diagnostics.

The shared SimulationInput helpers apply plant matrices, controller dynamics, reference, load, sample time, stop time, voltage limit and fault profiles to each run. All nonlinear actuator realizations limit drive to the smaller of the configured command limit and the available bus, including an unchanged nominal bus in baseline/Phase 2A. The linear baseline transfer functions remain an unsaturated reference and report when their commanded voltage exceeds that limit. The helpers reject stale model schemas and same-named models loaded from a different project location. Parameter metadata describes the configuration actually used by the model.

## Local verification

`run_supply_integration_study` executes 13 analytical/Simulink pairs: loaded reference, severe sag, interruption with hold, interruption with reset, combined EMI/communication/supply faults, one-sample interruption, startup interruption, interruption through the final interval, off-grid window edges, reverse load, zero load, mild sag and command saturation. It uses a 3 s record, explicit load parameters and matched no-fault baselines.

Acceptance requires finite ordered complete records, agreement of all 29 original channels and controller states within 1e-9, exact discrete and supply profiles, voltage bounded by the instantaneous supply limit, zero voltage during interruption, unchanged pre-fault motion, no simulation warnings and completion at stop time. Unit tests separately verify load direction and an independent linear closed-loop oracle, state hold/reset semantics, plant continuity, both voltage polarities and repeatability.

Recovery is measured against the same loaded no-fault trajectory using the documented Phase 2B threshold and dwell. If the record is too short or the trajectory has not recovered, the output explicitly marks recovery censored. The end-of-record interruption intentionally exercises this outcome. Numerical agreement is an implementation gate; recovery and physical stability are not inferred from agreement alone.

Each run uses a new output directory and includes source/model SHA-256 hashes, MATLAB/product versions, timestamps, actual case parameters, results, acceptance tables and per-channel differences. Saved earlier campaigns remain historical evidence.

## Reproduction

From `03_MATLAB`, run `startup_project`, then rebuild the updated model with `build_phase2b_model(true)` and call `study=run_supply_integration_study`. Its default creates a timestamped directory under `results/development`; an explicit output folder must be empty. Rebuild baseline and Phase 2A models after upgrading source. Run all tests with `runtests("tests")`.

The subsequent Phase 2 completion campaign records constructed packet collision/out-of-order tests and Phase 2A spectral/recovery evidence. Remaining development includes Phase 3 observer/detection/supervision and measured driver/receiver/supply identification. Physical power-disconnect topology, controller brownout, braking and hardware restart behavior require separate hardware-specific models and evidence.
