// =============================================================================
// Testbench : tb_axi_interconnect_wrap_2x9.v
// Project   : Aegis-V SoC  (AXI4 Interconnect 2x9 wrapper)
// Purpose   : Functional verification – 3 write transactions + 2 read
//             transactions using two dummy AXI4 masters (CPU=M0, DMA=M1)
//             and nine dummy AXI4 slaves (S0-S8, matching Aegis-V memory map)
//
// Memory Map (from Aegis-V Architecture Document):
//   S0 – Instruction Memory  0x0000_0000 – 0x0000_7FFF  (32 KB)
//   S1 – Data Memory         0x2000_0000 – 0x2000_7FFF  (32 KB)
//   S2 – UART Controller     0x4000_0000 – 0x4000_0FFF
//   S3 – System Timer        0x4000_1000 – 0x4000_1FFF
//   S4 – GPIO Subsystem      0x4000_2000 – 0x4000_2FFF
//   S5 – SHA-256 Engine      0x4000_3000 – 0x4000_3FFF
//   S6 – PWM Generator       0x4000_4000 – 0x4000_4FFF
//   S7 – Windowed WDT        0x4000_5000 – 0x4000_5FFF
//   S8 – System Control      0x4000_E000 – 0x4000_EFFF
//
// Transactions:
//   WR1 (M0→S1): CPU writes 0xDEAD_BEEF to Data Memory       0x2000_0000
//   WR2 (M0→S2): CPU writes 0x0000_0041 to UART TX FIFO      0x4000_0000
//   WR3 (M1→S1): DMA writes 0xCAFE_BABE to Data Memory       0x2000_0004
//   RD1 (M0→S1): CPU reads  from Data Memory                 0x2000_0000
//   RD2 (M1→S0): DMA reads  from Instruction Memory          0x0000_0000
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_axi_interconnect_wrap_2x9;

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
localparam DATA_WIDTH = 32;
localparam ADDR_WIDTH = 32;
localparam STRB_WIDTH = DATA_WIDTH / 8;   // 4
localparam ID_WIDTH   = 8;

// Aegis-V SoC slave base addresses
localparam S0_BASE = 32'h0000_0000;  // Instruction Memory
localparam S1_BASE = 32'h2000_0000;  // Data Memory
localparam S2_BASE = 32'h4000_0000;  // UART
localparam S3_BASE = 32'h4000_1000;  // System Timer
localparam S4_BASE = 32'h4000_2000;  // GPIO
localparam S5_BASE = 32'h4000_3000;  // SHA-256
localparam S6_BASE = 32'h4000_4000;  // PWM
localparam S7_BASE = 32'h4000_5000;  // W-WDT
localparam S8_BASE = 32'h4000_E000;  // System Control

localparam ADDR_BITS = 12;  // 4 KB per peripheral slave window
localparam MEM_ADDR_BITS = 15; // 32 KB for S0/S1

// ---------------------------------------------------------------------------
// Clock & Reset
// ---------------------------------------------------------------------------
reg clk;
reg rst;

initial clk = 0;
always #5 clk = ~clk;   // 100 MHz

initial begin
    rst = 1;
    repeat (10) @(posedge clk);
    @(negedge clk);
    rst = 0;
end

// ---------------------------------------------------------------------------
// Master 0 (CPU)  BFM interface wires
// ---------------------------------------------------------------------------
// Write Address Channel
wire [ID_WIDTH-1:0]   m0_awid;
wire [ADDR_WIDTH-1:0] m0_awaddr;
wire [7:0]            m0_awlen;
wire [2:0]            m0_awsize;
wire [1:0]            m0_awburst;
wire                  m0_awlock;
wire [3:0]            m0_awcache;
wire [2:0]            m0_awprot;
wire [3:0]            m0_awqos;
wire                  m0_awvalid;
wire                  m0_awready;
// Write Data Channel
wire [DATA_WIDTH-1:0] m0_wdata;
wire [STRB_WIDTH-1:0] m0_wstrb;
wire                  m0_wlast;
wire                  m0_wvalid;
wire                  m0_wready;
// Write Response Channel
wire [ID_WIDTH-1:0]   m0_bid;
wire [1:0]            m0_bresp;
wire                  m0_bvalid;
wire                  m0_bready;
// Read Address Channel
wire [ID_WIDTH-1:0]   m0_arid;
wire [ADDR_WIDTH-1:0] m0_araddr;
wire [7:0]            m0_arlen;
wire [2:0]            m0_arsize;
wire [1:0]            m0_arburst;
wire                  m0_arlock;
wire [3:0]            m0_arcache;
wire [2:0]            m0_arprot;
wire [3:0]            m0_arqos;
wire                  m0_arvalid;
wire                  m0_arready;
// Read Data Channel
wire [ID_WIDTH-1:0]   m0_rid;
wire [DATA_WIDTH-1:0] m0_rdata;
wire [1:0]            m0_rresp;
wire                  m0_rlast;
wire                  m0_rvalid;
wire                  m0_rready;

// ---------------------------------------------------------------------------
// Master 1 (DMA)  BFM interface wires
// ---------------------------------------------------------------------------
wire [ID_WIDTH-1:0]   m1_awid;
wire [ADDR_WIDTH-1:0] m1_awaddr;
wire [7:0]            m1_awlen;
wire [2:0]            m1_awsize;
wire [1:0]            m1_awburst;
wire                  m1_awlock;
wire [3:0]            m1_awcache;
wire [2:0]            m1_awprot;
wire [3:0]            m1_awqos;
wire                  m1_awvalid;
wire                  m1_awready;
wire [DATA_WIDTH-1:0] m1_wdata;
wire [STRB_WIDTH-1:0] m1_wstrb;
wire                  m1_wlast;
wire                  m1_wvalid;
wire                  m1_wready;
wire [ID_WIDTH-1:0]   m1_bid;
wire [1:0]            m1_bresp;
wire                  m1_bvalid;
wire                  m1_bready;
wire [ID_WIDTH-1:0]   m1_arid;
wire [ADDR_WIDTH-1:0] m1_araddr;
wire [7:0]            m1_arlen;
wire [2:0]            m1_arsize;
wire [1:0]            m1_arburst;
wire                  m1_arlock;
wire [3:0]            m1_arcache;
wire [2:0]            m1_arprot;
wire [3:0]            m1_arqos;
wire                  m1_arvalid;
wire                  m1_arready;
wire [ID_WIDTH-1:0]   m1_rid;
wire [DATA_WIDTH-1:0] m1_rdata;
wire [1:0]            m1_rresp;
wire                  m1_rlast;
wire                  m1_rvalid;
wire                  m1_rready;

