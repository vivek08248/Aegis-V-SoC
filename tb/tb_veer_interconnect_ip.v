// =============================================================================
// Project      : Aegis-V SoC
// File         : tb/tb_veer_interconnect_ip.v
// Description  : Verification testbench — VeeR EL2 ↔ AXI Interconnect ↔ IPs
//
//                Tests every connection between:
//                  • VeeR EL2 core (LSU port s00, IFU port s01)
//                  • axi_interconnect_wrap_2x11
//                  • UART  (M01 via axi4_to_axilite_bridge)
//                  • AES   (M02 via axi4_to_axilite_bridge)
//                  • I2C   (M03 via axi4_to_axilite_bridge + wb_to_axilite_bridge)
//
//                DUT: axi_uart_subsystem is EXTENDED by also wiring AES and I2C
//                     onto interconnect master ports M02 and M03.
//                     Because axi_uart_subsystem already exposes m00..m09
//                     as output AXI4 ports we hang AES and I2C bridges directly
//                     on m02/m03 in the testbench, exactly as aegis_v_soc.v does.
//
//                BFM style: identical to tb_axi_interconnect_uart.v
//                  - All tasks are procedural Verilog, same naming convention
//                  - FSDB dump via $fsdbDumpfile / $fsdbDumpvars
//                  - Self-checking: pass_count / fail_count at end
//
//                Test plan:
//                  T1 : Reset / clock check
//                  T2 : Interconnect routing — write to each peripheral base
//                       and verify bresp=OKAY (checks address decode)
//                  T3 : UART — baud config, 8N1, TX→RX loopback byte 0xA5
//                  T4 : UART — back-to-back bytes 0x11 0x22 0x33 from s01
//                  T5 : AES  — load NIST Appendix-B key + plaintext, encrypt,
//                              verify all 4 output words
//                  T6 : I2C  — prescaler write/read, enable core
//                  T7 : AXI bresp check — confirm DECERR on unmapped address
//                  T8 : Simultaneous s00 and s01 access (different peripherals)
//
//                Waveform output:  dump_veer_ic.fsdb
//                Verdi script  :   verdi_wave_veer_ic.tcl
//
//                Compile (from run/ directory):
//                  bash run.sh compile_d
//                Open waveforms:
//                  bash run.sh wave_d
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

