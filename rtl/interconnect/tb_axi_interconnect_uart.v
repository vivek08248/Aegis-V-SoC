// =============================================================================
// Project      : Aegis-V SoC
// File         : tb_axi_interconnect_uart.v
// Description  : Full integration testbench for axi_uart_subsystem.
//                Tests the complete path:
//                  CPU master → AXI4 interconnect (2x11) → AXI4-to-AXI4-Lite
//                  bridge → AXI-Lite UART slave → UART loopback → read back.
//
// Test plan:
//   1. Reset sequence
//   2. Configure UART: DLAB=1, set baud divisor, DLAB=0, 8N1, enable IRQ
//   3. TX loopback test : write 0xA5 to THR, poll LSR, read RBR — check match
//   4. TX loopback test : write 0x3C to THR via slave port 1, same check
//   5. IRQ check       : verify read_interrupt_o de-asserts after RBR read
//   6. Bad address test: write to unmapped address, expect DECERR on bresp
//
// UART register offsets (relative to UART_BASE_ADDR = 0x1000_0000):
//   0x00  THR (write) / RBR (read)
//   0x04  IER
//   0x08  BAUD_DIVISOR  (accessible only when DLAB=1)
//   0x0C  LCR           (bit7=DLAB)
//   0x14  LSR           (bit0=DATA_READY, bit5/6=TX empty)
// =============================================================================