// ---------------------------------------------------------------------------
// Slave BFM interface wires  (9 slaves)
// ---------------------------------------------------------------------------
// Each slave has: awid/awaddr/.../awvalid, awready, wdata/.../wvalid, wready,
//                bid/bresp/bvalid, bready, arid/araddr/.../arvalid, arready,
//                rid/rdata/rresp/rlast/rvalid, rready
// Macro to declare all wires for one slave port
`define DECL_SLAVE_WIRES(N) \
    wire [ID_WIDTH-1:0]   s``N``_awid;    \
    wire [ADDR_WIDTH-1:0] s``N``_awaddr;  \
    wire [7:0]            s``N``_awlen;   \
    wire [2:0]            s``N``_awsize;  \
    wire [1:0]            s``N``_awburst; \
    wire                  s``N``_awlock;  \
    wire [3:0]            s``N``_awcache; \
    wire [2:0]            s``N``_awprot;  \
    wire [3:0]            s``N``_awqos;   \
    wire [3:0]            s``N``_awregion;\
    wire                  s``N``_awvalid; \
    wire                  s``N``_awready; \
    wire [DATA_WIDTH-1:0] s``N``_wdata;   \
    wire [STRB_WIDTH-1:0] s``N``_wstrb;   \
    wire                  s``N``_wlast;   \
    wire                  s``N``_wvalid;  \
    wire                  s``N``_wready;  \
    wire [ID_WIDTH-1:0]   s``N``_bid;     \
    wire [1:0]            s``N``_bresp;   \
    wire                  s``N``_bvalid;  \
    wire                  s``N``_bready;  \
    wire [ID_WIDTH-1:0]   s``N``_arid;    \
    wire [ADDR_WIDTH-1:0] s``N``_araddr;  \
    wire [7:0]            s``N``_arlen;   \
    wire [2:0]            s``N``_arsize;  \
    wire [1:0]            s``N``_arburst; \
    wire                  s``N``_arlock;  \
    wire [3:0]            s``N``_arcache; \
    wire [2:0]            s``N``_arprot;  \
    wire [3:0]            s``N``_arqos;   \
    wire [3:0]            s``N``_arregion;\
    wire                  s``N``_arvalid; \
    wire                  s``N``_arready; \
    wire [ID_WIDTH-1:0]   s``N``_rid;     \
    wire [DATA_WIDTH-1:0] s``N``_rdata;   \
    wire [1:0]            s``N``_rresp;   \
    wire                  s``N``_rlast;   \
    wire                  s``N``_rvalid;  \
    wire                  s``N``_rready;

`DECL_SLAVE_WIRES(00)
`DECL_SLAVE_WIRES(01)
`DECL_SLAVE_WIRES(02)
`DECL_SLAVE_WIRES(03)
`DECL_SLAVE_WIRES(04)
`DECL_SLAVE_WIRES(05)
`DECL_SLAVE_WIRES(06)
`DECL_SLAVE_WIRES(07)
`DECL_SLAVE_WIRES(08)

