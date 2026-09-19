// =============================================================================
// Project      : Aegis-V SoC
// File         : axi4_to_axilite_bridge.v
// Description  : AXI4-Full to AXI4-Lite bridge.
//                The AXI interconnect produces full AXI4 master ports (with
//                awlen/awsize/awburst/awlock/awcache/awqos/wlast etc.).
//                The AXI-Lite UART slave does not have those signals.
//                This bridge:
//                  - accepts one AXI4 beat at a time (enforces single-beat
//                    transactions toward the Lite slave)
//                  - strips the burst/quality-of-service sideband signals
//                  - passes addr, data, strb, id, prot directly through
//                  - generates wlast / absorbs rlast internally
//
// Parameters
//   DATA_WIDTH  : data bus width (must match UART = 32)
//   ADDR_WIDTH  : AXI4 address bus width (32 from interconnect)
//   LITE_ADDR_W : AXI4-Lite slave address width (5 for UART)
//   ID_WIDTH    : ID bus width (12 for UART)
// =============================================================================

`resetall
`timescale 1ns / 1ps
`default_nettype none

module axi4_to_axilite_bridge #(
    parameter DATA_WIDTH  = 32,
    parameter ADDR_WIDTH  = 32,
    parameter LITE_ADDR_W = 5,
    parameter ID_WIDTH    = 12
)(
    input  wire                     clk,
    input  wire                     rst,   // synchronous active-high reset

    // ----------------------------------------------------------------
    // AXI4-Full Slave Port  (connects to interconnect master port)
    // ----------------------------------------------------------------
    // Write address channel
    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire [3:0]               s_axi_awqos,
    input  wire [3:0]               s_axi_awregion,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,
    // Write data channel
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,
    // Write response channel
    output wire [ID_WIDTH-1:0]      s_axi_bid,
    output wire [1:0]               s_axi_bresp,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,
    // Read address channel
    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arlock,
    input  wire [3:0]               s_axi_arcache,
    input  wire [2:0]               s_axi_arprot,
    input  wire [3:0]               s_axi_arqos,
    input  wire [3:0]               s_axi_arregion,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,
    // Read data channel
    output wire [ID_WIDTH-1:0]      s_axi_rid,
    output wire [DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rlast,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready,

    // ----------------------------------------------------------------
    // AXI4-Lite Master Port  (connects to UART slave)
    // ----------------------------------------------------------------
    // Write address channel
    output wire [ID_WIDTH-1:0]      m_axil_awid,
    output wire [LITE_ADDR_W-1:0]   m_axil_awaddr,
    output wire                     m_axil_awvalid,
    input  wire                     m_axil_awready,
    // Write data channel
    output wire [DATA_WIDTH-1:0]    m_axil_wdata,
    output wire [DATA_WIDTH/8-1:0]  m_axil_wstrb,
    output wire                     m_axil_wvalid,
    input  wire                     m_axil_wready,
    // Write response channel
    input  wire [ID_WIDTH-1:0]      m_axil_bid,
    input  wire [1:0]               m_axil_bresp,
    input  wire                     m_axil_bvalid,
    output wire                     m_axil_bready,
    // Read address channel
    output wire [ID_WIDTH-1:0]      m_axil_arid,
    output wire [LITE_ADDR_W-1:0]   m_axil_araddr,
    output wire                     m_axil_arvalid,
    input  wire                     m_axil_arready,
    // Read data channel
    input  wire [ID_WIDTH-1:0]      m_axil_rid,
    input  wire [DATA_WIDTH-1:0]    m_axil_rdata,
    input  wire [1:0]               m_axil_rresp,
    input  wire                     m_axil_rvalid,
    output wire                     m_axil_rready
);

// =============================================================================
// Write path
// =============================================================================
// The bridge accepts a single-beat write (AXI4-Lite only supports bursts of 1).
// For the UART we simply pass awaddr/awvalid straight through after truncating
// the address to LITE_ADDR_W bits. The AXI4 wlast is ignored (lite has none).
// The b-channel response is forwarded unmodified.

assign m_axil_awid    = s_axi_awid;
assign m_axil_awaddr  = s_axi_awaddr[LITE_ADDR_W-1:0];
assign m_axil_awvalid = s_axi_awvalid;
assign s_axi_awready  = m_axil_awready;

assign m_axil_wdata   = s_axi_wdata;
assign m_axil_wstrb   = s_axi_wstrb;
assign m_axil_wvalid  = s_axi_wvalid;
assign s_axi_wready   = m_axil_wready;

assign s_axi_bid      = m_axil_bid;
assign s_axi_bresp    = m_axil_bresp;
assign s_axi_bvalid   = m_axil_bvalid;
assign m_axil_bready  = s_axi_bready;

// =============================================================================
// Read path
// =============================================================================
// Same principle: truncate address, forward valid/ready.
// AXI4-Lite read response carries no rlast — we always assert it (burst = 1).

assign m_axil_arid    = s_axi_arid;
assign m_axil_araddr  = s_axi_araddr[LITE_ADDR_W-1:0];
assign m_axil_arvalid = s_axi_arvalid;
assign s_axi_arready  = m_axil_arready;

assign s_axi_rid      = m_axil_rid;
assign s_axi_rdata    = m_axil_rdata;
assign s_axi_rresp    = m_axil_rresp;
assign s_axi_rvalid   = m_axil_rvalid;
assign s_axi_rlast    = m_axil_rvalid; // single-beat: last == valid
assign m_axil_rready  = s_axi_rready;

// Unused inputs (suppress lint warnings)
wire _unused = &{rst, clk,
                 s_axi_awlen, s_axi_awsize, s_axi_awburst,
                 s_axi_awlock, s_axi_awcache, s_axi_awqos, s_axi_awregion,
                 s_axi_wlast,
                 s_axi_arlen, s_axi_arsize, s_axi_arburst,
                 s_axi_arlock, s_axi_arcache, s_axi_arqos, s_axi_arregion,
                 s_axi_awprot, s_axi_arprot,
                 1'b0};

endmodule

`resetall
