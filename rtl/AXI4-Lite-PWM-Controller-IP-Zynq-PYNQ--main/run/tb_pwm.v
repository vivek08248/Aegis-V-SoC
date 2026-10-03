`timescale 1ns/1ps

//============================================================================
// tb_pwm.v — Testbench for PWM Controller (AXI4-Lite, 4-bit addr)
// Top module: myip_v1_0
// DUT instance: u_pwm
// FSDB dump: dump_pwm.fsdb
//
// Tests:
//   1. Write 0x80 to slv_reg0 (50% duty), read back, verify
//   2. Write 0xFF to slv_reg0 (max duty), sample PWM_OUT over 256 cycles
//   3. Write 0x00 to slv_reg0 (0% duty), verify PWM_OUT all low
//   4. Write/read slv_reg1, slv_reg2, slv_reg3
//============================================================================

module tb_pwm;

  //--- Clock and reset ---
  reg  clk;
  reg  rst_n;

  //--- AXI4-Lite write address channel ---
  reg  [3:0]  s00_axi_awaddr;
  reg  [2:0]  s00_axi_awprot;
  reg         s00_axi_awvalid;
  wire        s00_axi_awready;

  //--- AXI4-Lite write data channel ---
  reg  [31:0] s00_axi_wdata;
  reg  [3:0]  s00_axi_wstrb;
  reg         s00_axi_wvalid;
  wire        s00_axi_wready;

  //--- AXI4-Lite write response channel ---
  wire [1:0]  s00_axi_bresp;
  wire        s00_axi_bvalid;
  reg         s00_axi_bready;

  //--- AXI4-Lite read address channel ---
  reg  [3:0]  s00_axi_araddr;
  reg  [2:0]  s00_axi_arprot;
  reg         s00_axi_arvalid;
  wire        s00_axi_arready;

  //--- AXI4-Lite read data channel ---
  wire [31:0] s00_axi_rdata;
  wire [1:0]  s00_axi_rresp;
  wire        s00_axi_rvalid;
  reg         s00_axi_rready;

  //--- PWM output ---
  wire        PWM_OUT;

  //--- Test variables ---
  integer     i;
  integer     error_count;
  reg  [31:0] read_data;
  integer     high_count;
  integer     low_count;

  //=========================================================================
  // DUT instantiation
  //=========================================================================
  myip_v1_0 #(
    .C_S00_AXI_DATA_WIDTH(32),
    .C_S00_AXI_ADDR_WIDTH(4)
  ) u_pwm (
    .s00_axi_aclk      (clk),
    .s00_axi_aresetn   (rst_n),
    .s00_axi_awaddr    (s00_axi_awaddr),
    .s00_axi_awprot    (s00_axi_awprot),
    .s00_axi_awvalid   (s00_axi_awvalid),
    .s00_axi_awready   (s00_axi_awready),
    .s00_axi_wdata     (s00_axi_wdata),
    .s00_axi_wstrb     (s00_axi_wstrb),
    .s00_axi_wvalid    (s00_axi_wvalid),
    .s00_axi_wready    (s00_axi_wready),
    .s00_axi_bresp     (s00_axi_bresp),
    .s00_axi_bvalid    (s00_axi_bvalid),
    .s00_axi_bready    (s00_axi_bready),
    .s00_axi_araddr    (s00_axi_araddr),
    .s00_axi_arprot    (s00_axi_arprot),
    .s00_axi_arvalid   (s00_axi_arvalid),
    .s00_axi_arready   (s00_axi_arready),
    .s00_axi_rdata     (s00_axi_rdata),
    .s00_axi_rresp     (s00_axi_rresp),
    .s00_axi_rvalid    (s00_axi_rvalid),
    .s00_axi_rready    (s00_axi_rready),
    .PWM_OUT           (PWM_OUT)
  );

  //=========================================================================
  // Clock generation: 100 MHz, 10 ns period (5 ns high / 5 ns low)
  //=========================================================================
  initial clk = 1'b0;
  always #5 clk = ~clk;

  //=========================================================================
  // AXI4-Lite write task
  //   Drives awaddr/awvalid/wdata/wstrb/wvalid/bready
  //   Waits for awready + wready, then bvalid
  //=========================================================================
  task axi_write;
    input [3:0]  addr;
    input [31:0] data;
    begin
      // Assert write address, data, and bready on negedge
      @(negedge clk);
      s00_axi_awaddr  = addr;
      s00_axi_awprot  = 3'b000;
      s00_axi_awvalid = 1'b1;
      s00_axi_wdata   = data;
      s00_axi_wstrb   = 4'hF;
      s00_axi_wvalid  = 1'b1;
      s00_axi_bready  = 1'b1;

      // Wait for awready AND wready (both asserted same cycle in this slave)
      @(posedge clk);
      while (s00_axi_awready !== 1'b1 || s00_axi_wready !== 1'b1)
        @(posedge clk);

      // Deassert awvalid and wvalid
      @(negedge clk);
      s00_axi_awvalid = 1'b0;
      s00_axi_wvalid  = 1'b0;

      // Wait for bvalid (write response)
      @(posedge clk);
      while (s00_axi_bvalid !== 1'b1)
        @(posedge clk);

      // Deassert bready
      @(negedge clk);
      s00_axi_bready  = 1'b0;
    end
  endtask

  //=========================================================================
  // AXI4-Lite read task
  //   Drives araddr/arvalid/rready
  //   Waits for arready + rvalid, captures rdata
  //=========================================================================
  task axi_read;
    input  [3:0]  addr;
    output [31:0] data;
    begin
      // Assert read address and rready on negedge
      @(negedge clk);
      s00_axi_araddr  = addr;
      s00_axi_arprot  = 3'b000;
      s00_axi_arvalid = 1'b1;
      s00_axi_rready  = 1'b1;

      // Wait for arready
      @(posedge clk);
      while (s00_axi_arready !== 1'b1)
        @(posedge clk);

      // Deassert arvalid
      @(negedge clk);
      s00_axi_arvalid = 1'b0;

      // Wait for rvalid and capture data
      @(posedge clk);
      while (s00_axi_rvalid !== 1'b1)
        @(posedge clk);

      // Sample rdata
      data = s00_axi_rdata;

      // Deassert rready
      @(negedge clk);
      s00_axi_rready  = 1'b0;
    end
  endtask

  //=========================================================================
  // Main test sequence
  //=========================================================================
  initial begin
    //--- FSDB dump (must be before simulation activity) ---
    $fsdbDumpfile("dump_pwm.fsdb");
    $fsdbDumpvars(0, tb_pwm);

    //--- Initialize all AXI signals ---
    s00_axi_awaddr  = 4'h0;
    s00_axi_awprot = 3'b000;
    s00_axi_awvalid = 1'b0;
    s00_axi_wdata   = 32'h0;
    s00_axi_wstrb   = 4'h0;
    s00_axi_wvalid  = 1'b0;
    s00_axi_bready  = 1'b0;
    s00_axi_araddr  = 4'h0;
    s00_axi_arprot  = 3'b000;
    s00_axi_arvalid = 1'b0;
    s00_axi_rready  = 1'b0;

    error_count = 0;

    //--- Reset (active-low) ---
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);

    $display("==================================================");
    $display("=== PWM Testbench Start                        ===");
    $display("==================================================");

    //-------------------------------------------------------------------
    // Test 1: Write 0x80 to slv_reg0 (50% duty cycle), read back, verify
    //-------------------------------------------------------------------
    $display("[TEST 1] Write 0x80 to slv_reg0 (50%% duty cycle)");
    axi_write(4'h0, 32'h0000_0080);
    axi_read(4'h0, read_data);
    if (read_data[7:0] === 8'h80) begin
      $display("  PASS: slv_reg0 readback = 0x%08x", read_data);
    end else begin
      $display("  FAIL: slv_reg0 readback = 0x%08x, expected 0x%08x", read_data, 32'h0000_0080);
      error_count = error_count + 1;
    end

    //-------------------------------------------------------------------
    // Test 2: Write 0xFF to slv_reg0 (max duty cycle)
    //   PWM_OUT = (pwm_counter < duty_cycle)
    //   With duty_cycle=0xFF (255), PWM_OUT is high for counter 0..254
    //   and low for counter 255. So expect 255 high / 1 low per 256 cycles.
    //-------------------------------------------------------------------
    $display("[TEST 2] Write 0xFF to slv_reg0 (max duty cycle)");
    axi_write(4'h0, 32'h0000_00FF);

    high_count = 0;
    low_count  = 0;
    for (i = 0; i < 256; i = i + 1) begin
      @(posedge clk);
      #1;  // small delay for combinational settling
      if (PWM_OUT === 1'b1)
        high_count = high_count + 1;
      else
        low_count = low_count + 1;
    end
    $display("  PWM_OUT: high_count=%0d, low_count=%0d (expect 255/1)", high_count, low_count);
    if (high_count >= 255 && low_count <= 1) begin
      $display("  PASS: PWM_OUT is high for %0d of 256 cycles", high_count);
    end else begin
      $display("  FAIL: expected ~255 high, got %0d high / %0d low", high_count, low_count);
      error_count = error_count + 1;
    end

    //-------------------------------------------------------------------
    // Test 3: Write 0x00 to slv_reg0 (0% duty cycle), verify PWM_OUT all low
    //-------------------------------------------------------------------
    $display("[TEST 3] Write 0x00 to slv_reg0 (0%% duty cycle)");
    axi_write(4'h0, 32'h0000_0000);

    high_count = 0;
    low_count  = 0;
    for (i = 0; i < 256; i = i + 1) begin
      @(posedge clk);
      #1;
      if (PWM_OUT === 1'b1)
        high_count = high_count + 1;
      else
        low_count = low_count + 1;
    end
    $display("  PWM_OUT: high_count=%0d, low_count=%0d (expect 0/256)", high_count, low_count);
    if (high_count == 0 && low_count == 256) begin
      $display("  PASS: PWM_OUT is all low (0%% duty)");
    end else begin
      $display("  FAIL: expected 0 high, got %0d high / %0d low", high_count, low_count);
      error_count = error_count + 1;
    end

    //-------------------------------------------------------------------
    // Test 4: Write and read slv_reg1 (offset 0x4)
    //-------------------------------------------------------------------
    $display("[TEST 4] Write/Read slv_reg1 (offset 0x4)");
    axi_write(4'h4, 32'hDEAD_BEEF);
    axi_read(4'h4, read_data);
    if (read_data === 32'hDEAD_BEEF) begin
      $display("  PASS: slv_reg1 = 0x%08x", read_data);
    end else begin
      $display("  FAIL: slv_reg1 = 0x%08x, expected 0x%08x", read_data, 32'hDEAD_BEEF);
      error_count = error_count + 1;
    end

    //-------------------------------------------------------------------
    // Test 5: Write and read slv_reg2 (offset 0x8)
    //-------------------------------------------------------------------
    $display("[TEST 5] Write/Read slv_reg2 (offset 0x8)");
    axi_write(4'h8, 32'hCAFE_BABE);
    axi_read(4'h8, read_data);
    if (read_data === 32'hCAFE_BABE) begin
      $display("  PASS: slv_reg2 = 0x%08x", read_data);
    end else begin
      $display("  FAIL: slv_reg2 = 0x%08x, expected 0x%08x", read_data, 32'hCAFE_BABE);
      error_count = error_count + 1;
    end

    //-------------------------------------------------------------------
    // Test 6: Write and read slv_reg3 (offset 0xC)
    //-------------------------------------------------------------------
    $display("[TEST 6] Write/Read slv_reg3 (offset 0xC)");
    axi_write(4'hC, 32'h1234_5678);
    axi_read(4'hC, read_data);
    if (read_data === 32'h1234_5678) begin
      $display("  PASS: slv_reg3 = 0x%08x", read_data);
    end else begin
      $display("  FAIL: slv_reg3 = 0x%08x, expected 0x%08x", read_data, 32'h1234_5678);
      error_count = error_count + 1;
    end

    //-------------------------------------------------------------------
    // Summary
    //-------------------------------------------------------------------
    $display("==================================================");
    $display("=== PWM Testbench Summary                       ===");
    $display("==================================================");
    $display("  Total errors: %0d", error_count);
    if (error_count == 0)
      $display("  ALL TESTS PASSED");
    else
      $display("  SOME TESTS FAILED");

    $finish;
  end

endmodule
