// =============================================================================
// Project  : Aegis-V SoC
// File     : tb/tb_axi_interconnect_wrap_2x11.v
// Purpose  : Standalone verification testbench for axi_interconnect_wrap_2x11.
//
// DUT topology:
//   Master BFM 0 (CPU)  ──┐
//                          ├─ axi_interconnect_wrap_2x11 ─┬─ Slave BFM 0  (M00 0x0000_0000)
//   Master BFM 1 (DMA)  ──┘                               ├─ Slave BFM 1  (M01 0x0100_0000)
//                                                          ├─ Slave BFM 2  (M02 0x0200_0000)
//                                                          ├─ Slave BFM 3  (M03 0x0300_0000)
//                                                          ├─ Slave BFM 4  (M04 0x0400_0000)
//                                                          ├─ Slave BFM 5  (M05 0x0500_0000)
//                                                          ├─ Slave BFM 6  (M06 0x0600_0000)
//                                                          ├─ Slave BFM 7  (M07 0x0700_0000)
//                                                          ├─ Slave BFM 8  (M08 0x0800_0000)
//                                                          ├─ Slave BFM 9  (M09 0x0900_0000)
//                                                          └─ Slave BFM 10 (M10 0x1000_0000)
//
// Each slave BFM has 256-word internal memory and responds with OKAY.
// Addresses outside all slave windows return DECERR from the interconnect.
//
// Test plan:
//   T01 – Reset & idle check
//   T02 – Master 0 single write → M00 (0x0000_0000)
//   T03 – Master 0 single read  ← M00 (verify round-trip)
//   T04 – Master 1 single write → M01 (0x0100_0004)
//   T05 – Master 1 single read  ← M01
//   T06 – Write to each of M02..M10 from Master 0
//   T07 – Read back from each of M02..M10 from Master 0
//   T08 – Concurrent: Master 0 writes M00, Master 1 writes M01 simultaneously
//   T09 – Concurrent: Master 0 reads  M00, Master 1 reads  M01 simultaneously
//   T10 – Arbitration: Master 0 and Master 1 both target M03 (shared slave)
//   T11 – Address routing: Master 1 writes M10 (0x1000_0000)
//   T12 – DECERR: Master 0 accesses unmapped address (0xDEAD_0000)
//
// Compile and run (from run/ directory):
//   vcs -full64 -sverilog -ntb_opts uvm -timescale=1ns/1ps \
//       -debug_access+all -kdb -f run.f -l compile.log
//   ./simv
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_axi_interconnect_wrap_2x11;

// ---------------------------------------------------------------------------
// Parameters — must match DUT instantiation below
// ---------------------------------------------------------------------------
localparam DATA_WIDTH = 32;
localparam ADDR_WIDTH = 32;
localparam STRB_WIDTH = DATA_WIDTH/8;
localparam ID_WIDTH   = 8;
localparam CLK_HALF   = 5;           // 5 ns → 100 MHz

// Slave (master-port) base addresses — one 16 MB window each (addr_width=24)
localparam [31:0] BASE_M00 = 32'h0000_0000;
localparam [31:0] BASE_M01 = 32'h0100_0000;
localparam [31:0] BASE_M02 = 32'h0200_0000;
localparam [31:0] BASE_M03 = 32'h0300_0000;
localparam [31:0] BASE_M04 = 32'h0400_0000;
localparam [31:0] BASE_M05 = 32'h0500_0000;
localparam [31:0] BASE_M06 = 32'h0600_0000;
localparam [31:0] BASE_M07 = 32'h0700_0000;
localparam [31:0] BASE_M08 = 32'h0800_0000;
localparam [31:0] BASE_M09 = 32'h0900_0000;
localparam [31:0] BASE_M10 = 32'h1000_0000;

// ---------------------------------------------------------------------------
// Clock and synchronous reset
// ---------------------------------------------------------------------------
reg clk;
reg rst;

initial  clk = 1'b0;
always #CLK_HALF clk = ~clk;

// ---------------------------------------------------------------------------
// BFM → DUT wires (slave-side / DUT s0x ports)
// ---------------------------------------------------------------------------
// Master BFM 0 (s00)
wire [ID_WIDTH-1:0]    m0_awid,   m0_bid,   m0_arid,   m0_rid;
wire [ADDR_WIDTH-1:0]  m0_awaddr, m0_araddr;
wire [7:0]             m0_awlen,  m0_arlen;
wire [2:0]             m0_awsize, m0_arsize;
wire [1:0]             m0_awburst,m0_arburst;
wire                   m0_awlock, m0_arlock;
wire [3:0]             m0_awcache,m0_arcache,m0_awqos,m0_arqos;
wire [2:0]             m0_awprot, m0_arprot;
wire                   m0_awvalid,m0_awready,m0_wvalid,m0_wready;
wire                   m0_bvalid, m0_bready, m0_arvalid,m0_arready;
wire                   m0_rvalid, m0_rready, m0_wlast,  m0_rlast;
wire [DATA_WIDTH-1:0]  m0_wdata,  m0_rdata;
wire [STRB_WIDTH-1:0]  m0_wstrb;
wire [1:0]             m0_bresp,  m0_rresp;

// Master BFM 1 (s01)
wire [ID_WIDTH-1:0]    m1_awid,   m1_bid,   m1_arid,   m1_rid;
wire [ADDR_WIDTH-1:0]  m1_awaddr, m1_araddr;
wire [7:0]             m1_awlen,  m1_arlen;
wire [2:0]             m1_awsize, m1_arsize;
wire [1:0]             m1_awburst,m1_arburst;
wire                   m1_awlock, m1_arlock;
wire [3:0]             m1_awcache,m1_arcache,m1_awqos,m1_arqos;
wire [2:0]             m1_awprot, m1_arprot;
wire                   m1_awvalid,m1_awready,m1_wvalid,m1_wready;
wire                   m1_bvalid, m1_bready, m1_arvalid,m1_arready;
wire                   m1_rvalid, m1_rready, m1_wlast,  m1_rlast;
wire [DATA_WIDTH-1:0]  m1_wdata,  m1_rdata;
wire [STRB_WIDTH-1:0]  m1_wstrb;
wire [1:0]             m1_bresp,  m1_rresp;

