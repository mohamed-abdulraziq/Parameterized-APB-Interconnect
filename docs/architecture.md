# Architecture and Protocol

## Overview

The project is a single-request-source, parameterized multi-slave APB interconnect. It consists of a request-side interface, a centralized APB bridge, a generate-based bank of RAM slave endpoints, and a response path.

The requester supplies the target slave selection through `selx_in`. The bridge does not decode the address into a slave index. A valid transfer is expected to select one slave.

## Main blocks

### Request-side interface

The top-level request inputs are:

| Signal | Description |
|---|---|
| `add_in` | Address supplied for the transfer |
| `data_in` | Write data |
| `selx_in` | Slave-selection vector |
| `write1_read0` | Transfer direction: 1 for write, 0 for read |
| `strb_in` | Byte write strobe |
| `prot_in` | Protection attribute |
| `vld_trnsfr` | Request-valid indication |

The top-level response signals are `PREADY`, `PRDATA`, and `PSLVERR`.

### APB bridge

The `apb_bridge` module captures the request fields and controls the APB transfer phases. The implemented FSM has three states:

| State | `PSELx` | `PENABLE` | Function |
|---|---:|---:|---|
| IDLE | 0 | 0 | Wait for a valid request |
| SETUP | Selected slave | 0 | Present address/control for setup |
| ACCESS | Selected slave | 1 | Complete the access when the selected endpoint is ready |

In ACCESS, the bridge waits for `|(PREADY & PSELx)`. When the current access completes, a valid next request causes a transition back to SETUP; otherwise the FSM returns to IDLE.

The bridge registers request fields and captures successful read data. Its response logic qualifies ready and error signals with the slave-select vector.

### Generated RAM slave bank

The `apb_top` module instantiates `SLV_NUM` copies of `apb_RAM_one` through a generate loop. Each endpoint receives the shared APB bus and its own configuration values:

- `SELx`: selection encoding for this endpoint.
- `PROTC`: expected protection value.
- `DEPTH`: number of addressable memory words.

Each RAM endpoint supports reads, writes, byte strobes, and error responses for an out-of-range address or protection mismatch.

### Response aggregation

For the selected slave vector, the bridge uses:

- `PREADY_out = |(PREADY & PSELx)`
- `PSLVERR_out = |(PSLVERR & PSELx)`

On a successful read completion, it captures the selected ready slave's `PRDATA` into the read-data register returned through `PRDATA_out`.

## Parameterization

Top-level and bridge defaults:

| Parameter | Default | Meaning |
|---|---:|---|
| `DATA_WIDTH` | 32 | Read/write data width |
| `ADDR_WIDTH` | 8 | Address width |
| `SLV_NUM` | 4 | Number of slave endpoints |
| `STRB_SIZE` | `DATA_WIDTH/8` | Byte strobe width |

The RAM endpoint has a default depth of 32 words. The top level provides per-slave configuration arrays for protection value, depth, and select encoding.

The supplied testbench uses `DATA_WIDTH=32`, `ADDR_WIDTH=8`, `SLV_NUM=2`, and `STRB_SIZE=4`. It configures slave 0 with select `2'b01` and protection `3'b101`, and slave 1 with select `2'b10` and protection `3'b010`. Both testbench memories have depth 32.

## Design scope and assumptions

- The current implementation is single-master; it does not contain multi-master arbitration.
- Slave selection is supplied by `selx_in`; automatic address decoding is not implemented.
- A request is intended to select one slave. Multi-hot select handling/arbitration is not implemented.
- The supplied verification exercises a two-slave configuration. A different slave count requires matching per-slave configuration and verification.

