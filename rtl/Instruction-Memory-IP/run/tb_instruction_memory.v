`timescale 1ns/1ps
//==========================================================
// Testbench: tb_instruction_memory
// DUT: instruction_memory (AXI4-Lite, 32-bit, read-only)
//
// Instruction Memory is read-only from the bus.
// Write attempts return SLVERR (bresp=2'b10).
// Reads return data from mem[araddr[ADDR_WIDTH+1:2]].
//
// FSDB dump: dump_imem.fsdb
// Clock: 100 MHz (10 ns period)
// Reset: active-low
//==========================================================

module tb_instruction_memory;

  //----------------------------------------------------------
  // Parameters
  //----------------------------------------------------------
  localparam ADDR_WIDTH = 4;
  localparam DEPTH = (1 << ADDR_WIDTH);

  //----------------------------------------------------------
  // Signal declarations
  //----------------------------------------------------------
  reg         clk;
  reg         rst_n;

  // AXI4-Lite AW channel
  reg  [31:0] s_axi_awaddr;
  reg         s_axi_awvalid;
  wire        s_axi_awready;

  // AXI4-Lite W channel
  reg  [31:0] s_axi_wdata;
  reg  [3:0]  s_axi_wstrb;
  reg         s_axi_wvalid;
  wire        s_axi_wready;

  // AXI4-Lite B channel
  wire [1:0]  s_axi_bresp;
  wire        s_axi_bvalid;
  reg         s_axi_bready;

  // AXI4-Lite AR channel
  reg  [31:0] s_axi_araddr;
  reg         s_axi_arvalid;
  wire        s_axi_arready;

  // AXI4-Lite R channel
  wire [31:0] s_axi_rdata;
  wire [1:0]  s_axi_rresp;
  wire        s_axi_rvalid;
  reg         s_axi_rready;

  //----------------------------------------------------------
  // DUT instantiation
  //----------------------------------------------------------
  instruction_memory #(
    .ADDR_WIDTH(ADDR_WIDTH)
    // DEPTH auto-calculated as 1 << ADDR_WIDTH = 16
    // INIT_FILE defaults to 32'b0 (no initialization file)
  ) u_imem (
    .aclk          (clk),
    .aresetn       (rst_n),
    .s_axi_awaddr  (s_axi_awaddr),
    .s_axi_awvalid (s_axi_awvalid),
    .s_axi_awready (s_axi_awready),
    .s_axi_wdata   (s_axi_wdata),
    .s_axi_wstrb   (s_axi_wstrb),
    .s_axi_wvalid  (s_axi_wvalid),
    .s_axi_wready  (s_axi_wready),
    .s_axi_bresp   (s_axi_bresp),
    .s_axi_bvalid  (s_axi_bvalid),
    .s_axi_bready  (s_axi_bready),
    .s_axi_araddr  (s_axi_araddr),
    .s_axi_arvalid (s_axi_arvalid),
    .s_axi_arready (s_axi_arready),
    .s_axi_rdata   (s_axi_rdata),
    .s_axi_rresp   (s_axi_rresp),
    .s_axi_rvalid  (s_axi_rvalid),
    .s_axi_rready  (s_axi_rready)
  );

  //----------------------------------------------------------
  // Clock generation: 100 MHz
  //----------------------------------------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  //----------------------------------------------------------
  // FSDB dump
  //----------------------------------------------------------
  initial begin
    $fsdbDumpfile("dump_imem.fsdb");
    $fsdbDumpvars(0, tb_instruction_memory);
  end

  //----------------------------------------------------------
  // AXI4-Lite read task
  // Drives AR channel, waits for handshake, then captures
  // R channel response.
  //----------------------------------------------------------
  task axi_lite_read;
    input  [31:0] addr;
    output [31:0] rdata;
    output [1:0]  rresp;
    begin
      // Drive AR channel on negedge to avoid races
      @(negedge clk);
      s_axi_araddr  = addr;
      s_axi_arvalid = 1'b1;
      s_axi_rready  = 1'b1;

      // Wait for AR handshake (arready high at posedge)
      @(posedge clk);
      while (!s_axi_arready) @(posedge clk);
      @(negedge clk);
      s_axi_arvalid = 1'b0;

      // Wait for R response (rvalid high)
      @(posedge clk);
      while (!s_axi_rvalid) @(posedge clk);
      @(negedge clk);
      rdata = s_axi_rdata;
      rresp = s_axi_rresp;
      s_axi_rready = 1'b0;
    end
  endtask

  //----------------------------------------------------------
  // AXI4-Lite write task
  // Drives AW and W channels, waits for handshakes, then
  // captures B channel response.
  //----------------------------------------------------------
  task axi_lite_write;
    input  [31:0] addr;
    input  [31:0] wdata;
    input  [3:0]  wstrb;
    output [1:0]  bresp;
    begin
      // Drive AW and W channels on negedge
      @(negedge clk);
      s_axi_awaddr  = addr;
      s_axi_awvalid = 1'b1;
      s_axi_wdata   = wdata;
      s_axi_wstrb   = wstrb;
      s_axi_wvalid  = 1'b1;
      s_axi_bready  = 1'b1;

      // Wait for AW and W handshakes
      @(posedge clk);
      while (!s_axi_awready || !s_axi_wready) @(posedge clk);
      @(negedge clk);
      s_axi_awvalid = 1'b0;
      s_axi_wvalid  = 1'b0;

      // Wait for B response (bvalid high)
      @(posedge clk);
      while (!s_axi_bvalid) @(posedge clk);
      @(negedge clk);
      bresp = s_axi_bresp;
      s_axi_bready = 1'b0;
    end
  endtask

  //----------------------------------------------------------
  // Test stimulus
  //----------------------------------------------------------
  integer errors;
  reg [31:0] read_data;
  reg [1:0]  read_resp;
  reg [1:0]  write_resp;
  integer k;

  initial begin
    errors = 0;

    // Initialize all AXI signals to idle
    s_axi_awaddr  = 32'h0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = 32'h0;
    s_axi_wstrb   = 4'h0;
    s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = 32'h0;
    s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;

    // Initialize memory to 0 for deterministic reads
    // (Without INIT_FILE, memory contents default to X)
    for (k = 0; k < DEPTH; k = k + 1)
      u_imem.mem[k] = 32'h0;

    // Reset
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    //========================================================
    // Test 1: Write attempt should return SLVERR (read-only)
    //========================================================
    $display("[%0t] Test 1: Write to read-only memory (expect SLVERR)", $time);
    axi_lite_write(32'h0000, 32'hDEADBEEF, 4'hF, write_resp);
    if (write_resp !== 2'b10) begin
      $display("  FAIL: bresp=%b, expected 2'b10 (SLVERR)", write_resp);
      errors = errors + 1;
    end else begin
      $display("  PASS: bresp=2'b10 (SLVERR) — write rejected");
    end

    //========================================================
    // Test 2: Read addr 0x0 (should return 0)
    //========================================================
    $display("[%0t] Test 2: Read addr 0x0", $time);
    axi_lite_read(32'h0000, read_data, read_resp);
    if (read_resp !== 2'b00) begin
      $display("  FAIL: rresp=%b, expected 2'b00 (OKAY)", read_resp);
      errors = errors + 1;
    end else if (read_data !== 32'h0000_0000) begin
      $display("  FAIL: rdata=%h, expected 0x00000000", read_data);
      errors = errors + 1;
    end else begin
      $display("  PASS: rdata=0x%08h (OKAY)", read_data);
    end

    //========================================================
    // Test 3: Read addr 0x4 (should return 0)
    //========================================================
    $display("[%0t] Test 3: Read addr 0x4", $time);
    axi_lite_read(32'h0004, read_data, read_resp);
    if (read_resp !== 2'b00) begin
      $display("  FAIL: rresp=%b, expected 2'b00 (OKAY)", read_resp);
      errors = errors + 1;
    end else if (read_data !== 32'h0000_0000) begin
      $display("  FAIL: rdata=%h, expected 0x00000000", read_data);
      errors = errors + 1;
    end else begin
      $display("  PASS: rdata=0x%08h (OKAY)", read_data);
    end

    //========================================================
    // Test 4: Read addr 0x8 (should return 0)
    //========================================================
    $display("[%0t] Test 4: Read addr 0x8", $time);
    axi_lite_read(32'h0008, read_data, read_resp);
    if (read_resp !== 2'b00) begin
      $display("  FAIL: rresp=%b, expected 2'b00 (OKAY)", read_resp);
      errors = errors + 1;
    end else if (read_data !== 32'h0000_0000) begin
      $display("  FAIL: rdata=%h, expected 0x00000000", read_data);
      errors = errors + 1;
    end else begin
      $display("  PASS: rdata=0x%08h (OKAY)", read_data);
    end

    //========================================================
    // Summary
    //========================================================
    $display("\n==========================================================");
    if (errors == 0)
      $display("  ALL TESTS PASSED");
    else
      $display("  TESTS FAILED: %0d error(s)", errors);
    $display("==========================================================");
    $finish;
  end

endmodule
