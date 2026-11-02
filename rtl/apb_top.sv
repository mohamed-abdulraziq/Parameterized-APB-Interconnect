module apb_top #(
    parameter DATA_WIDTH = 32,                 // Data bus width (default: 32 bits)
    parameter ADDR_WIDTH = 8,                  // Address bus width
    parameter SLV_NUM    = 4,                  // Number of APB slaves
    parameter STRB_SIZE  = (DATA_WIDTH/8)      // Number of byte strobes
)(
    input  PCLK,                               // APB clock
    input  PRESETn,                            // Active-low reset
    input  [ADDR_WIDTH-1:0] add_in,            // Input address
    input  [DATA_WIDTH-1:0] data_in,           // Input write data
    input  [SLV_NUM-1:0]    selx_in,           // Slave select input
    input  write1_read0,                       // Transfer direction (1=write, 0=read)
    input  [STRB_SIZE-1:0]  strb_in,           // Byte strobes for writes
    input  [2:0]            prot_in,           // Protection type input
    input  vld_trnsfr,                         // Valid transfer request
    output [DATA_WIDTH-1:0] PRDATA,            // Read data output
    output PSLVERR,                            // Slave error output
    output PREADY                              // Ready signal output
);

    // ------------------- Internal Signals -------------------
    // Bridge-to-slave bus signals
    wire [ADDR_WIDTH-1:0] PADDR;               // Address bus to slaves
    wire [2:0]            PPROT;               // Protection signal to slaves
    wire [SLV_NUM-1:0]    PSELx;               // Slave select signals
    wire PENABLE;                              // Enable signal
    wire PWRITE;                               // Write/read control
    wire [DATA_WIDTH-1:0] PWDATA;              // Write data bus
    wire [STRB_SIZE-1:0]  PSTRB;               // Byte strobes
    wire [DATA_WIDTH-1:0] PRDATA_array [SLV_NUM-1:0]; // Per-slave read data
    wire [SLV_NUM-1:0]    PREADY_array;        // Per-slave ready signals
    wire [SLV_NUM-1:0]    PSLVERR_array;       // Per-slave error signals

    // ------------------- APB Bridge -------------------
    // The bridge converts a high-level transfer request into APB protocol signals.
    apb_bridge #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SLV_NUM(SLV_NUM),
        .STRB_SIZE(STRB_SIZE)
    ) MASTER (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .add_in(add_in),
        .data_in(data_in),
        .selx_in(selx_in),
        .write1_read0(write1_read0),
        .strb_in(strb_in),
        .prot_in(prot_in),
        .vld_trnsfr(vld_trnsfr),
        .PREADY(PREADY_array),
        .PRDATA(PRDATA_array),
        .PSLVERR(PSLVERR_array),
        .PADDR(PADDR),
        .PPROT(PPROT),
        .PSELx(PSELx),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PSTRB(PSTRB),
        .PREADY_out(PREADY),
        .PRDATA_out(PRDATA),
        .PSLVERR_out(PSLVERR)
    );

    // ------------------- Slave Configuration -------------------
    // Each slave can have its own protection type, depth, and slave ID.
    parameter [2:0]   PROTC_ARRAY [SLV_NUM-1:0] = '{3'b110, 3'b111, 3'b010, 3'b101}; // Allowed PPROT per slave
    parameter [31:0]  DEPTH_ARRAY [SLV_NUM-1:0] = '{32, 32};         // Memory depth per slave
    parameter [SLV_NUM-1:0] SELx_ARRAY [SLV_NUM-1:0] = '{8, 4, 2, 1};      // Slave IDs

    // ------------------- Slave Instantiation -------------------
    // Generate SLV_NUM memory slaves connected to the bridge.
    genvar i;
    generate
        for (i = 0; i < SLV_NUM; i = i + 1) begin : slave_gen
            apb_RAM_one #(
                .DATA_WIDTH(DATA_WIDTH),
                .SLV_NUM(SLV_NUM),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DEPTH(DEPTH_ARRAY[i]),
                .STRB_SIZE(STRB_SIZE),
                .PROTC(PROTC_ARRAY[i]),
                .SELx(SELx_ARRAY[i])
            ) SLAVE (
                .PCLK(PCLK),
                .PRESETn(PRESETn),
                .PADDR(PADDR),
                .PWDATA(PWDATA),
                .PSELx(PSELx),
                .PWRITE(PWRITE),
                .PENABLE(PENABLE),
                .PPROT(PPROT),
                .PSTRB(PSTRB),
                .PRDATA(PRDATA_array[i]),
                .PSLVERR(PSLVERR_array[i]),
                .PREADY(PREADY_array[i])
            );
        end
    endgenerate

endmodule