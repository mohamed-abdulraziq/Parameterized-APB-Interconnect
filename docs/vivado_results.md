# Vivado Implementation and Timing Evidence

## Report context

The project was synthesized and implemented in AMD/Xilinx Vivado, including placement and routing, against a 100 MHz timing target. The values below are transcribed from the supplied Vivado Design Timing Summary screenshot.

## Reported timing

| Metric | Value |
|---|---:|
| Worst Negative Slack (WNS) | +7.086 ns |
| Total Negative Slack (TNS) | 0.000 ns |
| Setup failing endpoints | 0 |
| Setup endpoints analyzed | 4,345 |
| Worst Hold Slack (WHS) | +0.056 ns |
| Total Hold Slack (THS) | 0.000 ns |
| Hold failing endpoints | 0 |
| Hold endpoints analyzed | 4,345 |
| Worst Pulse Width Slack (WPWS) | +4.650 ns |
| Total Pulse Width Negative Slack (TPWS) | 0.000 ns |
| Pulse-width failing endpoints | 0 |
| Pulse-width endpoints analyzed | 2,202 |

The supplied report states that all user-specified timing constraints are met.

## Interpretation and limitations

The 100 MHz figure is the implementation target. Positive WNS/WHS/WPWS and zero corresponding total negative slack indicate that the timing summary reported no failing setup, hold, or pulse-width endpoints for that implementation.

These values are report evidence, not a measurement of board-level throughput or a statement about another device or constraint set.
