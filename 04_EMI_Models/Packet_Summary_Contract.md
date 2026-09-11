# Packet-summary contract

Current profiles identify their metadata with `packetSummary.schemaVersion = "PACKET-SUMMARY-V1"`. This fixes the stale forced-outage totals found in the full audit. It changes summary metadata, not packet generation, scheduling, sensor values, observer decisions or controller behavior.

## Count populations

Every source sample represents a transmission opportunity, including a packet subsequently lost. The top-level `transmittedPacketCount`, `droppedPacketCount` and `acceptedPacketCount` consistently refer to the **whole record** and mirror `packetSummary.record`.

`packetSummary.faultWindow` refers to the explicit `faultWindowSourceActive` mask. This mask is the union of enabled communication-fault windows and Phase 3 forced-outage windows. Overlap counts once. `configuredWindowActive` retains the original enabled communication window before forced gaps are added.

Accepted packets are attributed to their original source timestamp, even if they arrive outside that window. Counting arrival-time samples inside the window would describe a different population. The Phase 2B scenario manifest and Monte Carlo loss-rate calculation therefore use the explicit fault-window numerator and denominator, preserving their historical numerical values.

| Field in each population | Meaning |
|---|---|
| `transmittedPacketCount` | Source packets in the selected population, including subsequent drops. |
| `droppedPacketCount` | Source packets removed by the final combined drop mask. |
| `arrivedPacketCount` | Non-dropped source packets whose arrival is inside the record. |
| `acceptedPacketCount` | Source packets accepted by the final timestamped schedule. |
| `discardedAfterArrivalPacketCount` | Arrived packets not accepted, including collision/stale outcomes. |
| `pendingBeyondRecordPacketCount` | Non-dropped packets scheduled beyond the recorded end. |

For either population, transmitted equals dropped + accepted + discarded after arrival + pending beyond record. Arrived equals accepted + discarded after arrival. A packet pending beyond the record is not relabeled as dropped.

## Fixed examples

For 1,501 source samples with a forced outage over `[0.4, 0.5)` seconds at 1 ms sampling, record totals are **1,501 transmitted, 100 dropped and 1,401 accepted**. The fault-window totals are **100, 100 and 0**. The previous inherited metadata incorrectly reported zero dropped and 1,501 accepted after rescheduling.

The nominal seeded ordinary loss case still contains **91 drops in 400 fault-window opportunities**. Its record has 1,501 opportunities. A clean record has 1,501 transmitted/accepted packets and an empty fault window.

## Historical evidence

Old archived profiles have no `PACKET-SUMMARY-V1` identifier and retain their original bytes. Their transmitted total used the configured fault-window population; their forced-gap accepted/dropped totals could be stale. Do not silently reinterpret or rewrite those archives. For comparisons across versions, compare the unchanged schedule/state/signal arrays and explicitly map the old window denominator. Record the new schema for any regenerated report.

The regression fixtures check source-time attribution, losses, overlapping windows, collision and pending outcomes, and malformed schedules. A separate test changes only the summary metadata and confirms that complete controller state, loop values and signal tables remain identical.
