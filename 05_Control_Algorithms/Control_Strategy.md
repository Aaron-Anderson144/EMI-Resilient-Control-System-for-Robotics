# Control strategy

The baseline is a discrete PIDF position controller for the three-state electrical-mechanical actuator. The Phase 3 numerical prototype adds finite/range/rate/timestamp checks, source-time innovations, gated observer correction with applied-voltage replay, residual hysteresis, persistence and supervised normal/suspected/degraded/recovery/stop states.

Protected control uses the observer posterior in every mode. Rejected measurements produce prediction-only feedback. Degraded/recovery operation lowers the tuning target and voltage/slew limits; anti-windup and state rebasing control mode transfers. Stop requires qualified fresh measurements and an explicit reset before recovery.

Read [Phase 3 detection and supervision](Phase3_Detection_and_Supervision.md) for exact rules, thresholds, assumptions, reproduction and known limits. The [acceptance report](../03_MATLAB/results/development/phase3/Phase3_Implementation_Report.md) records the executed evidence.

The single-sensor observer cannot guarantee detection of frozen data at rest, small bias or slow drift. Zero-voltage stop permits load-driven motion. Physical stop behavior, independent sensing, calibrated thresholds and justified observer reacquisition remain open. Electromagnetic/software/combined comparisons belong to Phase 4; RES-005 remains open.
