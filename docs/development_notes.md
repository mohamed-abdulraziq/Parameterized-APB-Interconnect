# Development Notes and Attribution

## Project authorship

The RTL architecture and functional design were developed from scratch by the project author. The architecture, module decomposition, parameterization, and intended behavior were established before AI assistance was used.

The verification plan and test scenarios were also defined by the author. AI assistance was used to refine SystemVerilog syntax, format the testbench, and polish its presentation based on that predefined plan.

AI assistance on the RTL was limited to formatting and comment refinement after the design was complete. It was not used to originate the RTL architecture or define the verification strategy.

## Collaboration

The project was developed in collaboration with [Mohamed Khaled](https://www.linkedin.com/in/mohamed-khaled-77b685317/).

## Source preservation

The three RTL modules are included without functional logic changes. The active testbench module is included in `tb/apb_top_testbench.sv`. The original local testbench file also contained a second, older testbench draft fully commented out after the active `endmodule`; that inactive commented reference block is not repeated in this repository copy. The active testbench logic and scenarios are retained.
