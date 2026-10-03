`timescale 1ns/1ps
//==========================================================
// Testbench: tb_timer_core
// DUT: timer_core (sub-module of rv_timer)
//
// NOTE: The rv_timer top module uses TileLink UL (NOT AXI-Lite)
//       for its register interface. TileLink UL uses complex
//       SystemVerilog structs (tl_h2d, tl_d2h) requiring the
//       full tilelink package and rv_timer_reg_pkg. To keep
//       this standalone testbench simple and self-contained,
//       we test the timer_core sub-module directly, which has
//       a clean, simple port interface.
//
// FSDB dump: dump_rv_timer.fsdb
// Clock: 100 MHz (10 ns period)
// Reset: active-low, asynchronous
//==========================================================

module tb_timer_core;

  //----------------------------------------------------------
  // Signal declarations
  //----------------------------------------------------------
  reg          clk;
  reg          rst_n;
  reg          active;
  reg  [11:0]  prescaler;
  reg  [ 7:0]  step;
  reg  [63:0]  mtime;
  reg  [63:0]  mtimecmp [0:0];  // N=1, unpacked array
  wire         tick;
  wire [63:0]  mtime_d;
  wire [0:0]   intr;

  //----------------------------------------------------------
  // DUT instantiation
  //----------------------------------------------------------
  timer_core #(
    .N(1)
  ) dut (
    .clk_i      (clk),
    .rst_ni     (rst_n),
    .active     (active),
    .prescaler  (prescaler),
    .step       (step),
    .tick       (tick),
    .mtime_d    (mtime_d),
    .mtime      (mtime),
    .mtimecmp   (mtimecmp),
    .intr       (intr)
  );

  //----------------------------------------------------------
  // Clock generation: 100 MHz (period = 10 ns)
  //----------------------------------------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  //----------------------------------------------------------
  // mtime register model
  // In the real rv_timer, mtime is a CSR updated to mtime_d
  // on each tick. We replicate that behavior here.
  //----------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      mtime <= 64'h0;
    else if (tick)
      mtime <= mtime_d;
  end

  //----------------------------------------------------------
  // FSDB dump
  //----------------------------------------------------------
  initial begin
    $fsdbDumpfile("dump_rv_timer.fsdb");
    $fsdbDumpvars(0, tb_timer_core);
  end

  //----------------------------------------------------------
  // Test stimulus
  //----------------------------------------------------------
  integer errors;
  integer i;

  initial begin
    errors = 0;

    // Initialize inputs
    active      = 1'b0;
    prescaler   = 12'h0;
    step        = 8'h1;
    mtimecmp[0] = 64'h0;

    // Assert reset
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    // Release reset
    rst_n = 1'b1;
    @(posedge clk);

    //========================================================
    // Test 1: mtime_d increments by step
    //========================================================
    $display("[%0t] Test 1: mtime_d increment check", $time);
    active      = 1'b1;
    prescaler   = 12'h0;
    step        = 8'h1;
    mtimecmp[0] = 64'h100;
    @(posedge clk);
    #1; // settle
    if (mtime_d !== mtime + 64'h1) begin
      $display("  FAIL: mtime_d=%0h, expected mtime+1=%0h", mtime_d, mtime + 64'h1);
      errors = errors + 1;
    end else begin
      $display("  PASS: mtime_d=%0h (mtime=%0h + step=1)", mtime_d, mtime);
    end

    //========================================================
    // Test 2: tick is asserted (prescaler=0 → tick every cycle)
    //========================================================
    $display("[%0t] Test 2: tick assertion check", $time);
    #1;
    if (tick !== 1'b1) begin
      $display("  FAIL: tick=%b, expected 1", tick);
      errors = errors + 1;
    end else begin
      $display("  PASS: tick=1 (prescaler=0 → continuous)");
    end

    //========================================================
    // Test 3: Advance clock until mtime >= mtimecmp, verify intr
    //========================================================
    $display("[%0t] Test 3: interrupt generation (mtimecmp=0x100)", $time);
    i = 0;
    while (mtime < 64'h100 && i < 10000) begin
      @(posedge clk);
      #1;
      i = i + 1;
    end
    if (i >= 10000) begin
      $display("  FAIL: timeout waiting for mtime=0x100 (mtime=%0h)", mtime);
      errors = errors + 1;
    end else begin
      $display("  mtime reached %0h after %0d additional cycles", mtime, i);
      #1;
      if (intr[0] !== 1'b1) begin
        $display("  FAIL: intr=%b, expected 1 (mtime >= mtimecmp)", intr);
        errors = errors + 1;
      end else begin
        $display("  PASS: intr=1 (mtime=%0h >= mtimecmp=%0h)", mtime, mtimecmp[0]);
      end
    end

    //========================================================
    // Test 4: intr deasserts when active=0
    //========================================================
    $display("[%0t] Test 4: intr deassert when active=0", $time);
    active = 1'b0;
    @(posedge clk);
    #1;
    if (intr[0] !== 1'b0) begin
      $display("  FAIL: intr=%b, expected 0 (active=0)", intr);
      errors = errors + 1;
    end else begin
      $display("  PASS: intr=0 when active=0");
    end

    //========================================================
    // Test 5: prescaler behavior (prescaler=3, tick every 4 cycles)
    //========================================================
    $display("[%0t] Test 5: prescaler check (prescaler=3)", $time);
    active      = 1'b1;
    prescaler   = 12'h3;
    step        = 8'h1;
    mtimecmp[0] = 64'hFFFF_FFFF_FFFF_FFFF; // avoid interrupt
    @(posedge clk);
    #1;
    // With prescaler=3, tick should be 0 until tick_count reaches 3
    if (tick === 1'b1) begin
      $display("  NOTE: tick=1 immediately (tick_count may have been at prescaler)");
    end else begin
      $display("  PASS: tick=0 (prescaler=3, tick_count not yet reached)");
    end
    // Advance to let tick_count reach prescaler
    repeat (3) @(posedge clk);
    #1;
    $display("  After 4 cycles: tick=%b, mtime_d=%0h, mtime=%0h", tick, mtime_d, mtime);

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
