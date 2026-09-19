// =============================================================================
// Project      : Aegis-V SoC
// File         : axi_uart_subsystem.v
// Description  : Top-level integration of:
//                  - axi_interconnect_wrap_2x11  (2 AXI4 slaves, 11 AXI4 masters)
//                  - axi4_to_axilite_bridge      (one per UART, on master port m10)
//                  - axi_uart_top                (AXI4-Lite UART slave)
//
//                Address map (representative defaults — override via parameters):
//                  M00  0x0000_0000  RAM/ROM   (16 MB)
//                  M01  0x0100_0000  ...
//                  ...
//                  M10  0x1000_0000  UART      (4 KB window — min legal for interconnect)
//
//                The two SoC masters connect to s00 (CPU hart 0) and s01
//                (CPU hart 1 / DMA).
//
// Parameters
//   DATA_WIDTH         : AXI data width (must be 32 to match UART)
//   ADDR_WIDTH         : AXI address width
//   ID_WIDTH           : AXI ID width (must be 12 to match UART)
//   UART_BASE_ADDR     : Base address of UART in the 32-bit map
//   UART_ADDR_WIN_BITS : log2 of UART address window (12 → 4 KB; min legal value)
// =============================================================================

`resetall
`timescale 1ns / 1ps
`default_nettype none

module axi_uart_subsystem #(
    parameter DATA_WIDTH         = 32,
    parameter ADDR_WIDTH         = 32,
    parameter STRB_WIDTH         = (DATA_WIDTH/8),
    parameter ID_WIDTH           = 12,   // must match UART AXI_ID_WIDTH

    // UART parameters
    parameter UART_BASE_ADDR     = 32'h1000_0000,
    // Minimum address-width the interconnect accepts is 12 (4 KB).
    // The UART only uses 5 address bits internally but the interconnect
    // parameter M_ADDR_WIDTH must satisfy 12 <= width <= ADDR_WIDTH.
    // A 4 KB window (2^12 = 0x1000) is safe — it does not overlap any
    // other window (M09 ends at 0x0A00_0000, UART window ends at
    // 0x1000_1000 — no overlap).
    parameter UART_ADDR_WIN_BITS = 12,   // 2^12 = 4 KB window (min legal value)

    // Interconnect address map — M00..M09 are available for other peripherals
    parameter M00_BASE_ADDR  = 32'h0000_0000,
    parameter M00_ADDR_WIDTH = {1{32'd24}},
    parameter M01_BASE_ADDR  = 32'h0100_0000,
    parameter M01_ADDR_WIDTH = {1{32'd24}},
    parameter M02_BASE_ADDR  = 32'h0200_0000,
    parameter M02_ADDR_WIDTH = {1{32'd24}},
    parameter M03_BASE_ADDR  = 32'h0300_0000,
    parameter M03_ADDR_WIDTH = {1{32'd24}},
    parameter M04_BASE_ADDR  = 32'h0400_0000,
    parameter M04_ADDR_WIDTH = {1{32'd24}},
    parameter M05_BASE_ADDR  = 32'h0500_0000,
    parameter M05_ADDR_WIDTH = {1{32'd24}},
    parameter M06_BASE_ADDR  = 32'h0600_0000,
    parameter M06_ADDR_WIDTH = {1{32'd24}},
    parameter M07_BASE_ADDR  = 32'h0700_0000,
    parameter M07_ADDR_WIDTH = {1{32'd24}},
    parameter M08_BASE_ADDR  = 32'h0800_0000,
    parameter M08_ADDR_WIDTH = {1{32'd24}},
    parameter M09_BASE_ADDR  = 32'h0900_0000,
    parameter M09_ADDR_WIDTH = {1{32'd24}}
)(
    input  wire                  clk,
    input  wire                  rst_n,   // active-low async reset (UART convention)

    // ------------------------------------------------------------------
    // AXI4 Slave Port 0  (CPU hart-0 / primary master)
    // ------------------------------------------------------------------
    input  wire [ID_WIDTH-1:0]   s00_axi_awid,
    input  wire [ADDR_WIDTH-1:0] s00_axi_awaddr,
    input  wire [7:0]            s00_axi_awlen,
    input  wire [2:0]            s00_axi_awsize,
    input  wire [1:0]            s00_axi_awburst,
    input  wire                  s00_axi_awlock,
    input  wire [3:0]            s00_axi_awcache,
    input  wire [2:0]            s00_axi_awprot,
    input  wire [3:0]            s00_axi_awqos,
    input  wire                  s00_axi_awvalid,
    output wire                  s00_axi_awready,
    input  wire [DATA_WIDTH-1:0] s00_axi_wdata,
    input  wire [STRB_WIDTH-1:0] s00_axi_wstrb,
    input  wire                  s00_axi_wlast,
    input  wire                  s00_axi_wvalid,
    output wire                  s00_axi_wready,
    output wire [ID_WIDTH-1:0]   s00_axi_bid,
    output wire [1:0]            s00_axi_bresp,
    output wire                  s00_axi_bvalid,
    input  wire                  s00_axi_bready,
    input  wire [ID_WIDTH-1:0]   s00_axi_arid,
    input  wire [ADDR_WIDTH-1:0] s00_axi_araddr,
    input  wire [7:0]            s00_axi_arlen,
    input  wire [2:0]            s00_axi_arsize,
    input  wire [1:0]            s00_axi_arburst,
    input  wire                  s00_axi_arlock,
    input  wire [3:0]            s00_axi_arcache,
    input  wire [2:0]            s00_axi_arprot,
    input  wire [3:0]            s00_axi_arqos,
    input  wire                  s00_axi_arvalid,
    output wire                  s00_axi_arready,
    output wire [ID_WIDTH-1:0]   s00_axi_rid,
    output wire [DATA_WIDTH-1:0] s00_axi_rdata,
    output wire [1:0]            s00_axi_rresp,
    output wire                  s00_axi_rlast,
    output wire                  s00_axi_rvalid,
    input  wire                  s00_axi_rready,

    // ------------------------------------------------------------------
    // AXI4 Slave Port 1  (CPU hart-1 / DMA)
    // ------------------------------------------------------------------
    input  wire [ID_WIDTH-1:0]   s01_axi_awid,
    input  wire [ADDR_WIDTH-1:0] s01_axi_awaddr,
    input  wire [7:0]            s01_axi_awlen,
    input  wire [2:0]            s01_axi_awsize,
    input  wire [1:0]            s01_axi_awburst,
    input  wire                  s01_axi_awlock,
    input  wire [3:0]            s01_axi_awcache,
    input  wire [2:0]            s01_axi_awprot,
    input  wire [3:0]            s01_axi_awqos,
    input  wire                  s01_axi_awvalid,
    output wire                  s01_axi_awready,
    input  wire [DATA_WIDTH-1:0] s01_axi_wdata,
    input  wire [STRB_WIDTH-1:0] s01_axi_wstrb,
    input  wire                  s01_axi_wlast,
    input  wire                  s01_axi_wvalid,
    output wire                  s01_axi_wready,
    output wire [ID_WIDTH-1:0]   s01_axi_bid,
    output wire [1:0]            s01_axi_bresp,
    output wire                  s01_axi_bvalid,
    input  wire                  s01_axi_bready,
    input  wire [ID_WIDTH-1:0]   s01_axi_arid,
    input  wire [ADDR_WIDTH-1:0] s01_axi_araddr,
    input  wire [7:0]            s01_axi_arlen,
    input  wire [2:0]            s01_axi_arsize,
    input  wire [1:0]            s01_axi_arburst,
    input  wire                  s01_axi_arlock,
    input  wire [3:0]            s01_axi_arcache,
    input  wire [2:0]            s01_axi_arprot,
    input  wire [3:0]            s01_axi_arqos,
    input  wire                  s01_axi_arvalid,
    output wire                  s01_axi_arready,
    output wire [ID_WIDTH-1:0]   s01_axi_rid,
    output wire [DATA_WIDTH-1:0] s01_axi_rdata,
    output wire [1:0]            s01_axi_rresp,
    output wire                  s01_axi_rlast,
    output wire                  s01_axi_rvalid,
    input  wire                  s01_axi_rready,

    // ------------------------------------------------------------------
    // AXI4 Master Ports M00..M09 (exposed for other peripherals)
    // ------------------------------------------------------------------
    // M00
    output wire [ID_WIDTH-1:0]   m00_axi_awid,
    output wire [ADDR_WIDTH-1:0] m00_axi_awaddr,
    output wire [7:0]            m00_axi_awlen,
    output wire [2:0]            m00_axi_awsize,
    output wire [1:0]            m00_axi_awburst,
    output wire                  m00_axi_awlock,
    output wire [3:0]            m00_axi_awcache,
    output wire [2:0]            m00_axi_awprot,
    output wire [3:0]            m00_axi_awqos,
    output wire [3:0]            m00_axi_awregion,
    output wire                  m00_axi_awvalid,
    input  wire                  m00_axi_awready,
    output wire [DATA_WIDTH-1:0] m00_axi_wdata,
    output wire [STRB_WIDTH-1:0] m00_axi_wstrb,
    output wire                  m00_axi_wlast,
    output wire                  m00_axi_wvalid,
    input  wire                  m00_axi_wready,
    input  wire [ID_WIDTH-1:0]   m00_axi_bid,
    input  wire [1:0]            m00_axi_bresp,
    input  wire                  m00_axi_bvalid,
    output wire                  m00_axi_bready,
    output wire [ID_WIDTH-1:0]   m00_axi_arid,
    output wire [ADDR_WIDTH-1:0] m00_axi_araddr,
    output wire [7:0]            m00_axi_arlen,
    output wire [2:0]            m00_axi_arsize,
    output wire [1:0]            m00_axi_arburst,
    output wire                  m00_axi_arlock,
    output wire [3:0]            m00_axi_arcache,
    output wire [2:0]            m00_axi_arprot,
    output wire [3:0]            m00_axi_arqos,
    output wire [3:0]            m00_axi_arregion,
    output wire                  m00_axi_arvalid,
    input  wire                  m00_axi_arready,
    input  wire [ID_WIDTH-1:0]   m00_axi_rid,
    input  wire [DATA_WIDTH-1:0] m00_axi_rdata,
    input  wire [1:0]            m00_axi_rresp,
    input  wire                  m00_axi_rlast,
    input  wire                  m00_axi_rvalid,
    output wire                  m00_axi_rready,

    // M01
    output wire [ID_WIDTH-1:0]   m01_axi_awid,
    output wire [ADDR_WIDTH-1:0] m01_axi_awaddr,
    output wire [7:0]            m01_axi_awlen,
    output wire [2:0]            m01_axi_awsize,
    output wire [1:0]            m01_axi_awburst,
    output wire                  m01_axi_awlock,
    output wire [3:0]            m01_axi_awcache,
    output wire [2:0]            m01_axi_awprot,
    output wire [3:0]            m01_axi_awqos,
    output wire [3:0]            m01_axi_awregion,
    output wire                  m01_axi_awvalid,
    input  wire                  m01_axi_awready,
    output wire [DATA_WIDTH-1:0] m01_axi_wdata,
    output wire [STRB_WIDTH-1:0] m01_axi_wstrb,
    output wire                  m01_axi_wlast,
    output wire                  m01_axi_wvalid,
    input  wire                  m01_axi_wready,
    input  wire [ID_WIDTH-1:0]   m01_axi_bid,
    input  wire [1:0]            m01_axi_bresp,
    input  wire                  m01_axi_bvalid,
    output wire                  m01_axi_bready,
    output wire [ID_WIDTH-1:0]   m01_axi_arid,
    output wire [ADDR_WIDTH-1:0] m01_axi_araddr,
    output wire [7:0]            m01_axi_arlen,
    output wire [2:0]            m01_axi_arsize,
    output wire [1:0]            m01_axi_arburst,
    output wire                  m01_axi_arlock,
    output wire [3:0]            m01_axi_arcache,
    output wire [2:0]            m01_axi_arprot,
    output wire [3:0]            m01_axi_arqos,
    output wire [3:0]            m01_axi_arregion,
    output wire                  m01_axi_arvalid,
    input  wire                  m01_axi_arready,
    input  wire [ID_WIDTH-1:0]   m01_axi_rid,
    input  wire [DATA_WIDTH-1:0] m01_axi_rdata,
    input  wire [1:0]            m01_axi_rresp,
    input  wire                  m01_axi_rlast,
    input  wire                  m01_axi_rvalid,
    output wire                  m01_axi_rready,

    // (M02..M09 follow the same pattern — tied off here for brevity;
    //  connect to actual peripherals in SoC top level)

    // ------------------------------------------------------------------
    // UART external signals
    // ------------------------------------------------------------------
    input  wire                  uart_rx_i,
    output wire                  uart_tx_o,
    output wire                  uart_irq_o    // read-data-ready interrupt
);

// =============================================================================
// Internal wires — interconnect master port 10 to bridge
// =============================================================================
wire [ID_WIDTH-1:0]   ic_m10_awid;
wire [ADDR_WIDTH-1:0] ic_m10_awaddr;
wire [7:0]            ic_m10_awlen;
wire [2:0]            ic_m10_awsize;
wire [1:0]            ic_m10_awburst;
wire                  ic_m10_awlock;
wire [3:0]            ic_m10_awcache;
wire [2:0]            ic_m10_awprot;
wire [3:0]            ic_m10_awqos;
wire [3:0]            ic_m10_awregion;
wire                  ic_m10_awvalid;
wire                  ic_m10_awready;
wire [DATA_WIDTH-1:0] ic_m10_wdata;
wire [STRB_WIDTH-1:0] ic_m10_wstrb;
wire                  ic_m10_wlast;
wire                  ic_m10_wvalid;
wire                  ic_m10_wready;
wire [ID_WIDTH-1:0]   ic_m10_bid;
wire [1:0]            ic_m10_bresp;
wire                  ic_m10_bvalid;
wire                  ic_m10_bready;
wire [ID_WIDTH-1:0]   ic_m10_arid;
wire [ADDR_WIDTH-1:0] ic_m10_araddr;
wire [7:0]            ic_m10_arlen;
wire [2:0]            ic_m10_arsize;
wire [1:0]            ic_m10_arburst;
wire                  ic_m10_arlock;
wire [3:0]            ic_m10_arcache;
wire [2:0]            ic_m10_arprot;
wire [3:0]            ic_m10_arqos;
wire [3:0]            ic_m10_arregion;
wire                  ic_m10_arvalid;
wire                  ic_m10_arready;
wire [ID_WIDTH-1:0]   ic_m10_rid;
wire [DATA_WIDTH-1:0] ic_m10_rdata;
wire [1:0]            ic_m10_rresp;
wire                  ic_m10_rlast;
wire                  ic_m10_rvalid;
wire                  ic_m10_rready;

// Bridge → UART wires (AXI4-Lite, 5-bit address)
wire [ID_WIDTH-1:0]  uart_awid;
wire [4:0]           uart_awaddr;
wire                 uart_awvalid;
wire                 uart_awready;
wire [DATA_WIDTH-1:0] uart_wdata;
wire [STRB_WIDTH-1:0] uart_wstrb;
wire                 uart_wvalid;
wire                 uart_wready;
wire [ID_WIDTH-1:0]  uart_bid;
wire [1:0]           uart_bresp;
wire                 uart_bvalid;
wire                 uart_bready;
wire [ID_WIDTH-1:0]  uart_arid;
wire [4:0]           uart_araddr;
wire                 uart_arvalid;
wire                 uart_arready;
wire [ID_WIDTH-1:0]  uart_rid;
wire [DATA_WIDTH-1:0] uart_rdata;
wire [1:0]           uart_rresp;
wire                 uart_rvalid;
wire                 uart_rready;

// Synchronous reset for bridge (UART uses async active-low)
wire rst_sync = ~rst_n;

// Unused master ports (M02-M09) — tie off with no-response stubs
// In a full SoC these would connect to real peripherals.
// For now just wire the unused interconnect signals to known-safe values.
wire [ID_WIDTH-1:0]   stub_bid   = {ID_WIDTH{1'b0}};
wire [1:0]            stub_bresp = 2'b00;
wire                  stub_bvalid = 1'b0;
wire [ID_WIDTH-1:0]   stub_rid   = {ID_WIDTH{1'b0}};
wire [DATA_WIDTH-1:0] stub_rdata = {DATA_WIDTH{1'b0}};
wire [1:0]            stub_rresp = 2'b00;
wire                  stub_rlast = 1'b0;
wire                  stub_rvalid = 1'b0;

// =============================================================================
// AXI Interconnect 2x11
// =============================================================================
axi_interconnect_wrap_2x11 #(
    .DATA_WIDTH   (DATA_WIDTH),
    .ADDR_WIDTH   (ADDR_WIDTH),
    .STRB_WIDTH   (STRB_WIDTH),
    .ID_WIDTH     (ID_WIDTH),
    .FORWARD_ID   (1),           // forward ID to master side
    .M_REGIONS    (1),

    // M00-M09 address windows
    .M00_BASE_ADDR  (M00_BASE_ADDR),   .M00_ADDR_WIDTH (M00_ADDR_WIDTH),
    .M00_CONNECT_READ (2'b11),         .M00_CONNECT_WRITE (2'b11),
    .M01_BASE_ADDR  (M01_BASE_ADDR),   .M01_ADDR_WIDTH (M01_ADDR_WIDTH),
    .M01_CONNECT_READ (2'b11),         .M01_CONNECT_WRITE (2'b11),
    .M02_BASE_ADDR  (M02_BASE_ADDR),   .M02_ADDR_WIDTH (M02_ADDR_WIDTH),
    .M02_CONNECT_READ (2'b11),         .M02_CONNECT_WRITE (2'b11),
    .M03_BASE_ADDR  (M03_BASE_ADDR),   .M03_ADDR_WIDTH (M03_ADDR_WIDTH),
    .M03_CONNECT_READ (2'b11),         .M03_CONNECT_WRITE (2'b11),
    .M04_BASE_ADDR  (M04_BASE_ADDR),   .M04_ADDR_WIDTH (M04_ADDR_WIDTH),
    .M04_CONNECT_READ (2'b11),         .M04_CONNECT_WRITE (2'b11),
    .M05_BASE_ADDR  (M05_BASE_ADDR),   .M05_ADDR_WIDTH (M05_ADDR_WIDTH),
    .M05_CONNECT_READ (2'b11),         .M05_CONNECT_WRITE (2'b11),
    .M06_BASE_ADDR  (M06_BASE_ADDR),   .M06_ADDR_WIDTH (M06_ADDR_WIDTH),
    .M06_CONNECT_READ (2'b11),         .M06_CONNECT_WRITE (2'b11),
    .M07_BASE_ADDR  (M07_BASE_ADDR),   .M07_ADDR_WIDTH (M07_ADDR_WIDTH),
    .M07_CONNECT_READ (2'b11),         .M07_CONNECT_WRITE (2'b11),
    .M08_BASE_ADDR  (M08_BASE_ADDR),   .M08_ADDR_WIDTH (M08_ADDR_WIDTH),
    .M08_CONNECT_READ (2'b11),         .M08_CONNECT_WRITE (2'b11),
    .M09_BASE_ADDR  (M09_BASE_ADDR),   .M09_ADDR_WIDTH (M09_ADDR_WIDTH),
    .M09_CONNECT_READ (2'b11),         .M09_CONNECT_WRITE (2'b11),

    // M10 = UART, window size = 2^UART_ADDR_WIN_BITS
    // M_ADDR_WIDTH expects a packed array of 32-bit width fields.
    // {1{32'(...)}} ensures a proper 32-bit constant regardless of parameter width.
    .M10_BASE_ADDR  (UART_BASE_ADDR),
    .M10_ADDR_WIDTH ({1{32'(UART_ADDR_WIN_BITS)}}),
    .M10_CONNECT_READ  (2'b11),
    .M10_CONNECT_WRITE (2'b11),
    .M10_SECURE        (1'b0)
)
u_interconnect (
    .clk  (clk),
    .rst  (rst_sync),

    // Slave port 0
    .s00_axi_awid    (s00_axi_awid),   .s00_axi_awaddr  (s00_axi_awaddr),
    .s00_axi_awlen   (s00_axi_awlen),  .s00_axi_awsize  (s00_axi_awsize),
    .s00_axi_awburst (s00_axi_awburst),.s00_axi_awlock  (s00_axi_awlock),
    .s00_axi_awcache (s00_axi_awcache),.s00_axi_awprot  (s00_axi_awprot),
    .s00_axi_awqos   (s00_axi_awqos),  .s00_axi_awuser  (1'b0),
    .s00_axi_awvalid (s00_axi_awvalid),.s00_axi_awready (s00_axi_awready),
    .s00_axi_wdata   (s00_axi_wdata),  .s00_axi_wstrb   (s00_axi_wstrb),
    .s00_axi_wlast   (s00_axi_wlast),  .s00_axi_wuser   (1'b0),
    .s00_axi_wvalid  (s00_axi_wvalid), .s00_axi_wready  (s00_axi_wready),
    .s00_axi_bid     (s00_axi_bid),    .s00_axi_bresp   (s00_axi_bresp),
    .s00_axi_buser   (),               .s00_axi_bvalid  (s00_axi_bvalid),
    .s00_axi_bready  (s00_axi_bready),
    .s00_axi_arid    (s00_axi_arid),   .s00_axi_araddr  (s00_axi_araddr),
    .s00_axi_arlen   (s00_axi_arlen),  .s00_axi_arsize  (s00_axi_arsize),
    .s00_axi_arburst (s00_axi_arburst),.s00_axi_arlock  (s00_axi_arlock),
    .s00_axi_arcache (s00_axi_arcache),.s00_axi_arprot  (s00_axi_arprot),
    .s00_axi_arqos   (s00_axi_arqos),  .s00_axi_aruser  (1'b0),
    .s00_axi_arvalid (s00_axi_arvalid),.s00_axi_arready (s00_axi_arready),
    .s00_axi_rid     (s00_axi_rid),    .s00_axi_rdata   (s00_axi_rdata),
    .s00_axi_rresp   (s00_axi_rresp),  .s00_axi_rlast   (s00_axi_rlast),
    .s00_axi_ruser   (),               .s00_axi_rvalid  (s00_axi_rvalid),
    .s00_axi_rready  (s00_axi_rready),

    // Slave port 1
    .s01_axi_awid    (s01_axi_awid),   .s01_axi_awaddr  (s01_axi_awaddr),
    .s01_axi_awlen   (s01_axi_awlen),  .s01_axi_awsize  (s01_axi_awsize),
    .s01_axi_awburst (s01_axi_awburst),.s01_axi_awlock  (s01_axi_awlock),
    .s01_axi_awcache (s01_axi_awcache),.s01_axi_awprot  (s01_axi_awprot),
    .s01_axi_awqos   (s01_axi_awqos),  .s01_axi_awuser  (1'b0),
    .s01_axi_awvalid (s01_axi_awvalid),.s01_axi_awready (s01_axi_awready),
    .s01_axi_wdata   (s01_axi_wdata),  .s01_axi_wstrb   (s01_axi_wstrb),
    .s01_axi_wlast   (s01_axi_wlast),  .s01_axi_wuser   (1'b0),
    .s01_axi_wvalid  (s01_axi_wvalid), .s01_axi_wready  (s01_axi_wready),
    .s01_axi_bid     (s01_axi_bid),    .s01_axi_bresp   (s01_axi_bresp),
    .s01_axi_buser   (),               .s01_axi_bvalid  (s01_axi_bvalid),
    .s01_axi_bready  (s01_axi_bready),
    .s01_axi_arid    (s01_axi_arid),   .s01_axi_araddr  (s01_axi_araddr),
    .s01_axi_arlen   (s01_axi_arlen),  .s01_axi_arsize  (s01_axi_arsize),
    .s01_axi_arburst (s01_axi_arburst),.s01_axi_arlock  (s01_axi_arlock),
    .s01_axi_arcache (s01_axi_arcache),.s01_axi_arprot  (s01_axi_arprot),
    .s01_axi_arqos   (s01_axi_arqos),  .s01_axi_aruser  (1'b0),
    .s01_axi_arvalid (s01_axi_arvalid),.s01_axi_arready (s01_axi_arready),
    .s01_axi_rid     (s01_axi_rid),    .s01_axi_rdata   (s01_axi_rdata),
    .s01_axi_rresp   (s01_axi_rresp),  .s01_axi_rlast   (s01_axi_rlast),
    .s01_axi_ruser   (),               .s01_axi_rvalid  (s01_axi_rvalid),
    .s01_axi_rready  (s01_axi_rready),

    // Master port 0 — exposed to top level
    .m00_axi_awid    (m00_axi_awid),   .m00_axi_awaddr  (m00_axi_awaddr),
    .m00_axi_awlen   (m00_axi_awlen),  .m00_axi_awsize  (m00_axi_awsize),
    .m00_axi_awburst (m00_axi_awburst),.m00_axi_awlock  (m00_axi_awlock),
    .m00_axi_awcache (m00_axi_awcache),.m00_axi_awprot  (m00_axi_awprot),
    .m00_axi_awqos   (m00_axi_awqos),  .m00_axi_awregion(m00_axi_awregion),
    .m00_axi_awuser  (),               .m00_axi_awvalid (m00_axi_awvalid),
    .m00_axi_awready (m00_axi_awready),.m00_axi_wdata   (m00_axi_wdata),
    .m00_axi_wstrb   (m00_axi_wstrb),  .m00_axi_wlast   (m00_axi_wlast),
    .m00_axi_wuser   (),               .m00_axi_wvalid  (m00_axi_wvalid),
    .m00_axi_wready  (m00_axi_wready), .m00_axi_bid     (m00_axi_bid),
    .m00_axi_bresp   (m00_axi_bresp),  .m00_axi_buser   (1'b0),
    .m00_axi_bvalid  (m00_axi_bvalid), .m00_axi_bready  (m00_axi_bready),
    .m00_axi_arid    (m00_axi_arid),   .m00_axi_araddr  (m00_axi_araddr),
    .m00_axi_arlen   (m00_axi_arlen),  .m00_axi_arsize  (m00_axi_arsize),
    .m00_axi_arburst (m00_axi_arburst),.m00_axi_arlock  (m00_axi_arlock),
    .m00_axi_arcache (m00_axi_arcache),.m00_axi_arprot  (m00_axi_arprot),
    .m00_axi_arqos   (m00_axi_arqos),  .m00_axi_arregion(m00_axi_arregion),
    .m00_axi_aruser  (),               .m00_axi_arvalid (m00_axi_arvalid),
    .m00_axi_arready (m00_axi_arready),.m00_axi_rid     (m00_axi_rid),
    .m00_axi_rdata   (m00_axi_rdata),  .m00_axi_rresp   (m00_axi_rresp),
    .m00_axi_rlast   (m00_axi_rlast),  .m00_axi_ruser   (1'b0),
    .m00_axi_rvalid  (m00_axi_rvalid), .m00_axi_rready  (m00_axi_rready),

    // Master port 1 — exposed to top level
    .m01_axi_awid    (m01_axi_awid),   .m01_axi_awaddr  (m01_axi_awaddr),
    .m01_axi_awlen   (m01_axi_awlen),  .m01_axi_awsize  (m01_axi_awsize),
    .m01_axi_awburst (m01_axi_awburst),.m01_axi_awlock  (m01_axi_awlock),
    .m01_axi_awcache (m01_axi_awcache),.m01_axi_awprot  (m01_axi_awprot),
    .m01_axi_awqos   (m01_axi_awqos),  .m01_axi_awregion(m01_axi_awregion),
    .m01_axi_awuser  (),               .m01_axi_awvalid (m01_axi_awvalid),
    .m01_axi_awready (m01_axi_awready),.m01_axi_wdata   (m01_axi_wdata),
    .m01_axi_wstrb   (m01_axi_wstrb),  .m01_axi_wlast   (m01_axi_wlast),
    .m01_axi_wuser   (),               .m01_axi_wvalid  (m01_axi_wvalid),
    .m01_axi_wready  (m01_axi_wready), .m01_axi_bid     (m01_axi_bid),
    .m01_axi_bresp   (m01_axi_bresp),  .m01_axi_buser   (1'b0),
    .m01_axi_bvalid  (m01_axi_bvalid), .m01_axi_bready  (m01_axi_bready),
    .m01_axi_arid    (m01_axi_arid),   .m01_axi_araddr  (m01_axi_araddr),
    .m01_axi_arlen   (m01_axi_arlen),  .m01_axi_arsize  (m01_axi_arsize),
    .m01_axi_arburst (m01_axi_arburst),.m01_axi_arlock  (m01_axi_arlock),
    .m01_axi_arcache (m01_axi_arcache),.m01_axi_arprot  (m01_axi_arprot),
    .m01_axi_arqos   (m01_axi_arqos),  .m01_axi_arregion(m01_axi_arregion),
    .m01_axi_aruser  (),               .m01_axi_arvalid (m01_axi_arvalid),
    .m01_axi_arready (m01_axi_arready),.m01_axi_rid     (m01_axi_rid),
    .m01_axi_rdata   (m01_axi_rdata),  .m01_axi_rresp   (m01_axi_rresp),
    .m01_axi_rlast   (m01_axi_rlast),  .m01_axi_ruser   (1'b0),
    .m01_axi_rvalid  (m01_axi_rvalid), .m01_axi_rready  (m01_axi_rready),

    // Master ports M02-M09 — stub (tie off with passive no-response)
    .m02_axi_awuser(),  .m02_axi_awvalid(), .m02_axi_awready(1'b0),
    .m02_axi_wuser (),  .m02_axi_wvalid (),  .m02_axi_wready (1'b0),
    .m02_axi_bid   (stub_bid), .m02_axi_bresp(stub_bresp),
    .m02_axi_buser (1'b0), .m02_axi_bvalid(stub_bvalid), .m02_axi_bready(),
    .m02_axi_aruser(),  .m02_axi_arvalid(), .m02_axi_arready(1'b0),
    .m02_axi_rid   (stub_rid), .m02_axi_rdata(stub_rdata),
    .m02_axi_rresp (stub_rresp), .m02_axi_rlast(stub_rlast),
    .m02_axi_ruser (1'b0), .m02_axi_rvalid(stub_rvalid), .m02_axi_rready(),
    .m02_axi_awid(), .m02_axi_awaddr(), .m02_axi_awlen(), .m02_axi_awsize(),
    .m02_axi_awburst(), .m02_axi_awlock(), .m02_axi_awcache(), .m02_axi_awprot(),
    .m02_axi_awqos(), .m02_axi_awregion(),
    .m02_axi_wdata(), .m02_axi_wstrb(), .m02_axi_wlast(),
    .m02_axi_arid(), .m02_axi_araddr(), .m02_axi_arlen(), .m02_axi_arsize(),
    .m02_axi_arburst(), .m02_axi_arlock(), .m02_axi_arcache(), .m02_axi_arprot(),
    .m02_axi_arqos(), .m02_axi_arregion(),

    .m03_axi_awuser(),  .m03_axi_awvalid(), .m03_axi_awready(1'b0),
    .m03_axi_wuser (),  .m03_axi_wvalid (),  .m03_axi_wready (1'b0),
    .m03_axi_bid   (stub_bid), .m03_axi_bresp(stub_bresp),
    .m03_axi_buser (1'b0), .m03_axi_bvalid(stub_bvalid), .m03_axi_bready(),
    .m03_axi_aruser(),  .m03_axi_arvalid(), .m03_axi_arready(1'b0),
    .m03_axi_rid   (stub_rid), .m03_axi_rdata(stub_rdata),
    .m03_axi_rresp (stub_rresp), .m03_axi_rlast(stub_rlast),
    .m03_axi_ruser (1'b0), .m03_axi_rvalid(stub_rvalid), .m03_axi_rready(),
    .m03_axi_awid(), .m03_axi_awaddr(), .m03_axi_awlen(), .m03_axi_awsize(),
    .m03_axi_awburst(), .m03_axi_awlock(), .m03_axi_awcache(), .m03_axi_awprot(),
    .m03_axi_awqos(), .m03_axi_awregion(),
    .m03_axi_wdata(), .m03_axi_wstrb(), .m03_axi_wlast(),
    .m03_axi_arid(), .m03_axi_araddr(), .m03_axi_arlen(), .m03_axi_arsize(),
    .m03_axi_arburst(), .m03_axi_arlock(), .m03_axi_arcache(), .m03_axi_arprot(),
    .m03_axi_arqos(), .m03_axi_arregion(),

    .m04_axi_awuser(),  .m04_axi_awvalid(), .m04_axi_awready(1'b0),
    .m04_axi_wuser (),  .m04_axi_wvalid (),  .m04_axi_wready (1'b0),
    .m04_axi_bid   (stub_bid), .m04_axi_bresp(stub_bresp),
    .m04_axi_buser (1'b0), .m04_axi_bvalid(stub_bvalid), .m04_axi_bready(),
    .m04_axi_aruser(),  .m04_axi_arvalid(), .m04_axi_arready(1'b0),
    .m04_axi_rid   (stub_rid), .m04_axi_rdata(stub_rdata),
    .m04_axi_rresp (stub_rresp), .m04_axi_rlast(stub_rlast),
    .m04_axi_ruser (1'b0), .m04_axi_rvalid(stub_rvalid), .m04_axi_rready(),
    .m04_axi_awid(), .m04_axi_awaddr(), .m04_axi_awlen(), .m04_axi_awsize(),
    .m04_axi_awburst(), .m04_axi_awlock(), .m04_axi_awcache(), .m04_axi_awprot(),
    .m04_axi_awqos(), .m04_axi_awregion(),
    .m04_axi_wdata(), .m04_axi_wstrb(), .m04_axi_wlast(),
    .m04_axi_arid(), .m04_axi_araddr(), .m04_axi_arlen(), .m04_axi_arsize(),
    .m04_axi_arburst(), .m04_axi_arlock(), .m04_axi_arcache(), .m04_axi_arprot(),
    .m04_axi_arqos(), .m04_axi_arregion(),

    .m05_axi_awuser(),  .m05_axi_awvalid(), .m05_axi_awready(1'b0),
    .m05_axi_wuser (),  .m05_axi_wvalid (),  .m05_axi_wready (1'b0),
    .m05_axi_bid   (stub_bid), .m05_axi_bresp(stub_bresp),
    .m05_axi_buser (1'b0), .m05_axi_bvalid(stub_bvalid), .m05_axi_bready(),
    .m05_axi_aruser(),  .m05_axi_arvalid(), .m05_axi_arready(1'b0),
    .m05_axi_rid   (stub_rid), .m05_axi_rdata(stub_rdata),
    .m05_axi_rresp (stub_rresp), .m05_axi_rlast(stub_rlast),
    .m05_axi_ruser (1'b0), .m05_axi_rvalid(stub_rvalid), .m05_axi_rready(),
    .m05_axi_awid(), .m05_axi_awaddr(), .m05_axi_awlen(), .m05_axi_awsize(),
    .m05_axi_awburst(), .m05_axi_awlock(), .m05_axi_awcache(), .m05_axi_awprot(),
    .m05_axi_awqos(), .m05_axi_awregion(),
    .m05_axi_wdata(), .m05_axi_wstrb(), .m05_axi_wlast(),
    .m05_axi_arid(), .m05_axi_araddr(), .m05_axi_arlen(), .m05_axi_arsize(),
    .m05_axi_arburst(), .m05_axi_arlock(), .m05_axi_arcache(), .m05_axi_arprot(),
    .m05_axi_arqos(), .m05_axi_arregion(),

    .m06_axi_awuser(),  .m06_axi_awvalid(), .m06_axi_awready(1'b0),
    .m06_axi_wuser (),  .m06_axi_wvalid (),  .m06_axi_wready (1'b0),
    .m06_axi_bid   (stub_bid), .m06_axi_bresp(stub_bresp),
    .m06_axi_buser (1'b0), .m06_axi_bvalid(stub_bvalid), .m06_axi_bready(),
    .m06_axi_aruser(),  .m06_axi_arvalid(), .m06_axi_arready(1'b0),
    .m06_axi_rid   (stub_rid), .m06_axi_rdata(stub_rdata),
    .m06_axi_rresp (stub_rresp), .m06_axi_rlast(stub_rlast),
    .m06_axi_ruser (1'b0), .m06_axi_rvalid(stub_rvalid), .m06_axi_rready(),
    .m06_axi_awid(), .m06_axi_awaddr(), .m06_axi_awlen(), .m06_axi_awsize(),
    .m06_axi_awburst(), .m06_axi_awlock(), .m06_axi_awcache(), .m06_axi_awprot(),
    .m06_axi_awqos(), .m06_axi_awregion(),
    .m06_axi_wdata(), .m06_axi_wstrb(), .m06_axi_wlast(),
    .m06_axi_arid(), .m06_axi_araddr(), .m06_axi_arlen(), .m06_axi_arsize(),
    .m06_axi_arburst(), .m06_axi_arlock(), .m06_axi_arcache(), .m06_axi_arprot(),
    .m06_axi_arqos(), .m06_axi_arregion(),

    .m07_axi_awuser(),  .m07_axi_awvalid(), .m07_axi_awready(1'b0),
    .m07_axi_wuser (),  .m07_axi_wvalid (),  .m07_axi_wready (1'b0),
    .m07_axi_bid   (stub_bid), .m07_axi_bresp(stub_bresp),
    .m07_axi_buser (1'b0), .m07_axi_bvalid(stub_bvalid), .m07_axi_bready(),
    .m07_axi_aruser(),  .m07_axi_arvalid(), .m07_axi_arready(1'b0),
    .m07_axi_rid   (stub_rid), .m07_axi_rdata(stub_rdata),
    .m07_axi_rresp (stub_rresp), .m07_axi_rlast(stub_rlast),
    .m07_axi_ruser (1'b0), .m07_axi_rvalid(stub_rvalid), .m07_axi_rready(),
    .m07_axi_awid(), .m07_axi_awaddr(), .m07_axi_awlen(), .m07_axi_awsize(),
    .m07_axi_awburst(), .m07_axi_awlock(), .m07_axi_awcache(), .m07_axi_awprot(),
    .m07_axi_awqos(), .m07_axi_awregion(),
    .m07_axi_wdata(), .m07_axi_wstrb(), .m07_axi_wlast(),
    .m07_axi_arid(), .m07_axi_araddr(), .m07_axi_arlen(), .m07_axi_arsize(),
    .m07_axi_arburst(), .m07_axi_arlock(), .m07_axi_arcache(), .m07_axi_arprot(),
    .m07_axi_arqos(), .m07_axi_arregion(),

    .m08_axi_awuser(),  .m08_axi_awvalid(), .m08_axi_awready(1'b0),
    .m08_axi_wuser (),  .m08_axi_wvalid (),  .m08_axi_wready (1'b0),
    .m08_axi_bid   (stub_bid), .m08_axi_bresp(stub_bresp),
    .m08_axi_buser (1'b0), .m08_axi_bvalid(stub_bvalid), .m08_axi_bready(),
    .m08_axi_aruser(),  .m08_axi_arvalid(), .m08_axi_arready(1'b0),
    .m08_axi_rid   (stub_rid), .m08_axi_rdata(stub_rdata),
    .m08_axi_rresp (stub_rresp), .m08_axi_rlast(stub_rlast),
    .m08_axi_ruser (1'b0), .m08_axi_rvalid(stub_rvalid), .m08_axi_rready(),
    .m08_axi_awid(), .m08_axi_awaddr(), .m08_axi_awlen(), .m08_axi_awsize(),
    .m08_axi_awburst(), .m08_axi_awlock(), .m08_axi_awcache(), .m08_axi_awprot(),
    .m08_axi_awqos(), .m08_axi_awregion(),
    .m08_axi_wdata(), .m08_axi_wstrb(), .m08_axi_wlast(),
    .m08_axi_arid(), .m08_axi_araddr(), .m08_axi_arlen(), .m08_axi_arsize(),
    .m08_axi_arburst(), .m08_axi_arlock(), .m08_axi_arcache(), .m08_axi_arprot(),
    .m08_axi_arqos(), .m08_axi_arregion(),

    .m09_axi_awuser(),  .m09_axi_awvalid(), .m09_axi_awready(1'b0),
    .m09_axi_wuser (),  .m09_axi_wvalid (),  .m09_axi_wready (1'b0),
    .m09_axi_bid   (stub_bid), .m09_axi_bresp(stub_bresp),
    .m09_axi_buser (1'b0), .m09_axi_bvalid(stub_bvalid), .m09_axi_bready(),
    .m09_axi_aruser(),  .m09_axi_arvalid(), .m09_axi_arready(1'b0),
    .m09_axi_rid   (stub_rid), .m09_axi_rdata(stub_rdata),
    .m09_axi_rresp (stub_rresp), .m09_axi_rlast(stub_rlast),
    .m09_axi_ruser (1'b0), .m09_axi_rvalid(stub_rvalid), .m09_axi_rready(),
    .m09_axi_awid(), .m09_axi_awaddr(), .m09_axi_awlen(), .m09_axi_awsize(),
    .m09_axi_awburst(), .m09_axi_awlock(), .m09_axi_awcache(), .m09_axi_awprot(),
    .m09_axi_awqos(), .m09_axi_awregion(),
    .m09_axi_wdata(), .m09_axi_wstrb(), .m09_axi_wlast(),
    .m09_axi_arid(), .m09_axi_araddr(), .m09_axi_arlen(), .m09_axi_arsize(),
    .m09_axi_arburst(), .m09_axi_arlock(), .m09_axi_arcache(), .m09_axi_arprot(),
    .m09_axi_arqos(), .m09_axi_arregion(),

    // Master port 10 — wired to bridge
    .m10_axi_awid    (ic_m10_awid),    .m10_axi_awaddr  (ic_m10_awaddr),
    .m10_axi_awlen   (ic_m10_awlen),   .m10_axi_awsize  (ic_m10_awsize),
    .m10_axi_awburst (ic_m10_awburst), .m10_axi_awlock  (ic_m10_awlock),
    .m10_axi_awcache (ic_m10_awcache), .m10_axi_awprot  (ic_m10_awprot),
    .m10_axi_awqos   (ic_m10_awqos),   .m10_axi_awregion(ic_m10_awregion),
    .m10_axi_awuser  (),               .m10_axi_awvalid (ic_m10_awvalid),
    .m10_axi_awready (ic_m10_awready),
    .m10_axi_wdata   (ic_m10_wdata),   .m10_axi_wstrb   (ic_m10_wstrb),
    .m10_axi_wlast   (ic_m10_wlast),   .m10_axi_wuser   (),
    .m10_axi_wvalid  (ic_m10_wvalid),  .m10_axi_wready  (ic_m10_wready),
    .m10_axi_bid     (ic_m10_bid),     .m10_axi_bresp   (ic_m10_bresp),
    .m10_axi_buser   (1'b0),           .m10_axi_bvalid  (ic_m10_bvalid),
    .m10_axi_bready  (ic_m10_bready),
    .m10_axi_arid    (ic_m10_arid),    .m10_axi_araddr  (ic_m10_araddr),
    .m10_axi_arlen   (ic_m10_arlen),   .m10_axi_arsize  (ic_m10_arsize),
    .m10_axi_arburst (ic_m10_arburst), .m10_axi_arlock  (ic_m10_arlock),
    .m10_axi_arcache (ic_m10_arcache), .m10_axi_arprot  (ic_m10_arprot),
    .m10_axi_arqos   (ic_m10_arqos),   .m10_axi_arregion(ic_m10_arregion),
    .m10_axi_aruser  (),               .m10_axi_arvalid (ic_m10_arvalid),
    .m10_axi_arready (ic_m10_arready),
    .m10_axi_rid     (ic_m10_rid),     .m10_axi_rdata   (ic_m10_rdata),
    .m10_axi_rresp   (ic_m10_rresp),   .m10_axi_rlast   (ic_m10_rlast),
    .m10_axi_ruser   (1'b0),           .m10_axi_rvalid  (ic_m10_rvalid),
    .m10_axi_rready  (ic_m10_rready)
);

// =============================================================================
// AXI4-to-AXI4-Lite Bridge
// =============================================================================
axi4_to_axilite_bridge #(
    .DATA_WIDTH  (DATA_WIDTH),
    .ADDR_WIDTH  (ADDR_WIDTH),
    .LITE_ADDR_W (5),
    .ID_WIDTH    (ID_WIDTH)
)
u_bridge (
    .clk             (clk),
    .rst             (rst_sync),
    // AXI4 side (from interconnect)
    .s_axi_awid      (ic_m10_awid),    .s_axi_awaddr    (ic_m10_awaddr),
    .s_axi_awlen     (ic_m10_awlen),   .s_axi_awsize    (ic_m10_awsize),
    .s_axi_awburst   (ic_m10_awburst), .s_axi_awlock    (ic_m10_awlock),
    .s_axi_awcache   (ic_m10_awcache), .s_axi_awprot    (ic_m10_awprot),
    .s_axi_awqos     (ic_m10_awqos),   .s_axi_awregion  (ic_m10_awregion),
    .s_axi_awvalid   (ic_m10_awvalid), .s_axi_awready   (ic_m10_awready),
    .s_axi_wdata     (ic_m10_wdata),   .s_axi_wstrb     (ic_m10_wstrb),
    .s_axi_wlast     (ic_m10_wlast),   .s_axi_wvalid    (ic_m10_wvalid),
    .s_axi_wready    (ic_m10_wready),
    .s_axi_bid       (ic_m10_bid),     .s_axi_bresp     (ic_m10_bresp),
    .s_axi_bvalid    (ic_m10_bvalid),  .s_axi_bready    (ic_m10_bready),
    .s_axi_arid      (ic_m10_arid),    .s_axi_araddr    (ic_m10_araddr),
    .s_axi_arlen     (ic_m10_arlen),   .s_axi_arsize    (ic_m10_arsize),
    .s_axi_arburst   (ic_m10_arburst), .s_axi_arlock    (ic_m10_arlock),
    .s_axi_arcache   (ic_m10_arcache), .s_axi_arprot    (ic_m10_arprot),
    .s_axi_arqos     (ic_m10_arqos),   .s_axi_arregion  (ic_m10_arregion),
    .s_axi_arvalid   (ic_m10_arvalid), .s_axi_arready   (ic_m10_arready),
    .s_axi_rid       (ic_m10_rid),     .s_axi_rdata     (ic_m10_rdata),
    .s_axi_rresp     (ic_m10_rresp),   .s_axi_rlast     (ic_m10_rlast),
    .s_axi_rvalid    (ic_m10_rvalid),  .s_axi_rready    (ic_m10_rready),
    // AXI4-Lite side (to UART)
    .m_axil_awid     (uart_awid),      .m_axil_awaddr   (uart_awaddr),
    .m_axil_awvalid  (uart_awvalid),   .m_axil_awready  (uart_awready),
    .m_axil_wdata    (uart_wdata),     .m_axil_wstrb    (uart_wstrb),
    .m_axil_wvalid   (uart_wvalid),    .m_axil_wready   (uart_wready),
    .m_axil_bid      (uart_bid),       .m_axil_bresp    (uart_bresp),
    .m_axil_bvalid   (uart_bvalid),    .m_axil_bready   (uart_bready),
    .m_axil_arid     (uart_arid),      .m_axil_araddr   (uart_araddr),
    .m_axil_arvalid  (uart_arvalid),   .m_axil_arready  (uart_arready),
    .m_axil_rid      (uart_rid),       .m_axil_rdata    (uart_rdata),
    .m_axil_rresp    (uart_rresp),     .m_axil_rvalid   (uart_rvalid),
    .m_axil_rready   (uart_rready)
);

// =============================================================================
// AXI-Lite UART
// =============================================================================
axi_uart_top u_uart (
    .fixed_clk_i      (clk),
    .axi_aclk_i       (clk),
    .axi_aresetn_i    (rst_n),

    // Write address
    .axi_awid_i       (uart_awid),
    .axi_awaddr_i     (uart_awaddr),
    .axi_awvalid_i    (uart_awvalid),
    .axi_awready_o    (uart_awready),
    // Write data
    .axi_wdata_i      (uart_wdata),
    .axi_wstrb_i      (uart_wstrb),
    .axi_wvalid_i     (uart_wvalid),
    .axi_wready_o     (uart_wready),
    // Write response
    .axi_bid_o        (uart_bid),
    .axi_bresp_o      (uart_bresp),
    .axi_bvalid_o     (uart_bvalid),
    .axi_bready_i     (uart_bready),
    // Read address
    .axi_arid_i       (uart_arid),
    .axi_araddr_i     (uart_araddr),
    .axi_arvalid_i    (uart_arvalid),
    .axi_arready_o    (uart_arready),
    // Read data
    .axi_rid_o        (uart_rid),
    .axi_rdata_o      (uart_rdata),
    .axi_rresp_o      (uart_rresp),
    .axi_rvalid_o     (uart_rvalid),
    .axi_rready_i     (uart_rready),
    // UART pins
    .uart_rx_i        (uart_rx_i),
    .uart_tx_o        (uart_tx_o),
    .read_interrupt_o (uart_irq_o)
);

endmodule

`resetall
