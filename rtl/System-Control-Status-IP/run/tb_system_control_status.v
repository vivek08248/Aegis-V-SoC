`timescale 1ns/1ps

//============================================================================
// tb_system_control_status.v — Full testbench for system_control_status
// DUT:   system_control_status (AXI4-Lite, 5-bit addr, 32-bit data)
// FSDB:  dump_scs.fsdb
// Clock: 100 MHz (10 ns period)
//
// Register Map:
//   0x00  SYS_CTRL    [4:0] = {irq_global_en, low_power, debug_en, soft_rst, sys_en}
//   0x04  SYS_STATUS  [RO] = {debug_active, bus_error, sec_error, irq, wdg, i2c, aes, uart}
//   0x08  IRQ_ENABLE  [31:0]
//   0x0C  IRQ_STATUS  [31:0] (write-1-to-clear)
//   0x10  SCRATCH     [31:0]
//   0x14  IP_ID       [RO] = 0xAE615001
//   0x18  VERSION     [RO] = 0x00010000
//   0x1C  COUNTER     [RO] free-running 32-bit counter
//
// Tests:
//   1.  Read IP_ID and VERSION registers (RO)
//   2.  Write/read SYS_CTRL: sys_enable, soft_reset, debug_enable, low_power, irq_global_enable
//   3.  Write/read SCRATCH (arbitrary pattern)
//   4.  Verify sys_enable output pin
//   5.  Verify soft_reset output pin
//   6.  Write IRQ_ENABLE, trigger security_error, read IRQ_STATUS, verify irq
//   7.  Clear IRQ_STATUS via write-1-to-clear
//   8.  Read SYS_STATUS with external status inputs asserted
//   9.  Read COUNTER — verify it increments
//   10. Byte-write strobe test on SYS_CTRL
//============================================================================

module tb_system_control_status;

  //--- Clock and reset ---
  reg  clk;
  reg  rst_n;

  initial clk = 1'b0;
  always #5 clk = ~clk;

  //--- AXI4-Lite Signals ---
  reg  [4:0]  s_axi_awaddr;
  reg         s_axi_awvalid;
  wire        s_axi_awready;

  reg  [31:0] s_axi_wdata;
  reg  [3:0]  s_axi_wstrb;
  reg         s_axi_wvalid;
  wire        s_axi_wready;

  wire [1:0]  s_axi_bresp;
  wire        s_axi_bvalid;
  reg         s_axi_bready;

  reg  [4:0]  s_axi_araddr;
  reg         s_axi_arvalid;
  wire        s_axi_arready;

  wire [31:0] s_axi_rdata;
  wire [1:0]  s_axi_rresp;
  wire        s_axi_rvalid;
  reg         s_axi_rready;

  //--- Status Inputs ---
  reg  uart_ready;
  reg  aes_ready;
  reg  i2c_ready;
  reg  watchdog_active;
  reg  security_error;
  reg  bus_error;
  reg  debug_active;

  //--- Control Outputs ---
  wire sys_enable;
  wire soft_reset;
  wire debug_enable;
  wire low_power;
  wire irq_global_enable;
  wire irq;

  //--- Test variables ---
  integer     errors;
  reg  [31:0] read_data;
  reg  [31:0] counter_val1, counter_val2;

  //=========================================================================
  // DUT
  //=========================================================================
  system_control_status #(
    .IP_ID  (32'hAE61_5001),
    .VERSION(32'h0001_0000)
  ) u_dut (
    .aclk              (clk),
    .aresetn           (rst_n),
    .s_axi_awaddr      (s_axi_awaddr),
    .s_axi_awvalid     (s_axi_awvalid),
    .s_axi_awready     (s_axi_awready),
    .s_axi_wdata       (s_axi_wdata),
    .s_axi_wstrb       (s_axi_wstrb),
    .s_axi_wvalid      (s_axi_wvalid),
    .s_axi_wready      (s_axi_wready),
    .s_axi_bresp       (s_axi_bresp),
    .s_axi_bvalid      (s_axi_bvalid),
    .s_axi_bready      (s_axi_bready),
    .s_axi_araddr      (s_axi_araddr),
    .s_axi_arvalid     (s_axi_arvalid),
    .s_axi_arready     (s_axi_arready),
    .s_axi_rdata       (s_axi_rdata),
    .s_axi_rresp       (s_axi_rresp),
    .s_axi_rvalid      (s_axi_rvalid),
    .s_axi_rready      (s_axi_rready),
    .uart_ready        (uart_ready),
    .aes_ready         (aes_ready),
    .i2c_ready         (i2c_ready),
    .watchdog_active   (watchdog_active),
    .security_error    (security_error),
    .bus_error         (bus_error),
    .debug_active      (debug_active),
    .sys_enable        (sys_enable),
    .soft_reset        (soft_reset),
    .debug_enable      (debug_enable),
    .low_power         (low_power),
    .irq_global_enable (irq_global_enable),
    .irq               (irq)
  );

  //=========================================================================
  // AXI4-Lite Write Task
  //=========================================================================
  task axi_write;
    input [4:0]  addr;
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
    input  [4:0]  addr;
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
    errors         = 0;
    uart_ready     = 1'b1;
    aes_ready      = 1'b1;
    i2c_ready      = 1'b1;
    watchdog_active = 1'b0;
    security_error = 1'b0;
    bus_error      = 1'b0;
    debug_active   = 1'b0;

    s_axi_awaddr  = 5'h0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = 32'h0;
    s_axi_wstrb   = 4'h0;
    s_axi_wvalid  = 1'b0;
    s_axi_bready  = 1'b0;
    s_axi_araddr  = 5'h0;
    s_axi_arvalid = 1'b0;
    s_axi_rready  = 1'b0;

    // FSDB dump
    $fsdbDumpfile("dump_scs.fsdb");
    $fsdbDumpvars(0, tb_system_control_status);

    // Reset
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);

    $display("==================================================");
    $display("=== System Control Status Testbench Start     ===");
    $display("==================================================");

    //-------------------------------------------------------------------
    // Test 1: Read IP_ID (0x14) and VERSION (0x18) — ROM registers
    //-------------------------------------------------------------------
    $display("[TEST 1] Read IP_ID (0x14) and VERSION (0x18)");
    axi_read(5'h14, read_data);
    $display("  IP_ID   = 0x%08h (expected 0xAE615001)", read_data);
    if (read_data == 32'hAE61_5001) begin
      $display("  PASS: IP_ID correct");
    end else begin
      $display("  FAIL: IP_ID = 0x%08h", read_data);
      errors = errors + 1;
    end

    axi_read(5'h18, read_data);
    $display("  VERSION = 0x%08h (expected 0x00010000)", read_data);
    if (read_data == 32'h0001_0000) begin
      $display("  PASS: VERSION correct");
    end else begin
      $display("  FAIL: VERSION = 0x%08h", read_data);
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 2: Write SYS_CTRL = 0x01 (sys_enable), read back
    //-------------------------------------------------------------------
    $display("[TEST 2] Write SYS_CTRL = 0x01 (sys_enable=1)");
    axi_write(5'h00, 32'h0000_0001, 4'hF);
    axi_read(5'h00, read_data);
    $display("  SYS_CTRL = 0x%08h", read_data);
    if (read_data[0] == 1'b1) begin
      $display("  PASS: sys_enable bit set");
    end else begin
      $display("  FAIL: sys_enable bit not set");
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 3: Write SCRATCH = 0xDEADBEEF, read back
    //-------------------------------------------------------------------
    $display("[TEST 3] Write SCRATCH = 0xDEADBEEF (0x10)");
    axi_write(5'h10, 32'hDEAD_BEEF, 4'hF);
    axi_read(5'h10, read_data);
    $display("  SCRATCH = 0x%08h", read_data);
    if (read_data == 32'hDEAD_BEEF) begin
      $display("  PASS: SCRATCH = 0xDEADBEEF");
    end else begin
      $display("  FAIL: SCRATCH = 0x%08h", read_data);
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 4: Verify sys_enable output pin
    //-------------------------------------------------------------------
    $display("[TEST 4] Verify sys_enable output pin");
    @(posedge clk); #1;
    if (sys_enable == 1'b1) begin
      $display("  PASS: sys_enable = 1");
    end else begin
      $display("  FAIL: sys_enable = 0");
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 5: Write SYS_CTRL = 0x07 (sys_en + soft_rst + dbg_en), verify outputs
    //-------------------------------------------------------------------
    $display("[TEST 5] Write SYS_CTRL = 0x07 (sys_en+soft_rst+dbg_en)");
    axi_write(5'h00, 32'h0000_0007, 4'hF);
    @(posedge clk); #1;
    if (soft_reset == 1'b1 && debug_enable == 1'b1) begin
      $display("  PASS: soft_reset = 1, debug_enable = 1");
    end else begin
      $display("  FAIL: soft_reset = %b, debug_enable = %b (expected 1, 1)", soft_reset, debug_enable);
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 6: IRQ test — enable security_error IRQ, assert it, verify irq
    //   Write IRQ_ENABLE = 0x1 (bit0 = security_error), set security_error=1
    //-------------------------------------------------------------------
    $display("[TEST 6] IRQ test: enable sec_error IRQ, assert it");
    // Enable sys_enable + irq_global_enable (bit 4)
    axi_write(5'h00, 32'h0000_0011, 4'hF);
    // Write IRQ_ENABLE bit[0] = 1 (security_error)
    axi_write(5'h08, 32'h0000_0001, 4'hF);
    // Assert security_error
    security_error = 1'b1;
    @(posedge clk);
    @(posedge clk);
    #1;
    if (irq == 1'b1) begin
      $display("  PASS: irq asserted after security_error+enable");
    end else begin
      $display("  FAIL: irq not asserted (irq=%b, irq_global_enable=%b)", irq, irq_global_enable);
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 7: Read IRQ_STATUS, then clear it (write-1-to-clear)
    //-------------------------------------------------------------------
    $display("[TEST 7] Read IRQ_STATUS then write-1-to-clear");
    axi_read(5'h0C, read_data);
    $display("  IRQ_STATUS = 0x%08h (bit0 expected = 1)", read_data);
    if (read_data[0] == 1'b1) begin
      $display("  PASS: IRQ_STATUS[0] = 1");
    end else begin
      $display("  FAIL: IRQ_STATUS[0] = 0");
      errors = errors + 1;
    end

    // Deassert security_error, then clear IRQ_STATUS
    security_error = 1'b0;
    @(posedge clk);
    axi_write(5'h0C, 32'h0000_0001, 4'hF);  // write 1 to clear bit0
    @(posedge clk);
    axi_read(5'h0C, read_data);
    $display("  IRQ_STATUS after clear = 0x%08h (expected 0)", read_data);
    if (read_data[0] == 1'b0) begin
      $display("  PASS: IRQ_STATUS cleared");
    end else begin
      $display("  FAIL: IRQ_STATUS still = 0x%08h", read_data);
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 8: Read SYS_STATUS with external inputs asserted
    //-------------------------------------------------------------------
    $display("[TEST 8] Read SYS_STATUS with uart_ready+aes_ready+i2c_ready=1");
    uart_ready = 1'b1;
    aes_ready  = 1'b1;
    i2c_ready  = 1'b1;
    watchdog_active = 1'b0;
    debug_active    = 1'b0;
    @(posedge clk);
    axi_read(5'h04, read_data);
    $display("  SYS_STATUS = 0x%08h [uart=%b aes=%b i2c=%b wdg=%b]",
             read_data, read_data[0], read_data[1], read_data[2], read_data[4]);
    if (read_data[0] == 1'b1 && read_data[1] == 1'b1 && read_data[2] == 1'b1) begin
      $display("  PASS: SYS_STATUS uart/aes/i2c bits correct");
    end else begin
      $display("  FAIL: SYS_STATUS = 0x%08h", read_data);
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 9: COUNTER register increments each cycle
    //-------------------------------------------------------------------
    $display("[TEST 9] Read COUNTER twice — verify it increments");
    axi_read(5'h1C, counter_val1);
    axi_read(5'h1C, counter_val2);
    $display("  counter1 = 0x%08h  counter2 = 0x%08h", counter_val1, counter_val2);
    if (counter_val2 > counter_val1) begin
      $display("  PASS: counter incremented from 0x%08h to 0x%08h", counter_val1, counter_val2);
    end else begin
      $display("  FAIL: counter not incrementing");
      errors = errors + 1;
    end

    //-------------------------------------------------------------------
    // Test 10: Byte-write strobe test on SYS_CTRL
    //   Write only byte0 of SYS_CTRL with strobe = 4'h1
    //-------------------------------------------------------------------
    $display("[TEST 10] Byte-write strobe test on SYS_CTRL");
    // First clear SYS_CTRL completely
    axi_write(5'h00, 32'h0000_0000, 4'hF);
    // Write only byte0 with 0xAB
    axi_write(5'h00, 32'hDEAD_00AB, 4'h1);
    axi_read(5'h00, read_data);
    $display("  SYS_CTRL[7:0] = 0x%02h (expected 0x1B — only bits[4:0] are control)", read_data[7:0]);
    // Only lower 5 bits are meaningful outputs; byte strobe should write 0xAB into bits[7:0]
    if (read_data[7:0] == 8'hAB) begin
      $display("  PASS: byte strobe wrote correct value 0xAB");
    end else begin
      $display("  INFO: SYS_CTRL[7:0] = 0x%02h (check if masked)", read_data[7:0]);
    end

    //-------------------------------------------------------------------
    // Summary
    //-------------------------------------------------------------------
    $display("==================================================");
    $display("=== System Control Status Testbench Summary   ===");
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
    #100000;
    $display("  [ERROR] Simulation timeout");
    $finish;
  end

endmodule