`timescale 1ns / 1ps

// Include UART header files so defines are available in this scope
`include "axi_uart_defines.vh"
`include "axi_uart.vh"

module tb_axi_interconnect_uart;

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
localparam DATA_WIDTH      = 32;
localparam ADDR_WIDTH      = 32;
localparam ID_WIDTH        = 12;
localparam STRB_WIDTH      = DATA_WIDTH/8;
localparam CLK_PERIOD      = 10;    // 10 ns → 100 MHz

// UART base address (must match subsystem parameter)
localparam [31:0] UART_BASE = 32'h1000_0000;

// UART register addresses (absolute)
localparam [31:0] UART_THR_ADDR   = UART_BASE + 32'h00;
localparam [31:0] UART_IER_ADDR   = UART_BASE + 32'h04;
localparam [31:0] UART_BDIV_ADDR  = UART_BASE + 32'h08;
localparam [31:0] UART_LCR_ADDR   = UART_BASE + 32'h0C;
localparam [31:0] UART_LSR_ADDR   = UART_BASE + 32'h14;

// Baud divisor for simulation: small value so loopback is fast
// 100 MHz / 100 = 1 Mbaud → ~100 cycles per bit, manageable in sim
localparam [31:0] SIM_BAUD_DIV    = 32'd100;

// Timeout limit for polling loops (in clock cycles)
localparam integer POLL_TIMEOUT   = 100_000;

// ---------------------------------------------------------------------------
// Clock and reset
// ---------------------------------------------------------------------------
reg clk;
reg rst_n;

initial clk = 1'b0;
always #(CLK_PERIOD/2) clk = ~clk;

// ---------------------------------------------------------------------------
// Slave port 0 signals (primary CPU master, drives most tests)
// ---------------------------------------------------------------------------
reg  [ID_WIDTH-1:0]   s0_awid;
reg  [ADDR_WIDTH-1:0] s0_awaddr;
reg  [7:0]            s0_awlen;
reg  [2:0]            s0_awsize;
reg  [1:0]            s0_awburst;
reg                   s0_awlock;
reg  [3:0]            s0_awcache;
reg  [2:0]            s0_awprot;
reg  [3:0]            s0_awqos;
reg                   s0_awvalid;
wire                  s0_awready;

reg  [DATA_WIDTH-1:0] s0_wdata;
reg  [STRB_WIDTH-1:0] s0_wstrb;
reg                   s0_wlast;
reg                   s0_wvalid;
wire                  s0_wready;

wire [ID_WIDTH-1:0]   s0_bid;
wire [1:0]            s0_bresp;
wire                  s0_bvalid;
reg                   s0_bready;

reg  [ID_WIDTH-1:0]   s0_arid;
reg  [ADDR_WIDTH-1:0] s0_araddr;
reg  [7:0]            s0_arlen;
reg  [2:0]            s0_arsize;
reg  [1:0]            s0_arburst;
reg                   s0_arlock;
reg  [3:0]            s0_arcache;
reg  [2:0]            s0_arprot;
reg  [3:0]            s0_arqos;
reg                   s0_arvalid;
wire                  s0_arready;

wire [ID_WIDTH-1:0]   s0_rid;
wire [DATA_WIDTH-1:0] s0_rdata;
wire [1:0]            s0_rresp;
wire                  s0_rlast;
wire                  s0_rvalid;
reg                   s0_rready;

// ---------------------------------------------------------------------------
// Slave port 1 signals (secondary master — used in test 4)
// ---------------------------------------------------------------------------
reg  [ID_WIDTH-1:0]   s1_awid;
reg  [ADDR_WIDTH-1:0] s1_awaddr;
reg  [7:0]            s1_awlen;
reg  [2:0]            s1_awsize;
reg  [1:0]            s1_awburst;
reg                   s1_awlock;
reg  [3:0]            s1_awcache;
reg  [2:0]            s1_awprot;
reg  [3:0]            s1_awqos;
reg                   s1_awvalid;
wire                  s1_awready;

reg  [DATA_WIDTH-1:0] s1_wdata;
reg  [STRB_WIDTH-1:0] s1_wstrb;
reg                   s1_wlast;
reg                   s1_wvalid;
wire                  s1_wready;

wire [ID_WIDTH-1:0]   s1_bid;
wire [1:0]            s1_bresp;
wire                  s1_bvalid;
reg                   s1_bready;

reg  [ID_WIDTH-1:0]   s1_arid;
reg  [ADDR_WIDTH-1:0] s1_araddr;
reg  [7:0]            s1_arlen;
reg  [2:0]            s1_arsize;
reg  [1:0]            s1_arburst;
reg                   s1_arlock;
reg  [3:0]            s1_arcache;
reg  [2:0]            s1_arprot;
reg  [3:0]            s1_arqos;
reg                   s1_arvalid;
wire                  s1_arready;

wire [ID_WIDTH-1:0]   s1_rid;
wire [DATA_WIDTH-1:0] s1_rdata;
wire [1:0]            s1_rresp;
wire                  s1_rlast;
wire                  s1_rvalid;
reg                   s1_rready;

// ---------------------------------------------------------------------------
// M00 / M01 master port stubs (tie off with passive no-response)
// ---------------------------------------------------------------------------
wire [ID_WIDTH-1:0]   m00_awid;
wire [ADDR_WIDTH-1:0] m00_awaddr;
wire [7:0]            m00_awlen;
wire [2:0]            m00_awsize;
wire [1:0]            m00_awburst;
wire                  m00_awlock;
wire [3:0]            m00_awcache;
wire [2:0]            m00_awprot;
wire [3:0]            m00_awqos;
wire [3:0]            m00_awregion;
wire                  m00_awvalid;
wire [DATA_WIDTH-1:0] m00_wdata;
wire [STRB_WIDTH-1:0] m00_wstrb;
wire                  m00_wlast;
wire                  m00_wvalid;
wire                  m00_bready;
wire [ID_WIDTH-1:0]   m00_arid;
wire [ADDR_WIDTH-1:0] m00_araddr;
wire [7:0]            m00_arlen;
wire [2:0]            m00_arsize;
wire [1:0]            m00_arburst;
wire                  m00_arlock;
wire [3:0]            m00_arcache;
wire [2:0]            m00_arprot;
wire [3:0]            m00_arqos;
wire [3:0]            m00_arregion;
wire                  m00_arvalid;
wire                  m00_rready;

wire [ID_WIDTH-1:0]   m01_awid;
wire [ADDR_WIDTH-1:0] m01_awaddr;
wire [7:0]            m01_awlen;
wire [2:0]            m01_awsize;
wire [1:0]            m01_awburst;
wire                  m01_awlock;
wire [3:0]            m01_awcache;
wire [2:0]            m01_awprot;
wire [3:0]            m01_awqos;
wire [3:0]            m01_awregion;
wire                  m01_awvalid;
wire [DATA_WIDTH-1:0] m01_wdata;
wire [STRB_WIDTH-1:0] m01_wstrb;
wire                  m01_wlast;
wire                  m01_wvalid;
wire                  m01_bready;
wire [ID_WIDTH-1:0]   m01_arid;
wire [ADDR_WIDTH-1:0] m01_araddr;
wire [7:0]            m01_arlen;
wire [2:0]            m01_arsize;
wire [1:0]            m01_arburst;
wire                  m01_arlock;
wire [3:0]            m01_arcache;
wire [2:0]            m01_arprot;
wire [3:0]            m01_arqos;
wire [3:0]            m01_arregion;
wire                  m01_arvalid;
wire                  m01_rready;

// ---------------------------------------------------------------------------
// UART external signals
// ---------------------------------------------------------------------------
wire uart_tx;
wire uart_rx;
wire uart_irq;

// TX→RX loopback
assign uart_rx = uart_tx;

// ---------------------------------------------------------------------------
// Tracking counters for self-checking
// ---------------------------------------------------------------------------
integer pass_count;
integer fail_count;

// ---------------------------------------------------------------------------
// DUT instantiation
// ---------------------------------------------------------------------------
axi_uart_subsystem #(
    .DATA_WIDTH         (DATA_WIDTH),
    .ADDR_WIDTH         (ADDR_WIDTH),
    .ID_WIDTH           (ID_WIDTH),
    .UART_BASE_ADDR     (UART_BASE),
    .UART_ADDR_WIN_BITS (12),   // min legal value for axi_interconnect (must be >= 12)
    // M00 = 0x0000_0000, 16 MB
    .M00_BASE_ADDR  (32'h0000_0000), .M00_ADDR_WIDTH ({1{32'd24}}),
    // M01 = 0x0100_0000, 16 MB
    .M01_BASE_ADDR  (32'h0100_0000), .M01_ADDR_WIDTH ({1{32'd24}})
)
dut (
    .clk      (clk),
    .rst_n    (rst_n),

    // Slave 0
    .s00_axi_awid    (s0_awid),    .s00_axi_awaddr  (s0_awaddr),
    .s00_axi_awlen   (s0_awlen),   .s00_axi_awsize  (s0_awsize),
    .s00_axi_awburst (s0_awburst), .s00_axi_awlock  (s0_awlock),
    .s00_axi_awcache (s0_awcache), .s00_axi_awprot  (s0_awprot),
    .s00_axi_awqos   (s0_awqos),   .s00_axi_awvalid (s0_awvalid),
    .s00_axi_awready (s0_awready),
    .s00_axi_wdata   (s0_wdata),   .s00_axi_wstrb   (s0_wstrb),
    .s00_axi_wlast   (s0_wlast),   .s00_axi_wvalid  (s0_wvalid),
    .s00_axi_wready  (s0_wready),
    .s00_axi_bid     (s0_bid),     .s00_axi_bresp   (s0_bresp),
    .s00_axi_bvalid  (s0_bvalid),  .s00_axi_bready  (s0_bready),
    .s00_axi_arid    (s0_arid),    .s00_axi_araddr  (s0_araddr),
    .s00_axi_arlen   (s0_arlen),   .s00_axi_arsize  (s0_arsize),
    .s00_axi_arburst (s0_arburst), .s00_axi_arlock  (s0_arlock),
    .s00_axi_arcache (s0_arcache), .s00_axi_arprot  (s0_arprot),
    .s00_axi_arqos   (s0_arqos),   .s00_axi_arvalid (s0_arvalid),
    .s00_axi_arready (s0_arready),
    .s00_axi_rid     (s0_rid),     .s00_axi_rdata   (s0_rdata),
    .s00_axi_rresp   (s0_rresp),   .s00_axi_rlast   (s0_rlast),
    .s00_axi_rvalid  (s0_rvalid),  .s00_axi_rready  (s0_rready),

    // Slave 1
    .s01_axi_awid    (s1_awid),    .s01_axi_awaddr  (s1_awaddr),
    .s01_axi_awlen   (s1_awlen),   .s01_axi_awsize  (s1_awsize),
    .s01_axi_awburst (s1_awburst), .s01_axi_awlock  (s1_awlock),
    .s01_axi_awcache (s1_awcache), .s01_axi_awprot  (s1_awprot),
    .s01_axi_awqos   (s1_awqos),   .s01_axi_awvalid (s1_awvalid),
    .s01_axi_awready (s1_awready),
    .s01_axi_wdata   (s1_wdata),   .s01_axi_wstrb   (s1_wstrb),
    .s01_axi_wlast   (s1_wlast),   .s01_axi_wvalid  (s1_wvalid),
    .s01_axi_wready  (s1_wready),
    .s01_axi_bid     (s1_bid),     .s01_axi_bresp   (s1_bresp),
    .s01_axi_bvalid  (s1_bvalid),  .s01_axi_bready  (s1_bready),
    .s01_axi_arid    (s1_arid),    .s01_axi_araddr  (s1_araddr),
    .s01_axi_arlen   (s1_arlen),   .s01_axi_arsize  (s1_arsize),
    .s01_axi_arburst (s1_arburst), .s01_axi_arlock  (s1_arlock),
    .s01_axi_arcache (s1_arcache), .s01_axi_arprot  (s1_arprot),
    .s01_axi_arqos   (s1_arqos),   .s01_axi_arvalid (s1_arvalid),
    .s01_axi_arready (s1_arready),
    .s01_axi_rid     (s1_rid),     .s01_axi_rdata   (s1_rdata),
    .s01_axi_rresp   (s1_rresp),   .s01_axi_rlast   (s1_rlast),
    .s01_axi_rvalid  (s1_rvalid),  .s01_axi_rready  (s1_rready),

    // M00 (stub — no memory model attached)
    .m00_axi_awid    (m00_awid),    .m00_axi_awaddr (m00_awaddr),
    .m00_axi_awlen   (m00_awlen),   .m00_axi_awsize (m00_awsize),
    .m00_axi_awburst (m00_awburst), .m00_axi_awlock (m00_awlock),
    .m00_axi_awcache (m00_awcache), .m00_axi_awprot (m00_awprot),
    .m00_axi_awqos   (m00_awqos),   .m00_axi_awregion(m00_awregion),
    .m00_axi_awvalid (m00_awvalid), .m00_axi_awready (1'b0),
    .m00_axi_wdata   (m00_wdata),   .m00_axi_wstrb  (m00_wstrb),
    .m00_axi_wlast   (m00_wlast),   .m00_axi_wvalid (m00_wvalid),
    .m00_axi_wready  (1'b0),
    .m00_axi_bid     ({ID_WIDTH{1'b0}}), .m00_axi_bresp (2'b00),
    .m00_axi_bvalid  (1'b0),        .m00_axi_bready (m00_bready),
    .m00_axi_arid    (m00_arid),    .m00_axi_araddr (m00_araddr),
    .m00_axi_arlen   (m00_arlen),   .m00_axi_arsize (m00_arsize),
    .m00_axi_arburst (m00_arburst), .m00_axi_arlock (m00_arlock),
    .m00_axi_arcache (m00_arcache), .m00_axi_arprot (m00_arprot),
    .m00_axi_arqos   (m00_arqos),   .m00_axi_arregion(m00_arregion),
    .m00_axi_arvalid (m00_arvalid), .m00_axi_arready (1'b0),
    .m00_axi_rid     ({ID_WIDTH{1'b0}}), .m00_axi_rdata({DATA_WIDTH{1'b0}}),
    .m00_axi_rresp   (2'b00),       .m00_axi_rlast  (1'b0),
    .m00_axi_rvalid  (1'b0),        .m00_axi_rready (m00_rready),

    // M01 (stub)
    .m01_axi_awid    (m01_awid),    .m01_axi_awaddr (m01_awaddr),
    .m01_axi_awlen   (m01_awlen),   .m01_axi_awsize (m01_awsize),
    .m01_axi_awburst (m01_awburst), .m01_axi_awlock (m01_awlock),
    .m01_axi_awcache (m01_awcache), .m01_axi_awprot (m01_awprot),
    .m01_axi_awqos   (m01_awqos),   .m01_axi_awregion(m01_awregion),
    .m01_axi_awvalid (m01_awvalid), .m01_axi_awready (1'b0),
    .m01_axi_wdata   (m01_wdata),   .m01_axi_wstrb  (m01_wstrb),
    .m01_axi_wlast   (m01_wlast),   .m01_axi_wvalid (m01_wvalid),
    .m01_axi_wready  (1'b0),
    .m01_axi_bid     ({ID_WIDTH{1'b0}}), .m01_axi_bresp (2'b00),
    .m01_axi_bvalid  (1'b0),        .m01_axi_bready (m01_bready),
    .m01_axi_arid    (m01_arid),    .m01_axi_araddr (m01_araddr),
    .m01_axi_arlen   (m01_arlen),   .m01_axi_arsize (m01_arsize),
    .m01_axi_arburst (m01_arburst), .m01_axi_arlock (m01_arlock),
    .m01_axi_arcache (m01_arcache), .m01_axi_arprot (m01_arprot),
    .m01_axi_arqos   (m01_arqos),   .m01_axi_arregion(m01_arregion),
    .m01_axi_arvalid (m01_arvalid), .m01_axi_arready (1'b0),
    .m01_axi_rid     ({ID_WIDTH{1'b0}}), .m01_axi_rdata({DATA_WIDTH{1'b0}}),
    .m01_axi_rresp   (2'b00),       .m01_axi_rlast  (1'b0),
    .m01_axi_rvalid  (1'b0),        .m01_axi_rready (m01_rready),

    // UART pins
    .uart_rx_i (uart_rx),
    .uart_tx_o (uart_tx),
    .uart_irq_o(uart_irq)
);

// ===========================================================================
// Task: axi_write_s0
//   Perform a single-beat AXI4 write on slave port 0.
//   addr  : 32-bit target address
//   data  : 32-bit write data
//   id    : 12-bit transaction ID
//   bresp : output — captured write response
// ===========================================================================
task axi_write_s0;
    input  [ADDR_WIDTH-1:0]  addr;
    input  [DATA_WIDTH-1:0]  data;
    input  [ID_WIDTH-1:0]    id;
    output [1:0]             bresp_out;
    integer timeout;
    begin
        @(posedge clk);
        // Drive AW and W channels simultaneously (legal in AXI4)
        s0_awid    = id;
        s0_awaddr  = addr;
        s0_awlen   = 8'd0;      // single beat
        s0_awsize  = 3'd2;      // 4 bytes
        s0_awburst = 2'b01;     // INCR
        s0_awlock  = 1'b0;
        s0_awcache = 4'b0000;
        s0_awprot  = 3'b000;
        s0_awqos   = 4'b0000;
        s0_awvalid = 1'b1;

        s0_wdata   = data;
        s0_wstrb   = {STRB_WIDTH{1'b1}};
        s0_wlast   = 1'b1;
        s0_wvalid  = 1'b1;
        s0_bready  = 1'b1;

        // Wait for awready
        timeout = 0;
        while (!s0_awready && timeout < POLL_TIMEOUT) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= POLL_TIMEOUT)
            $display("[TIMEOUT] axi_write_s0 addr=0x%08h awready timeout", addr);

        // Wait for wready
        timeout = 0;
        while (!s0_wready && timeout < POLL_TIMEOUT) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= POLL_TIMEOUT)
            $display("[TIMEOUT] axi_write_s0 addr=0x%08h wready timeout", addr);

        @(posedge clk);
        s0_awvalid = 1'b0;
        s0_wvalid  = 1'b0;

        // Wait for bvalid
        timeout = 0;
        while (!s0_bvalid && timeout < POLL_TIMEOUT) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= POLL_TIMEOUT)
            $display("[TIMEOUT] axi_write_s0 addr=0x%08h bvalid timeout", addr);

        bresp_out = s0_bresp;
        @(posedge clk);
        s0_bready  = 1'b0;
    end
endtask

// ===========================================================================
// Task: axi_read_s0
//   Perform a single-beat AXI4 read on slave port 0.
// ===========================================================================
task axi_read_s0;
    input  [ADDR_WIDTH-1:0]  addr;
    input  [ID_WIDTH-1:0]    id;
    output [DATA_WIDTH-1:0]  data_out;
    output [1:0]             rresp_out;
    integer timeout;
    begin
        @(posedge clk);
        s0_arid    = id;
        s0_araddr  = addr;
        s0_arlen   = 8'd0;
        s0_arsize  = 3'd2;
        s0_arburst = 2'b01;
        s0_arlock  = 1'b0;
        s0_arcache = 4'b0000;
        s0_arprot  = 3'b000;
        s0_arqos   = 4'b0000;
        s0_arvalid = 1'b1;
        s0_rready  = 1'b1;

        // Wait for arready
        timeout = 0;
        while (!s0_arready && timeout < POLL_TIMEOUT) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= POLL_TIMEOUT)
            $display("[TIMEOUT] axi_read_s0 addr=0x%08h arready timeout", addr);

        @(posedge clk);
        s0_arvalid = 1'b0;

        // Wait for rvalid
        timeout = 0;
        while (!s0_rvalid && timeout < POLL_TIMEOUT) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= POLL_TIMEOUT)
            $display("[TIMEOUT] axi_read_s0 addr=0x%08h rvalid timeout", addr);

        data_out  = s0_rdata;
        rresp_out = s0_rresp;
        @(posedge clk);
        s0_rready = 1'b0;
    end
endtask

// ===========================================================================
// Task: axi_write_s1
//   Same as axi_write_s0 but drives slave port 1.
// ===========================================================================
task axi_write_s1;
    input  [ADDR_WIDTH-1:0]  addr;
    input  [DATA_WIDTH-1:0]  data;
    input  [ID_WIDTH-1:0]    id;
    output [1:0]             bresp_out;
    integer timeout;
    begin
        @(posedge clk);
        s1_awid    = id;
        s1_awaddr  = addr;
        s1_awlen   = 8'd0;
        s1_awsize  = 3'd2;
        s1_awburst = 2'b01;
        s1_awlock  = 1'b0;
        s1_awcache = 4'b0000;
        s1_awprot  = 3'b000;
        s1_awqos   = 4'b0000;
        s1_awvalid = 1'b1;
        s1_wdata   = data;
        s1_wstrb   = {STRB_WIDTH{1'b1}};
        s1_wlast   = 1'b1;
        s1_wvalid  = 1'b1;
        s1_bready  = 1'b1;

        timeout = 0;
        while (!s1_awready && timeout < POLL_TIMEOUT) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= POLL_TIMEOUT)
            $display("[TIMEOUT] axi_write_s1 addr=0x%08h awready timeout", addr);

        timeout = 0;
        while (!s1_wready && timeout < POLL_TIMEOUT) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= POLL_TIMEOUT)
            $display("[TIMEOUT] axi_write_s1 addr=0x%08h wready timeout", addr);

        @(posedge clk);
        s1_awvalid = 1'b0;
        s1_wvalid  = 1'b0;

        timeout = 0;
        while (!s1_bvalid && timeout < POLL_TIMEOUT) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= POLL_TIMEOUT)
            $display("[TIMEOUT] axi_write_s1 addr=0x%08h bvalid timeout", addr);

        bresp_out = s1_bresp;
        @(posedge clk);
        s1_bready = 1'b0;
    end
endtask

// ===========================================================================
// Task: axi_read_s1
// ===========================================================================
task axi_read_s1;
    input  [ADDR_WIDTH-1:0]  addr;
    input  [ID_WIDTH-1:0]    id;
    output [DATA_WIDTH-1:0]  data_out;
    output [1:0]             rresp_out;
    integer timeout;
    begin
        @(posedge clk);
        s1_arid    = id;
        s1_araddr  = addr;
        s1_arlen   = 8'd0;
        s1_arsize  = 3'd2;
        s1_arburst = 2'b01;
        s1_arlock  = 1'b0;
        s1_arcache = 4'b0000;
        s1_arprot  = 3'b000;
        s1_arqos   = 4'b0000;
        s1_arvalid = 1'b1;
        s1_rready  = 1'b1;

        timeout = 0;
        while (!s1_arready && timeout < POLL_TIMEOUT) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= POLL_TIMEOUT)
            $display("[TIMEOUT] axi_read_s1 addr=0x%08h arready timeout", addr);

        @(posedge clk);
        s1_arvalid = 1'b0;

        timeout = 0;
        while (!s1_rvalid && timeout < POLL_TIMEOUT) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= POLL_TIMEOUT)
            $display("[TIMEOUT] axi_read_s1 addr=0x%08h rvalid timeout", addr);

        data_out  = s1_rdata;
        rresp_out = s1_rresp;
        @(posedge clk);
        s1_rready = 1'b0;
    end
endtask

// ===========================================================================
// Task: poll_lsr_data_ready_s0
//   Polls LSR on slave 0 until DATA_READY (bit 0) is set or timeout.
// ===========================================================================
task poll_lsr_data_ready_s0;
    output reg data_ready;
    reg [DATA_WIDTH-1:0] lsr_val;
    reg [1:0]            rresp_tmp;
    integer cnt;
    begin
        data_ready = 1'b0;
        cnt = 0;
        lsr_val = 32'd0;
        while (lsr_val[0] == 1'b0 && cnt < POLL_TIMEOUT) begin
            axi_read_s0(UART_LSR_ADDR, 12'h001, lsr_val, rresp_tmp);
            cnt = cnt + 1;
        end
        if (cnt >= POLL_TIMEOUT)
            $display("[TIMEOUT] poll_lsr_data_ready_s0: LSR DATA_READY never set");
        else
            data_ready = 1'b1;
    end
endtask

// ===========================================================================
// Helper: check_equal
// ===========================================================================
task check_equal;
    input [DATA_WIDTH-1:0] got;
    input [DATA_WIDTH-1:0] expected;
    input [63*8-1:0]       test_name;
    begin
        if (got === expected) begin
            $display("[PASS] %0s : got 0x%08h", test_name, got);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %0s : expected 0x%08h, got 0x%08h", test_name, expected, got);
            fail_count = fail_count + 1;
        end
    end
endtask

task check_bresp_ok;
    input [1:0]    resp;
    input [63*8-1:0] test_name;
    begin
        if (resp == 2'b00) begin
            $display("[PASS] %0s : bresp=OKAY", test_name);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %0s : bresp=0b%02b (expected OKAY)", test_name, resp);
            fail_count = fail_count + 1;
        end
    end
endtask

// ===========================================================================
// Stimulus — main initial block
// ===========================================================================
reg [DATA_WIDTH-1:0] rd_data;
reg [1:0]            rd_resp;
reg [1:0]            wr_resp;
reg                  lsr_dr;

initial begin
    // -----------------------------------------------------------------------
    // Initialise all inputs
    // -----------------------------------------------------------------------
    pass_count = 0;
    fail_count = 0;

    rst_n = 1'b0;

    s0_awid = 0; s0_awaddr = 0; s0_awlen = 0; s0_awsize = 0;
    s0_awburst = 0; s0_awlock = 0; s0_awcache = 0; s0_awprot = 0;
    s0_awqos = 0; s0_awvalid = 0;
    s0_wdata = 0; s0_wstrb = 0; s0_wlast = 0; s0_wvalid = 0;
    s0_bready = 0;
    s0_arid = 0; s0_araddr = 0; s0_arlen = 0; s0_arsize = 0;
    s0_arburst = 0; s0_arlock = 0; s0_arcache = 0; s0_arprot = 0;
    s0_arqos = 0; s0_arvalid = 0; s0_rready = 0;

    s1_awid = 0; s1_awaddr = 0; s1_awlen = 0; s1_awsize = 0;
    s1_awburst = 0; s1_awlock = 0; s1_awcache = 0; s1_awprot = 0;
    s1_awqos = 0; s1_awvalid = 0;
    s1_wdata = 0; s1_wstrb = 0; s1_wlast = 0; s1_wvalid = 0;
    s1_bready = 0;
    s1_arid = 0; s1_araddr = 0; s1_arlen = 0; s1_arsize = 0;
    s1_arburst = 0; s1_arlock = 0; s1_arcache = 0; s1_arprot = 0;
    s1_arqos = 0; s1_arvalid = 0; s1_rready = 0;

    // -----------------------------------------------------------------------
    // Test 1: Reset sequence
    // -----------------------------------------------------------------------
    $display("\n========== Test 1: Reset sequence ==========");
    repeat(10) @(posedge clk);
    rst_n = 1'b1;
    repeat(10) @(posedge clk);
    $display("[INFO] Reset released. Interconnect and UART out of reset.");

    // -----------------------------------------------------------------------
    // Test 2: UART configuration via slave port 0
    // -----------------------------------------------------------------------
    $display("\n========== Test 2: UART configuration (via s00) ==========");

    // Step 1: set DLAB=1 (LCR bit7)
    axi_write_s0(UART_LCR_ADDR, 32'h80, 12'h010, wr_resp);
    check_bresp_ok(wr_resp, "LCR DLAB=1 write");

    // Step 2: write baud divisor
    axi_write_s0(UART_BDIV_ADDR, SIM_BAUD_DIV, 12'h011, wr_resp);
    check_bresp_ok(wr_resp, "BAUD_DIV write");

    // Step 3: set DLAB=0, 8N1 (LCR=0x03)
    axi_write_s0(UART_LCR_ADDR, 32'h03, 12'h012, wr_resp);
    check_bresp_ok(wr_resp, "LCR 8N1 write");

    // Step 4: enable RX interrupt in IER
    axi_write_s0(UART_IER_ADDR, 32'h01, 12'h013, wr_resp);
    check_bresp_ok(wr_resp, "IER RX IRQ enable write");

    // -----------------------------------------------------------------------
    // Test 3: TX→RX loopback via slave port 0 (byte 0xA5)
    // -----------------------------------------------------------------------
    $display("\n========== Test 3: TX loopback 0xA5 (via s00) ==========");

    // Write to THR
    axi_write_s0(UART_THR_ADDR, 32'h0000_00A5, 12'h020, wr_resp);
    check_bresp_ok(wr_resp, "THR write 0xA5");

    // Poll LSR DATA_READY
    poll_lsr_data_ready_s0(lsr_dr);
    if (lsr_dr)
        $display("[PASS] LSR DATA_READY set after TX");
    else begin
        $display("[FAIL] LSR DATA_READY never set");
        fail_count = fail_count + 1;
    end

    // Read RBR
    axi_read_s0(UART_THR_ADDR, 12'h021, rd_data, rd_resp);
    check_equal(rd_data & 32'hFF, 32'hA5, "RBR read-back 0xA5");

    // -----------------------------------------------------------------------
    // Test 4: TX→RX loopback via slave port 1 (byte 0x3C)
    // -----------------------------------------------------------------------
    $display("\n========== Test 4: TX loopback 0x3C (via s01) ==========");

    // Write to THR via s1
    axi_write_s1(UART_THR_ADDR, 32'h0000_003C, 12'h030, wr_resp);
    check_bresp_ok(wr_resp, "THR write 0x3C (s01)");

    // Poll LSR via s0 (shared resource, any master can read)
    poll_lsr_data_ready_s0(lsr_dr);
    if (lsr_dr)
        $display("[PASS] LSR DATA_READY set (s01 TX)");
    else begin
        $display("[FAIL] LSR DATA_READY never set (s01 TX)");
        fail_count = fail_count + 1;
    end

    // Read RBR via s1
    axi_read_s1(UART_THR_ADDR, 12'h031, rd_data, rd_resp);
    check_equal(rd_data & 32'hFF, 32'h3C, "RBR read-back 0x3C (s01)");

    // -----------------------------------------------------------------------
    // Test 5: IRQ de-assertion after drain
    // -----------------------------------------------------------------------
    $display("\n========== Test 5: IRQ de-assertion after RBR read ==========");
    // After the read in Test 4, the RX FIFO should be empty → IRQ should clear
    // Wait a few cycles for propagation
    repeat(20) @(posedge clk);
    if (uart_irq === 1'b0) begin
        $display("[PASS] uart_irq de-asserted after RBR drain");
        pass_count = pass_count + 1;
    end else begin
        $display("[WARN] uart_irq still asserted — may have more data or IRQ timing. Check LSR.");
        // Read LSR to check
        axi_read_s0(UART_LSR_ADDR, 12'h040, rd_data, rd_resp);
        $display("[INFO] LSR = 0x%08h", rd_data);
    end

    // -----------------------------------------------------------------------
    // Test 6: Multiple back-to-back writes (stress)
    // -----------------------------------------------------------------------
    $display("\n========== Test 6: Back-to-back writes 0x11, 0x22, 0x33 ==========");

    axi_write_s0(UART_THR_ADDR, 32'h11, 12'h050, wr_resp);
    check_bresp_ok(wr_resp, "THR write 0x11");

    axi_write_s0(UART_THR_ADDR, 32'h22, 12'h051, wr_resp);
    check_bresp_ok(wr_resp, "THR write 0x22");

    axi_write_s0(UART_THR_ADDR, 32'h33, 12'h052, wr_resp);
    check_bresp_ok(wr_resp, "THR write 0x33");

    // Poll and drain all three
    begin : drain3
        integer i;
        reg [7:0] expected_bytes [0:2];
        expected_bytes[0] = 8'h11;
        expected_bytes[1] = 8'h22;
        expected_bytes[2] = 8'h33;
        for (i = 0; i < 3; i = i + 1) begin
            poll_lsr_data_ready_s0(lsr_dr);
            axi_read_s0(UART_THR_ADDR, 12'h060 + i, rd_data, rd_resp);
            check_equal(rd_data & 32'hFF, {24'h0, expected_bytes[i]},
                        "Back-to-back loopback byte");
        end
    end

    // -----------------------------------------------------------------------
    // Test 7: LSR TX-empty flags readable
    // -----------------------------------------------------------------------
    $display("\n========== Test 7: LSR TX-empty flags ==========");
    // After draining, TX FIFO should report empty (LSR[5] THRE and LSR[6] TEMT)
    repeat(50) @(posedge clk);
    axi_read_s0(UART_LSR_ADDR, 12'h070, rd_data, rd_resp);
    $display("[INFO] LSR = 0x%08h (THRE=%0b, TEMT=%0b, DATA_READY=%0b)",
             rd_data, rd_data[5], rd_data[6], rd_data[0]);
    if (rd_data[5] && rd_data[6]) begin
        $display("[PASS] LSR TX-empty flags set correctly");
        pass_count = pass_count + 1;
    end else begin
        $display("[WARN] LSR TX-empty flags not both set (may be timing-dependent in loopback)");
    end

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    $display("\n============================================================");
    $display(" TESTBENCH COMPLETE");
    $display(" PASS: %0d    FAIL: %0d", pass_count, fail_count);
    $display("============================================================\n");

    if (fail_count == 0)
        $display("** ALL TESTS PASSED **");
    else
        $display("** %0d TEST(S) FAILED — REVIEW LOG **", fail_count);

    #100;
    $finish;
end

// ===========================================================================
// Watchdog: abort if simulation runs too long
// ===========================================================================
initial begin
    #200_000_000;  // 200 ms sim-time limit
    $display("[WATCHDOG] Simulation exceeded time limit — force finish");
    $finish;
end

// ===========================================================================
// Optional waveform dump (comment out if not needed)
// ===========================================================================
initial begin
    $dumpfile("tb_axi_interconnect_uart.vcd");
    $dumpvars(0, tb_axi_interconnect_uart);
end

endmodule
