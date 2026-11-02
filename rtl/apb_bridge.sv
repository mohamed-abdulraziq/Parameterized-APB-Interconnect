module apb_bridge #(
    parameter DATA_WIDTH = 32,              // Data bus width (default: 32 bits)
    parameter ADDR_WIDTH = 8,               // Address bus width
    parameter SLV_NUM    = 4,               // Number of APB slaves
    parameter STRB_SIZE  = (DATA_WIDTH/8)   // Number of byte strobes (1 per byte)
)(
    input  PCLK,                            // APB clock
    input  PRESETn,                         // Active-low reset

    // Input transaction signals from master
    input  [ADDR_WIDTH-1:0] add_in,         // Input address
    input  [DATA_WIDTH-1:0] data_in,        // Input data
    input  [SLV_NUM-1:0]    selx_in,        // Slave select input
    input  write1_read0,                    // Transfer direction: 1 = Write, 0 = Read
    input  [STRB_SIZE-1:0]  strb_in,        // Byte strobe mask
    input  [2:0]            prot_in,        // Protection control
    input  vld_trnsfr,                      // Valid transfer request

    // Slave response arrays (multiple slaves supported)
    input  [SLV_NUM-1:0]    PREADY,         // Ready signals from slaves
    input  [DATA_WIDTH-1:0] PRDATA [SLV_NUM-1:0], // Read data from slaves
    input  [SLV_NUM-1:0]    PSLVERR,        // Error signals from slaves

    // APB protocol outputs (to slaves)
    output reg [ADDR_WIDTH-1:0] PADDR,      // APB address
    output reg [2:0] PPROT,                 // APB protection type
    output reg [SLV_NUM-1:0] PSELx,         // APB slave select
    output reg PENABLE,                     // APB enable
    output reg PWRITE,                      // APB write control
    output reg [DATA_WIDTH-1:0] PWDATA,     // APB write data
    output reg [STRB_SIZE-1:0] PSTRB,       // APB byte strobe

    // Outputs back to master
    output PREADY_out,                      // Global ready (any selected slave ready)
    output [DATA_WIDTH-1:0] PRDATA_out,     // Read data returned to master
    output PSLVERR_out                      // Error flag back to master
);

    // Input registers (to capture requests)
    reg [ADDR_WIDTH-1:0] add_in_reg;
    reg [DATA_WIDTH-1:0] data_in_reg;
    reg [DATA_WIDTH-1:0] PRDATA_reg;
    reg [SLV_NUM-1:0] selx_in_reg;
    reg write1_read0_reg;
    reg [STRB_SIZE-1:0] strb_in_reg;
    reg [2:0] prot_in_reg;

    // FSM state encoding
    typedef enum bit [1:0] {  
        IDLE   = 2'b00,  // No transfer in progress
        SETUP  = 2'b01,  // Address & control setup phase
        ACCESS = 2'b11   // Data access phase
    } state_e;

    state_e current_state, next_state;

    //------------------------------
    // State Transition (Sequential)
    //------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    //------------------------------
    // Next-State Logic (Combinational)
    //------------------------------
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (vld_trnsfr)
                    next_state = SETUP;    // Start new transfer
                else
                    next_state = IDLE;
            end
            SETUP: begin
                next_state = ACCESS;       // Always move to access phase
            end
            ACCESS: begin
                if (vld_trnsfr && |(PREADY & PSELx))
                    next_state = SETUP;    // Pipelined transfer (next valid transfer)
                else if (!vld_trnsfr && |(PREADY & PSELx))
                    next_state = IDLE;     // Transaction complete
                else
                    next_state = ACCESS;   // Wait until ready
            end
            default: next_state = IDLE;
        endcase
    end    

    //------------------------------
    // Output Logic (Combinational)
    //------------------------------
    always @(*) begin  
        case (current_state)
            IDLE: begin
                PSELx   = 0;                   // No slave selected
                PENABLE = 0;
                PADDR   = add_in_reg;          // Hold last captured values
                PPROT   = prot_in_reg;
                PWRITE  = write1_read0_reg;
                PWDATA  = data_in_reg;
                PSTRB   = strb_in_reg;
            end 
            SETUP: begin
                PSELx   = selx_in_reg;         // Assert select for targeted slave
                PENABLE = 0;                   // Setup phase: PENABLE low
                PADDR   = add_in_reg;
                PPROT   = prot_in_reg;
                PWRITE  = write1_read0;
                PWDATA  = data_in_reg;
                PSTRB   = strb_in_reg;
            end
            ACCESS: begin
                PSELx   = selx_in_reg;         // Maintain slave selection
                PENABLE = 1;                   // Access phase: PENABLE high
                PADDR   = add_in_reg;
                PPROT   = prot_in_reg;
                PWRITE  = write1_read0_reg;
                PWDATA  = data_in_reg;
                PSTRB   = strb_in_reg;
            end 
            default: begin
                PSELx   = 0;
                PENABLE = 0;
                PADDR   = add_in_reg;
                PPROT   = prot_in_reg;
                PWRITE  = write1_read0_reg;
                PWDATA  = data_in_reg;
                PSTRB   = strb_in_reg;
            end
        endcase  
    end

    //------------------------------
    // Input Registering (Sequential)
    //------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            add_in_reg       <= 0;
            data_in_reg      <= 0;
            selx_in_reg      <= 0;
            write1_read0_reg <= 0;
            strb_in_reg      <= 0;
            prot_in_reg      <= 0;
        end  
        // Capture inputs only at IDLE or after ACCESS completes
        else if (vld_trnsfr && ((current_state == ACCESS && |(PREADY & PSELx)) || current_state == IDLE)) begin
            add_in_reg       <= add_in;
            data_in_reg      <= data_in;
            selx_in_reg      <= selx_in;
            write1_read0_reg <= write1_read0;
            strb_in_reg      <= strb_in;
            prot_in_reg      <= prot_in;
        end
    end

    //------------------------------
    // Read Data Registering
    //------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PRDATA_reg <= 0;
        end   
        // Capture read data only when ACCESS completes with no error
        else if (current_state == ACCESS && |(PREADY & PSELx) && !write1_read0 && !(|(PSLVERR & PSELx))) begin
            for (int i = 0; i < SLV_NUM; i = i + 1) begin
                if (PSELx[i] && PREADY[i])
                    PRDATA_reg <= PRDATA[i];  // Select the responding slave’s data
            end
        end
    end

    //------------------------------
    // Final Output Assignments
    //------------------------------
    assign PREADY_out  = |(PREADY & PSELx);   // Ready if any selected slave is ready
    assign PRDATA_out  = PRDATA_reg;          // Captured read data to master
    assign PSLVERR_out = |(PSLVERR & PSELx);  // Error if any selected slave flags error

endmodule
