module apb_RAM_one #(
    parameter DATA_WIDTH = 32,              // Data bus width (default: 32 bits)
    parameter SLV_NUM    = 4,               // Number of APB slaves in the system
    parameter ADDR_WIDTH = 16,              // Address bus width
    parameter DEPTH      = 32,              // Memory depth (number of addressable entries)
    parameter STRB_SIZE  = (DATA_WIDTH/8),  // Number of byte strobes (one per byte in DATA_WIDTH)
    parameter PROTC      = 3'b010,          // Expected PPROT value for legal accesses
    parameter SELx       = 1                // Slave select ID for this memory block
)(
    input  PCLK,                            // APB clock
    input  PRESETn,                         // Active-low reset
    input  [ADDR_WIDTH-1:0] PADDR,          // APB address bus
    input  [DATA_WIDTH-1:0] PWDATA,         // APB write data bus
    input  [SLV_NUM-1:0]    PSELx,          // APB slave select
    input  PWRITE,                          // APB write control signal (1 = write, 0 = read)
    input  PENABLE,                         // APB enable signal
    input  [2:0]            PPROT,          // APB protection type
    input  [STRB_SIZE-1:0]  PSTRB,          // Byte strobes for selective writes
    output reg [DATA_WIDTH-1:0] PRDATA,     // Read data bus
    output reg PSLVERR,                     // Slave error response
    output reg PREADY                       // Slave ready response
);

    // Local parameters
    localparam BYTE_WIDTH = 8;              // Width of a single byte
    reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];   // Internal memory array

    // Main APB slave process
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            // Reset all outputs and memory contents
            PRDATA  <= 0;
            PREADY  <= 0;
            PSLVERR <= 0;
            for (int i = 0; i < DEPTH; i = i + 1) begin
                mem[i] <= 0;
            end
        end 
        // ---------------------- READ OPERATION ----------------------
        else if (PSELx == SELx && PPROT == PROTC && PADDR < DEPTH && !PWRITE && PENABLE) begin 
            PREADY  <= 1;                   // Indicate slave is ready
            PSLVERR <= 0;                   // No error
            PRDATA  <= mem[PADDR];          // Return data from memory
        end
        // ---------------------- WRITE OPERATION ---------------------
        else if (PSELx == SELx && PPROT == PROTC && PADDR < DEPTH && PWRITE && PENABLE) begin
            PREADY  <= 1;                   // Indicate slave is ready
            PSLVERR <= 0;                   // No error
            // Perform byte-wise write according to PSTRB
            for (int byte_idx = 0; byte_idx < STRB_SIZE; byte_idx = byte_idx + 1) begin
                if (PSTRB[byte_idx]) begin
                    mem[PADDR][((byte_idx+1)*BYTE_WIDTH)-1 -: (BYTE_WIDTH)] 
                        <= PWDATA[((byte_idx+1)*BYTE_WIDTH)-1 -: (BYTE_WIDTH)];
                end
            end
        end
        // ---------------------- ILLEGAL ACCESS ----------------------
        else if (PSELx == SELx && PENABLE && (PPROT != PROTC || PADDR >= DEPTH)) begin
            PSLVERR <= 1;                   // Raise error (invalid protection or address)
            PREADY  <= 1;                   // Still acknowledge the transfer
        end
        // ---------------------- IDLE / DEFAULT ----------------------
        else begin
            PREADY  <= 0;                   // Not ready when idle
            PSLVERR <= 0;                   // Clear error flag
        end
    end
endmodule
