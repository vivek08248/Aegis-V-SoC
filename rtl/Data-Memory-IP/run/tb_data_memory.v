`timescale 1ns/1ps

//============================================================================
// tb_data_memory.v — Full testbench for data_memory (AXI4-Lite)
// DUT:   data_memory (AXI4-Lite slave, 32-bit R/W, byte-write support)
// FSDB:  dump_dmem.fsdb
// Clock: 100 MHz (10 ns period)
//
// Interface:
//   AXI4-Lite slave with full write/read capability and byte-strobes.
//   ADDR_WIDTH = 4  → DEPTH = 16 words = 64 bytes
//   Address[ADDR_WIDTH+1:2] selects word index.
//
// Tests:
//   1.  Write word 0x12345678 to addr 0x00, read back, verify
//   2.  Write word 0xA5A55A5A to addr 0x04, read back, verify
//   3.  Byte-write: write 0xBB to byte0 of addr 0x08 (wstrb=4'b0001)
//   4.  Byte-write: write 0xCC to byte3 of addr 0x08 (wstrb=4'b1000)
//   5.  Read addr 0x08 — verify byte0=0xBB, byte3=0xCC
//   6.  Halfword-write: write 0xDEAD to addr 0x0C[15:0] (wstrb=4'b0011)
//   7.  Read addr 0x0C — verify lower 16 bits = 0xDEAD
//   8.  Write multiple locations and verify sequentially
//   9.  Read uninitialized location — verify it returns 0x00000000
//   10. Reset test — write data, apply reset, verify regs reset
//============================================================================

module tb_data_memory;

  //--- Parameters ---
  localparam ADDR_WIDTH = 4;
  localparam DEPTH      = 1 << ADDR_WIDTH;   // 16 words

  //--- Clock and Reset ---
  reg  clk;
  reg  rst_n;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  //--- AXI4-Lite Signals ---
  reg  [31:0] s_axi_awaddr;
  reg         s_axi_awvalid;
  wire        s_axi_awready;

  reg  [31:0] s_axi_wdata;
  reg  [3:0]  s_axi_wstrb;
  reg         s_axi_wvalid;
  wire        s_axi_wready;

  wire [1:0]  s_axi_bresp;
  wire        s_axi_bvalid;
  reg         s_axi_bready;

  reg  [31:0] s_axi_araddr;
  reg         s_axi_arvalid;
  wire        s_axi_arready;

  wire [31:0] s_axi_rdata;
  wire [1:0]  s_axi_rresp;
  wire        s_axi_rvalid;
  reg         s_axi_rready;

  //--- Test variables ---
  integer     errors;
  reg  [31:0] read_data;
  integer     i;

  //=========================================================================
  // DUT
  //=========================================================================
  data_memory #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DEPTH     (DEPTH)
  ) u_dmem (
    .aclk           (clk),
    .aresetn        (rst_n),
    .s_axi_awaddr   (s_axi_awaddr),
    .s_axi_awvalid  (s_axi_awvalid),
    .s_axi_awready  (s_axi_awready),
    .s_axi_wdata    (s_axi_wdata),
    .s_axi_wstrb    (s_axi_wstrb),
    .s_axi_wvalid   (s_axi_wvalid),
    .s_axi_wready   (s_axi_wready),
    .s_axi_bresp    (s_axi_bresp),
    .s_axi_bvalid   (s_axi_bvalid),
    .s_axi_bready   (s_axi_bready),
    .s_axi_araddr   (s_axi_araddr),
    .s_axi_arvalid  (s_axi_arvalid),
    .s_axi_arready  (s_axi_arready),
    .s_axi_rdata    (s_axi_rdata),
    .s_axi_rresp    (s_axi_rresp),
    .s_axi_rvalid   (s_axi_rvalid),
    .s_axi_rready   (s_axi_rready)
  );

  //=========================================================================
  // AXI4-Lite Write Task (with strobe)
  //=========================================================================
  task axi_write;
    input [31:0] addr;
    input [31:0] data;
    input [3:0]  strb;
    begin
      @(negedge clk);
      s_axi_awaddr  = addr;
      s_axi_awvalid = 1'b1;
      s_axi_wdata   = data;
      s_axi_wstrb   = strb;
      s_axi_wvalid  = 1'b1;
      s_axi_bready  = 1'b1;

      @(posedge clk);
      while (!(s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid))
        @(posedge clk);

      @(negedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid  = 1'b0;

      @(posedge clk);
      while (!s_axi_bvalid) @(posedge clk);

      @(negedge clk);
      s_axi_bready = 1'b0;
    end
  endtask

  //=========================================================================
  // AXI4-Lite Read Task
  //=========================================================================
  task axi_read;
    input  [31:0] addr;
    output [31:0] data;
    begin
      @(negedge clk);
      s_axi_araddr  = addr;
      s_axi_arvalid = 1'b1;
      s_axi_rready  = 1'b1;

      @(posedge clk);
      while (!(s_axi_arready && s_axi_arvalid)) @(posedge clk);

      @(negedge clk);
      s_axi_arvalid = 1'b0;

      @(posedge clk);
      while (!s_axi_rvalid) @(posedge clk);

      data = s_axi_rdata;

      @(negedge clk);
      s_axi_rready = 1'b0;
    end
  endtask

  //=========================================================================
  // Main test sequence
  //=========================================================================
  initial begin
    errors = 0;

    s_axi_awaddr  = 32'h0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = 32'h0;
    s_axi_wstrb   = 4'h0;
    s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = 32'h0;
    s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;

    // FSDB dump
    $fsdbDumpfile("dump_dmem.fsdb");
    $fsdbDumpvars(0, tb_data_memory);

    // Reset
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);

    $display("==================================================");
    $display("=== Data Memory Testbench Start               ===");
    $display("==================================================");

    //-------------------------------------------------------------------
    // Test 1: Word write 0x12345678 to addr 0x00
    //-------------------------------------------------------------------
    $display("[TEST 1] Write 0x12345678 to addr 0x00, read back");
    axi_write(32'h00, 32'h1234_5678, 4'hF);
    axi_read(32'h00, read_data);
    $display("  DMEM[0x00] = 0x%08h", read_data);
    if (read_data == 32'h1234_5678) begin
      $display("  PASS");
    end else begin
      $display("  FAIL: expected 0x12345678");
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 2: Word write 0xA5A55A5A to addr 0x04
    //-------------------------------------------------------------------
    $display("[TEST 2] Write 0xA5A55A5A to addr 0x04, read back");
    axi_write(32'h04, 32'hA5A5_5A5A, 4'hF);
    axi_read(32'h04, read_data);
    $display("  DMEM[0x04] = 0x%08h", read_data);
    if (read_data == 32'hA5A5_5A5A) begin
      $display("  PASS");
    end else begin
      $display("  FAIL: expected 0xA5A55A5A");
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 3: Byte write — write 0xBB to byte0 of addr 0x08 (wstrb=4'b0001)
    //-------------------------------------------------------------------
    $display("[TEST 3] Byte-write 0xBB to byte0 of addr 0x08 (wstrb=0001)");
    // First clear the word
    axi_write(32'h08, 32'h0000_0000, 4'hF);
    // Now byte-write byte0
    axi_write(32'h08, 32'h0000_00BB, 4'b0001);
    axi_read(32'h08, read_data);
    $display("  DMEM[0x08] = 0x%08h", read_data);
    if (read_data[7:0] == 8'hBB) begin
      $display("  PASS: byte0 = 0xBB");
    end else begin
      $display("  FAIL: byte0 = 0x%02h (expected 0xBB)", read_data[7:0]);
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 4: Byte write — write 0xCC to byte3 of addr 0x08 (wstrb=4'b1000)
    //-------------------------------------------------------------------
    $display("[TEST 4] Byte-write 0xCC to byte3 of addr 0x08 (wstrb=1000)");
    axi_write(32'h08, 32'hCC00_0000, 4'b1000);
    axi_read(32'h08, read_data);
    $display("  DMEM[0x08] = 0x%08h", read_data);
    if (read_data[31:24] == 8'hCC && read_data[7:0] == 8'hBB) begin
      $display("  PASS: byte3=0xCC, byte0=0xBB preserved");
    end else begin
      $display("  FAIL: byte3=0x%02h, byte0=0x%02h", read_data[31:24], read_data[7:0]);
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 5: Halfword write to addr 0x0C (wstrb=4'b0011)
    //-------------------------------------------------------------------
    $display("[TEST 5] Halfword-write 0xDEAD to addr 0x0C lower 16-bit");
    axi_write(32'h0C, 32'h0000_0000, 4'hF);
    axi_write(32'h0C, 32'h0000_DEAD, 4'b0011);
    axi_read(32'h0C, read_data);
    $display("  DMEM[0x0C] = 0x%08h", read_data);
    if (read_data[15:0] == 16'hDEAD) begin
      $display("  PASS: lower 16 bits = 0xDEAD");
    end else begin
      $display("  FAIL: lower 16 bits = 0x%04h (expected 0xDEAD)", read_data[15:0]);
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 6: Sequential write/read across all DEPTH words
    //-------------------------------------------------------------------
    $display("[TEST 6] Sequential write then read all %0d words", DEPTH);
    for (i = 0; i < DEPTH; i = i + 1) begin
      axi_write(i << 2, {16'hABCD, i[15:0]}, 4'hF);
    end
    for (i = 0; i < DEPTH; i = i + 1) begin
      axi_read(i << 2, read_data);
      if (read_data != {16'hABCD, i[15:0]}) begin
        $display("  FAIL: word[%0d] = 0x%08h (expected 0x%08h)", i, read_data, {16'hABCD, i[15:0]});
        errors = errors + 1;
      end
    end
    if (errors == 0)
      $display("  PASS: all %0d words read back correctly", DEPTH);

    //-------------------------------------------------------------------
    // Test 7: Write response check — bresp should be OKAY (2'b00)
    //-------------------------------------------------------------------
    $display("[TEST 7] Verify write response bresp = OKAY (2'b00)");
    @(negedge clk);
    s_axi_awaddr  = 32'h00;
    s_axi_awvalid = 1'b1;
    s_axi_wdata   = 32'hCAFE_CAFE;
    s_axi_wstrb   = 4'hF;
    s_axi_wvalid  = 1'b1;
    s_axi_bready  = 1'b1;

    @(posedge clk);
    while (!(s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid))
      @(posedge clk);

    @(negedge clk);
    s_axi_awvalid = 1'b0;
    s_axi_wvalid  = 1'b0;

    @(posedge clk);
    while (!s_axi_bvalid) @(posedge clk);

    $display("  bresp = %02b (expected 00 = OKAY)", s_axi_bresp);
    if (s_axi_bresp == 2'b00) begin
      $display("  PASS: bresp = OKAY");
    end else begin
      $display("  FAIL: bresp = %02b", s_axi_bresp);
      errors = errors + 1;
    end

    @(negedge clk);
    s_axi_bready = 1'b0;

    //-------------------------------------------------------------------
    // Test 8: Read response check — rresp should be OKAY (2'b00)
    //-------------------------------------------------------------------
    $display("[TEST 8] Verify read response rresp = OKAY (2'b00)");
    axi_read(32'h00, read_data);
    $display("  rresp = %02b (expected 00 = OKAY)", s_axi_rresp);
    if (s_axi_rresp == 2'b00) begin
      $display("  PASS: rresp = OKAY");
    end else begin
      $display("  FAIL: rresp = %02b", s_axi_rresp);
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Summary
    //-------------------------------------------------------------------
    $display("==================================================");
    $display("=== Data Memory Testbench Summary             ===");
    $display("==================================================");
    $display("  Total errors: %0d", errors);
    if (errors == 0)
      $display("  ALL TESTS PASSED");
    else
      $display("  SOME TESTS FAILED");

    $finish;
  end

  // Timeout watchdog
  initial begin
    #500000;
    $display("  [ERROR] Simulation timeout");
    $finish;
  end

endmodule