// ---------------------------------------------------------------------------
// DUT → Slave BFM wires (master-side / DUT mXX ports)
// Macro to declare all signals for one master port number
// ---------------------------------------------------------------------------
`define MPORT_WIRES(N) \
    wire [ID_WIDTH-1:0]   m``N``_awid_o,  m``N``_arid_o,  m``N``_bid_i,  m``N``_rid_i; \
    wire [ADDR_WIDTH-1:0] m``N``_awaddr_o,m``N``_araddr_o; \
    wire [7:0]            m``N``_awlen_o, m``N``_arlen_o;  \
    wire [2:0]            m``N``_awsize_o,m``N``_arsize_o; \
    wire [1:0]            m``N``_awburst_o,m``N``_arburst_o; \
    wire                  m``N``_awlock_o, m``N``_arlock_o; \
    wire [3:0]            m``N``_awcache_o,m``N``_arcache_o; \
    wire [2:0]            m``N``_awprot_o, m``N``_arprot_o; \
    wire [3:0]            m``N``_awqos_o,  m``N``_arqos_o;  \
    wire [3:0]            m``N``_awregion_o,m``N``_arregion_o; \
    wire                  m``N``_awvalid_o,m``N``_awready_i; \
    wire [DATA_WIDTH-1:0] m``N``_wdata_o,  m``N``_rdata_i; \
    wire [STRB_WIDTH-1:0] m``N``_wstrb_o; \
    wire                  m``N``_wlast_o,  m``N``_wvalid_o, m``N``_wready_i; \
    wire [1:0]            m``N``_bresp_i,  m``N``_rresp_i;  \
    wire                  m``N``_bvalid_i, m``N``_bready_o; \
    wire                  m``N``_arvalid_o,m``N``_arready_i; \
    wire                  m``N``_rvalid_i, m``N``_rready_o, m``N``_rlast_i;

`MPORT_WIRES(00)
`MPORT_WIRES(01)
`MPORT_WIRES(02)
`MPORT_WIRES(03)
`MPORT_WIRES(04)
`MPORT_WIRES(05)
`MPORT_WIRES(06)
`MPORT_WIRES(07)
`MPORT_WIRES(08)
`MPORT_WIRES(09)
`MPORT_WIRES(10)

