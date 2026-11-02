`timescale 1ns/100ps
module apb_top_testbench;

  // ----------------------------------------------------------------
  // Parameters (must match DUT configuration)
  // ----------------------------------------------------------------
  parameter half_clk   = 1;                 // Half-period for clock
  parameter one_clk    = 2;                 // Full clock period
  parameter DATA_WIDTH = 32;                // Data bus width
  parameter ADDR_WIDTH = 8;                 // Address bus width
  parameter SLV_NUM    = 2;                 // Number of slaves
  parameter STRB_SIZE  = (DATA_WIDTH/8);    // Byte strobe width

  // ----------------------------------------------------------------
  // Counters / tracking
  // ----------------------------------------------------------------
  integer checks=0, fails=0, passes=0;      // Scoreboard counters
  integer i;                                // Loop variable
  bit ready;                                // Global ready used by wait_ready_with_timeout

  // ----------------------------------------------------------------
  // DUT Interface Signals
  // ----------------------------------------------------------------
  reg                   PCLK;
  reg                   PRESETn;
  reg  [ADDR_WIDTH-1:0] add_in;
  reg  [DATA_WIDTH-1:0] data_in;
  reg  [SLV_NUM-1:0]    selx_in;
  reg                   write1_read0;
  reg  [STRB_SIZE-1:0]  strb_in;
  reg  [2:0]            prot_in;
  reg                   vld_trnsfr;
  wire [DATA_WIDTH-1:0] PRDATA;
  wire                  PSLVERR;
  wire                  PREADY;

  // ----------------------------------------------------------------
  // Slave Address Mapping / Attributes
  // ----------------------------------------------------------------
  localparam [SLV_NUM-1:0] SEL_SLV0 = 2'b01; // Slave0 select encoding
  localparam [SLV_NUM-1:0] SEL_SLV1 = 2'b10; // Slave1 select encoding

  localparam [2:0] PROT_SLV0 = 3'b101;       // Protection type for slave0
  localparam [2:0] PROT_SLV1 = 3'b010;       // Protection type for slave1

  localparam int DEPTH_SLV0 = 32;            // Addressable depth for slave0
  localparam int DEPTH_SLV1 = 32;            // Addressable depth for slave1

  // ----------------------------------------------------------------
  // DUT Instantiation
  // ----------------------------------------------------------------
  apb_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .SLV_NUM(SLV_NUM),
    .STRB_SIZE(STRB_SIZE)
  ) DUT (
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .add_in(add_in),
    .data_in(data_in),
    .selx_in(selx_in),
    .write1_read0(write1_read0),
    .strb_in(strb_in),
    .prot_in(prot_in),
    .vld_trnsfr(vld_trnsfr),
    .PRDATA(PRDATA),
    .PSLVERR(PSLVERR),
    .PREADY(PREADY)
  );

  // ----------------------------------------------------------------
  // Clock Generation
  // ----------------------------------------------------------------
  initial begin
    PCLK = 0;
  end
  always #half_clk PCLK = ~PCLK;

  // ----------------------------------------------------------------
  // Helper Tasks
  // ----------------------------------------------------------------
  // Initialize all signals
  task init;
  begin
    PCLK          = 0;
    PRESETn       = 0;
    add_in        = '0;
    data_in       = '0;
    selx_in       = '0;
    write1_read0  = 0;
    strb_in       = '0;
    prot_in       = '0;
    vld_trnsfr    = 0;
  end
  endtask

  // Apply and release reset
  task deassert_reset;
  begin
    PRESETn = 0;
    #(3*one_clk);
    PRESETn = 1;
    #(1*one_clk);
    $display("[%0t] Reset deasserted", $time);
  end
  endtask

  // Drive a single transaction
  task drive_txn(
    input  [ADDR_WIDTH-1:0] t_addr,
    input  [DATA_WIDTH-1:0] t_data,
    input  [SLV_NUM-1:0]    t_sel,
    input                   t_write,
    input  [STRB_SIZE-1:0]  t_strb,
    input  [2:0]            t_prot,
    input                   t_vld
  );
  begin
    add_in        = t_addr;
    data_in       = t_data;
    selx_in       = t_sel;
    write1_read0  = t_write;
    strb_in       = t_strb;
    prot_in       = t_prot;
    vld_trnsfr    = t_vld;
  end
  endtask

  // Wait for PREADY with timeout
  task automatic wait_ready_with_timeout(
    output bit ready_out,
    input int max_cycles = 50
  );
    int cyc;
    ready_out = 0;
    for (cyc = 0; cyc < max_cycles; cyc++) begin
        if (PREADY) begin
            ready_out = 1;
            return;
        end
        @(posedge PCLK);
    end
  endtask

  // Check single-bit result
  task check_bit(input bit actual, expected);
  begin
    if (actual===expected) begin
      $display(">>> PASS [check %0d] Got=%0b Expected=%0b", checks, actual, expected);
      passes++;
    end else begin
      $display("XXX FAIL [check %0d] Got=%0b Expected=%0b", checks, actual, expected);
      fails++;
    end
    checks++;
  end
  endtask

  // Check 32-bit word result
  task check_word(input [31:0] actual, expected);
  begin
    if (actual===expected) begin
      $display(">>> PASS [check %0d] Got=0x%08h Expected=0x%08h", checks, actual, expected);
      passes++;
    end else begin
      $display("XXX FAIL [check %0d] Got=0x%08h Expected=0x%08h", checks, actual, expected);
      fails++;
    end
    checks++;
  end
  endtask

  // Perform APB Write Transaction
  task apb_write(
    input [SLV_NUM-1:0] sel,
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] wdata,
    input [STRB_SIZE-1:0]  strb,
    input [2:0]            prot
  );
    bit ready_local;
  begin
    drive_txn(addr, wdata, sel, 1'b1, strb, prot, 1'b1); // Assert valid
    @(posedge PCLK);
    drive_txn(addr, wdata, sel, 1'b1, strb, prot, 1'b0); // Deassert valid
    wait_ready_with_timeout(ready_local, 50);
    if (!ready_local) begin
      $display("XXX FAIL WRITE timeout (sel=%b addr=0x%0h)", sel, addr);
      fails++; checks++;
    end else begin
      check_bit(PREADY, 1'b1);
    end
    // Clear signals after completion
    vld_trnsfr = 0;
    selx_in    = 0;
  end
  endtask

  // Perform APB Read Transaction
  task apb_read(
    input [SLV_NUM-1:0] sel,
    input [ADDR_WIDTH-1:0] addr,
    input [2:0]            prot,
    input bit              check_data_valid,
    input [DATA_WIDTH-1:0] expected
  );
    bit ready_local;
  begin
    drive_txn(addr, '0, sel, 1'b0, '1, prot, 1'b1); // Assert valid (read)
    @(posedge PCLK);
    drive_txn(addr, '0, sel, 1'b0, '1, prot, 1'b0); // Deassert valid
    wait_ready_with_timeout(ready_local, 50);
    if (!ready_local) begin
      $display("XXX FAIL READ timeout (sel=%b addr=0x%0h)", sel, addr);
      fails++; checks++;
    end else begin
      check_bit(PREADY, 1'b1);
      if (check_data_valid) begin
        @(posedge PCLK);
        check_word(PRDATA, expected);
      end 
    end
    // Clear signals
    vld_trnsfr = 0;
    selx_in    = 0;
    @(posedge PCLK);
  end
  endtask

  // ----------------------------------------------------------------
  // Main Test Sequence
  // ----------------------------------------------------------------
  initial begin
    init();
    deassert_reset();

    $display("===== DIRECTED TESTS: SLAVE0 (SEL=01) =====");
    apb_write(SEL_SLV0, 8'h05, 32'hA5A5_5A5A, 4'b1111, PROT_SLV0);
    apb_read (SEL_SLV0, 8'h05, PROT_SLV0, 1, 32'hA5A5_5A5A);

    apb_write(SEL_SLV0, 8'h06, 32'hDEAD_BEEF, 4'b0101, PROT_SLV0);
    apb_read (SEL_SLV0, 8'h06, PROT_SLV0, 1, 32'h00AD_00EF);

    apb_write(SEL_SLV0, DEPTH_SLV0-1, 32'h1111_2222, 4'b1111, PROT_SLV0);
    apb_read (SEL_SLV0, DEPTH_SLV0-1, PROT_SLV0, 1, 32'h1111_2222);
    apb_write(SEL_SLV0, DEPTH_SLV0,   32'h9999_AAAA, 4'b1111, PROT_SLV0);
    // Expecting error: address out-of-range for slave0
    wait_ready_with_timeout(ready, 50);
    check_bit(PSLVERR, 1'b1);

    apb_write(SEL_SLV0, 8'h08, 32'h1234_5678, 4'b1111, 3'b000);
    // Expecting error: protection mismatch for slave0
    wait_ready_with_timeout(ready, 50);
    check_bit(PSLVERR, 1'b1);

    $display("===== DIRECTED TESTS: SLAVE1 (SEL=10) =====");
    apb_write(SEL_SLV1, 8'h0A, 32'hCAFEBABE, 4'b1111, PROT_SLV1);
    apb_read (SEL_SLV1, 8'h0A, PROT_SLV1, 1, 32'hCAFEBABE);

    apb_write(SEL_SLV1, 8'h0B, 32'h1122_3344, 4'b1010, PROT_SLV1);
    apb_read (SEL_SLV1, 8'h0B, PROT_SLV1, 1, 32'h1100_3300);

    apb_write(SEL_SLV1, DEPTH_SLV1-1, 32'h0BAD_F00D, 4'b1111, PROT_SLV1);
    apb_read (SEL_SLV1, DEPTH_SLV1-1, PROT_SLV1, 1, 32'h0BAD_F00D);
    // Test OOR and protection mismatch for slave1
    apb_write(SEL_SLV1, DEPTH_SLV1, 32'h9999_AAAA, 4'b1111, PROT_SLV1);
    wait_ready_with_timeout(ready, 50);
    check_bit(PSLVERR, 1'b1);

    apb_write(SEL_SLV1, 8'h02, 32'hAAAAAAAA, 4'b1111, 3'b101); // Wrong protection for slave1
    wait_ready_with_timeout(ready, 50);
    check_bit(PSLVERR, 1'b1);

    $display("===== BACK-TO-BACK TRANSFERS =====");
    apb_write(SEL_SLV0, 8'h12, 32'h0000_0001, 4'b1111, PROT_SLV0);
    apb_write(SEL_SLV0, 8'h12, 32'h0000_00FF, 4'b0001, PROT_SLV0);
    apb_read (SEL_SLV0, 8'h12, PROT_SLV0, 1, 32'h0000_00FF);

    // ----------------------------------------------------------------
    // Systematic Negative Tests for Both Slaves
    // ----------------------------------------------------------------
    $display("===== NEGATIVE TESTS: SLAVE0 =====");
    // Address out-of-range
    drive_txn(DEPTH_SLV0, 32'hDEAD_BEEF, SEL_SLV0, 1'b1, 4'b1111, PROT_SLV0, 1'b1);
    @(posedge PCLK);
    drive_txn(DEPTH_SLV0, 32'hDEAD_BEEF, SEL_SLV0, 1'b1, 4'b1111, PROT_SLV0, 1'b0);
    wait_ready_with_timeout(ready, 50);
    check_bit(PSLVERR, 1'b1);
    vld_trnsfr = 0; selx_in = 0; @(posedge PCLK);

    // Protection mismatch
    drive_txn(8'h10, 32'hCAFEBABE, SEL_SLV0, 1'b1, 4'b1111, 3'b000, 1'b1);
    @(posedge PCLK);
    drive_txn(8'h10, 32'hCAFEBABE, SEL_SLV0, 1'b1, 4'b1111, 3'b000, 1'b0);
    wait_ready_with_timeout(ready, 50);
    check_bit(PSLVERR, 1'b1);
    vld_trnsfr = 0; selx_in = 0; @(posedge PCLK);

    // Read with wrong protection
    drive_txn(8'h05, 32'h0, SEL_SLV0, 1'b0, 4'b1111, 3'b000, 1'b1);
    @(posedge PCLK);
    drive_txn(8'h05, 32'h0, SEL_SLV0, 1'b0, 4'b1111, 3'b000, 1'b0);
    wait_ready_with_timeout(ready, 50);
    check_bit(PSLVERR, 1'b1);
    vld_trnsfr = 0; selx_in = 0; @(posedge PCLK);

    $display("===== NEGATIVE TESTS: SLAVE1 =====");
    // Address out-of-range
    drive_txn(DEPTH_SLV1, 32'hDEAD_BEEF, SEL_SLV1, 1'b1, 4'b1111, PROT_SLV1, 1'b1);
    @(posedge PCLK);
    drive_txn(DEPTH_SLV1, 32'hDEAD_BEEF, SEL_SLV1, 1'b1, 4'b1111, PROT_SLV1, 1'b0);
    wait_ready_with_timeout(ready, 50);
    check_bit(PSLVERR, 1'b1);
    vld_trnsfr = 0; selx_in = 0; @(posedge PCLK);

    // Protection mismatch
    drive_txn(8'h10, 32'hCAFEBABE, SEL_SLV1, 1'b1, 4'b1111, 3'b101, 1'b1);
    @(posedge PCLK);
    drive_txn(8'h10, 32'hCAFEBABE, SEL_SLV1, 1'b1, 4'b1111, 3'b101, 1'b0);
    wait_ready_with_timeout(ready, 50);
    check_bit(PSLVERR, 1'b1);
    vld_trnsfr = 0; selx_in = 0; @(posedge PCLK);

    // Read with wrong protection
    drive_txn(8'h0A, 32'h0, SEL_SLV1, 1'b0, 4'b1111, 3'b111, 1'b1);
    @(posedge PCLK);
    drive_txn(8'h0A, 32'h0, SEL_SLV1, 1'b0, 4'b1111, 3'b111, 1'b0);
    wait_ready_with_timeout(ready, 50);
    check_bit(PSLVERR, 1'b1);
    vld_trnsfr = 0; selx_in = 0; @(posedge PCLK);

    // ----------------------------------------------------------------
    // Randomized Smoke Test
    // ----------------------------------------------------------------
    $display("===== RANDOMIZED (quick) =====");
    for (i=0; i<50; i++) begin
      automatic bit pick;
      automatic logic [SLV_NUM-1:0] sel;
      automatic logic [2:0]         prot;
      automatic logic [ADDR_WIDTH-1:0] addr;
      automatic logic [DATA_WIDTH-1:0] data;

      pick = $urandom_range(0,1);
      sel  = pick ? SEL_SLV0 : SEL_SLV1;
      prot = pick ? PROT_SLV0 : PROT_SLV1;
      addr = $urandom_range(0,(pick?DEPTH_SLV0-1:DEPTH_SLV1-1));
      data = $urandom;

      apb_write(sel, addr, data, 4'b1111, prot);
      apb_read (sel, addr, prot, 1, data);
    end

    // ----------------------------------------------------------------
    // Final Report
    // ----------------------------------------------------------------
    $display("====================================");
    $display("Total Checks=%0d, PASSES=%0d, FAILS=%0d", checks, passes, fails);
    $display("====================================");
    $stop;
  end

endmodule