// ---------------------------------------------------------------------------
// Inlined defines (avoid re-including IP headers at TB level)
// ---------------------------------------------------------------------------
// UART register byte addresses (base 0x1000_0000)
`define UART_BASE     32'h1000_0000
`define UART_THR      (`UART_BASE + 32'h00)
`define UART_RBR      (`UART_BASE + 32'h00)
`define UART_IER      (`UART_BASE + 32'h04)
`define UART_BAUD     (`UART_BASE + 32'h08)
`define UART_LCR      (`UART_BASE + 32'h0C)
`define UART_LSR      (`UART_BASE + 32'h14)

// AES register byte addresses (base 0x2000_0000)
`define AES_BASE      32'h2000_0000
`define AES_CTRL      (`AES_BASE  + 32'h00)
`define AES_KEY0      (`AES_BASE  + 32'h04)
`define AES_KEY1      (`AES_BASE  + 32'h08)
`define AES_KEY2      (`AES_BASE  + 32'h0C)
`define AES_KEY3      (`AES_BASE  + 32'h10)
`define AES_TEXT0     (`AES_BASE  + 32'h14)
`define AES_TEXT1     (`AES_BASE  + 32'h18)
`define AES_TEXT2     (`AES_BASE  + 32'h1C)
`define AES_TEXT3     (`AES_BASE  + 32'h20)
`define AES_OUT0      (`AES_BASE  + 32'h24)
`define AES_OUT1      (`AES_BASE  + 32'h28)
`define AES_OUT2      (`AES_BASE  + 32'h2C)
`define AES_OUT3      (`AES_BASE  + 32'h30)

// I2C register byte addresses (WB 3-bit word addr → ×4 = byte)
`define I2C_BASE      32'h3000_0000
`define I2C_PRER_LO   (`I2C_BASE  + 32'h00)
`define I2C_PRER_HI   (`I2C_BASE  + 32'h04)
`define I2C_CTR       (`I2C_BASE  + 32'h08)
`define I2C_TXR       (`I2C_BASE  + 32'h0C)
`define I2C_CR        (`I2C_BASE  + 32'h10)
`define I2C_SR        (`I2C_BASE  + 32'h10)

// Unmapped address (for DECERR test)
`define UNMAPPED      32'hF000_0000

// Timing
`define CLK_PERIOD    10          // 10 ns = 100 MHz
`define SIM_BAUD_DIV  32'd4       // very short for simulation (4 cycles/bit)
`define POLL_MAX      200_000

// =============================================================================
module tb_veer_interconnect_ip;
// =============================================================================

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
localparam DATA_WIDTH   = 32;
localparam ADDR_WIDTH   = 32;
localparam ID_WIDTH     = 12;
localparam STRB_WIDTH   = DATA_WIDTH / 8;
localparam BRIDGE_ID_W  = 8;         // bridge ID width (axi4_to_axilite_bridge)
localparam BRIDGE_LAW   = 5;         // AXI-Lite address width from bridge

// ---------------------------------------------------------------------------
// Clock and reset
// ---------------------------------------------------------------------------
reg clk;
reg rst_n;

initial  clk = 1'b0;
always  #(`CLK_PERIOD/2) clk = ~clk;

// ---------------------------------------------------------------------------
// AXI4 slave port 0  (simulates VeeR EL2 LSU — data bus)
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
// AXI4 slave port 1  (simulates VeeR EL2 IFU — instruction fetch)
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
// UART serial loopback
// ---------------------------------------------------------------------------
wire uart_tx;
wire uart_rx;
wire uart_irq;
assign uart_rx = uart_tx;     // TX directly wired to RX

// ---------------------------------------------------------------------------
// AXI4 master port wires from axi_uart_subsystem
// M00..M09 exposed; we connect AES on M02 and I2C on M03
// Remaining ports need stub responses
// ---------------------------------------------------------------------------
// --- M00 (stub — not used in this TB) ---
wire [ID_WIDTH-1:0]   m00_awid; wire [ADDR_WIDTH-1:0] m00_awaddr;
wire [7:0] m00_awlen; wire [2:0] m00_awsize; wire [1:0] m00_awburst;
wire m00_awlock; wire [3:0] m00_awcache; wire [2:0] m00_awprot;
wire [3:0] m00_awqos; wire [3:0] m00_awregion; wire m00_awvalid;
wire [DATA_WIDTH-1:0] m00_wdata; wire [STRB_WIDTH-1:0] m00_wstrb;
wire m00_wlast; wire m00_wvalid; wire m00_bready;
wire [ID_WIDTH-1:0] m00_arid; wire [ADDR_WIDTH-1:0] m00_araddr;
wire [7:0] m00_arlen; wire [2:0] m00_arsize; wire [1:0] m00_arburst;
wire m00_arlock; wire [3:0] m00_arcache; wire [2:0] m00_arprot;
wire [3:0] m00_arqos; wire [3:0] m00_arregion; wire m00_arvalid;
wire m00_rready;

// --- M01 (stub) ---
wire [ID_WIDTH-1:0]   m01_awid; wire [ADDR_WIDTH-1:0] m01_awaddr;
wire [7:0] m01_awlen; wire [2:0] m01_awsize; wire [1:0] m01_awburst;
wire m01_awlock; wire [3:0] m01_awcache; wire [2:0] m01_awprot;
wire [3:0] m01_awqos; wire [3:0] m01_awregion; wire m01_awvalid;
wire [DATA_WIDTH-1:0] m01_wdata; wire [STRB_WIDTH-1:0] m01_wstrb;
wire m01_wlast; wire m01_wvalid; wire m01_bready;
wire [ID_WIDTH-1:0] m01_arid; wire [ADDR_WIDTH-1:0] m01_araddr;
wire [7:0] m01_arlen; wire [2:0] m01_arsize; wire [1:0] m01_arburst;
wire m01_arlock; wire [3:0] m01_arcache; wire [2:0] m01_arprot;
wire [3:0] m01_arqos; wire [3:0] m01_arregion; wire m01_arvalid;
wire m01_rready;

// --- M02 → AES bridge wires ---
wire [ID_WIDTH-1:0]   m02_awid; wire [ADDR_WIDTH-1:0] m02_awaddr;
wire [7:0] m02_awlen; wire [2:0] m02_awsize; wire [1:0] m02_awburst;
wire m02_awlock; wire [3:0] m02_awcache; wire [2:0] m02_awprot;
wire [3:0] m02_awqos; wire [3:0] m02_awregion; wire m02_awvalid;
wire m02_awready;
wire [DATA_WIDTH-1:0] m02_wdata; wire [STRB_WIDTH-1:0] m02_wstrb;
wire m02_wlast; wire m02_wvalid; wire m02_wready;
wire [ID_WIDTH-1:0] m02_bid; wire [1:0] m02_bresp;
wire m02_bvalid; wire m02_bready;
wire [ID_WIDTH-1:0] m02_arid; wire [ADDR_WIDTH-1:0] m02_araddr;
wire [7:0] m02_arlen; wire [2:0] m02_arsize; wire [1:0] m02_arburst;
wire m02_arlock; wire [3:0] m02_arcache; wire [2:0] m02_arprot;
wire [3:0] m02_arqos; wire [3:0] m02_arregion; wire m02_arvalid;
wire m02_arready;
wire [ID_WIDTH-1:0] m02_rid; wire [DATA_WIDTH-1:0] m02_rdata;
wire [1:0] m02_rresp; wire m02_rlast; wire m02_rvalid; wire m02_rready;

// --- M03 → I2C bridge wires ---
wire [ID_WIDTH-1:0]   m03_awid; wire [ADDR_WIDTH-1:0] m03_awaddr;
wire [7:0] m03_awlen; wire [2:0] m03_awsize; wire [1:0] m03_awburst;
wire m03_awlock; wire [3:0] m03_awcache; wire [2:0] m03_awprot;
wire [3:0] m03_awqos; wire [3:0] m03_awregion; wire m03_awvalid;
wire m03_awready;
wire [DATA_WIDTH-1:0] m03_wdata; wire [STRB_WIDTH-1:0] m03_wstrb;
wire m03_wlast; wire m03_wvalid; wire m03_wready;
wire [ID_WIDTH-1:0] m03_bid; wire [1:0] m03_bresp;
wire m03_bvalid; wire m03_bready;
wire [ID_WIDTH-1:0] m03_arid; wire [ADDR_WIDTH-1:0] m03_araddr;
wire [7:0] m03_arlen; wire [2:0] m03_arsize; wire [1:0] m03_arburst;
wire m03_arlock; wire [3:0] m03_arcache; wire [2:0] m03_arprot;
wire [3:0] m03_arqos; wire [3:0] m03_arregion; wire m03_arvalid;
wire m03_arready;
wire [ID_WIDTH-1:0] m03_rid; wire [DATA_WIDTH-1:0] m03_rdata;
wire [1:0] m03_rresp; wire m03_rlast; wire m03_rvalid; wire m03_rready;

// --- AXI-Lite wires after AES bridge ---
wire [BRIDGE_ID_W-1:0]  aes_axil_awid;
wire [BRIDGE_LAW-1:0]   aes_axil_awaddr;
wire                    aes_axil_awvalid, aes_axil_awready;
wire [31:0]             aes_axil_wdata;
wire [3:0]              aes_axil_wstrb;
wire                    aes_axil_wvalid, aes_axil_wready;
wire [BRIDGE_ID_W-1:0]  aes_axil_bid;
wire [1:0]              aes_axil_bresp;
wire                    aes_axil_bvalid, aes_axil_bready;
wire [BRIDGE_ID_W-1:0]  aes_axil_arid;
wire [BRIDGE_LAW-1:0]   aes_axil_araddr;
wire                    aes_axil_arvalid, aes_axil_arready;
wire [BRIDGE_ID_W-1:0]  aes_axil_rid;
wire [31:0]             aes_axil_rdata;
wire [1:0]              aes_axil_rresp;
wire                    aes_axil_rvalid, aes_axil_rready;

// --- AXI-Lite wires after I2C bridge ---
wire [BRIDGE_ID_W-1:0]  i2c_axil_awid;
wire [BRIDGE_LAW-1:0]   i2c_axil_awaddr;
wire                    i2c_axil_awvalid, i2c_axil_awready;
wire [31:0]             i2c_axil_wdata;
wire [3:0]              i2c_axil_wstrb;
wire                    i2c_axil_wvalid, i2c_axil_wready;
wire [BRIDGE_ID_W-1:0]  i2c_axil_bid;
wire [1:0]              i2c_axil_bresp;
wire                    i2c_axil_bvalid, i2c_axil_bready;
wire [BRIDGE_ID_W-1:0]  i2c_axil_arid;
wire [BRIDGE_LAW-1:0]   i2c_axil_araddr;
wire                    i2c_axil_arvalid, i2c_axil_arready;
wire [BRIDGE_ID_W-1:0]  i2c_axil_rid;
wire [31:0]             i2c_axil_rdata;
wire [1:0]              i2c_axil_rresp;
wire                    i2c_axil_rvalid, i2c_axil_rready;

// --- Wishbone wires (wb_to_axilite_bridge → i2c_master_top) ---
wire [2:0]  wb_adr;
wire [7:0]  wb_dat_w, wb_dat_r;
wire        wb_we, wb_stb, wb_cyc, wb_ack, wb_inta;

// I2C bus (open-drain with pull-ups)
wire scl_o, scl_oen, sda_o, sda_oen;
wire scl = scl_oen ? 1'b1 : scl_o;
wire sda = sda_oen ? 1'b1 : sda_o;

// Active-high reset for bridges and interconnect
wire rst_ah = ~rst_n;

// ============================================================================
// DUT 1: axi_uart_subsystem
//   (contains axi_interconnect_wrap_2x11 + axi4_to_axilite_bridge + UART)
//   M10 port connects to UART internally.
//   M00..M09 exposed as AXI4 master ports.
//   We connect AES to M02 and I2C to M03.
// ============================================================================
axi_uart_subsystem #(
    .DATA_WIDTH         (DATA_WIDTH),
    .ADDR_WIDTH         (ADDR_WIDTH),
    .ID_WIDTH           (ID_WIDTH),
    .UART_BASE_ADDR     (`UART_BASE),
    .UART_ADDR_WIN_BITS (12),
    // M00 stub window
    .M00_BASE_ADDR  (32'h0000_0000), .M00_ADDR_WIDTH ({1{32'd24}}),
    // M01 stub window
    .M01_BASE_ADDR  (32'h0100_0000), .M01_ADDR_WIDTH ({1{32'd24}}),
    // M02 = AES
    .M02_BASE_ADDR  (`AES_BASE),     .M02_ADDR_WIDTH ({1{32'd12}}),
    // M03 = I2C
    .M03_BASE_ADDR  (`I2C_BASE),     .M03_ADDR_WIDTH ({1{32'd12}}),
    // M04..M09 unused (small windows to not overlap)
    .M04_BASE_ADDR  (32'h4000_0000), .M04_ADDR_WIDTH ({1{32'd12}}),
    .M05_BASE_ADDR  (32'h5000_0000), .M05_ADDR_WIDTH ({1{32'd12}}),
    .M06_BASE_ADDR  (32'h6000_0000), .M06_ADDR_WIDTH ({1{32'd12}}),
    .M07_BASE_ADDR  (32'h7000_0000), .M07_ADDR_WIDTH ({1{32'd12}}),
    .M08_BASE_ADDR  (32'h8000_0000), .M08_ADDR_WIDTH ({1{32'd12}}),
    .M09_BASE_ADDR  (32'h9000_0000), .M09_ADDR_WIDTH ({1{32'd12}})
) u_subsystem (
    .clk      (clk),
    .rst_n    (rst_n),

    // slave port 0  (simulated VeeR LSU)
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

    // slave port 1  (simulated VeeR IFU)
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

    // UART serial
    .uart_tx (uart_tx), .uart_rx (uart_rx), .uart_irq (uart_irq),

    // M00 stub
    .m00_axi_awid(m00_awid), .m00_axi_awaddr(m00_awaddr),
    .m00_axi_awlen(m00_awlen), .m00_axi_awsize(m00_awsize),
    .m00_axi_awburst(m00_awburst), .m00_axi_awlock(m00_awlock),
    .m00_axi_awcache(m00_awcache), .m00_axi_awprot(m00_awprot),
    .m00_axi_awqos(m00_awqos), .m00_axi_awregion(m00_awregion),
    .m00_axi_awvalid(m00_awvalid), .m00_axi_awready(1'b0),
    .m00_axi_wdata(m00_wdata), .m00_axi_wstrb(m00_wstrb),
    .m00_axi_wlast(m00_wlast), .m00_axi_wvalid(m00_wvalid), .m00_axi_wready(1'b0),
    .m00_axi_bid({ID_WIDTH{1'b0}}), .m00_axi_bresp(2'b10), .m00_axi_bvalid(1'b0),
    .m00_axi_bready(m00_bready),
    .m00_axi_arid(m00_arid), .m00_axi_araddr(m00_araddr),
    .m00_axi_arlen(m00_arlen), .m00_axi_arsize(m00_arsize),
    .m00_axi_arburst(m00_arburst), .m00_axi_arlock(m00_arlock),
    .m00_axi_arcache(m00_arcache), .m00_axi_arprot(m00_arprot),
    .m00_axi_arqos(m00_arqos), .m00_axi_arregion(m00_arregion),
    .m00_axi_arvalid(m00_arvalid), .m00_axi_arready(1'b0),
    .m00_axi_rid({ID_WIDTH{1'b0}}), .m00_axi_rdata({DATA_WIDTH{1'b0}}),
    .m00_axi_rresp(2'b10), .m00_axi_rlast(1'b1),
    .m00_axi_rvalid(1'b0), .m00_axi_rready(m00_rready),

    // M01 stub
    .m01_axi_awid(m01_awid), .m01_axi_awaddr(m01_awaddr),
    .m01_axi_awlen(m01_awlen), .m01_axi_awsize(m01_awsize),
    .m01_axi_awburst(m01_awburst), .m01_axi_awlock(m01_awlock),
    .m01_axi_awcache(m01_awcache), .m01_axi_awprot(m01_awprot),
    .m01_axi_awqos(m01_awqos), .m01_axi_awregion(m01_awregion),
    .m01_axi_awvalid(m01_awvalid), .m01_axi_awready(1'b0),
    .m01_axi_wdata(m01_wdata), .m01_axi_wstrb(m01_wstrb),
    .m01_axi_wlast(m01_wlast), .m01_axi_wvalid(m01_wvalid), .m01_axi_wready(1'b0),
    .m01_axi_bid({ID_WIDTH{1'b0}}), .m01_axi_bresp(2'b10), .m01_axi_bvalid(1'b0),
    .m01_axi_bready(m01_bready),
    .m01_axi_arid(m01_arid), .m01_axi_araddr(m01_araddr),
    .m01_axi_arlen(m01_arlen), .m01_axi_arsize(m01_arsize),
    .m01_axi_arburst(m01_arburst), .m01_axi_arlock(m01_arlock),
    .m01_axi_arcache(m01_arcache), .m01_axi_arprot(m01_arprot),
    .m01_axi_arqos(m01_arqos), .m01_axi_arregion(m01_arregion),
    .m01_axi_arvalid(m01_arvalid), .m01_axi_arready(1'b0),
    .m01_axi_rid({ID_WIDTH{1'b0}}), .m01_axi_rdata({DATA_WIDTH{1'b0}}),
    .m01_axi_rresp(2'b10), .m01_axi_rlast(1'b1),
    .m01_axi_rvalid(1'b0), .m01_axi_rready(m01_rready),

    // M02 → AES bridge (wired below)
    .m02_axi_awid(m02_awid), .m02_axi_awaddr(m02_awaddr),
    .m02_axi_awlen(m02_awlen), .m02_axi_awsize(m02_awsize),
    .m02_axi_awburst(m02_awburst), .m02_axi_awlock(m02_awlock),
    .m02_axi_awcache(m02_awcache), .m02_axi_awprot(m02_awprot),
    .m02_axi_awqos(m02_awqos), .m02_axi_awregion(m02_awregion),
    .m02_axi_awvalid(m02_awvalid), .m02_axi_awready(m02_awready),
    .m02_axi_wdata(m02_wdata), .m02_axi_wstrb(m02_wstrb),
    .m02_axi_wlast(m02_wlast), .m02_axi_wvalid(m02_wvalid), .m02_axi_wready(m02_wready),
    .m02_axi_bid(m02_bid), .m02_axi_bresp(m02_bresp), .m02_axi_bvalid(m02_bvalid),
    .m02_axi_bready(m02_bready),
    .m02_axi_arid(m02_arid), .m02_axi_araddr(m02_araddr),
    .m02_axi_arlen(m02_arlen), .m02_axi_arsize(m02_arsize),
    .m02_axi_arburst(m02_arburst), .m02_axi_arlock(m02_arlock),
    .m02_axi_arcache(m02_arcache), .m02_axi_arprot(m02_arprot),
    .m02_axi_arqos(m02_arqos), .m02_axi_arregion(m02_arregion),
    .m02_axi_arvalid(m02_arvalid), .m02_axi_arready(m02_arready),
    .m02_axi_rid(m02_rid), .m02_axi_rdata(m02_rdata),
    .m02_axi_rresp(m02_rresp), .m02_axi_rlast(m02_rlast),
    .m02_axi_rvalid(m02_rvalid), .m02_axi_rready(m02_rready),

    // M03 → I2C bridge (wired below)
    .m03_axi_awid(m03_awid), .m03_axi_awaddr(m03_awaddr),
    .m03_axi_awlen(m03_awlen), .m03_axi_awsize(m03_awsize),
    .m03_axi_awburst(m03_awburst), .m03_axi_awlock(m03_awlock),
    .m03_axi_awcache(m03_awcache), .m03_axi_awprot(m03_awprot),
    .m03_axi_awqos(m03_awqos), .m03_axi_awregion(m03_awregion),
    .m03_axi_awvalid(m03_awvalid), .m03_axi_awready(m03_awready),
    .m03_axi_wdata(m03_wdata), .m03_axi_wstrb(m03_wstrb),
    .m03_axi_wlast(m03_wlast), .m03_axi_wvalid(m03_wvalid), .m03_axi_wready(m03_wready),
    .m03_axi_bid(m03_bid), .m03_axi_bresp(m03_bresp), .m03_axi_bvalid(m03_bvalid),
    .m03_axi_bready(m03_bready),
    .m03_axi_arid(m03_arid), .m03_axi_araddr(m03_araddr),
    .m03_axi_arlen(m03_arlen), .m03_axi_arsize(m03_arsize),
    .m03_axi_arburst(m03_arburst), .m03_axi_arlock(m03_arlock),
    .m03_axi_arcache(m03_arcache), .m03_axi_arprot(m03_arprot),
    .m03_axi_arqos(m03_arqos), .m03_axi_arregion(m03_arregion),
    .m03_axi_arvalid(m03_arvalid), .m03_axi_arready(m03_arready),
    .m03_axi_rid(m03_rid), .m03_axi_rdata(m03_rdata),
    .m03_axi_rresp(m03_rresp), .m03_axi_rlast(m03_rlast),
    .m03_axi_rvalid(m03_rvalid), .m03_axi_rready(m03_rready),

    // M04..M09 stubs
    .m04_axi_awvalid(), .m04_axi_awready(1'b0), .m04_axi_awid(), .m04_axi_awaddr(),
    .m04_axi_awlen(), .m04_axi_awsize(), .m04_axi_awburst(), .m04_axi_awlock(),
    .m04_axi_awcache(), .m04_axi_awprot(), .m04_axi_awqos(), .m04_axi_awregion(),
    .m04_axi_wvalid(), .m04_axi_wready(1'b0), .m04_axi_wdata(), .m04_axi_wstrb(), .m04_axi_wlast(),
    .m04_axi_bid({ID_WIDTH{1'b0}}), .m04_axi_bresp(2'b10), .m04_axi_bvalid(1'b0), .m04_axi_bready(),
    .m04_axi_arid(), .m04_axi_araddr(), .m04_axi_arlen(), .m04_axi_arsize(),
    .m04_axi_arburst(), .m04_axi_arlock(), .m04_axi_arcache(), .m04_axi_arprot(),
    .m04_axi_arqos(), .m04_axi_arregion(), .m04_axi_arvalid(), .m04_axi_arready(1'b0),
    .m04_axi_rid({ID_WIDTH{1'b0}}), .m04_axi_rdata({DATA_WIDTH{1'b0}}),
    .m04_axi_rresp(2'b10), .m04_axi_rlast(1'b1), .m04_axi_rvalid(1'b0), .m04_axi_rready(),

    .m05_axi_awvalid(), .m05_axi_awready(1'b0), .m05_axi_awid(), .m05_axi_awaddr(),
    .m05_axi_awlen(), .m05_axi_awsize(), .m05_axi_awburst(), .m05_axi_awlock(),
    .m05_axi_awcache(), .m05_axi_awprot(), .m05_axi_awqos(), .m05_axi_awregion(),
    .m05_axi_wvalid(), .m05_axi_wready(1'b0), .m05_axi_wdata(), .m05_axi_wstrb(), .m05_axi_wlast(),
    .m05_axi_bid({ID_WIDTH{1'b0}}), .m05_axi_bresp(2'b10), .m05_axi_bvalid(1'b0), .m05_axi_bready(),
    .m05_axi_arid(), .m05_axi_araddr(), .m05_axi_arlen(), .m05_axi_arsize(),
    .m05_axi_arburst(), .m05_axi_arlock(), .m05_axi_arcache(), .m05_axi_arprot(),
    .m05_axi_arqos(), .m05_axi_arregion(), .m05_axi_arvalid(), .m05_axi_arready(1'b0),
    .m05_axi_rid({ID_WIDTH{1'b0}}), .m05_axi_rdata({DATA_WIDTH{1'b0}}),
    .m05_axi_rresp(2'b10), .m05_axi_rlast(1'b1), .m05_axi_rvalid(1'b0), .m05_axi_rready(),

    .m06_axi_awvalid(), .m06_axi_awready(1'b0), .m06_axi_awid(), .m06_axi_awaddr(),
    .m06_axi_awlen(), .m06_axi_awsize(), .m06_axi_awburst(), .m06_axi_awlock(),
    .m06_axi_awcache(), .m06_axi_awprot(), .m06_axi_awqos(), .m06_axi_awregion(),
    .m06_axi_wvalid(), .m06_axi_wready(1'b0), .m06_axi_wdata(), .m06_axi_wstrb(), .m06_axi_wlast(),
    .m06_axi_bid({ID_WIDTH{1'b0}}), .m06_axi_bresp(2'b10), .m06_axi_bvalid(1'b0), .m06_axi_bready(),
    .m06_axi_arid(), .m06_axi_araddr(), .m06_axi_arlen(), .m06_axi_arsize(),
    .m06_axi_arburst(), .m06_axi_arlock(), .m06_axi_arcache(), .m06_axi_arprot(),
    .m06_axi_arqos(), .m06_axi_arregion(), .m06_axi_arvalid(), .m06_axi_arready(1'b0),
    .m06_axi_rid({ID_WIDTH{1'b0}}), .m06_axi_rdata({DATA_WIDTH{1'b0}}),
    .m06_axi_rresp(2'b10), .m06_axi_rlast(1'b1), .m06_axi_rvalid(1'b0), .m06_axi_rready(),

    .m07_axi_awvalid(), .m07_axi_awready(1'b0), .m07_axi_awid(), .m07_axi_awaddr(),
    .m07_axi_awlen(), .m07_axi_awsize(), .m07_axi_awburst(), .m07_axi_awlock(),
    .m07_axi_awcache(), .m07_axi_awprot(), .m07_axi_awqos(), .m07_axi_awregion(),
    .m07_axi_wvalid(), .m07_axi_wready(1'b0), .m07_axi_wdata(), .m07_axi_wstrb(), .m07_axi_wlast(),
    .m07_axi_bid({ID_WIDTH{1'b0}}), .m07_axi_bresp(2'b10), .m07_axi_bvalid(1'b0), .m07_axi_bready(),
    .m07_axi_arid(), .m07_axi_araddr(), .m07_axi_arlen(), .m07_axi_arsize(),
    .m07_axi_arburst(), .m07_axi_arlock(), .m07_axi_arcache(), .m07_axi_arprot(),
    .m07_axi_arqos(), .m07_axi_arregion(), .m07_axi_arvalid(), .m07_axi_arready(1'b0),
    .m07_axi_rid({ID_WIDTH{1'b0}}), .m07_axi_rdata({DATA_WIDTH{1'b0}}),
    .m07_axi_rresp(2'b10), .m07_axi_rlast(1'b1), .m07_axi_rvalid(1'b0), .m07_axi_rready(),

    .m08_axi_awvalid(), .m08_axi_awready(1'b0), .m08_axi_awid(), .m08_axi_awaddr(),
    .m08_axi_awlen(), .m08_axi_awsize(), .m08_axi_awburst(), .m08_axi_awlock(),
    .m08_axi_awcache(), .m08_axi_awprot(), .m08_axi_awqos(), .m08_axi_awregion(),
    .m08_axi_wvalid(), .m08_axi_wready(1'b0), .m08_axi_wdata(), .m08_axi_wstrb(), .m08_axi_wlast(),
    .m08_axi_bid({ID_WIDTH{1'b0}}), .m08_axi_bresp(2'b10), .m08_axi_bvalid(1'b0), .m08_axi_bready(),
    .m08_axi_arid(), .m08_axi_araddr(), .m08_axi_arlen(), .m08_axi_arsize(),
    .m08_axi_arburst(), .m08_axi_arlock(), .m08_axi_arcache(), .m08_axi_arprot(),
    .m08_axi_arqos(), .m08_axi_arregion(), .m08_axi_arvalid(), .m08_axi_arready(1'b0),
    .m08_axi_rid({ID_WIDTH{1'b0}}), .m08_axi_rdata({DATA_WIDTH{1'b0}}),
    .m08_axi_rresp(2'b10), .m08_axi_rlast(1'b1), .m08_axi_rvalid(1'b0), .m08_axi_rready(),

    .m09_axi_awvalid(), .m09_axi_awready(1'b0), .m09_axi_awid(), .m09_axi_awaddr(),
    .m09_axi_awlen(), .m09_axi_awsize(), .m09_axi_awburst(), .m09_axi_awlock(),
    .m09_axi_awcache(), .m09_axi_awprot(), .m09_axi_awqos(), .m09_axi_awregion(),
    .m09_axi_wvalid(), .m09_axi_wready(1'b0), .m09_axi_wdata(), .m09_axi_wstrb(), .m09_axi_wlast(),
    .m09_axi_bid({ID_WIDTH{1'b0}}), .m09_axi_bresp(2'b10), .m09_axi_bvalid(1'b0), .m09_axi_bready(),
    .m09_axi_arid(), .m09_axi_araddr(), .m09_axi_arlen(), .m09_axi_arsize(),
    .m09_axi_arburst(), .m09_axi_arlock(), .m09_axi_arcache(), .m09_axi_arprot(),
    .m09_axi_arqos(), .m09_axi_arregion(), .m09_axi_arvalid(), .m09_axi_arready(1'b0),
    .m09_axi_rid({ID_WIDTH{1'b0}}), .m09_axi_rdata({DATA_WIDTH{1'b0}}),
    .m09_axi_rresp(2'b10), .m09_axi_rlast(1'b1), .m09_axi_rvalid(1'b0), .m09_axi_rready()
);

// ============================================================================
// DUT 2: axi4_to_axilite_bridge for AES  (M02)
// ============================================================================
axi4_to_axilite_bridge #(
    .DATA_WIDTH  (DATA_WIDTH),
    .ADDR_WIDTH  (ADDR_WIDTH),
    .LITE_ADDR_W (BRIDGE_LAW),
    .ID_WIDTH    (BRIDGE_ID_W)
) u_bridge_aes (
    .clk            (clk),
    .rst            (rst_ah),
    .s_axi_awid     (m02_awid[BRIDGE_ID_W-1:0]),
    .s_axi_awaddr   (m02_awaddr),
    .s_axi_awlen    (m02_awlen),
    .s_axi_awsize   (m02_awsize),
    .s_axi_awburst  (m02_awburst),
    .s_axi_awlock   (m02_awlock),
    .s_axi_awcache  (m02_awcache),
    .s_axi_awprot   (m02_awprot),
    .s_axi_awqos    (m02_awqos),
    .s_axi_awregion (m02_awregion),
    .s_axi_awvalid  (m02_awvalid),
    .s_axi_awready  (m02_awready),
    .s_axi_wdata    (m02_wdata),
    .s_axi_wstrb    (m02_wstrb),
    .s_axi_wlast    (m02_wlast),
    .s_axi_wvalid   (m02_wvalid),
    .s_axi_wready   (m02_wready),
    .s_axi_bid      (m02_bid[BRIDGE_ID_W-1:0]),
    .s_axi_bresp    (m02_bresp),
    .s_axi_bvalid   (m02_bvalid),
    .s_axi_bready   (m02_bready),
    .s_axi_arid     (m02_arid[BRIDGE_ID_W-1:0]),
    .s_axi_araddr   (m02_araddr),
    .s_axi_arlen    (m02_arlen),
    .s_axi_arsize   (m02_arsize),
    .s_axi_arburst  (m02_arburst),
    .s_axi_arlock   (m02_arlock),
    .s_axi_arcache  (m02_arcache),
    .s_axi_arprot   (m02_arprot),
    .s_axi_arqos    (m02_arqos),
    .s_axi_arregion (m02_arregion),
    .s_axi_arvalid  (m02_arvalid),
    .s_axi_arready  (m02_arready),
    .s_axi_rid      (m02_rid[BRIDGE_ID_W-1:0]),
    .s_axi_rdata    (m02_rdata),
    .s_axi_rresp    (m02_rresp),
    .s_axi_rlast    (m02_rlast),
    .s_axi_rvalid   (m02_rvalid),
    .s_axi_rready   (m02_rready),
    .m_axil_awid    (aes_axil_awid),
    .m_axil_awaddr  (aes_axil_awaddr),
    .m_axil_awvalid (aes_axil_awvalid),
    .m_axil_awready (aes_axil_awready),
    .m_axil_wdata   (aes_axil_wdata),
    .m_axil_wstrb   (aes_axil_wstrb),
    .m_axil_wvalid  (aes_axil_wvalid),
    .m_axil_wready  (aes_axil_wready),
    .m_axil_bid     (aes_axil_bid),
    .m_axil_bresp   (aes_axil_bresp),
    .m_axil_bvalid  (aes_axil_bvalid),
    .m_axil_bready  (aes_axil_bready),
    .m_axil_arid    (aes_axil_arid),
    .m_axil_araddr  (aes_axil_araddr),
    .m_axil_arvalid (aes_axil_arvalid),
    .m_axil_arready (aes_axil_arready),
    .m_axil_rid     (aes_axil_rid),
    .m_axil_rdata   (aes_axil_rdata),
    .m_axil_rresp   (aes_axil_rresp),
    .m_axil_rvalid  (aes_axil_rvalid),
    .m_axil_rready  (aes_axil_rready)
);

// ============================================================================
// DUT 3: aes_axi_slave  (AES-128 encrypt/decrypt)
// ============================================================================
aes_axi_slave u_aes (
    .s_axi_aclk    (clk),
    .s_axi_aresetn (rst_n),
    .s_axi_awaddr  (aes_axil_awaddr[5:0]),
    .s_axi_awvalid (aes_axil_awvalid),
    .s_axi_awready (aes_axil_awready),
    .s_axi_wdata   (aes_axil_wdata),
    .s_axi_wstrb   (aes_axil_wstrb),
    .s_axi_wvalid  (aes_axil_wvalid),
    .s_axi_wready  (aes_axil_wready),
    .s_axi_bresp   (aes_axil_bresp),
    .s_axi_bvalid  (aes_axil_bvalid),
    .s_axi_bready  (aes_axil_bready),
    .s_axi_araddr  (aes_axil_araddr[5:0]),
    .s_axi_arvalid (aes_axil_arvalid),
    .s_axi_arready (aes_axil_arready),
    .s_axi_rdata   (aes_axil_rdata),
    .s_axi_rresp   (aes_axil_rresp),
    .s_axi_rvalid  (aes_axil_rvalid),
    .s_axi_rready  (aes_axil_rready)
);

// ============================================================================
// DUT 4: axi4_to_axilite_bridge for I2C  (M03)
// ============================================================================
axi4_to_axilite_bridge #(
    .DATA_WIDTH  (DATA_WIDTH),
    .ADDR_WIDTH  (ADDR_WIDTH),
    .LITE_ADDR_W (BRIDGE_LAW),
    .ID_WIDTH    (BRIDGE_ID_W)
) u_bridge_i2c (
    .clk            (clk),
    .rst            (rst_ah),
    .s_axi_awid     (m03_awid[BRIDGE_ID_W-1:0]),
    .s_axi_awaddr   (m03_awaddr),
    .s_axi_awlen    (m03_awlen),
    .s_axi_awsize   (m03_awsize),
    .s_axi_awburst  (m03_awburst),
    .s_axi_awlock   (m03_awlock),
    .s_axi_awcache  (m03_awcache),
    .s_axi_awprot   (m03_awprot),
    .s_axi_awqos    (m03_awqos),
    .s_axi_awregion (m03_awregion),
    .s_axi_awvalid  (m03_awvalid),
    .s_axi_awready  (m03_awready),
    .s_axi_wdata    (m03_wdata),
    .s_axi_wstrb    (m03_wstrb),
    .s_axi_wlast    (m03_wlast),
    .s_axi_wvalid   (m03_wvalid),
    .s_axi_wready   (m03_wready),
    .s_axi_bid      (m03_bid[BRIDGE_ID_W-1:0]),
    .s_axi_bresp    (m03_bresp),
    .s_axi_bvalid   (m03_bvalid),
    .s_axi_bready   (m03_bready),
    .s_axi_arid     (m03_arid[BRIDGE_ID_W-1:0]),
    .s_axi_araddr   (m03_araddr),
    .s_axi_arlen    (m03_arlen),
    .s_axi_arsize   (m03_arsize),
    .s_axi_arburst  (m03_arburst),
    .s_axi_arlock   (m03_arlock),
    .s_axi_arcache  (m03_arcache),
    .s_axi_arprot   (m03_arprot),
    .s_axi_arqos    (m03_arqos),
    .s_axi_arregion (m03_arregion),
    .s_axi_arvalid  (m03_arvalid),
    .s_axi_arready  (m03_arready),
    .s_axi_rid      (m03_rid[BRIDGE_ID_W-1:0]),
    .s_axi_rdata    (m03_rdata),
    .s_axi_rresp    (m03_rresp),
    .s_axi_rlast    (m03_rlast),
    .s_axi_rvalid   (m03_rvalid),
    .s_axi_rready   (m03_rready),
    .m_axil_awid    (i2c_axil_awid),
    .m_axil_awaddr  (i2c_axil_awaddr),
    .m_axil_awvalid (i2c_axil_awvalid),
    .m_axil_awready (i2c_axil_awready),
    .m_axil_wdata   (i2c_axil_wdata),
    .m_axil_wstrb   (i2c_axil_wstrb),
    .m_axil_wvalid  (i2c_axil_wvalid),
    .m_axil_wready  (i2c_axil_wready),
    .m_axil_bid     (i2c_axil_bid),
    .m_axil_bresp   (i2c_axil_bresp),
    .m_axil_bvalid  (i2c_axil_bvalid),
    .m_axil_bready  (i2c_axil_bready),
    .m_axil_arid    (i2c_axil_arid),
    .m_axil_araddr  (i2c_axil_araddr),
    .m_axil_arvalid (i2c_axil_arvalid),
    .m_axil_arready (i2c_axil_arready),
    .m_axil_rid     (i2c_axil_rid),
    .m_axil_rdata   (i2c_axil_rdata),
    .m_axil_rresp   (i2c_axil_rresp),
    .m_axil_rvalid  (i2c_axil_rvalid),
    .m_axil_rready  (i2c_axil_rready)
);

// ============================================================================
// DUT 5: wb_to_axilite_bridge  (AXI-Lite → Wishbone for I2C)
// ============================================================================
wb_to_axilite_bridge #(
    .ADDR_WIDTH   (ADDR_WIDTH),
    .WB_BASE_ADDR (`I2C_BASE)
) u_wb_bridge (
    .clk          (clk),
    .rst_n        (rst_n),
    .wb_adr_i     (wb_adr),
    .wb_dat_i     (wb_dat_w),
    .wb_dat_o     (wb_dat_r),
    .wb_we_i      (wb_we),
    .wb_stb_i     (wb_stb),
    .wb_cyc_i     (wb_cyc),
    .wb_ack_o     (wb_ack),
    .m_axi_awaddr  ({{(ADDR_WIDTH-BRIDGE_LAW){1'b0}}, i2c_axil_awaddr}),
    .m_axi_awvalid (i2c_axil_awvalid),
    .m_axi_awready (i2c_axil_awready),
    .m_axi_wdata   (i2c_axil_wdata),
    .m_axi_wstrb   (i2c_axil_wstrb),
    .m_axi_wvalid  (i2c_axil_wvalid),
    .m_axi_wready  (i2c_axil_wready),
    .m_axi_bresp   (i2c_axil_bresp),
    .m_axi_bvalid  (i2c_axil_bvalid),
    .m_axi_bready  (i2c_axil_bready),
    .m_axi_araddr  ({{(ADDR_WIDTH-BRIDGE_LAW){1'b0}}, i2c_axil_araddr}),
    .m_axi_arvalid (i2c_axil_arvalid),
    .m_axi_arready (i2c_axil_arready),
    .m_axi_rdata   (i2c_axil_rdata),
    .m_axi_rresp   (i2c_axil_rresp),
    .m_axi_rvalid  (i2c_axil_rvalid),
    .m_axi_rready  (i2c_axil_rready)
);

// ============================================================================
// DUT 6: i2c_master_top  (Wishbone slave)
// ============================================================================
i2c_master_top u_i2c (
    .wb_clk_i     (clk),
    .wb_rst_i     (rst_ah),
    .arst_i       (1'b0),
    .wb_adr_i     (wb_adr),
    .wb_dat_i     (wb_dat_w),
    .wb_dat_o     (wb_dat_r),
    .wb_we_i      (wb_we),
    .wb_stb_i     (wb_stb),
    .wb_cyc_i     (wb_cyc),
    .wb_ack_o     (wb_ack),
    .wb_inta_o    (wb_inta),
    .scl_pad_i    (scl),
    .scl_pad_o    (scl_o),
    .scl_padoen_o (scl_oen),
    .sda_pad_i    (sda),
    .sda_pad_o    (sda_o),
    .sda_padoen_o (sda_oen)
);

// ============================================================================
// BFM tasks  (identical style to tb_axi_interconnect_uart.v)
// ============================================================================

// --------------------------------------------------------------------------
// axi_write_s0  — single-beat write on slave port 0  (VeeR LSU simulation)
// --------------------------------------------------------------------------
task axi_write_s0;
    input  [ADDR_WIDTH-1:0] addr;
    input  [DATA_WIDTH-1:0] data;
    input  [ID_WIDTH-1:0]   tid;
    output [1:0]            bresp_out;
    integer t;
    begin
        @(posedge clk);
        s0_awid    = tid;  s0_awaddr  = addr;
        s0_awlen   = 8'd0; s0_awsize  = 3'd2; s0_awburst = 2'b01;
        s0_awlock  = 1'b0; s0_awcache = 4'h0; s0_awprot  = 3'b000;
        s0_awqos   = 4'h0; s0_awvalid = 1'b1;
        s0_wdata   = data; s0_wstrb   = {STRB_WIDTH{1'b1}};
        s0_wlast   = 1'b1; s0_wvalid  = 1'b1; s0_bready  = 1'b1;
        t = 0;
        while ((!s0_awready || !s0_wready) && t < `POLL_MAX) begin @(posedge clk); t=t+1; end
        @(posedge clk); s0_awvalid = 1'b0; s0_wvalid = 1'b0;
        t = 0;
        while (!s0_bvalid && t < `POLL_MAX) begin @(posedge clk); t=t+1; end
        bresp_out = s0_bresp;
        @(posedge clk); s0_bready = 1'b0;
    end
endtask

// --------------------------------------------------------------------------
// axi_read_s0  — single-beat read on slave port 0
// --------------------------------------------------------------------------
task axi_read_s0;
    input  [ADDR_WIDTH-1:0] addr;
    input  [ID_WIDTH-1:0]   tid;
    output [DATA_WIDTH-1:0] data_out;
    output [1:0]            rresp_out;
    integer t;
    begin
        @(posedge clk);
        s0_arid    = tid;  s0_araddr  = addr;
        s0_arlen   = 8'd0; s0_arsize  = 3'd2; s0_arburst = 2'b01;
        s0_arlock  = 1'b0; s0_arcache = 4'h0; s0_arprot  = 3'b000;
        s0_arqos   = 4'h0; s0_arvalid = 1'b1; s0_rready  = 1'b1;
        t = 0;
        while (!s0_arready && t < `POLL_MAX) begin @(posedge clk); t=t+1; end
        @(posedge clk); s0_arvalid = 1'b0;
        t = 0;
        while (!s0_rvalid && t < `POLL_MAX) begin @(posedge clk); t=t+1; end
        data_out  = s0_rdata; rresp_out = s0_rresp;
        @(posedge clk); s0_rready = 1'b0;
    end
endtask

// --------------------------------------------------------------------------
// axi_write_s1  — single-beat write on slave port 1  (VeeR IFU simulation)
// --------------------------------------------------------------------------
task axi_write_s1;
    input  [ADDR_WIDTH-1:0] addr;
    input  [DATA_WIDTH-1:0] data;
    input  [ID_WIDTH-1:0]   tid;
    output [1:0]            bresp_out;
    integer t;
    begin
        @(posedge clk);
        s1_awid    = tid;  s1_awaddr  = addr;
        s1_awlen   = 8'd0; s1_awsize  = 3'd2; s1_awburst = 2'b01;
        s1_awlock  = 1'b0; s1_awcache = 4'h0; s1_awprot  = 3'b000;
        s1_awqos   = 4'h0; s1_awvalid = 1'b1;
        s1_wdata   = data; s1_wstrb   = {STRB_WIDTH{1'b1}};
        s1_wlast   = 1'b1; s1_wvalid  = 1'b1; s1_bready  = 1'b1;
        t = 0;
        while ((!s1_awready || !s1_wready) && t < `POLL_MAX) begin @(posedge clk); t=t+1; end
        @(posedge clk); s1_awvalid = 1'b0; s1_wvalid = 1'b0;
        t = 0;
        while (!s1_bvalid && t < `POLL_MAX) begin @(posedge clk); t=t+1; end
        bresp_out = s1_bresp;
        @(posedge clk); s1_bready = 1'b0;
    end
endtask

// --------------------------------------------------------------------------
// axi_read_s1
// --------------------------------------------------------------------------
task axi_read_s1;
    input  [ADDR_WIDTH-1:0] addr;
    input  [ID_WIDTH-1:0]   tid;
    output [DATA_WIDTH-1:0] data_out;
    output [1:0]            rresp_out;
    integer t;
    begin
        @(posedge clk);
        s1_arid    = tid;  s1_araddr  = addr;
        s1_arlen   = 8'd0; s1_arsize  = 3'd2; s1_arburst = 2'b01;
        s1_arlock  = 1'b0; s1_arcache = 4'h0; s1_arprot  = 3'b000;
        s1_arqos   = 4'h0; s1_arvalid = 1'b1; s1_rready  = 1'b1;
        t = 0;
        while (!s1_arready && t < `POLL_MAX) begin @(posedge clk); t=t+1; end
        @(posedge clk); s1_arvalid = 1'b0;
        t = 0;
        while (!s1_rvalid && t < `POLL_MAX) begin @(posedge clk); t=t+1; end
        data_out  = s1_rdata; rresp_out = s1_rresp;
        @(posedge clk); s1_rready = 1'b0;
    end
endtask

// ============================================================================
// Scoreboard helpers
// ============================================================================
integer pass_count;
integer fail_count;

task check;
    input [255:0] label;
    input         result;
    begin
        if (result) begin
            $display("[PASS] %-50s @ %0t ns", label, $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %-50s @ %0t ns", label, $time);
            fail_count = fail_count + 1;
        end
    end
endtask

// ============================================================================
// FSDB dump
// ============================================================================
initial begin
    $fsdbDumpfile("dump_veer_ic.fsdb");
    $fsdbDumpvars(0, tb_veer_interconnect_ip);
    $fsdbDumpvars(0, tb_veer_interconnect_ip.u_subsystem);
    $fsdbDumpvars(0, tb_veer_interconnect_ip.u_aes);
    $fsdbDumpvars(0, tb_veer_interconnect_ip.u_i2c);
    $fsdbDumpvars(0, tb_veer_interconnect_ip.u_bridge_aes);
    $fsdbDumpvars(0, tb_veer_interconnect_ip.u_bridge_i2c);
    $fsdbDumpvars(0, tb_veer_interconnect_ip.u_wb_bridge);
end

// ============================================================================
// Main stimulus
// ============================================================================
reg [DATA_WIDTH-1:0] rd_data;
reg [1:0]            resp;
integer              poll_t;

initial begin
    // -----------------------------------------------------------------------
    // Initialise all bus drivers
    // -----------------------------------------------------------------------
    pass_count = 0; fail_count = 0;
    // s0 idle
    s0_awid=0; s0_awaddr=0; s0_awlen=0; s0_awsize=0; s0_awburst=0;
    s0_awlock=0; s0_awcache=0; s0_awprot=0; s0_awqos=0; s0_awvalid=0;
    s0_wdata=0; s0_wstrb=0; s0_wlast=0; s0_wvalid=0; s0_bready=0;
    s0_arid=0; s0_araddr=0; s0_arlen=0; s0_arsize=0; s0_arburst=0;
    s0_arlock=0; s0_arcache=0; s0_arprot=0; s0_arqos=0; s0_arvalid=0;
    s0_rready=0;
    // s1 idle
    s1_awid=0; s1_awaddr=0; s1_awlen=0; s1_awsize=0; s1_awburst=0;
    s1_awlock=0; s1_awcache=0; s1_awprot=0; s1_awqos=0; s1_awvalid=0;
    s1_wdata=0; s1_wstrb=0; s1_wlast=0; s1_wvalid=0; s1_bready=0;
    s1_arid=0; s1_araddr=0; s1_arlen=0; s1_arsize=0; s1_arburst=0;
    s1_arlock=0; s1_arcache=0; s1_arprot=0; s1_arqos=0; s1_arvalid=0;
    s1_rready=0;

    // -----------------------------------------------------------------------
    // T1: Reset sequence
    // -----------------------------------------------------------------------
    rst_n = 1'b0;
    repeat(20) @(posedge clk);
    rst_n = 1'b1;
    repeat(10) @(posedge clk);

    $display("============================================================");
    $display(" Aegis-V SoC: VeeR ↔ Interconnect ↔ IP Verification");
    $display(" Clock: 100 MHz  |  Time unit: 1 ns");
    $display("============================================================");

    // -----------------------------------------------------------------------
    // T1: verify reset de-asserts cleanly
    // -----------------------------------------------------------------------
    $display("\n── T1: Reset & Clock ──────────────────────────────────────");
    check("rst_n de-asserted",       (rst_n === 1'b1));
    check("rst_ah de-asserted",      (rst_ah === 1'b0));
    check("UART aresetn high",
          (tb_veer_interconnect_ip.u_subsystem.rst_n === 1'b1));

    // -----------------------------------------------------------------------
    // T2: Interconnect routing — write to each peripheral, expect OKAY bresp
    // -----------------------------------------------------------------------
    $display("\n── T2: Interconnect Address Routing (s0 → UART/AES/I2C) ──");

    // Write to UART LCR to confirm M10 path (UART is on M10 of subsystem)
    axi_write_s0(`UART_LCR, 32'h0000_0080, 12'h001, resp);
    check("Interconnect routes s0 → UART  (bresp=OKAY)", (resp === 2'b00));

    // Write to AES CTRL to confirm M02 path
    axi_write_s0(`AES_CTRL, 32'h0000_0004, 12'h002, resp);
    check("Interconnect routes s0 → AES   (bresp=OKAY)", (resp === 2'b00));

    // Write to I2C PRER_LO to confirm M03 path
    axi_write_s0(`I2C_PRER_LO, 32'h0000_00C8, 12'h003, resp);
    check("Interconnect routes s0 → I2C   (bresp=OKAY)", (resp === 2'b00));

    // -----------------------------------------------------------------------
    // T3: UART — configure + TX/RX loopback byte 0xA5 via s0 (VeeR LSU)
    // -----------------------------------------------------------------------
    $display("\n── T3: UART TX/RX Loopback (s0 = VeeR LSU) ───────────────");

    // LCR DLAB=1
    axi_write_s0(`UART_LCR, 32'h0000_0080, 12'hA00, resp);
    // Baud divisor
    axi_write_s0(`UART_BAUD, `SIM_BAUD_DIV, 12'hA01, resp);
    // LCR 8N1, DLAB=0
    axi_write_s0(`UART_LCR, 32'h0000_0003, 12'hA02, resp);
    // IER RX interrupt enable
    axi_write_s0(`UART_IER, 32'h0000_0001, 12'hA03, resp);
    // Verify LCR reads back 0x03
    axi_read_s0(`UART_LCR, 12'hA04, rd_data, resp);
    check("UART LCR = 0x03 (8N1, DLAB=0)",       (rd_data[6:0] === 7'h03));
    check("UART LCR read rresp = OKAY",           (resp === 2'b00));

    // Write 0xA5 to THR
    axi_write_s0(`UART_THR, 32'h0000_00A5, 12'hA05, resp);
    check("UART THR write bresp = OKAY",          (resp === 2'b00));

    // Wait for serial loopback (baud_div=4 → very fast)
    repeat(800) @(posedge clk);

    // Poll LSR DATA_READY
    rd_data = 32'h0; poll_t = 0;
    while (rd_data[0] === 1'b0 && poll_t < `POLL_MAX) begin
        axi_read_s0(`UART_LSR, 12'hA06, rd_data, resp);
        poll_t = poll_t + 1;
    end
    check("UART LSR DATA_READY set after loopback", (rd_data[0] === 1'b1));
    check("UART LSR THRE set (TX empty)",           (rd_data[5] === 1'b1));

    // Read RBR — must be 0xA5
    axi_read_s0(`UART_RBR, 12'hA07, rd_data, resp);
    check("UART RBR loopback data = 0xA5",         (rd_data[7:0] === 8'hA5));
    check("UART RBR rresp = OKAY",                 (resp === 2'b00));

    // -----------------------------------------------------------------------
    // T4: UART — back-to-back bytes via s1 (VeeR IFU port)
    // -----------------------------------------------------------------------
    $display("\n── T4: UART Back-to-back via s1 (VeeR IFU) ────────────────");

    axi_write_s1(`UART_THR, 32'h0000_0011, 12'hB00, resp);
    check("UART s1 write 0x11 bresp = OKAY", (resp === 2'b00));
    repeat(800) @(posedge clk);
    rd_data = 0; poll_t = 0;
    while (rd_data[0] === 1'b0 && poll_t < `POLL_MAX) begin
        axi_read_s1(`UART_LSR, 12'hB01, rd_data, resp); poll_t=poll_t+1;
    end
    axi_read_s1(`UART_RBR, 12'hB02, rd_data, resp);
    check("UART s1 loopback byte 0x11",      (rd_data[7:0] === 8'h11));

    axi_write_s1(`UART_THR, 32'h0000_0022, 12'hB03, resp);
    repeat(800) @(posedge clk);
    rd_data = 0; poll_t = 0;
    while (rd_data[0] === 1'b0 && poll_t < `POLL_MAX) begin
        axi_read_s1(`UART_LSR, 12'hB04, rd_data, resp); poll_t=poll_t+1;
    end
    axi_read_s1(`UART_RBR, 12'hB05, rd_data, resp);
    check("UART s1 loopback byte 0x22",      (rd_data[7:0] === 8'h22));

    // -----------------------------------------------------------------------
    // T5: AES — NIST FIPS-197 Appendix B encryption
    //   Key:       2B7E1516 28AED2A6 ABF71588 09CF4F3C
    //   Plaintext: 3243F6A8 885A308D 3131982A E0370734
    //   Expected:  39258441D 02DC09FB DC118597 196A0B32
    // -----------------------------------------------------------------------
    $display("\n── T5: AES-128 Encryption (NIST Appendix B test vector) ───");

    // Reset AES (RST bit)
    axi_write_s0(`AES_CTRL, 32'h0000_0004, 12'hC00, resp);
    repeat(4) @(posedge clk);
    axi_write_s0(`AES_CTRL, 32'h0000_0000, 12'hC01, resp);

    // Load key
    axi_write_s0(`AES_KEY0, 32'h2B7E1516, 12'hC02, resp);
    axi_write_s0(`AES_KEY1, 32'h28AED2A6, 12'hC03, resp);
    axi_write_s0(`AES_KEY2, 32'hABF71588, 12'hC04, resp);
    axi_write_s0(`AES_KEY3, 32'h09CF4F3C, 12'hC05, resp);
    check("AES key load all bresp OKAY", (resp === 2'b00));

    // Load plaintext
    axi_write_s0(`AES_TEXT0, 32'h3243F6A8, 12'hC06, resp);
    axi_write_s0(`AES_TEXT1, 32'h885A308D, 12'hC07, resp);
    axi_write_s0(`AES_TEXT2, 32'h3131982A, 12'hC08, resp);
    axi_write_s0(`AES_TEXT3, 32'hE0370734, 12'hC09, resp);
    check("AES plaintext load all bresp OKAY", (resp === 2'b00));

    // KLD=1 (expand key)
    axi_write_s0(`AES_CTRL, 32'h0000_0002, 12'hC0A, resp);
    repeat(20) @(posedge clk);

    // Poll KDONE (bit 17)
    rd_data = 0; poll_t = 0;
    while (rd_data[17] === 1'b0 && poll_t < `POLL_MAX) begin
        axi_read_s0(`AES_CTRL, 12'hC0B, rd_data, resp); poll_t=poll_t+1;
    end
    check("AES KDONE set",  (rd_data[17] === 1'b1));

    // LD=1 (start encrypt)
    axi_write_s0(`AES_CTRL, 32'h0000_0001, 12'hC0C, resp);

    // Poll DONE (bit 16)
    rd_data = 0; poll_t = 0;
    while (rd_data[16] === 1'b0 && poll_t < `POLL_MAX) begin
        axi_read_s0(`AES_CTRL, 12'hC0D, rd_data, resp); poll_t=poll_t+1;
    end
    check("AES DONE set",   (rd_data[16] === 1'b1));

    // Verify ciphertext (all 4 words)
    axi_read_s0(`AES_OUT0, 12'hC0E, rd_data, resp);
    check("AES OUT0 = 0x3925841D", (rd_data === 32'h3925841D));
    axi_read_s0(`AES_OUT1, 12'hC0F, rd_data, resp);
    check("AES OUT1 = 0x02DC09FB", (rd_data === 32'h02DC09FB));
    axi_read_s0(`AES_OUT2, 12'hC10, rd_data, resp);
    check("AES OUT2 = 0xDC118597", (rd_data === 32'hDC118597));
    axi_read_s0(`AES_OUT3, 12'hC11, rd_data, resp);
    check("AES OUT3 = 0x196A0B32", (rd_data === 32'h196A0B32));

    // -----------------------------------------------------------------------
    // T6: I2C — write prescaler, enable core, verify readback
    // -----------------------------------------------------------------------
    $display("\n── T6: I2C Prescaler & Core Enable ─────────────────────────");

    // Write PRER_LO = 0xC8 (200 decimal)
    axi_write_s0(`I2C_PRER_LO, 32'h0000_00C8, 12'hD00, resp);
    check("I2C PRER_LO write bresp OKAY", (resp === 2'b00));

    // Write PRER_HI = 0x00
    axi_write_s0(`I2C_PRER_HI, 32'h0000_0000, 12'hD01, resp);
    check("I2C PRER_HI write bresp OKAY", (resp === 2'b00));

    // Read back PRER_LO
    axi_read_s0(`I2C_PRER_LO, 12'hD02, rd_data, resp);
    check("I2C PRER_LO read = 0xC8",      (rd_data[7:0] === 8'hC8));
    check("I2C PRER_LO rresp OKAY",       (resp === 2'b00));

    // Enable core: CTR[7]=EN=1
    axi_write_s0(`I2C_CTR, 32'h0000_0080, 12'hD03, resp);
    check("I2C CTR write EN=1 bresp OKAY",(resp === 2'b00));

    // Read CTR back
    axi_read_s0(`I2C_CTR, 12'hD04, rd_data, resp);
    check("I2C CTR[7] (EN) = 1",          (rd_data[7] === 1'b1));

    // -----------------------------------------------------------------------
    // T7: Simultaneous s0 (AES) and s1 (UART) — checks arbitration
    // -----------------------------------------------------------------------
    $display("\n── T7: Simultaneous s0 ↔ AES  and  s1 ↔ UART ──────────────");
    fork
        begin
            axi_write_s0(`AES_CTRL, 32'h0000_0004, 12'hE00, resp);
            check("Concurrent: s0 → AES  bresp OKAY", (resp === 2'b00));
        end
        begin
            axi_write_s1(`UART_IER, 32'h0000_0000, 12'hE01, resp);
            check("Concurrent: s1 → UART bresp OKAY", (resp === 2'b00));
        end
    join

    // -----------------------------------------------------------------------
    // T8: Connection integrity — read-back UART LCR and AES CTRL via s1
    // -----------------------------------------------------------------------
    $display("\n── T8: Connection Integrity Read-back (s1) ─────────────────");

    axi_read_s1(`UART_LCR, 12'hF00, rd_data, resp);
    check("s1 → UART LCR readable (rresp OKAY)", (resp === 2'b00));

    axi_read_s1(`I2C_CTR, 12'hF01, rd_data, resp);
    check("s1 → I2C  CTR readable (rresp OKAY)", (resp === 2'b00));
    check("s1 → I2C  CTR[7]=EN still 1",         (rd_data[7] === 1'b1));

    // -----------------------------------------------------------------------
    // Final report
    // -----------------------------------------------------------------------
    repeat(20) @(posedge clk);
    $display("\n============================================================");
    $display(" SIMULATION COMPLETE");
    $display(" PASSED : %0d", pass_count);
    $display(" FAILED : %0d", fail_count);
    $display("============================================================");
    if (fail_count === 0)
        $display(" *** ALL TESTS PASSED ***");
    else
        $display(" *** %0d FAILURE(S) — check waveform dump_veer_ic.fsdb ***",
                 fail_count);
    $finish;
end

// Global watchdog
initial begin
    #(`POLL_MAX * `CLK_PERIOD * 5);
    $display("[WATCHDOG] Simulation timed out!");
    $finish;
end

endmodule

`default_nettype wire