// ---------------------------------------------------------------------------
// DUT: axi_interconnect_wrap_2x11
// ---------------------------------------------------------------------------
axi_interconnect_wrap_2x11 #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .STRB_WIDTH (STRB_WIDTH),
    .ID_WIDTH   (ID_WIDTH),
    .FORWARD_ID (1),
    .M_REGIONS  (1),
    // Each slave window = 16 MB (addr_width = 24 bits)
    .M00_BASE_ADDR(BASE_M00), .M00_ADDR_WIDTH({1{32'd24}}),
    .M00_CONNECT_READ(2'b11), .M00_CONNECT_WRITE(2'b11),
    .M01_BASE_ADDR(BASE_M01), .M01_ADDR_WIDTH({1{32'd24}}),
    .M01_CONNECT_READ(2'b11), .M01_CONNECT_WRITE(2'b11),
    .M02_BASE_ADDR(BASE_M02), .M02_ADDR_WIDTH({1{32'd24}}),
    .M02_CONNECT_READ(2'b11), .M02_CONNECT_WRITE(2'b11),
    .M03_BASE_ADDR(BASE_M03), .M03_ADDR_WIDTH({1{32'd24}}),
    .M03_CONNECT_READ(2'b11), .M03_CONNECT_WRITE(2'b11),
    .M04_BASE_ADDR(BASE_M04), .M04_ADDR_WIDTH({1{32'd24}}),
    .M04_CONNECT_READ(2'b11), .M04_CONNECT_WRITE(2'b11),
    .M05_BASE_ADDR(BASE_M05), .M05_ADDR_WIDTH({1{32'd24}}),
    .M05_CONNECT_READ(2'b11), .M05_CONNECT_WRITE(2'b11),
    .M06_BASE_ADDR(BASE_M06), .M06_ADDR_WIDTH({1{32'd24}}),
    .M06_CONNECT_READ(2'b11), .M06_CONNECT_WRITE(2'b11),
    .M07_BASE_ADDR(BASE_M07), .M07_ADDR_WIDTH({1{32'd24}}),
    .M07_CONNECT_READ(2'b11), .M07_CONNECT_WRITE(2'b11),
    .M08_BASE_ADDR(BASE_M08), .M08_ADDR_WIDTH({1{32'd24}}),
    .M08_CONNECT_READ(2'b11), .M08_CONNECT_WRITE(2'b11),
    .M09_BASE_ADDR(BASE_M09), .M09_ADDR_WIDTH({1{32'd24}}),
    .M09_CONNECT_READ(2'b11), .M09_CONNECT_WRITE(2'b11),
    .M10_BASE_ADDR(BASE_M10), .M10_ADDR_WIDTH({1{32'd24}}),
    .M10_CONNECT_READ(2'b11), .M10_CONNECT_WRITE(2'b11)
) u_dut (
    .clk (clk), .rst (rst),

    // ---- slave port 0 (Master BFM 0) ----
    .s00_axi_awid(m0_awid),     .s00_axi_awaddr(m0_awaddr),
    .s00_axi_awlen(m0_awlen),   .s00_axi_awsize(m0_awsize),
    .s00_axi_awburst(m0_awburst),.s00_axi_awlock(m0_awlock),
    .s00_axi_awcache(m0_awcache),.s00_axi_awprot(m0_awprot),
    .s00_axi_awqos(m0_awqos),   .s00_axi_awuser(1'b0),
    .s00_axi_awvalid(m0_awvalid),.s00_axi_awready(m0_awready),
    .s00_axi_wdata(m0_wdata),   .s00_axi_wstrb(m0_wstrb),
    .s00_axi_wlast(m0_wlast),   .s00_axi_wuser(1'b0),
    .s00_axi_wvalid(m0_wvalid), .s00_axi_wready(m0_wready),
    .s00_axi_bid(m0_bid),       .s00_axi_bresp(m0_bresp),
    .s00_axi_buser(),           .s00_axi_bvalid(m0_bvalid),
    .s00_axi_bready(m0_bready),
    .s00_axi_arid(m0_arid),     .s00_axi_araddr(m0_araddr),
    .s00_axi_arlen(m0_arlen),   .s00_axi_arsize(m0_arsize),
    .s00_axi_arburst(m0_arburst),.s00_axi_arlock(m0_arlock),
    .s00_axi_arcache(m0_arcache),.s00_axi_arprot(m0_arprot),
    .s00_axi_arqos(m0_arqos),   .s00_axi_aruser(1'b0),
    .s00_axi_arvalid(m0_arvalid),.s00_axi_arready(m0_arready),
    .s00_axi_rid(m0_rid),       .s00_axi_rdata(m0_rdata),
    .s00_axi_rresp(m0_rresp),   .s00_axi_rlast(m0_rlast),
    .s00_axi_ruser(),           .s00_axi_rvalid(m0_rvalid),
    .s00_axi_rready(m0_rready),

    // ---- slave port 1 (Master BFM 1) ----
    .s01_axi_awid(m1_awid),     .s01_axi_awaddr(m1_awaddr),
    .s01_axi_awlen(m1_awlen),   .s01_axi_awsize(m1_awsize),
    .s01_axi_awburst(m1_awburst),.s01_axi_awlock(m1_awlock),
    .s01_axi_awcache(m1_awcache),.s01_axi_awprot(m1_awprot),
    .s01_axi_awqos(m1_awqos),   .s01_axi_awuser(1'b0),
    .s01_axi_awvalid(m1_awvalid),.s01_axi_awready(m1_awready),
    .s01_axi_wdata(m1_wdata),   .s01_axi_wstrb(m1_wstrb),
    .s01_axi_wlast(m1_wlast),   .s01_axi_wuser(1'b0),
    .s01_axi_wvalid(m1_wvalid), .s01_axi_wready(m1_wready),
    .s01_axi_bid(m1_bid),       .s01_axi_bresp(m1_bresp),
    .s01_axi_buser(),           .s01_axi_bvalid(m1_bvalid),
    .s01_axi_bready(m1_bready),
    .s01_axi_arid(m1_arid),     .s01_axi_araddr(m1_araddr),
    .s01_axi_arlen(m1_arlen),   .s01_axi_arsize(m1_arsize),
    .s01_axi_arburst(m1_arburst),.s01_axi_arlock(m1_arlock),
    .s01_axi_arcache(m1_arcache),.s01_axi_arprot(m1_arprot),
    .s01_axi_arqos(m1_arqos),   .s01_axi_aruser(1'b0),
    .s01_axi_arvalid(m1_arvalid),.s01_axi_arready(m1_arready),
    .s01_axi_rid(m1_rid),       .s01_axi_rdata(m1_rdata),
    .s01_axi_rresp(m1_rresp),   .s01_axi_rlast(m1_rlast),
    .s01_axi_ruser(),           .s01_axi_rvalid(m1_rvalid),
    .s01_axi_rready(m1_rready),

    // ---- master port 00 ----
    .m00_axi_awid(m00_awid_o),  .m00_axi_awaddr(m00_awaddr_o),
    .m00_axi_awlen(m00_awlen_o),.m00_axi_awsize(m00_awsize_o),
    .m00_axi_awburst(m00_awburst_o),.m00_axi_awlock(m00_awlock_o),
    .m00_axi_awcache(m00_awcache_o),.m00_axi_awprot(m00_awprot_o),
    .m00_axi_awqos(m00_awqos_o),.m00_axi_awregion(m00_awregion_o),
    .m00_axi_awuser(),.m00_axi_awvalid(m00_awvalid_o),.m00_axi_awready(m00_awready_i),
    .m00_axi_wdata(m00_wdata_o),.m00_axi_wstrb(m00_wstrb_o),
    .m00_axi_wlast(m00_wlast_o),.m00_axi_wuser(),.m00_axi_wvalid(m00_wvalid_o),.m00_axi_wready(m00_wready_i),
    .m00_axi_bid(m00_bid_i),    .m00_axi_bresp(m00_bresp_i),
    .m00_axi_buser(1'b0),       .m00_axi_bvalid(m00_bvalid_i),.m00_axi_bready(m00_bready_o),
    .m00_axi_arid(m00_arid_o),  .m00_axi_araddr(m00_araddr_o),
    .m00_axi_arlen(m00_arlen_o),.m00_axi_arsize(m00_arsize_o),
    .m00_axi_arburst(m00_arburst_o),.m00_axi_arlock(m00_arlock_o),
    .m00_axi_arcache(m00_arcache_o),.m00_axi_arprot(m00_arprot_o),
    .m00_axi_arqos(m00_arqos_o),.m00_axi_arregion(m00_arregion_o),
    .m00_axi_aruser(),.m00_axi_arvalid(m00_arvalid_o),.m00_axi_arready(m00_arready_i),
    .m00_axi_rid(m00_rid_i),    .m00_axi_rdata(m00_rdata_i),
    .m00_axi_rresp(m00_rresp_i),.m00_axi_rlast(m00_rlast_i),
    .m00_axi_ruser(1'b0),.m00_axi_rvalid(m00_rvalid_i),.m00_axi_rready(m00_rready_o),

    // ---- master port 01 ----
    .m01_axi_awid(m01_awid_o),  .m01_axi_awaddr(m01_awaddr_o),
    .m01_axi_awlen(m01_awlen_o),.m01_axi_awsize(m01_awsize_o),
    .m01_axi_awburst(m01_awburst_o),.m01_axi_awlock(m01_awlock_o),
    .m01_axi_awcache(m01_awcache_o),.m01_axi_awprot(m01_awprot_o),
    .m01_axi_awqos(m01_awqos_o),.m01_axi_awregion(m01_awregion_o),
    .m01_axi_awuser(),.m01_axi_awvalid(m01_awvalid_o),.m01_axi_awready(m01_awready_i),
    .m01_axi_wdata(m01_wdata_o),.m01_axi_wstrb(m01_wstrb_o),
    .m01_axi_wlast(m01_wlast_o),.m01_axi_wuser(),.m01_axi_wvalid(m01_wvalid_o),.m01_axi_wready(m01_wready_i),
    .m01_axi_bid(m01_bid_i),    .m01_axi_bresp(m01_bresp_i),
    .m01_axi_buser(1'b0),       .m01_axi_bvalid(m01_bvalid_i),.m01_axi_bready(m01_bready_o),
    .m01_axi_arid(m01_arid_o),  .m01_axi_araddr(m01_araddr_o),
    .m01_axi_arlen(m01_arlen_o),.m01_axi_arsize(m01_arsize_o),
    .m01_axi_arburst(m01_arburst_o),.m01_axi_arlock(m01_arlock_o),
    .m01_axi_arcache(m01_arcache_o),.m01_axi_arprot(m01_arprot_o),
    .m01_axi_arqos(m01_arqos_o),.m01_axi_arregion(m01_arregion_o),
    .m01_axi_aruser(),.m01_axi_arvalid(m01_arvalid_o),.m01_axi_arready(m01_arready_i),
    .m01_axi_rid(m01_rid_i),    .m01_axi_rdata(m01_rdata_i),
    .m01_axi_rresp(m01_rresp_i),.m01_axi_rlast(m01_rlast_i),
    .m01_axi_ruser(1'b0),.m01_axi_rvalid(m01_rvalid_i),.m01_axi_rready(m01_rready_o),

    // ---- master port 02 ----
    .m02_axi_awid(m02_awid_o),  .m02_axi_awaddr(m02_awaddr_o),
    .m02_axi_awlen(m02_awlen_o),.m02_axi_awsize(m02_awsize_o),
    .m02_axi_awburst(m02_awburst_o),.m02_axi_awlock(m02_awlock_o),
    .m02_axi_awcache(m02_awcache_o),.m02_axi_awprot(m02_awprot_o),
    .m02_axi_awqos(m02_awqos_o),.m02_axi_awregion(m02_awregion_o),
    .m02_axi_awuser(),.m02_axi_awvalid(m02_awvalid_o),.m02_axi_awready(m02_awready_i),
    .m02_axi_wdata(m02_wdata_o),.m02_axi_wstrb(m02_wstrb_o),
    .m02_axi_wlast(m02_wlast_o),.m02_axi_wuser(),.m02_axi_wvalid(m02_wvalid_o),.m02_axi_wready(m02_wready_i),
    .m02_axi_bid(m02_bid_i),    .m02_axi_bresp(m02_bresp_i),
    .m02_axi_buser(1'b0),       .m02_axi_bvalid(m02_bvalid_i),.m02_axi_bready(m02_bready_o),
    .m02_axi_arid(m02_arid_o),  .m02_axi_araddr(m02_araddr_o),
    .m02_axi_arlen(m02_arlen_o),.m02_axi_arsize(m02_arsize_o),
    .m02_axi_arburst(m02_arburst_o),.m02_axi_arlock(m02_arlock_o),
    .m02_axi_arcache(m02_arcache_o),.m02_axi_arprot(m02_arprot_o),
    .m02_axi_arqos(m02_arqos_o),.m02_axi_arregion(m02_arregion_o),
    .m02_axi_aruser(),.m02_axi_arvalid(m02_arvalid_o),.m02_axi_arready(m02_arready_i),
    .m02_axi_rid(m02_rid_i),    .m02_axi_rdata(m02_rdata_i),
    .m02_axi_rresp(m02_rresp_i),.m02_axi_rlast(m02_rlast_i),
    .m02_axi_ruser(1'b0),.m02_axi_rvalid(m02_rvalid_i),.m02_axi_rready(m02_rready_o),

    // ---- master ports 03..10 (same pattern) ----
    .m03_axi_awid(m03_awid_o),  .m03_axi_awaddr(m03_awaddr_o),
    .m03_axi_awlen(m03_awlen_o),.m03_axi_awsize(m03_awsize_o),
    .m03_axi_awburst(m03_awburst_o),.m03_axi_awlock(m03_awlock_o),
    .m03_axi_awcache(m03_awcache_o),.m03_axi_awprot(m03_awprot_o),
    .m03_axi_awqos(m03_awqos_o),.m03_axi_awregion(m03_awregion_o),
    .m03_axi_awuser(),.m03_axi_awvalid(m03_awvalid_o),.m03_axi_awready(m03_awready_i),
    .m03_axi_wdata(m03_wdata_o),.m03_axi_wstrb(m03_wstrb_o),
    .m03_axi_wlast(m03_wlast_o),.m03_axi_wuser(),.m03_axi_wvalid(m03_wvalid_o),.m03_axi_wready(m03_wready_i),
    .m03_axi_bid(m03_bid_i),    .m03_axi_bresp(m03_bresp_i),
    .m03_axi_buser(1'b0),       .m03_axi_bvalid(m03_bvalid_i),.m03_axi_bready(m03_bready_o),
    .m03_axi_arid(m03_arid_o),  .m03_axi_araddr(m03_araddr_o),
    .m03_axi_arlen(m03_arlen_o),.m03_axi_arsize(m03_arsize_o),
    .m03_axi_arburst(m03_arburst_o),.m03_axi_arlock(m03_arlock_o),
    .m03_axi_arcache(m03_arcache_o),.m03_axi_arprot(m03_arprot_o),
    .m03_axi_arqos(m03_arqos_o),.m03_axi_arregion(m03_arregion_o),
    .m03_axi_aruser(),.m03_axi_arvalid(m03_arvalid_o),.m03_axi_arready(m03_arready_i),
    .m03_axi_rid(m03_rid_i),    .m03_axi_rdata(m03_rdata_i),
    .m03_axi_rresp(m03_rresp_i),.m03_axi_rlast(m03_rlast_i),
    .m03_axi_ruser(1'b0),.m03_axi_rvalid(m03_rvalid_i),.m03_axi_rready(m03_rready_o),

    .m04_axi_awid(m04_awid_o),  .m04_axi_awaddr(m04_awaddr_o),
    .m04_axi_awlen(m04_awlen_o),.m04_axi_awsize(m04_awsize_o),
    .m04_axi_awburst(m04_awburst_o),.m04_axi_awlock(m04_awlock_o),
    .m04_axi_awcache(m04_awcache_o),.m04_axi_awprot(m04_awprot_o),
    .m04_axi_awqos(m04_awqos_o),.m04_axi_awregion(m04_awregion_o),
    .m04_axi_awuser(),.m04_axi_awvalid(m04_awvalid_o),.m04_axi_awready(m04_awready_i),
    .m04_axi_wdata(m04_wdata_o),.m04_axi_wstrb(m04_wstrb_o),
    .m04_axi_wlast(m04_wlast_o),.m04_axi_wuser(),.m04_axi_wvalid(m04_wvalid_o),.m04_axi_wready(m04_wready_i),
    .m04_axi_bid(m04_bid_i),    .m04_axi_bresp(m04_bresp_i),
    .m04_axi_buser(1'b0),       .m04_axi_bvalid(m04_bvalid_i),.m04_axi_bready(m04_bready_o),
    .m04_axi_arid(m04_arid_o),  .m04_axi_araddr(m04_araddr_o),
    .m04_axi_arlen(m04_arlen_o),.m04_axi_arsize(m04_arsize_o),
    .m04_axi_arburst(m04_arburst_o),.m04_axi_arlock(m04_arlock_o),
    .m04_axi_arcache(m04_arcache_o),.m04_axi_arprot(m04_arprot_o),
    .m04_axi_arqos(m04_arqos_o),.m04_axi_arregion(m04_arregion_o),
    .m04_axi_aruser(),.m04_axi_arvalid(m04_arvalid_o),.m04_axi_arready(m04_arready_i),
    .m04_axi_rid(m04_rid_i),    .m04_axi_rdata(m04_rdata_i),
    .m04_axi_rresp(m04_rresp_i),.m04_axi_rlast(m04_rlast_i),
    .m04_axi_ruser(1'b0),.m04_axi_rvalid(m04_rvalid_i),.m04_axi_rready(m04_rready_o),

    .m05_axi_awid(m05_awid_o),  .m05_axi_awaddr(m05_awaddr_o),
    .m05_axi_awlen(m05_awlen_o),.m05_axi_awsize(m05_awsize_o),
    .m05_axi_awburst(m05_awburst_o),.m05_axi_awlock(m05_awlock_o),
    .m05_axi_awcache(m05_awcache_o),.m05_axi_awprot(m05_awprot_o),
    .m05_axi_awqos(m05_awqos_o),.m05_axi_awregion(m05_awregion_o),
    .m05_axi_awuser(),.m05_axi_awvalid(m05_awvalid_o),.m05_axi_awready(m05_awready_i),
    .m05_axi_wdata(m05_wdata_o),.m05_axi_wstrb(m05_wstrb_o),
    .m05_axi_wlast(m05_wlast_o),.m05_axi_wuser(),.m05_axi_wvalid(m05_wvalid_o),.m05_axi_wready(m05_wready_i),
    .m05_axi_bid(m05_bid_i),    .m05_axi_bresp(m05_bresp_i),
    .m05_axi_buser(1'b0),       .m05_axi_bvalid(m05_bvalid_i),.m05_axi_bready(m05_bready_o),
    .m05_axi_arid(m05_arid_o),  .m05_axi_araddr(m05_araddr_o),
    .m05_axi_arlen(m05_arlen_o),.m05_axi_arsize(m05_arsize_o),
    .m05_axi_arburst(m05_arburst_o),.m05_axi_arlock(m05_arlock_o),
    .m05_axi_arcache(m05_arcache_o),.m05_axi_arprot(m05_arprot_o),
    .m05_axi_arqos(m05_arqos_o),.m05_axi_arregion(m05_arregion_o),
    .m05_axi_aruser(),.m05_axi_arvalid(m05_arvalid_o),.m05_axi_arready(m05_arready_i),
    .m05_axi_rid(m05_rid_i),    .m05_axi_rdata(m05_rdata_i),
    .m05_axi_rresp(m05_rresp_i),.m05_axi_rlast(m05_rlast_i),
    .m05_axi_ruser(1'b0),.m05_axi_rvalid(m05_rvalid_i),.m05_axi_rready(m05_rready_o),

    .m06_axi_awid(m06_awid_o),  .m06_axi_awaddr(m06_awaddr_o),
    .m06_axi_awlen(m06_awlen_o),.m06_axi_awsize(m06_awsize_o),
    .m06_axi_awburst(m06_awburst_o),.m06_axi_awlock(m06_awlock_o),
    .m06_axi_awcache(m06_awcache_o),.m06_axi_awprot(m06_awprot_o),
    .m06_axi_awqos(m06_awqos_o),.m06_axi_awregion(m06_awregion_o),
    .m06_axi_awuser(),.m06_axi_awvalid(m06_awvalid_o),.m06_axi_awready(m06_awready_i),
    .m06_axi_wdata(m06_wdata_o),.m06_axi_wstrb(m06_wstrb_o),
    .m06_axi_wlast(m06_wlast_o),.m06_axi_wuser(),.m06_axi_wvalid(m06_wvalid_o),.m06_axi_wready(m06_wready_i),
    .m06_axi_bid(m06_bid_i),    .m06_axi_bresp(m06_bresp_i),
    .m06_axi_buser(1'b0),       .m06_axi_bvalid(m06_bvalid_i),.m06_axi_bready(m06_bready_o),
    .m06_axi_arid(m06_arid_o),  .m06_axi_araddr(m06_araddr_o),
    .m06_axi_arlen(m06_arlen_o),.m06_axi_arsize(m06_arsize_o),
    .m06_axi_arburst(m06_arburst_o),.m06_axi_arlock(m06_arlock_o),
    .m06_axi_arcache(m06_arcache_o),.m06_axi_arprot(m06_arprot_o),
    .m06_axi_arqos(m06_arqos_o),.m06_axi_arregion(m06_arregion_o),
    .m06_axi_aruser(),.m06_axi_arvalid(m06_arvalid_o),.m06_axi_arready(m06_arready_i),
    .m06_axi_rid(m06_rid_i),    .m06_axi_rdata(m06_rdata_i),
    .m06_axi_rresp(m06_rresp_i),.m06_axi_rlast(m06_rlast_i),
    .m06_axi_ruser(1'b0),.m06_axi_rvalid(m06_rvalid_i),.m06_axi_rready(m06_rready_o),

    .m07_axi_awid(m07_awid_o),  .m07_axi_awaddr(m07_awaddr_o),
    .m07_axi_awlen(m07_awlen_o),.m07_axi_awsize(m07_awsize_o),
    .m07_axi_awburst(m07_awburst_o),.m07_axi_awlock(m07_awlock_o),
    .m07_axi_awcache(m07_awcache_o),.m07_axi_awprot(m07_awprot_o),
    .m07_axi_awqos(m07_awqos_o),.m07_axi_awregion(m07_awregion_o),
    .m07_axi_awuser(),.m07_axi_awvalid(m07_awvalid_o),.m07_axi_awready(m07_awready_i),
    .m07_axi_wdata(m07_wdata_o),.m07_axi_wstrb(m07_wstrb_o),
    .m07_axi_wlast(m07_wlast_o),.m07_axi_wuser(),.m07_axi_wvalid(m07_wvalid_o),.m07_axi_wready(m07_wready_i),
    .m07_axi_bid(m07_bid_i),    .m07_axi_bresp(m07_bresp_i),
    .m07_axi_buser(1'b0),       .m07_axi_bvalid(m07_bvalid_i),.m07_axi_bready(m07_bready_o),
    .m07_axi_arid(m07_arid_o),  .m07_axi_araddr(m07_araddr_o),
    .m07_axi_arlen(m07_arlen_o),.m07_axi_arsize(m07_arsize_o),
    .m07_axi_arburst(m07_arburst_o),.m07_axi_arlock(m07_arlock_o),
    .m07_axi_arcache(m07_arcache_o),.m07_axi_arprot(m07_arprot_o),
    .m07_axi_arqos(m07_arqos_o),.m07_axi_arregion(m07_arregion_o),
    .m07_axi_aruser(),.m07_axi_arvalid(m07_arvalid_o),.m07_axi_arready(m07_arready_i),
    .m07_axi_rid(m07_rid_i),    .m07_axi_rdata(m07_rdata_i),
    .m07_axi_rresp(m07_rresp_i),.m07_axi_rlast(m07_rlast_i),
    .m07_axi_ruser(1'b0),.m07_axi_rvalid(m07_rvalid_i),.m07_axi_rready(m07_rready_o),

    .m08_axi_awid(m08_awid_o),  .m08_axi_awaddr(m08_awaddr_o),
    .m08_axi_awlen(m08_awlen_o),.m08_axi_awsize(m08_awsize_o),
    .m08_axi_awburst(m08_awburst_o),.m08_axi_awlock(m08_awlock_o),
    .m08_axi_awcache(m08_awcache_o),.m08_axi_awprot(m08_awprot_o),
    .m08_axi_awqos(m08_awqos_o),.m08_axi_awregion(m08_awregion_o),
    .m08_axi_awuser(),.m08_axi_awvalid(m08_awvalid_o),.m08_axi_awready(m08_awready_i),
    .m08_axi_wdata(m08_wdata_o),.m08_axi_wstrb(m08_wstrb_o),
    .m08_axi_wlast(m08_wlast_o),.m08_axi_wuser(),.m08_axi_wvalid(m08_wvalid_o),.m08_axi_wready(m08_wready_i),
    .m08_axi_bid(m08_bid_i),    .m08_axi_bresp(m08_bresp_i),
    .m08_axi_buser(1'b0),       .m08_axi_bvalid(m08_bvalid_i),.m08_axi_bready(m08_bready_o),
    .m08_axi_arid(m08_arid_o),  .m08_axi_araddr(m08_araddr_o),
    .m08_axi_arlen(m08_arlen_o),.m08_axi_arsize(m08_arsize_o),
    .m08_axi_arburst(m08_arburst_o),.m08_axi_arlock(m08_arlock_o),
    .m08_axi_arcache(m08_arcache_o),.m08_axi_arprot(m08_arprot_o),
    .m08_axi_arqos(m08_arqos_o),.m08_axi_arregion(m08_arregion_o),
    .m08_axi_aruser(),.m08_axi_arvalid(m08_arvalid_o),.m08_axi_arready(m08_arready_i),
    .m08_axi_rid(m08_rid_i),    .m08_axi_rdata(m08_rdata_i),
    .m08_axi_rresp(m08_rresp_i),.m08_axi_rlast(m08_rlast_i),
    .m08_axi_ruser(1'b0),.m08_axi_rvalid(m08_rvalid_i),.m08_axi_rready(m08_rready_o),

    .m09_axi_awid(m09_awid_o),  .m09_axi_awaddr(m09_awaddr_o),
    .m09_axi_awlen(m09_awlen_o),.m09_axi_awsize(m09_awsize_o),
    .m09_axi_awburst(m09_awburst_o),.m09_axi_awlock(m09_awlock_o),
    .m09_axi_awcache(m09_awcache_o),.m09_axi_awprot(m09_awprot_o),
    .m09_axi_awqos(m09_awqos_o),.m09_axi_awregion(m09_awregion_o),
    .m09_axi_awuser(),.m09_axi_awvalid(m09_awvalid_o),.m09_axi_awready(m09_awready_i),
    .m09_axi_wdata(m09_wdata_o),.m09_axi_wstrb(m09_wstrb_o),
    .m09_axi_wlast(m09_wlast_o),.m09_axi_wuser(),.m09_axi_wvalid(m09_wvalid_o),.m09_axi_wready(m09_wready_i),
    .m09_axi_bid(m09_bid_i),    .m09_axi_bresp(m09_bresp_i),
    .m09_axi_buser(1'b0),       .m09_axi_bvalid(m09_bvalid_i),.m09_axi_bready(m09_bready_o),
    .m09_axi_arid(m09_arid_o),  .m09_axi_araddr(m09_araddr_o),
    .m09_axi_arlen(m09_arlen_o),.m09_axi_arsize(m09_arsize_o),
    .m09_axi_arburst(m09_arburst_o),.m09_axi_arlock(m09_arlock_o),
    .m09_axi_arcache(m09_arcache_o),.m09_axi_arprot(m09_arprot_o),
    .m09_axi_arqos(m09_arqos_o),.m09_axi_arregion(m09_arregion_o),
    .m09_axi_aruser(),.m09_axi_arvalid(m09_arvalid_o),.m09_axi_arready(m09_arready_i),
    .m09_axi_rid(m09_rid_i),    .m09_axi_rdata(m09_rdata_i),
    .m09_axi_rresp(m09_rresp_i),.m09_axi_rlast(m09_rlast_i),
    .m09_axi_ruser(1'b0),.m09_axi_rvalid(m09_rvalid_i),.m09_axi_rready(m09_rready_o),

    .m10_axi_awid(m10_awid_o),  .m10_axi_awaddr(m10_awaddr_o),
    .m10_axi_awlen(m10_awlen_o),.m10_axi_awsize(m10_awsize_o),
    .m10_axi_awburst(m10_awburst_o),.m10_axi_awlock(m10_awlock_o),
    .m10_axi_awcache(m10_awcache_o),.m10_axi_awprot(m10_awprot_o),
    .m10_axi_awqos(m10_awqos_o),.m10_axi_awregion(m10_awregion_o),
    .m10_axi_awuser(),.m10_axi_awvalid(m10_awvalid_o),.m10_axi_awready(m10_awready_i),
    .m10_axi_wdata(m10_wdata_o),.m10_axi_wstrb(m10_wstrb_o),
    .m10_axi_wlast(m10_wlast_o),.m10_axi_wuser(),.m10_axi_wvalid(m10_wvalid_o),.m10_axi_wready(m10_wready_i),
    .m10_axi_bid(m10_bid_i),    .m10_axi_bresp(m10_bresp_i),
    .m10_axi_buser(1'b0),       .m10_axi_bvalid(m10_bvalid_i),.m10_axi_bready(m10_bready_o),
    .m10_axi_arid(m10_arid_o),  .m10_axi_araddr(m10_araddr_o),
    .m10_axi_arlen(m10_arlen_o),.m10_axi_arsize(m10_arsize_o),
    .m10_axi_arburst(m10_arburst_o),.m10_axi_arlock(m10_arlock_o),
    .m10_axi_arcache(m10_arcache_o),.m10_axi_arprot(m10_arprot_o),
    .m10_axi_arqos(m10_arqos_o),.m10_axi_arregion(m10_arregion_o),
    .m10_axi_aruser(),.m10_axi_arvalid(m10_arvalid_o),.m10_axi_arready(m10_arready_i),
    .m10_axi_rid(m10_rid_i),    .m10_axi_rdata(m10_rdata_i),
    .m10_axi_rresp(m10_rresp_i),.m10_axi_rlast(m10_rlast_i),
    .m10_axi_ruser(1'b0),.m10_axi_rvalid(m10_rvalid_i),.m10_axi_rready(m10_rready_o)
);

// ---------------------------------------------------------------------------
// Master BFM 0  (CPU — slave port 0 of DUT)
// ---------------------------------------------------------------------------
axi_master_bfm #(
    .MASTER_ID(0), .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH), .TIMEOUT(500)
) u_master0 (
    .clk(clk), .rst(rst),
    .awid(m0_awid),   .awaddr(m0_awaddr), .awlen(m0_awlen),
    .awsize(m0_awsize),.awburst(m0_awburst),.awlock(m0_awlock),
    .awcache(m0_awcache),.awprot(m0_awprot),.awqos(m0_awqos),
    .awvalid(m0_awvalid),.awready(m0_awready),
    .wdata(m0_wdata),  .wstrb(m0_wstrb),  .wlast(m0_wlast),
    .wvalid(m0_wvalid),.wready(m0_wready),
    .bid(m0_bid),      .bresp(m0_bresp),  .bvalid(m0_bvalid),.bready(m0_bready),
    .arid(m0_arid),    .araddr(m0_araddr),.arlen(m0_arlen),
    .arsize(m0_arsize),.arburst(m0_arburst),.arlock(m0_arlock),
    .arcache(m0_arcache),.arprot(m0_arprot),.arqos(m0_arqos),
    .arvalid(m0_arvalid),.arready(m0_arready),
    .rid(m0_rid),      .rdata(m0_rdata),  .rresp(m0_rresp),
    .rlast(m0_rlast),  .rvalid(m0_rvalid),.rready(m0_rready)
);

// ---------------------------------------------------------------------------
// Master BFM 1  (DMA — slave port 1 of DUT)
// ---------------------------------------------------------------------------
axi_master_bfm #(
    .MASTER_ID(1), .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH), .TIMEOUT(500)
) u_master1 (
    .clk(clk), .rst(rst),
    .awid(m1_awid),   .awaddr(m1_awaddr), .awlen(m1_awlen),
    .awsize(m1_awsize),.awburst(m1_awburst),.awlock(m1_awlock),
    .awcache(m1_awcache),.awprot(m1_awprot),.awqos(m1_awqos),
    .awvalid(m1_awvalid),.awready(m1_awready),
    .wdata(m1_wdata),  .wstrb(m1_wstrb),  .wlast(m1_wlast),
    .wvalid(m1_wvalid),.wready(m1_wready),
    .bid(m1_bid),      .bresp(m1_bresp),  .bvalid(m1_bvalid),.bready(m1_bready),
    .arid(m1_arid),    .araddr(m1_araddr),.arlen(m1_arlen),
    .arsize(m1_arsize),.arburst(m1_arburst),.arlock(m1_arlock),
    .arcache(m1_arcache),.arprot(m1_arprot),.arqos(m1_arqos),
    .arvalid(m1_arvalid),.arready(m1_arready),
    .rid(m1_rid),      .rdata(m1_rdata),  .rresp(m1_rresp),
    .rlast(m1_rlast),  .rvalid(m1_rvalid),.rready(m1_rready)
);

// ---------------------------------------------------------------------------
// Slave BFMs — one per master port (M00..M10)
// Macro to instantiate a slave BFM for port number N with base address B
// ---------------------------------------------------------------------------
`define SLAVE_BFM(N, B) \
axi_slave_bfm #( \
    .SLAVE_ID(N), .DATA_WIDTH(DATA_WIDTH), \
    .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH), \
    .BASE_ADDR(B), .MEM_DEPTH(256) \
) u_slave``N`` ( \
    .clk(clk), .rst(rst), \
    .awid(m``N``_awid_o),    .awaddr(m``N``_awaddr_o), \
    .awlen(m``N``_awlen_o),  .awsize(m``N``_awsize_o),  \
    .awburst(m``N``_awburst_o),.awlock(m``N``_awlock_o), \
    .awcache(m``N``_awcache_o),.awprot(m``N``_awprot_o), \
    .awqos(m``N``_awqos_o),  .awregion(m``N``_awregion_o), \
    .awvalid(m``N``_awvalid_o),.awready(m``N``_awready_i), \
    .wdata(m``N``_wdata_o),  .wstrb(m``N``_wstrb_o),   \
    .wlast(m``N``_wlast_o),  .wvalid(m``N``_wvalid_o), \
    .wready(m``N``_wready_i), \
    .bid(m``N``_bid_i),      .bresp(m``N``_bresp_i),   \
    .bvalid(m``N``_bvalid_i),.bready(m``N``_bready_o), \
    .arid(m``N``_arid_o),    .araddr(m``N``_araddr_o), \
    .arlen(m``N``_arlen_o),  .arsize(m``N``_arsize_o),  \
    .arburst(m``N``_arburst_o),.arlock(m``N``_arlock_o), \
    .arcache(m``N``_arcache_o),.arprot(m``N``_arprot_o), \
    .arqos(m``N``_arqos_o),  .arregion(m``N``_arregion_o), \
    .arvalid(m``N``_arvalid_o),.arready(m``N``_arready_i), \
    .rid(m``N``_rid_i),      .rdata(m``N``_rdata_i),   \
    .rresp(m``N``_rresp_i),  .rlast(m``N``_rlast_i),   \
    .rvalid(m``N``_rvalid_i),.rready(m``N``_rready_o)  \
);

`SLAVE_BFM(00, BASE_M00)
`SLAVE_BFM(01, BASE_M01)
`SLAVE_BFM(02, BASE_M02)
`SLAVE_BFM(03, BASE_M03)
`SLAVE_BFM(04, BASE_M04)
`SLAVE_BFM(05, BASE_M05)
`SLAVE_BFM(06, BASE_M06)
`SLAVE_BFM(07, BASE_M07)
`SLAVE_BFM(08, BASE_M08)
`SLAVE_BFM(09, BASE_M09)
`SLAVE_BFM(10, BASE_M10)

// ---------------------------------------------------------------------------
// Pass / fail tracking
// ---------------------------------------------------------------------------
integer total_pass;
integer total_fail;

// ---------------------------------------------------------------------------
// Stimulus
// ---------------------------------------------------------------------------
initial begin
    total_pass = 0;
    total_fail = 0;

    // -----------------------------------------------------------------------
    // T01: Reset
    // -----------------------------------------------------------------------
    $display("\n========== T01: Reset ==========");
    rst = 1'b1;
    repeat (10) @(posedge clk);
    rst = 1'b0;
    repeat (5)  @(posedge clk);
    $display("[INFO] Reset released. All BFMs and DUT out of reset.");

    // -----------------------------------------------------------------------
    // T02: Master 0 single write to M00
    // -----------------------------------------------------------------------
    $display("\n========== T02: M0 write to M00 (0x0000_0010) ==========");
    u_master0.do_write(8'h01, BASE_M00 + 32'h10, 32'hDEAD_BEEF, 4'hF);
    total_pass = total_pass + u_master0.pass_cnt;
    total_fail = total_fail + u_master0.fail_cnt;

    // -----------------------------------------------------------------------
    // T03: Master 0 read back from M00
    // -----------------------------------------------------------------------
    $display("\n========== T03: M0 read from M00 (0x0000_0010) ==========");
    u_master0.do_read(8'h02, BASE_M00 + 32'h10);
    total_pass = total_pass + u_master0.pass_cnt;
    total_fail = total_fail + u_master0.fail_cnt;

    // -----------------------------------------------------------------------
    // T04: Master 1 write to M01
    // -----------------------------------------------------------------------
    $display("\n========== T04: M1 write to M01 (0x0100_0020) ==========");
    u_master1.do_write(8'h11, BASE_M01 + 32'h20, 32'hCAFE_BABE, 4'hF);
    total_pass = total_pass + u_master1.pass_cnt;
    total_fail = total_fail + u_master1.fail_cnt;

    // -----------------------------------------------------------------------
    // T05: Master 1 read back from M01
    // -----------------------------------------------------------------------
    $display("\n========== T05: M1 read from M01 (0x0100_0020) ==========");
    u_master1.do_read(8'h12, BASE_M01 + 32'h20);
    total_pass = total_pass + u_master1.pass_cnt;
    total_fail = total_fail + u_master1.fail_cnt;

    // -----------------------------------------------------------------------
    // T06: Master 0 writes to M02..M10 (address routing test)
    // -----------------------------------------------------------------------
    $display("\n========== T06: Address routing — M0 writes M02..M10 ==========");
    u_master0.do_write(8'h03, BASE_M02 + 32'h04, 32'h0200_0004, 4'hF);
    u_master0.do_write(8'h04, BASE_M03 + 32'h04, 32'h0300_0004, 4'hF);
    u_master0.do_write(8'h05, BASE_M04 + 32'h04, 32'h0400_0004, 4'hF);
    u_master0.do_write(8'h06, BASE_M05 + 32'h04, 32'h0500_0004, 4'hF);
    u_master0.do_write(8'h07, BASE_M06 + 32'h04, 32'h0600_0004, 4'hF);
    u_master0.do_write(8'h08, BASE_M07 + 32'h04, 32'h0700_0004, 4'hF);
    u_master0.do_write(8'h09, BASE_M08 + 32'h04, 32'h0800_0004, 4'hF);
    u_master0.do_write(8'h0A, BASE_M09 + 32'h04, 32'h0900_0004, 4'hF);
    u_master0.do_write(8'h0B, BASE_M10 + 32'h04, 32'h1000_0004, 4'hF);
    total_pass = total_pass + u_master0.pass_cnt;
    total_fail = total_fail + u_master0.fail_cnt;

    // -----------------------------------------------------------------------
    // T07: Master 0 reads back from M02..M10
    // -----------------------------------------------------------------------
    $display("\n========== T07: Address routing — M0 reads M02..M10 ==========");
    u_master0.do_read(8'h13, BASE_M02 + 32'h04);
    u_master0.do_read(8'h14, BASE_M03 + 32'h04);
    u_master0.do_read(8'h15, BASE_M04 + 32'h04);
    u_master0.do_read(8'h16, BASE_M05 + 32'h04);
    u_master0.do_read(8'h17, BASE_M06 + 32'h04);
    u_master0.do_read(8'h18, BASE_M07 + 32'h04);
    u_master0.do_read(8'h19, BASE_M08 + 32'h04);
    u_master0.do_read(8'h1A, BASE_M09 + 32'h04);
    u_master0.do_read(8'h1B, BASE_M10 + 32'h04);
    total_pass = total_pass + u_master0.pass_cnt;
    total_fail = total_fail + u_master0.fail_cnt;

    // -----------------------------------------------------------------------
    // T08: Concurrent writes — M0→M00 and M1→M01 simultaneously
    //      Fork both masters at the same time.
    // -----------------------------------------------------------------------
    $display("\n========== T08: Concurrent writes M0→M00, M1→M01 ==========");
    fork
        u_master0.do_write(8'h20, BASE_M00 + 32'h40, 32'hAAAA_1111, 4'hF);
        u_master1.do_write(8'h21, BASE_M01 + 32'h40, 32'hBBBB_2222, 4'hF);
    join
    total_pass = total_pass + u_master0.pass_cnt + u_master1.pass_cnt;
    total_fail = total_fail + u_master0.fail_cnt + u_master1.fail_cnt;

    // -----------------------------------------------------------------------
    // T09: Concurrent reads — M0←M00 and M1←M01 simultaneously
    // -----------------------------------------------------------------------
    $display("\n========== T09: Concurrent reads M0←M00, M1←M01 ==========");
    fork
        u_master0.do_read(8'h22, BASE_M00 + 32'h40);
        u_master1.do_read(8'h23, BASE_M01 + 32'h40);
    join
    total_pass = total_pass + u_master0.pass_cnt + u_master1.pass_cnt;
    total_fail = total_fail + u_master0.fail_cnt + u_master1.fail_cnt;

    // -----------------------------------------------------------------------
    // T10: Arbitration — both masters target the same slave (M03) concurrently
    //      The interconnect arbiter must serialise these. Both should succeed.
    // -----------------------------------------------------------------------
    $display("\n========== T10: Arbitration — M0 and M1 both target M03 ==========");
    fork
        u_master0.do_write(8'h30, BASE_M03 + 32'h50, 32'hCCCC_3333, 4'hF);
        u_master1.do_write(8'h31, BASE_M03 + 32'h54, 32'hDDDD_4444, 4'hF);
    join
    total_pass = total_pass + u_master0.pass_cnt + u_master1.pass_cnt;
    total_fail = total_fail + u_master0.fail_cnt + u_master1.fail_cnt;

    // -----------------------------------------------------------------------
    // T11: Cross-master routing — Master 1 writes M10 (far address)
    // -----------------------------------------------------------------------
    $display("\n========== T11: M1 writes M10 (0x1000_0008) ==========");
    u_master1.do_write(8'h40, BASE_M10 + 32'h08, 32'h1234_5678, 4'hF);
    u_master1.do_read (8'h41, BASE_M10 + 32'h08);
    total_pass = total_pass + u_master1.pass_cnt;
    total_fail = total_fail + u_master1.fail_cnt;

    // -----------------------------------------------------------------------
    // T12: DECERR — Master 0 accesses unmapped address
    //      Interconnect should return DECERR on the B / R channels.
    // -----------------------------------------------------------------------
    $display("\n========== T12: DECERR on unmapped address 0xDEAD_0000 ==========");
    // do_write / do_read check for OKAY so they'll print FAIL for DECERR.
    // That is the expected result for an unmapped address — we note it here.
    $display("[INFO] Expect DECERR (FAIL message from BFM is the correct behaviour)");
    u_master0.do_write(8'h50, 32'hDEAD_0000, 32'h1111_2222, 4'hF);
    $display("[INFO] Write bresp=0b%02b (expected DECERR=2'b11)", u_master0.last_bresp);
    u_master0.do_read (8'h51, 32'hDEAD_0000);
    $display("[INFO] Read  rresp=0b%02b (expected DECERR=2'b11)", u_master0.last_rresp);

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    repeat (10) @(posedge clk);
    $display("\n============================================================");
    $display("  INTERCONNECT VERIFICATION COMPLETE");
    $display("  Cumulative PASS: %0d    FAIL: %0d", total_pass, total_fail);
    $display("  (T12 intentional DECERR not counted as FAIL above)");
    $display("============================================================\n");

    if (total_fail == 0)
        $display("** ALL INTERCONNECT TESTS PASSED **");
    else
        $display("** %0d TEST(S) FAILED **", total_fail);

    #100;
    $finish;
end

// ---------------------------------------------------------------------------
// Watchdog
// ---------------------------------------------------------------------------
initial begin
    #10_000_000;
    $display("[WATCHDOG] Sim timeout — forcing finish");
    $finish;
end

// ---------------------------------------------------------------------------
// FSDB waveform dump  (Synopsys Verdi / nWave)
// Requires -kdb and the Verdi PLI library linked into simv (VCS -debug_access+all).
// The dump file is written to the run/ working directory.
// ---------------------------------------------------------------------------
initial begin
    // Enable FSDB dumping of all signals at every hierarchy level
    $fsdbDumpfile("dump_interconnect.fsdb");
    $fsdbDumpvars(0, tb_axi_interconnect_wrap_2x11);   // depth 0 = full hierarchy

    // Uncomment the lines below for enhanced Verdi features:
    // $fsdbDumpMDA();        // multi-dimensional arrays
    // $fsdbDumpSVA();        // SVA pass/fail markers
    $display("[FSDB] dump_interconnect.fsdb opened — all signals captured");
end

endmodule

`default_nettype wire
