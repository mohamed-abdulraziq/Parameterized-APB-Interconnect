# APB Interconnect Testbench

The self-checking testbench is `apb_top_testbench.sv`. It targets the two-slave configuration documented in [the verification notes](../docs/verification.md).

The testbench covers normal reads/writes, partial byte writes, boundary and out-of-range addresses, protection mismatches, back-to-back transfers, and randomized smoke tests. The supplied simulator evidence reports 186 checks passed and zero failures.

A ModelSim/Questa run script is provided in `run.do`. Run it from this directory.