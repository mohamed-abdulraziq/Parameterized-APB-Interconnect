# Functional Verification

## Testbench configuration

The supplied self-checking SystemVerilog testbench instantiates the top-level interconnect with:

| Parameter | Value |
|---|---:|
| `DATA_WIDTH` | 32 |
| `ADDR_WIDTH` | 8 |
| `SLV_NUM` | 2 |
| `STRB_SIZE` | 4 |
| Slave 0 select | `2'b01` |
| Slave 1 select | `2'b10` |
| Slave 0 protection | `3'b101` |
| Slave 1 protection | `3'b010` |
| Depth per slave | 32 words |

## Implemented test scenarios

The testbench includes:

1. Reset initialization and release.
2. Basic write/read operations on each slave.
3. Full-word writes and partial-byte writes using `PSTRB`.
4. Readback checks for expected byte-lane results.
5. First/last valid memory locations and out-of-range address checks.
6. Protection mismatch checks on writes and reads.
7. Back-to-back write and read sequencing.
8. Fifty randomized write/read iterations across the two slaves.
9. Timeout checks for a transaction that does not receive ready.
10. Self-checking comparisons and pass/fail counters.

The helper tasks drive request fields, wait for `PREADY` with a bounded timeout, and compare returned data and response flags.

## Reported result

The supplied final simulation evidence reports:

| Metric | Result |
|---|---:|
| Total checks | 186 |
| Passes | 186 |
| Failures | 0 |
| Reported simulation time | 1,247 ns |

<**186 / 186 checks passed**>

This result is transcribed from the project's supplied simulator output. It is presented as project evidence; this repository-preparation environment did not independently rerun the simulation.

## Running the testbench

A ModelSim/Questa example script is provided as `tb/run.do`. Run it from the `tb` directory, where the script expects RTL files in the sibling `rtl` directory.

The testbench uses SystemVerilog constructs, so select a simulator version and compile mode that support the language features used in the RTL and testbench.