// ---------------------------------------------------------------------------
// DUT : axi_interconnect_wrap_2x9
// ---------------------------------------------------------------------------
axi_interconnect_wrap_2x9 #(
    // Address map aligned to Aegis-V SoC
    // M_REGIONS = 1  →  each M_BASE_ADDR is a flat 32-bit address
    // M_ADDR_WIDTH = 15 for 32 KB memories, 12 for 4 KB peripherals
    .DATA_WIDTH      (DATA_WIDTH),
    .ADDR_WIDTH      (ADDR_WIDTH),
    .ID_WIDTH        (ID_WIDTH),
    .M_REGIONS       (1),
    // S0 – Instruction Memory  base=0x0000_0000  width=15 (32 KB)
    .M00_BASE_ADDR   (S0_BASE),
    .M00_ADDR_WIDTH  (MEM_ADDR_BITS),
    .M00_CONNECT_READ (2'b11),
    .M00_CONNECT_WRITE(2'b11),
    // S1 – Data Memory         base=0x2000_0000  width=15 (32 KB)
    .M01_BASE_ADDR   (S1_BASE),
    .M01_ADDR_WIDTH  (MEM_ADDR_BITS),
    .M01_CONNECT_READ (2'b11),
    .M01_CONNECT_WRITE(2'b11),
    // S2 – UART                base=0x4000_0000  width=12 (4 KB)
    .M02_BASE_ADDR   (S2_BASE),
    .M02_ADDR_WIDTH  (ADDR_BITS),
    .M02_CONNECT_READ (2'b11),
    .M02_CONNECT_WRITE(2'b11),
    // S3 – System Timer        base=0x4000_1000  width=12
    .M03_BASE_ADDR   (S3_BASE),
    .M03_ADDR_WIDTH  (ADDR_BITS),
    .M03_CONNECT_READ (2'b11),
    .M03_CONNECT_WRITE(2'b11),
    // S4 – GPIO                base=0x4000_2000  width=12
    .M04_BASE_ADDR   (S4_BASE),
    .M04_ADDR_WIDTH  (ADDR_BITS),
    .M04_CONNECT_READ (2'b11),
    .M04_CONNECT_WRITE(2'b11),
    // S5 – SHA-256             base=0x4000_3000  width=12
    .M05_BASE_ADDR   (S5_BASE),
    .M05_ADDR_WIDTH  (ADDR_BITS),
    .M05_CONNECT_READ (2'b11),
    .M05_CONNECT_WRITE(2'b11),
    // S6 – PWM                 base=0x4000_4000  width=12
    .M06_BASE_ADDR   (S6_BASE),
    .M06_ADDR_WIDTH  (ADDR_BITS),
    .M06_CONNECT_READ (2'b11),
    .M06_CONNECT_WRITE(2'b11),
    // S7 – W-WDT               base=0x4000_5000  width=12
    .M07_BASE_ADDR   (S7_BASE),
    .M07_ADDR_WIDTH  (ADDR_BITS),
    .M07_CONNECT_READ (2'b11),
    .M07_CONNECT_WRITE(2'b11),
    // S8 – System Control      base=0x4000_E000  width=12
    .M08_BASE_ADDR   (S8_BASE),
    .M08_ADDR_WIDTH  (ADDR_BITS),
    .M08_CONNECT_READ (2'b11),
    .M08_CONNECT_WRITE(2'b11)
) dut (
    .clk  (clk),
    .rst  (rst),

    // ---------- Slave port 0 (CPU = M0) ----------
    .s00_axi_awid    (m0_awid),
    .s00_axi_awaddr  (m0_awaddr),
    .s00_axi_awlen   (m0_awlen),
    .s00_axi_awsize  (m0_awsize),
    .s00_axi_awburst (m0_awburst),
    .s00_axi_awlock  (m0_awlock),
    .s00_axi_awcache (m0_awcache),
    .s00_axi_awprot  (m0_awprot),
    .s00_axi_awqos   (m0_awqos),
    .s00_axi_awuser  (1'b0),
    .s00_axi_awvalid (m0_awvalid),
    .s00_axi_awready (m0_awready),
    .s00_axi_wdata   (m0_wdata),
    .s00_axi_wstrb   (m0_wstrb),
    .s00_axi_wlast   (m0_wlast),
    .s00_axi_wuser   (1'b0),
    .s00_axi_wvalid  (m0_wvalid),
    .s00_axi_wready  (m0_wready),
    .s00_axi_bid     (m0_bid),
    .s00_axi_bresp   (m0_bresp),
    .s00_axi_buser   (),
    .s00_axi_bvalid  (m0_bvalid),
    .s00_axi_bready  (m0_bready),
    .s00_axi_arid    (m0_arid),
    .s00_axi_araddr  (m0_araddr),
    .s00_axi_arlen   (m0_arlen),
    .s00_axi_arsize  (m0_arsize),
    .s00_axi_arburst (m0_arburst),
    .s00_axi_arlock  (m0_arlock),
    .s00_axi_arcache (m0_arcache),
    .s00_axi_arprot  (m0_arprot),
    .s00_axi_arqos   (m0_arqos),
    .s00_axi_aruser  (1'b0),
    .s00_axi_arvalid (m0_arvalid),
    .s00_axi_arready (m0_arready),
    .s00_axi_rid     (m0_rid),
    .s00_axi_rdata   (m0_rdata),
    .s00_axi_rresp   (m0_rresp),
    .s00_axi_rlast   (m0_rlast),
    .s00_axi_ruser   (),
    .s00_axi_rvalid  (m0_rvalid),
    .s00_axi_rready  (m0_rready),

    // ---------- Slave port 1 (DMA = M1) ----------
    .s01_axi_awid    (m1_awid),
    .s01_axi_awaddr  (m1_awaddr),
    .s01_axi_awlen   (m1_awlen),
    .s01_axi_awsize  (m1_awsize),
    .s01_axi_awburst (m1_awburst),
    .s01_axi_awlock  (m1_awlock),
    .s01_axi_awcache (m1_awcache),
    .s01_axi_awprot  (m1_awprot),
    .s01_axi_awqos   (m1_awqos),
    .s01_axi_awuser  (1'b0),
    .s01_axi_awvalid (m1_awvalid),
    .s01_axi_awready (m1_awready),
    .s01_axi_wdata   (m1_wdata),
    .s01_axi_wstrb   (m1_wstrb),
    .s01_axi_wlast   (m1_wlast),
    .s01_axi_wuser   (1'b0),
    .s01_axi_wvalid  (m1_wvalid),
    .s01_axi_wready  (m1_wready),
    .s01_axi_bid     (m1_bid),
    .s01_axi_bresp   (m1_bresp),
    .s01_axi_buser   (),
    .s01_axi_bvalid  (m1_bvalid),
    .s01_axi_bready  (m1_bready),
    .s01_axi_arid    (m1_arid),
    .s01_axi_araddr  (m1_araddr),
    .s01_axi_arlen   (m1_arlen),
    .s01_axi_arsize  (m1_arsize),
    .s01_axi_arburst (m1_arburst),
    .s01_axi_arlock  (m1_arlock),
    .s01_axi_arcache (m1_arcache),
    .s01_axi_arprot  (m1_arprot),
    .s01_axi_arqos   (m1_arqos),
    .s01_axi_aruser  (1'b0),
    .s01_axi_arvalid (m1_arvalid),
    .s01_axi_arready (m1_arready),
    .s01_axi_rid     (m1_rid),
    .s01_axi_rdata   (m1_rdata),
    .s01_axi_rresp   (m1_rresp),
    .s01_axi_rlast   (m1_rlast),
    .s01_axi_ruser   (),
    .s01_axi_rvalid  (m1_rvalid),
    .s01_axi_rready  (m1_rready),

    // ---------- Master port 00 (→ S0 Instruction Memory) ----------
    .m00_axi_awid    (s00_awid),
    .m00_axi_awaddr  (s00_awaddr),
    .m00_axi_awlen   (s00_awlen),
    .m00_axi_awsize  (s00_awsize),
    .m00_axi_awburst (s00_awburst),
    .m00_axi_awlock  (s00_awlock),
    .m00_axi_awcache (s00_awcache),
    .m00_axi_awprot  (s00_awprot),
    .m00_axi_awqos   (s00_awqos),
    .m00_axi_awregion(s00_awregion),
    .m00_axi_awuser  (),
    .m00_axi_awvalid (s00_awvalid),
    .m00_axi_awready (s00_awready),
    .m00_axi_wdata   (s00_wdata),
    .m00_axi_wstrb   (s00_wstrb),
    .m00_axi_wlast   (s00_wlast),
    .m00_axi_wuser   (),
    .m00_axi_wvalid  (s00_wvalid),
    .m00_axi_wready  (s00_wready),
    .m00_axi_bid     (s00_bid),
    .m00_axi_bresp   (s00_bresp),
    .m00_axi_buser   (1'b0),
    .m00_axi_bvalid  (s00_bvalid),
    .m00_axi_bready  (s00_bready),
    .m00_axi_arid    (s00_arid),
    .m00_axi_araddr  (s00_araddr),
    .m00_axi_arlen   (s00_arlen),
    .m00_axi_arsize  (s00_arsize),
    .m00_axi_arburst (s00_arburst),
    .m00_axi_arlock  (s00_arlock),
    .m00_axi_arcache (s00_arcache),
    .m00_axi_arprot  (s00_arprot),
    .m00_axi_arqos   (s00_arqos),
    .m00_axi_arregion(s00_arregion),
    .m00_axi_aruser  (),
    .m00_axi_arvalid (s00_arvalid),
    .m00_axi_arready (s00_arready),
    .m00_axi_rid     (s00_rid),
    .m00_axi_rdata   (s00_rdata),
    .m00_axi_rresp   (s00_rresp),
    .m00_axi_rlast   (s00_rlast),
    .m00_axi_ruser   (1'b0),
    .m00_axi_rvalid  (s00_rvalid),
    .m00_axi_rready  (s00_rready),

    // ---------- Master port 01 (→ S1 Data Memory) ----------
    .m01_axi_awid    (s01_awid),
    .m01_axi_awaddr  (s01_awaddr),
    .m01_axi_awlen   (s01_awlen),
    .m01_axi_awsize  (s01_awsize),
    .m01_axi_awburst (s01_awburst),
    .m01_axi_awlock  (s01_awlock),
    .m01_axi_awcache (s01_awcache),
    .m01_axi_awprot  (s01_awprot),
    .m01_axi_awqos   (s01_awqos),
    .m01_axi_awregion(s01_awregion),
    .m01_axi_awuser  (),
    .m01_axi_awvalid (s01_awvalid),
    .m01_axi_awready (s01_awready),
    .m01_axi_wdata   (s01_wdata),
    .m01_axi_wstrb   (s01_wstrb),
    .m01_axi_wlast   (s01_wlast),
    .m01_axi_wuser   (),
    .m01_axi_wvalid  (s01_wvalid),
    .m01_axi_wready  (s01_wready),
    .m01_axi_bid     (s01_bid),
    .m01_axi_bresp   (s01_bresp),
    .m01_axi_buser   (1'b0),
    .m01_axi_bvalid  (s01_bvalid),
    .m01_axi_bready  (s01_bready),
    .m01_axi_arid    (s01_arid),
    .m01_axi_araddr  (s01_araddr),
    .m01_axi_arlen   (s01_arlen),
    .m01_axi_arsize  (s01_arsize),
    .m01_axi_arburst (s01_arburst),
    .m01_axi_arlock  (s01_arlock),
    .m01_axi_arcache (s01_arcache),
    .m01_axi_arprot  (s01_arprot),
    .m01_axi_arqos   (s01_arqos),
    .m01_axi_arregion(s01_arregion),
    .m01_axi_aruser  (),
    .m01_axi_arvalid (s01_arvalid),
    .m01_axi_arready (s01_arready),
    .m01_axi_rid     (s01_rid),
    .m01_axi_rdata   (s01_rdata),
    .m01_axi_rresp   (s01_rresp),
    .m01_axi_rlast   (s01_rlast),
    .m01_axi_ruser   (1'b0),
    .m01_axi_rvalid  (s01_rvalid),
    .m01_axi_rready  (s01_rready),

    // ---------- Master port 02 (→ S2 UART) ----------
    .m02_axi_awid    (s02_awid),
    .m02_axi_awaddr  (s02_awaddr),
    .m02_axi_awlen   (s02_awlen),
    .m02_axi_awsize  (s02_awsize),
    .m02_axi_awburst (s02_awburst),
    .m02_axi_awlock  (s02_awlock),
    .m02_axi_awcache (s02_awcache),
    .m02_axi_awprot  (s02_awprot),
    .m02_axi_awqos   (s02_awqos),
    .m02_axi_awregion(s02_awregion),
    .m02_axi_awuser  (),
    .m02_axi_awvalid (s02_awvalid),
    .m02_axi_awready (s02_awready),
    .m02_axi_wdata   (s02_wdata),
    .m02_axi_wstrb   (s02_wstrb),
    .m02_axi_wlast   (s02_wlast),
    .m02_axi_wuser   (),
    .m02_axi_wvalid  (s02_wvalid),
    .m02_axi_wready  (s02_wready),
    .m02_axi_bid     (s02_bid),
    .m02_axi_bresp   (s02_bresp),
    .m02_axi_buser   (1'b0),
    .m02_axi_bvalid  (s02_bvalid),
    .m02_axi_bready  (s02_bready),
    .m02_axi_arid    (s02_arid),
    .m02_axi_araddr  (s02_araddr),
    .m02_axi_arlen   (s02_arlen),
    .m02_axi_arsize  (s02_arsize),
    .m02_axi_arburst (s02_arburst),
    .m02_axi_arlock  (s02_arlock),
    .m02_axi_arcache (s02_arcache),
    .m02_axi_arprot  (s02_arprot),
    .m02_axi_arqos   (s02_arqos),
    .m02_axi_arregion(s02_arregion),
    .m02_axi_aruser  (),
    .m02_axi_arvalid (s02_arvalid),
    .m02_axi_arready (s02_arready),
    .m02_axi_rid     (s02_rid),
    .m02_axi_rdata   (s02_rdata),
    .m02_axi_rresp   (s02_rresp),
    .m02_axi_rlast   (s02_rlast),
    .m02_axi_ruser   (1'b0),
    .m02_axi_rvalid  (s02_rvalid),
    .m02_axi_rready  (s02_rready),

    // ---------- Master port 03 (→ S3 System Timer) ----------
    .m03_axi_awid    (s03_awid),
    .m03_axi_awaddr  (s03_awaddr),
    .m03_axi_awlen   (s03_awlen),
    .m03_axi_awsize  (s03_awsize),
    .m03_axi_awburst (s03_awburst),
    .m03_axi_awlock  (s03_awlock),
    .m03_axi_awcache (s03_awcache),
    .m03_axi_awprot  (s03_awprot),
    .m03_axi_awqos   (s03_awqos),
    .m03_axi_awregion(s03_awregion),
    .m03_axi_awuser  (),
    .m03_axi_awvalid (s03_awvalid),
    .m03_axi_awready (s03_awready),
    .m03_axi_wdata   (s03_wdata),
    .m03_axi_wstrb   (s03_wstrb),
    .m03_axi_wlast   (s03_wlast),
    .m03_axi_wuser   (),
    .m03_axi_wvalid  (s03_wvalid),
    .m03_axi_wready  (s03_wready),
    .m03_axi_bid     (s03_bid),
    .m03_axi_bresp   (s03_bresp),
    .m03_axi_buser   (1'b0),
    .m03_axi_bvalid  (s03_bvalid),
    .m03_axi_bready  (s03_bready),
    .m03_axi_arid    (s03_arid),
    .m03_axi_araddr  (s03_araddr),
    .m03_axi_arlen   (s03_arlen),
    .m03_axi_arsize  (s03_arsize),
    .m03_axi_arburst (s03_arburst),
    .m03_axi_arlock  (s03_arlock),
    .m03_axi_arcache (s03_arcache),
    .m03_axi_arprot  (s03_arprot),
    .m03_axi_arqos   (s03_arqos),
    .m03_axi_arregion(s03_arregion),
    .m03_axi_aruser  (),
    .m03_axi_arvalid (s03_arvalid),
    .m03_axi_arready (s03_arready),
    .m03_axi_rid     (s03_rid),
    .m03_axi_rdata   (s03_rdata),
    .m03_axi_rresp   (s03_rresp),
    .m03_axi_rlast   (s03_rlast),
    .m03_axi_ruser   (1'b0),
    .m03_axi_rvalid  (s03_rvalid),
    .m03_axi_rready  (s03_rready),

    // ---------- Master port 04 (→ S4 GPIO) ----------
    .m04_axi_awid    (s04_awid),
    .m04_axi_awaddr  (s04_awaddr),
    .m04_axi_awlen   (s04_awlen),
    .m04_axi_awsize  (s04_awsize),
    .m04_axi_awburst (s04_awburst),
    .m04_axi_awlock  (s04_awlock),
    .m04_axi_awcache (s04_awcache),
    .m04_axi_awprot  (s04_awprot),
    .m04_axi_awqos   (s04_awqos),
    .m04_axi_awregion(s04_awregion),
    .m04_axi_awuser  (),
    .m04_axi_awvalid (s04_awvalid),
    .m04_axi_awready (s04_awready),
    .m04_axi_wdata   (s04_wdata),
    .m04_axi_wstrb   (s04_wstrb),
    .m04_axi_wlast   (s04_wlast),
    .m04_axi_wuser   (),
    .m04_axi_wvalid  (s04_wvalid),
    .m04_axi_wready  (s04_wready),
    .m04_axi_bid     (s04_bid),
    .m04_axi_bresp   (s04_bresp),
    .m04_axi_buser   (1'b0),
    .m04_axi_bvalid  (s04_bvalid),
    .m04_axi_bready  (s04_bready),
    .m04_axi_arid    (s04_arid),
    .m04_axi_araddr  (s04_araddr),
    .m04_axi_arlen   (s04_arlen),
    .m04_axi_arsize  (s04_arsize),
    .m04_axi_arburst (s04_arburst),
    .m04_axi_arlock  (s04_arlock),
    .m04_axi_arcache (s04_arcache),
    .m04_axi_arprot  (s04_arprot),
    .m04_axi_arqos   (s04_arqos),
    .m04_axi_arregion(s04_arregion),
    .m04_axi_aruser  (),
    .m04_axi_arvalid (s04_arvalid),
    .m04_axi_arready (s04_arready),
    .m04_axi_rid     (s04_rid),
    .m04_axi_rdata   (s04_rdata),
    .m04_axi_rresp   (s04_rresp),
    .m04_axi_rlast   (s04_rlast),
    .m04_axi_ruser   (1'b0),
    .m04_axi_rvalid  (s04_rvalid),
    .m04_axi_rready  (s04_rready),

    // ---------- Master port 05 (→ S5 SHA-256) ----------
    .m05_axi_awid    (s05_awid),
    .m05_axi_awaddr  (s05_awaddr),
    .m05_axi_awlen   (s05_awlen),
    .m05_axi_awsize  (s05_awsize),
    .m05_axi_awburst (s05_awburst),
    .m05_axi_awlock  (s05_awlock),
    .m05_axi_awcache (s05_awcache),
    .m05_axi_awprot  (s05_awprot),
    .m05_axi_awqos   (s05_awqos),
    .m05_axi_awregion(s05_awregion),
    .m05_axi_awuser  (),
    .m05_axi_awvalid (s05_awvalid),
    .m05_axi_awready (s05_awready),
    .m05_axi_wdata   (s05_wdata),
    .m05_axi_wstrb   (s05_wstrb),
    .m05_axi_wlast   (s05_wlast),
    .m05_axi_wuser   (),
    .m05_axi_wvalid  (s05_wvalid),
    .m05_axi_wready  (s05_wready),
    .m05_axi_bid     (s05_bid),
    .m05_axi_bresp   (s05_bresp),
    .m05_axi_buser   (1'b0),
    .m05_axi_bvalid  (s05_bvalid),
    .m05_axi_bready  (s05_bready),
    .m05_axi_arid    (s05_arid),
    .m05_axi_araddr  (s05_araddr),
    .m05_axi_arlen   (s05_arlen),
    .m05_axi_arsize  (s05_arsize),
    .m05_axi_arburst (s05_arburst),
    .m05_axi_arlock  (s05_arlock),
    .m05_axi_arcache (s05_arcache),
    .m05_axi_arprot  (s05_arprot),
    .m05_axi_arqos   (s05_arqos),
    .m05_axi_arregion(s05_arregion),
    .m05_axi_aruser  (),
    .m05_axi_arvalid (s05_arvalid),
    .m05_axi_arready (s05_arready),
    .m05_axi_rid     (s05_rid),
    .m05_axi_rdata   (s05_rdata),
    .m05_axi_rresp   (s05_rresp),
    .m05_axi_rlast   (s05_rlast),
    .m05_axi_ruser   (1'b0),
    .m05_axi_rvalid  (s05_rvalid),
    .m05_axi_rready  (s05_rready),

    // ---------- Master port 06 (→ S6 PWM) ----------
    .m06_axi_awid    (s06_awid),
    .m06_axi_awaddr  (s06_awaddr),
    .m06_axi_awlen   (s06_awlen),
    .m06_axi_awsize  (s06_awsize),
    .m06_axi_awburst (s06_awburst),
    .m06_axi_awlock  (s06_awlock),
    .m06_axi_awcache (s06_awcache),
    .m06_axi_awprot  (s06_awprot),
    .m06_axi_awqos   (s06_awqos),
    .m06_axi_awregion(s06_awregion),
    .m06_axi_awuser  (),
    .m06_axi_awvalid (s06_awvalid),
    .m06_axi_awready (s06_awready),
    .m06_axi_wdata   (s06_wdata),
    .m06_axi_wstrb   (s06_wstrb),
    .m06_axi_wlast   (s06_wlast),
    .m06_axi_wuser   (),
    .m06_axi_wvalid  (s06_wvalid),
    .m06_axi_wready  (s06_wready),
    .m06_axi_bid     (s06_bid),
    .m06_axi_bresp   (s06_bresp),
    .m06_axi_buser   (1'b0),
    .m06_axi_bvalid  (s06_bvalid),
    .m06_axi_bready  (s06_bready),
    .m06_axi_arid    (s06_arid),
    .m06_axi_araddr  (s06_araddr),
    .m06_axi_arlen   (s06_arlen),
    .m06_axi_arsize  (s06_arsize),
    .m06_axi_arburst (s06_arburst),
    .m06_axi_arlock  (s06_arlock),
    .m06_axi_arcache (s06_arcache),
    .m06_axi_arprot  (s06_arprot),
    .m06_axi_arqos   (s06_arqos),
    .m06_axi_arregion(s06_arregion),
    .m06_axi_aruser  (),
    .m06_axi_arvalid (s06_arvalid),
    .m06_axi_arready (s06_arready),
    .m06_axi_rid     (s06_rid),
    .m06_axi_rdata   (s06_rdata),
    .m06_axi_rresp   (s06_rresp),
    .m06_axi_rlast   (s06_rlast),
    .m06_axi_ruser   (1'b0),
    .m06_axi_rvalid  (s06_rvalid),
    .m06_axi_rready  (s06_rready),

    // ---------- Master port 07 (→ S7 W-WDT) ----------
    .m07_axi_awid    (s07_awid),
    .m07_axi_awaddr  (s07_awaddr),
    .m07_axi_awlen   (s07_awlen),
    .m07_axi_awsize  (s07_awsize),
    .m07_axi_awburst (s07_awburst),
    .m07_axi_awlock  (s07_awlock),
    .m07_axi_awcache (s07_awcache),
    .m07_axi_awprot  (s07_awprot),
    .m07_axi_awqos   (s07_awqos),
    .m07_axi_awregion(s07_awregion),
    .m07_axi_awuser  (),
    .m07_axi_awvalid (s07_awvalid),
    .m07_axi_awready (s07_awready),
    .m07_axi_wdata   (s07_wdata),
    .m07_axi_wstrb   (s07_wstrb),
    .m07_axi_wlast   (s07_wlast),
    .m07_axi_wuser   (),
    .m07_axi_wvalid  (s07_wvalid),
    .m07_axi_wready  (s07_wready),
    .m07_axi_bid     (s07_bid),
    .m07_axi_bresp   (s07_bresp),
    .m07_axi_buser   (1'b0),
    .m07_axi_bvalid  (s07_bvalid),
    .m07_axi_bready  (s07_bready),
    .m07_axi_arid    (s07_arid),
    .m07_axi_araddr  (s07_araddr),
    .m07_axi_arlen   (s07_arlen),
    .m07_axi_arsize  (s07_arsize),
    .m07_axi_arburst (s07_arburst),
    .m07_axi_arlock  (s07_arlock),
    .m07_axi_arcache (s07_arcache),
    .m07_axi_arprot  (s07_arprot),
    .m07_axi_arqos   (s07_arqos),
    .m07_axi_arregion(s07_arregion),
    .m07_axi_aruser  (),
    .m07_axi_arvalid (s07_arvalid),
    .m07_axi_arready (s07_arready),
    .m07_axi_rid     (s07_rid),
    .m07_axi_rdata   (s07_rdata),
    .m07_axi_rresp   (s07_rresp),
    .m07_axi_rlast   (s07_rlast),
    .m07_axi_ruser   (1'b0),
    .m07_axi_rvalid  (s07_rvalid),
    .m07_axi_rready  (s07_rready),

    // ---------- Master port 08 (→ S8 System Control) ----------
    .m08_axi_awid    (s08_awid),
    .m08_axi_awaddr  (s08_awaddr),
    .m08_axi_awlen   (s08_awlen),
    .m08_axi_awsize  (s08_awsize),
    .m08_axi_awburst (s08_awburst),
    .m08_axi_awlock  (s08_awlock),
    .m08_axi_awcache (s08_awcache),
    .m08_axi_awprot  (s08_awprot),
    .m08_axi_awqos   (s08_awqos),
    .m08_axi_awregion(s08_awregion),
    .m08_axi_awuser  (),
    .m08_axi_awvalid (s08_awvalid),
    .m08_axi_awready (s08_awready),
    .m08_axi_wdata   (s08_wdata),
    .m08_axi_wstrb   (s08_wstrb),
    .m08_axi_wlast   (s08_wlast),
    .m08_axi_wuser   (),
    .m08_axi_wvalid  (s08_wvalid),
    .m08_axi_wready  (s08_wready),
    .m08_axi_bid     (s08_bid),
    .m08_axi_bresp   (s08_bresp),
    .m08_axi_buser   (1'b0),
    .m08_axi_bvalid  (s08_bvalid),
    .m08_axi_bready  (s08_bready),
    .m08_axi_arid    (s08_arid),
    .m08_axi_araddr  (s08_araddr),
    .m08_axi_arlen   (s08_arlen),
    .m08_axi_arsize  (s08_arsize),
    .m08_axi_arburst (s08_arburst),
    .m08_axi_arlock  (s08_arlock),
    .m08_axi_arcache (s08_arcache),
    .m08_axi_arprot  (s08_arprot),
    .m08_axi_arqos   (s08_arqos),
    .m08_axi_arregion(s08_arregion),
    .m08_axi_aruser  (),
    .m08_axi_arvalid (s08_arvalid),
    .m08_axi_arready (s08_arready),
    .m08_axi_rid     (s08_rid),
    .m08_axi_rdata   (s08_rdata),
    .m08_axi_rresp   (s08_rresp),
    .m08_axi_rlast   (s08_rlast),
    .m08_axi_ruser   (1'b0),
    .m08_axi_rvalid  (s08_rvalid),
    .m08_axi_rready  (s08_rready)
);

// ---------------------------------------------------------------------------
// Master BFM instantiations
// ---------------------------------------------------------------------------
// Master 0 – CPU (RV32I core)
axi_master_bfm #(.MASTER_ID(0), .DATA_WIDTH(DATA_WIDTH),
                 .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH))
u_master0 (
    .clk      (clk),
    .rst      (rst),
    // AW
    .awid     (m0_awid),    .awaddr  (m0_awaddr),
    .awlen    (m0_awlen),   .awsize  (m0_awsize),
    .awburst  (m0_awburst), .awlock  (m0_awlock),
    .awcache  (m0_awcache), .awprot  (m0_awprot),
    .awqos    (m0_awqos),   .awvalid (m0_awvalid),
    .awready  (m0_awready),
    // W
    .wdata    (m0_wdata),   .wstrb   (m0_wstrb),
    .wlast    (m0_wlast),   .wvalid  (m0_wvalid),
    .wready   (m0_wready),
    // B
    .bid      (m0_bid),     .bresp   (m0_bresp),
    .bvalid   (m0_bvalid),  .bready  (m0_bready),
    // AR
    .arid     (m0_arid),    .araddr  (m0_araddr),
    .arlen    (m0_arlen),   .arsize  (m0_arsize),
    .arburst  (m0_arburst), .arlock  (m0_arlock),
    .arcache  (m0_arcache), .arprot  (m0_arprot),
    .arqos    (m0_arqos),   .arvalid (m0_arvalid),
    .arready  (m0_arready),
    // R
    .rid      (m0_rid),     .rdata   (m0_rdata),
    .rresp    (m0_rresp),   .rlast   (m0_rlast),
    .rvalid   (m0_rvalid),  .rready  (m0_rready)
);

// Master 1 – DMA Controller
axi_master_bfm #(.MASTER_ID(1), .DATA_WIDTH(DATA_WIDTH),
                 .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH))
u_master1 (
    .clk      (clk),
    .rst      (rst),
    .awid     (m1_awid),    .awaddr  (m1_awaddr),
    .awlen    (m1_awlen),   .awsize  (m1_awsize),
    .awburst  (m1_awburst), .awlock  (m1_awlock),
    .awcache  (m1_awcache), .awprot  (m1_awprot),
    .awqos    (m1_awqos),   .awvalid (m1_awvalid),
    .awready  (m1_awready),
    .wdata    (m1_wdata),   .wstrb   (m1_wstrb),
    .wlast    (m1_wlast),   .wvalid  (m1_wvalid),
    .wready   (m1_wready),
    .bid      (m1_bid),     .bresp   (m1_bresp),
    .bvalid   (m1_bvalid),  .bready  (m1_bready),
    .arid     (m1_arid),    .araddr  (m1_araddr),
    .arlen    (m1_arlen),   .arsize  (m1_arsize),
    .arburst  (m1_arburst), .arlock  (m1_arlock),
    .arcache  (m1_arcache), .arprot  (m1_arprot),
    .arqos    (m1_arqos),   .arvalid (m1_arvalid),
    .arready  (m1_arready),
    .rid      (m1_rid),     .rdata   (m1_rdata),
    .rresp    (m1_rresp),   .rlast   (m1_rlast),
    .rvalid   (m1_rvalid),  .rready  (m1_rready)
);

// ---------------------------------------------------------------------------
// Slave BFM instantiations  (macro to save repetition)
// ---------------------------------------------------------------------------
`define INST_SLAVE(N, NAME, BASE) \
axi_slave_bfm #(.SLAVE_ID(N), .SLAVE_NAME(NAME),          \
                .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), \
                .ID_WIDTH(ID_WIDTH), .BASE_ADDR(BASE))     \
u_slave``N (                                               \
    .clk      (clk),         .rst      (rst),              \
    .awid     (s``N``_awid),   .awaddr  (s``N``_awaddr),   \
    .awlen    (s``N``_awlen),  .awsize  (s``N``_awsize),   \
    .awburst  (s``N``_awburst),.awlock  (s``N``_awlock),   \
    .awcache  (s``N``_awcache),.awprot  (s``N``_awprot),   \
    .awqos    (s``N``_awqos),  .awregion(s``N``_awregion), \
    .awvalid  (s``N``_awvalid),.awready (s``N``_awready),  \
    .wdata    (s``N``_wdata),  .wstrb   (s``N``_wstrb),    \
    .wlast    (s``N``_wlast),  .wvalid  (s``N``_wvalid),   \
    .wready   (s``N``_wready),                              \
    .bid      (s``N``_bid),    .bresp   (s``N``_bresp),    \
    .bvalid   (s``N``_bvalid), .bready  (s``N``_bready),   \
    .arid     (s``N``_arid),   .araddr  (s``N``_araddr),   \
    .arlen    (s``N``_arlen),  .arsize  (s``N``_arsize),   \
    .arburst  (s``N``_arburst),.arlock  (s``N``_arlock),   \
    .arcache  (s``N``_arcache),.arprot  (s``N``_arprot),   \
    .arqos    (s``N``_arqos),  .arregion(s``N``_arregion), \
    .arvalid  (s``N``_arvalid),.arready (s``N``_arready),  \
    .rid      (s``N``_rid),    .rdata   (s``N``_rdata),    \
    .rresp    (s``N``_rresp),  .rlast   (s``N``_rlast),    \
    .rvalid   (s``N``_rvalid), .rready  (s``N``_rready)    \
);

`INST_SLAVE(00, "IMEM ",  S0_BASE)
`INST_SLAVE(01, "DMEM ",  S1_BASE)
`INST_SLAVE(02, "UART ",  S2_BASE)
`INST_SLAVE(03, "TIMER",  S3_BASE)
`INST_SLAVE(04, "GPIO ",  S4_BASE)
`INST_SLAVE(05, "SHA  ",  S5_BASE)
`INST_SLAVE(06, "PWM  ",  S6_BASE)
`INST_SLAVE(07, "WDT  ",  S7_BASE)
`INST_SLAVE(08, "SYSCTRL", S8_BASE)

// ---------------------------------------------------------------------------
// Stimulus – task-based AXI transactions driven from master BFMs via tasks
// ---------------------------------------------------------------------------
// Shared transaction counter for pass/fail
integer pass_cnt = 0;
integer fail_cnt = 0;

// ---- helper tasks forwarded to master BFM via force/release ----
// The master BFM exposes tasks do_write / do_read that we call directly.
// We reference the hierarchical names for the BFM tasks.
initial begin
    $fsdbDumpfile("dump.fsdb");
    $fsdbDumpvars("+all");
    $fsdbDumpSVA();
    $fsdbDumpMDA();
end
initial begin : stimulus
    // VCD dump
   

    // Wait for reset de-assertion
    @(negedge rst);
    repeat (5) @(posedge clk);

    $display("=============================================================");
    $display(" Aegis-V SoC  AXI Interconnect 2x9  Functional Testbench");
    $display(" 3 Write Transactions + 2 Read Transactions");
    $display("=============================================================");

    // ------------------------------------------------------------------
    // WRITE TRANSACTION 1 : CPU (M0) → Data Memory (S1)  @ 0x2000_0000
    //   Write data : 0xDEAD_BEEF
    // ------------------------------------------------------------------
    $display("\n[WR1] CPU (M0) → Data Memory (S1) @ 0x2000_0000  data=0xDEAD_BEEF");
    u_master0.do_write(8'h01, 32'h2000_0000, 32'hDEAD_BEEF, 4'hF);
    $display("[WR1] DONE");

    // ------------------------------------------------------------------
    // WRITE TRANSACTION 2 : CPU (M0) → UART Controller (S2) @ 0x4000_0000
    //   Write data : 0x0000_0041  ('A' to TX FIFO)
    // ------------------------------------------------------------------
    repeat (2) @(posedge clk);
    $display("\n[WR2] CPU (M0) → UART TX FIFO (S2) @ 0x4000_0000  data=0x00000041 ('A')");
    u_master0.do_write(8'h02, 32'h4000_0000, 32'h0000_0041, 4'hF);
    $display("[WR2] DONE");

    // ------------------------------------------------------------------
    // WRITE TRANSACTION 3 : DMA (M1) → Data Memory (S1)  @ 0x2000_0004
    //   Write data : 0xCAFE_BABE  (concurrent with M0 idle)
    // ------------------------------------------------------------------
    repeat (2) @(posedge clk);
    $display("\n[WR3] DMA  (M1) → Data Memory (S1) @ 0x2000_0004  data=0xCAFE_BABE");
    u_master1.do_write(8'h11, 32'h2000_0004, 32'hCAFE_BABE, 4'hF);
    $display("[WR3] DONE");

    // ------------------------------------------------------------------
    // READ TRANSACTION 1 : CPU (M0) → Data Memory (S1) @ 0x2000_0000
    //   Expected read-back : 0xDEAD_BEEF  (written in WR1)
    // ------------------------------------------------------------------
    repeat (2) @(posedge clk);
    $display("\n[RD1] CPU (M0) ← Data Memory (S1) @ 0x2000_0000  expect=0xDEAD_BEEF");
    u_master0.do_read(8'h03, 32'h2000_0000);

    // ------------------------------------------------------------------
    // READ TRANSACTION 2 : DMA (M1) → Instruction Memory (S0) @ 0x0000_0000
    //   Expected read-back : 0xAAAA_AAAA  (slave reset data pattern)
    // ------------------------------------------------------------------
    repeat (2) @(posedge clk);
    $display("\n[RD2] DMA  (M1) ← Instruction Memory (S0) @ 0x0000_0000  expect=0xAAAA_AAAA");
    u_master1.do_read(8'h12, 32'h0000_0000);

    // ------------------------------------------------------------------
    // Wait for all in-flight completions
    // ------------------------------------------------------------------
    repeat (20) @(posedge clk);

    // ------------------------------------------------------------------
    // Summary
    // ------------------------------------------------------------------
    $display("\n=============================================================");
    $display(" SIMULATION COMPLETE");
    $display(" PASS: %0d   FAIL: %0d", u_master0.pass_cnt + u_master1.pass_cnt,
                                       u_master0.fail_cnt + u_master1.fail_cnt);
    $display("=============================================================\n");

    if ((u_master0.fail_cnt + u_master1.fail_cnt) == 0)
        $display("** ALL TRANSACTIONS PASSED **");
    else
        $display("** SOME TRANSACTIONS FAILED – review log above **");

    $finish;
end

// ---------------------------------------------------------------------------
// Watchdog – abort if simulation hangs
// ---------------------------------------------------------------------------
initial begin
    #100000;
    $display("ERROR: Simulation watchdog timeout!");
    $finish;
end

endmodule

`default_nettype wire
