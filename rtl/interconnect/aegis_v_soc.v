// =============================================================================
// Project      : Aegis-V SoC
// File         : aegis_v_soc.v
// Description  : Top-level SoC integration module.
//
//                Instantiates and wires:
//                  1. el2_veer_wrapper   – VeeR EL2 RISC-V core (RV_BUILD_AXI4)
//                  2. el2_mem            – ICCM/DCCM on-chip memories
//                  3. axi_interconnect_wrap_2x11 – AXI4 crossbar (2 masters, 11 slaves)
//                  4. axi_uart_top       – AXI-Lite UART peripheral
//                  5. aes_axi_slave      – AXI-Lite AES-128 accelerator
//                  6. i2c_master_top     – Wishbone I2C master
//                  7. wb_to_axilite_bridge – WB-to-AXI-Lite bridge for I2C
//                  8. axi4_to_axilite_bridge – AXI4-to-AXI-Lite bridge
//                     (one instance per peripheral on the interconnect)
//
//                Address map (32-bit physical):
//                  0x0000_0000  256 MB  – Instruction/Data SRAM (M00, external)
//                  0x1000_0000    4 KB  – UART  (M01)
//                  0x2000_0000    4 KB  – AES   (M02)
//                  0x3000_0000    4 KB  – I2C   (M03)
//                  M04..M10 reserved for future peripherals
//
//                VeeR EL2 AXI bus usage:
//                  LSU AXI  → interconnect slave port s00 (data bus)
//                  IFU AXI  → interconnect slave port s01 (instruction fetch)
//                  SB  AXI  → tied off (debug system bus not used in SoC)
//                  DMA AXI  → tied off (no external DMA master)
//
//                Port name conventions matched to actual sub-module interfaces:
//                  axi4_to_axilite_bridge  : uses .rst  (active-high sync reset)
//                                           m_axil_* ports, LITE_ADDR_W=5
//                  axi_uart_top            : uses axi_*_i / axi_*_o naming,
//                                           fixed_clk_i, ID_WIDTH=12, ADDR_WIDTH=5
//                  aes_axi_slave           : uses s_axi_* naming, 6-bit addr
//                  i2c_master_top          : Wishbone wb_* naming
//
//                Compile with:  +define+RV_BUILD_AXI4
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module aegis_v_soc #(
    // -------------------------------------------------------------------------
    // VeeR EL2 parameters
    // -------------------------------------------------------------------------
    parameter [30:0] VEER_RESET_VEC  = 31'h0000_0000,
    parameter [30:0] VEER_NMI_VEC    = 31'h0000_0040,
    parameter [30:0] VEER_JTAG_ID    = 31'h1,
    parameter [27:0] VEER_CORE_ID    = 28'h0,

    // -------------------------------------------------------------------------
    // Interconnect / peripheral parameters
    // -------------------------------------------------------------------------
    parameter AXI_DATA_WIDTH  = 32,
    parameter AXI_ADDR_WIDTH  = 32,
    parameter AXI_ID_WIDTH    = 8,

    // Peripheral base addresses
    parameter UART_BASE_ADDR  = 32'h1000_0000,
    parameter AES_BASE_ADDR   = 32'h2000_0000,
    parameter I2C_BASE_ADDR   = 32'h3000_0000,

    // Address window bits (2^12 = 4 KB per peripheral)
    parameter PERIPH_ADDR_WIN = 32'd12
)(
    // -------------------------------------------------------------------------
    // System signals
    // -------------------------------------------------------------------------
    input  wire        clk,
    input  wire        rst_n,        // active-low async reset

    // -------------------------------------------------------------------------
    // UART serial interface
    // -------------------------------------------------------------------------
    input  wire        uart_rx,
    output wire        uart_tx,

    // -------------------------------------------------------------------------
    // I2C bus
    // -------------------------------------------------------------------------
    input  wire        i2c_scl_i,
    output wire        i2c_scl_o,
    output wire        i2c_scl_oen,  // 0 = drive, 1 = tristate
    input  wire        i2c_sda_i,
    output wire        i2c_sda_o,
    output wire        i2c_sda_oen,

    // -------------------------------------------------------------------------
    // JTAG (for VeeR debug)
    // -------------------------------------------------------------------------
    input  wire        jtag_tck,
    input  wire        jtag_tms,
    input  wire        jtag_tdi,
    input  wire        jtag_trst_n,
    output wire        jtag_tdo,
    output wire        jtag_tdoEn,

    // -------------------------------------------------------------------------
    // External memory interface (M00 – connects to off-chip SRAM or boot ROM)
    // Exposes the M00 AXI4 master port of the interconnect directly to top.
    // -------------------------------------------------------------------------
    // Write address
    output wire [AXI_ID_WIDTH-1:0]   mem_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0] mem_axi_awaddr,
    output wire [7:0]                mem_axi_awlen,
    output wire [2:0]                mem_axi_awsize,
    output wire [1:0]                mem_axi_awburst,
    output wire                      mem_axi_awlock,
    output wire [3:0]                mem_axi_awcache,
    output wire [2:0]                mem_axi_awprot,
    output wire [3:0]                mem_axi_awqos,
    output wire                      mem_axi_awvalid,
    input  wire                      mem_axi_awready,
    // Write data
    output wire [AXI_DATA_WIDTH-1:0] mem_axi_wdata,
    output wire [3:0]                mem_axi_wstrb,
    output wire                      mem_axi_wlast,
    output wire                      mem_axi_wvalid,
    input  wire                      mem_axi_wready,
    // Write response
    input  wire [AXI_ID_WIDTH-1:0]   mem_axi_bid,
    input  wire [1:0]                mem_axi_bresp,
    input  wire                      mem_axi_bvalid,
    output wire                      mem_axi_bready,
    // Read address
    output wire [AXI_ID_WIDTH-1:0]   mem_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0] mem_axi_araddr,
    output wire [7:0]                mem_axi_arlen,
    output wire [2:0]                mem_axi_arsize,
    output wire [1:0]                mem_axi_arburst,
    output wire                      mem_axi_arlock,
    output wire [3:0]                mem_axi_arcache,
    output wire [2:0]                mem_axi_arprot,
    output wire [3:0]                mem_axi_arqos,
    output wire                      mem_axi_arvalid,
    input  wire                      mem_axi_arready,
    // Read data
    input  wire [AXI_ID_WIDTH-1:0]   mem_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0] mem_axi_rdata,
    input  wire [1:0]                mem_axi_rresp,
    input  wire                      mem_axi_rlast,
    input  wire                      mem_axi_rvalid,
    output wire                      mem_axi_rready,

    // -------------------------------------------------------------------------
    // Interrupt inputs (to VeeR EL2 PIC)
    // -------------------------------------------------------------------------
    input  wire [31:1]  extintsrc_req   // external interrupt sources
);

    // =========================================================================
    // Reset synchronisation
    //   rst_l     = active-high synchronous reset for VeeR (1 = running)
    //   rst_sync  = same signal, active-low for AXI/UART/AES/I2C
    //   rst_ah    = active-high for axi4_to_axilite_bridge
    // =========================================================================
    reg  rst_sync1, rst_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rst_sync1 <= 1'b0; rst_sync2 <= 1'b0; end
        else        begin rst_sync1 <= 1'b1; rst_sync2 <= rst_sync1; end
    end
    wire rst_l    = rst_sync2;    // active-high: 1 = running  (for VeeR)
    wire rst_n_s  = rst_sync2;    // active-low  (for AXI IPs)
    wire rst_ah   = ~rst_sync2;   // active-high (for axi4_to_axilite_bridge)

    // =========================================================================
    // VeeR EL2 AXI buses  (64-bit data, 32-bit address)
    // =========================================================================
    // --- LSU AXI4 master ---
    wire                     lsu_axi_awvalid, lsu_axi_awready;
    wire [3:0]               lsu_axi_awid;
    wire [31:0]              lsu_axi_awaddr;
    wire [3:0]               lsu_axi_awregion;
    wire [7:0]               lsu_axi_awlen;
    wire [2:0]               lsu_axi_awsize;
    wire [1:0]               lsu_axi_awburst;
    wire                     lsu_axi_awlock;
    wire [3:0]               lsu_axi_awcache;
    wire [2:0]               lsu_axi_awprot;
    wire [3:0]               lsu_axi_awqos;
    wire                     lsu_axi_wvalid,  lsu_axi_wready;
    wire [63:0]              lsu_axi_wdata;
    wire [7:0]               lsu_axi_wstrb;
    wire                     lsu_axi_wlast;
    wire                     lsu_axi_bvalid,  lsu_axi_bready;
    wire [1:0]               lsu_axi_bresp;
    wire [3:0]               lsu_axi_bid;
    wire                     lsu_axi_arvalid, lsu_axi_arready;
    wire [3:0]               lsu_axi_arid;
    wire [31:0]              lsu_axi_araddr;
    wire [3:0]               lsu_axi_arregion;
    wire [7:0]               lsu_axi_arlen;
    wire [2:0]               lsu_axi_arsize;
    wire [1:0]               lsu_axi_arburst;
    wire                     lsu_axi_arlock;
    wire [3:0]               lsu_axi_arcache;
    wire [2:0]               lsu_axi_arprot;
    wire [3:0]               lsu_axi_arqos;
    wire                     lsu_axi_rvalid,  lsu_axi_rready;
    wire [3:0]               lsu_axi_rid;
    wire [63:0]              lsu_axi_rdata;
    wire [1:0]               lsu_axi_rresp;
    wire                     lsu_axi_rlast;

    // --- IFU AXI4 master ---
    wire                     ifu_axi_awvalid, ifu_axi_awready;
    wire [3:0]               ifu_axi_awid;
    wire [31:0]              ifu_axi_awaddr;
    wire [3:0]               ifu_axi_awregion;
    wire [7:0]               ifu_axi_awlen;
    wire [2:0]               ifu_axi_awsize;
    wire [1:0]               ifu_axi_awburst;
    wire                     ifu_axi_awlock;
    wire [3:0]               ifu_axi_awcache;
    wire [2:0]               ifu_axi_awprot;
    wire [3:0]               ifu_axi_awqos;
    wire                     ifu_axi_wvalid,  ifu_axi_wready;
    wire [63:0]              ifu_axi_wdata;
    wire [7:0]               ifu_axi_wstrb;
    wire                     ifu_axi_wlast;
    wire                     ifu_axi_bvalid,  ifu_axi_bready;
    wire [1:0]               ifu_axi_bresp;
    wire [3:0]               ifu_axi_bid;
    wire                     ifu_axi_arvalid, ifu_axi_arready;
    wire [3:0]               ifu_axi_arid;
    wire [31:0]              ifu_axi_araddr;
    wire [3:0]               ifu_axi_arregion;
    wire [7:0]               ifu_axi_arlen;
    wire [2:0]               ifu_axi_arsize;
    wire [1:0]               ifu_axi_arburst;
    wire                     ifu_axi_arlock;
    wire [3:0]               ifu_axi_arcache;
    wire [2:0]               ifu_axi_arprot;
    wire [3:0]               ifu_axi_arqos;
    wire                     ifu_axi_rvalid,  ifu_axi_rready;
    wire [3:0]               ifu_axi_rid;
    wire [63:0]              ifu_axi_rdata;
    wire [1:0]               ifu_axi_rresp;
    wire                     ifu_axi_rlast;

    // --- SB / DMA (tied off) ---
    wire sb_axi_awvalid, sb_axi_awready;
    wire sb_axi_wvalid,  sb_axi_wready;
    wire sb_axi_bvalid,  sb_axi_bready;
    wire sb_axi_arvalid, sb_axi_arready;
    wire sb_axi_rvalid,  sb_axi_rready;
    assign sb_axi_awready = 1'b0; assign sb_axi_wready = 1'b0;
    assign sb_axi_bvalid  = 1'b0; assign sb_axi_arready = 1'b0;
    assign sb_axi_rvalid  = 1'b0;

    wire dma_axi_awvalid, dma_axi_awready;
    wire dma_axi_wvalid,  dma_axi_wready;
    wire dma_axi_bvalid,  dma_axi_bready;
    wire dma_axi_arvalid, dma_axi_arready;
    wire dma_axi_rvalid,  dma_axi_rready;
    assign dma_axi_awvalid = 1'b0; assign dma_axi_wvalid  = 1'b0;
    assign dma_axi_bready  = 1'b0; assign dma_axi_arvalid = 1'b0;
    assign dma_axi_rready  = 1'b0;

    // =========================================================================
    // VeeR EL2 data-width adaptation
    //   VeeR: 64-bit data bus; Interconnect: 32-bit
    //   Only lower 32-bit data/strobe used for 32-bit peripheral accesses.
    // =========================================================================
    wire [31:0] lsu_axi_wdata_32 = lsu_axi_wdata[31:0];
    wire [3:0]  lsu_axi_wstrb_4  = lsu_axi_wstrb[3:0];
    wire [31:0] lsu_ic_rdata_32;
    assign lsu_axi_rdata = {32'h0, lsu_ic_rdata_32};

    wire [31:0] ifu_axi_wdata_32 = ifu_axi_wdata[31:0];
    wire [3:0]  ifu_axi_wstrb_4  = ifu_axi_wstrb[3:0];
    wire [31:0] ifu_ic_rdata_32;
    assign ifu_axi_rdata = {32'h0, ifu_ic_rdata_32};

    // =========================================================================
    // Interconnect M01..M03 wires (AXI4 from interconnect → bridges)
    // =========================================================================
    // UART (M01)
    wire [AXI_ID_WIDTH-1:0]   ic_m01_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m01_awaddr;
    wire [7:0]  ic_m01_awlen;  wire [2:0] ic_m01_awsize; wire [1:0] ic_m01_awburst;
    wire        ic_m01_awlock; wire [3:0] ic_m01_awcache; wire [2:0] ic_m01_awprot;
    wire [3:0]  ic_m01_awqos;  wire [3:0] ic_m01_awregion;
    wire        ic_m01_awvalid, ic_m01_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m01_wdata;
    wire [3:0]  ic_m01_wstrb;  wire ic_m01_wlast; wire ic_m01_wvalid; wire ic_m01_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m01_bid;
    wire [1:0]  ic_m01_bresp;  wire ic_m01_bvalid; wire ic_m01_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m01_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m01_araddr;
    wire [7:0]  ic_m01_arlen;  wire [2:0] ic_m01_arsize; wire [1:0] ic_m01_arburst;
    wire        ic_m01_arlock; wire [3:0] ic_m01_arcache; wire [2:0] ic_m01_arprot;
    wire [3:0]  ic_m01_arqos;  wire [3:0] ic_m01_arregion;
    wire        ic_m01_arvalid, ic_m01_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m01_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m01_rdata;
    wire [1:0]  ic_m01_rresp;  wire ic_m01_rlast; wire ic_m01_rvalid; wire ic_m01_rready;

    // AES (M02)
    wire [AXI_ID_WIDTH-1:0]   ic_m02_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m02_awaddr;
    wire [7:0]  ic_m02_awlen;  wire [2:0] ic_m02_awsize; wire [1:0] ic_m02_awburst;
    wire        ic_m02_awlock; wire [3:0] ic_m02_awcache; wire [2:0] ic_m02_awprot;
    wire [3:0]  ic_m02_awqos;  wire [3:0] ic_m02_awregion;
    wire        ic_m02_awvalid, ic_m02_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m02_wdata;
    wire [3:0]  ic_m02_wstrb;  wire ic_m02_wlast; wire ic_m02_wvalid; wire ic_m02_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m02_bid;
    wire [1:0]  ic_m02_bresp;  wire ic_m02_bvalid; wire ic_m02_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m02_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m02_araddr;
    wire [7:0]  ic_m02_arlen;  wire [2:0] ic_m02_arsize; wire [1:0] ic_m02_arburst;
    wire        ic_m02_arlock; wire [3:0] ic_m02_arcache; wire [2:0] ic_m02_arprot;
    wire [3:0]  ic_m02_arqos;  wire [3:0] ic_m02_arregion;
    wire        ic_m02_arvalid, ic_m02_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m02_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m02_rdata;
    wire [1:0]  ic_m02_rresp;  wire ic_m02_rlast; wire ic_m02_rvalid; wire ic_m02_rready;

    // I2C (M03)
    wire [AXI_ID_WIDTH-1:0]   ic_m03_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m03_awaddr;
    wire [7:0]  ic_m03_awlen;  wire [2:0] ic_m03_awsize; wire [1:0] ic_m03_awburst;
    wire        ic_m03_awlock; wire [3:0] ic_m03_awcache; wire [2:0] ic_m03_awprot;
    wire [3:0]  ic_m03_awqos;  wire [3:0] ic_m03_awregion;
    wire        ic_m03_awvalid, ic_m03_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m03_wdata;
    wire [3:0]  ic_m03_wstrb;  wire ic_m03_wlast; wire ic_m03_wvalid; wire ic_m03_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m03_bid;
    wire [1:0]  ic_m03_bresp;  wire ic_m03_bvalid; wire ic_m03_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m03_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m03_araddr;
    wire [7:0]  ic_m03_arlen;  wire [2:0] ic_m03_arsize; wire [1:0] ic_m03_arburst;
    wire        ic_m03_arlock; wire [3:0] ic_m03_arcache; wire [2:0] ic_m03_arprot;
    wire [3:0]  ic_m03_arqos;  wire [3:0] ic_m03_arregion;
    wire        ic_m03_arvalid, ic_m03_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m03_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m03_rdata;
    wire [1:0]  ic_m03_rresp;  wire ic_m03_rlast; wire ic_m03_rvalid; wire ic_m03_rready;

    // =========================================================================
    // AXI-Lite wires after axi4_to_axilite_bridge
    // Note: axi4_to_axilite_bridge LITE_ADDR_W=5, ID_WIDTH=12
    //       but we use ID_WIDTH=8; parameterise accordingly
    // =========================================================================
    localparam BRIDGE_ID_W    = AXI_ID_WIDTH;
    localparam BRIDGE_LITE_AW = 5;  // LITE_ADDR_W in axi4_to_axilite_bridge

    // UART AXI-Lite (output of bridge → input of axi_uart_top)
    wire [BRIDGE_ID_W-1:0]    uart_axil_awid;
    wire [BRIDGE_LITE_AW-1:0] uart_axil_awaddr;
    wire                      uart_axil_awvalid, uart_axil_awready;
    wire [31:0]               uart_axil_wdata;
    wire [3:0]                uart_axil_wstrb;
    wire                      uart_axil_wvalid, uart_axil_wready;
    wire [BRIDGE_ID_W-1:0]    uart_axil_bid;
    wire [1:0]                uart_axil_bresp;
    wire                      uart_axil_bvalid, uart_axil_bready;
    wire [BRIDGE_ID_W-1:0]    uart_axil_arid;
    wire [BRIDGE_LITE_AW-1:0] uart_axil_araddr;
    wire                      uart_axil_arvalid, uart_axil_arready;
    wire [BRIDGE_ID_W-1:0]    uart_axil_rid;
    wire [31:0]               uart_axil_rdata;
    wire [1:0]                uart_axil_rresp;
    wire                      uart_axil_rvalid, uart_axil_rready;

    // AES AXI-Lite (output of bridge → input of aes_axi_slave)
    wire [BRIDGE_ID_W-1:0]    aes_axil_awid;
    wire [BRIDGE_LITE_AW-1:0] aes_axil_awaddr;
    wire                      aes_axil_awvalid, aes_axil_awready;
    wire [31:0]               aes_axil_wdata;
    wire [3:0]                aes_axil_wstrb;
    wire                      aes_axil_wvalid, aes_axil_wready;
    wire [BRIDGE_ID_W-1:0]    aes_axil_bid;
    wire [1:0]                aes_axil_bresp;
    wire                      aes_axil_bvalid, aes_axil_bready;
    wire [BRIDGE_ID_W-1:0]    aes_axil_arid;
    wire [BRIDGE_LITE_AW-1:0] aes_axil_araddr;
    wire                      aes_axil_arvalid, aes_axil_arready;
    wire [BRIDGE_ID_W-1:0]    aes_axil_rid;
    wire [31:0]               aes_axil_rdata;
    wire [1:0]                aes_axil_rresp;
    wire                      aes_axil_rvalid, aes_axil_rready;

    // I2C AXI-Lite (output of bridge → wb_to_axilite_bridge)
    wire [BRIDGE_ID_W-1:0]    i2c_axil_awid;
    wire [BRIDGE_LITE_AW-1:0] i2c_axil_awaddr;
    wire                      i2c_axil_awvalid, i2c_axil_awready;
    wire [31:0]               i2c_axil_wdata;
    wire [3:0]                i2c_axil_wstrb;
    wire                      i2c_axil_wvalid, i2c_axil_wready;
    wire [BRIDGE_ID_W-1:0]    i2c_axil_bid;
    wire [1:0]                i2c_axil_bresp;
    wire                      i2c_axil_bvalid, i2c_axil_bready;
    wire [BRIDGE_ID_W-1:0]    i2c_axil_arid;
    wire [BRIDGE_LITE_AW-1:0] i2c_axil_araddr;
    wire                      i2c_axil_arvalid, i2c_axil_arready;
    wire [BRIDGE_ID_W-1:0]    i2c_axil_rid;
    wire [31:0]               i2c_axil_rdata;
    wire [1:0]                i2c_axil_rresp;
    wire                      i2c_axil_rvalid, i2c_axil_rready;

    // WB master wires (from wb_to_axilite_bridge → i2c_master_top)
    wire [2:0]  i2c_wb_adr;
    wire [7:0]  i2c_wb_dat_w;
    wire [7:0]  i2c_wb_dat_r;
    wire        i2c_wb_we;
    wire        i2c_wb_stb;
    wire        i2c_wb_cyc;
    wire        i2c_wb_ack;
    wire        i2c_irq;

    // VeeR clock enables
    wire lsu_bus_clk_en = 1'b1;
    wire ifu_bus_clk_en = 1'b1;
    wire dbg_bus_clk_en = 1'b1;
    wire dma_bus_clk_en = 1'b1;

    // el2_mem_if interface
    el2_mem_if el2_mem_export_if();

    // =========================================================================
    // 1.  VeeR EL2 RISC-V Core
    // =========================================================================
    el2_veer_wrapper u_veer (
        .clk                        (clk),
        .rst_l                      (rst_l),
        .dbg_rst_l                  (rst_l),
        .rst_vec                    (VEER_RESET_VEC),
        .nmi_int                    (1'b0),
        .nmi_vec                    (VEER_NMI_VEC),
        .jtag_id                    (VEER_JTAG_ID),

        // Trace (unused)
        .trace_rv_i_insn_ip         (),
        .trace_rv_i_address_ip      (),
        .trace_rv_i_valid_ip        (),
        .trace_rv_i_exception_ip    (),
        .trace_rv_i_ecause_ip       (),
        .trace_rv_i_interrupt_ip    (),
        .trace_rv_i_tval_ip         (),

        // LSU AXI4 master
        .lsu_axi_awvalid            (lsu_axi_awvalid),
        .lsu_axi_awready            (lsu_axi_awready),
        .lsu_axi_awid               (lsu_axi_awid),
        .lsu_axi_awaddr             (lsu_axi_awaddr),
        .lsu_axi_awregion           (lsu_axi_awregion),
        .lsu_axi_awlen              (lsu_axi_awlen),
        .lsu_axi_awsize             (lsu_axi_awsize),
        .lsu_axi_awburst            (lsu_axi_awburst),
        .lsu_axi_awlock             (lsu_axi_awlock),
        .lsu_axi_awcache            (lsu_axi_awcache),
        .lsu_axi_awprot             (lsu_axi_awprot),
        .lsu_axi_awqos              (lsu_axi_awqos),
        .lsu_axi_wvalid             (lsu_axi_wvalid),
        .lsu_axi_wready             (lsu_axi_wready),
        .lsu_axi_wdata              (lsu_axi_wdata),
        .lsu_axi_wstrb              (lsu_axi_wstrb),
        .lsu_axi_wlast              (lsu_axi_wlast),
        .lsu_axi_bvalid             (lsu_axi_bvalid),
        .lsu_axi_bready             (lsu_axi_bready),
        .lsu_axi_bresp              (lsu_axi_bresp),
        .lsu_axi_bid                (lsu_axi_bid),
        .lsu_axi_arvalid            (lsu_axi_arvalid),
        .lsu_axi_arready            (lsu_axi_arready),
        .lsu_axi_arid               (lsu_axi_arid),
        .lsu_axi_araddr             (lsu_axi_araddr),
        .lsu_axi_arregion           (lsu_axi_arregion),
        .lsu_axi_arlen              (lsu_axi_arlen),
        .lsu_axi_arsize             (lsu_axi_arsize),
        .lsu_axi_arburst            (lsu_axi_arburst),
        .lsu_axi_arlock             (lsu_axi_arlock),
        .lsu_axi_arcache            (lsu_axi_arcache),
        .lsu_axi_arprot             (lsu_axi_arprot),
        .lsu_axi_arqos              (lsu_axi_arqos),
        .lsu_axi_rvalid             (lsu_axi_rvalid),
        .lsu_axi_rready             (lsu_axi_rready),
        .lsu_axi_rid                (lsu_axi_rid),
        .lsu_axi_rdata              (lsu_axi_rdata),
        .lsu_axi_rresp              (lsu_axi_rresp),
        .lsu_axi_rlast              (lsu_axi_rlast),

        // IFU AXI4 master
        .ifu_axi_awvalid            (ifu_axi_awvalid),
        .ifu_axi_awready            (ifu_axi_awready),
        .ifu_axi_awid               (ifu_axi_awid),
        .ifu_axi_awaddr             (ifu_axi_awaddr),
        .ifu_axi_awregion           (ifu_axi_awregion),
        .ifu_axi_awlen              (ifu_axi_awlen),
        .ifu_axi_awsize             (ifu_axi_awsize),
        .ifu_axi_awburst            (ifu_axi_awburst),
        .ifu_axi_awlock             (ifu_axi_awlock),
        .ifu_axi_awcache            (ifu_axi_awcache),
        .ifu_axi_awprot             (ifu_axi_awprot),
        .ifu_axi_awqos              (ifu_axi_awqos),
        .ifu_axi_wvalid             (ifu_axi_wvalid),
        .ifu_axi_wready             (ifu_axi_wready),
        .ifu_axi_wdata              (ifu_axi_wdata),
        .ifu_axi_wstrb              (ifu_axi_wstrb),
        .ifu_axi_wlast              (ifu_axi_wlast),
        .ifu_axi_bvalid             (ifu_axi_bvalid),
        .ifu_axi_bready             (ifu_axi_bready),
        .ifu_axi_bresp              (ifu_axi_bresp),
        .ifu_axi_bid                (ifu_axi_bid),
        .ifu_axi_arvalid            (ifu_axi_arvalid),
        .ifu_axi_arready            (ifu_axi_arready),
        .ifu_axi_arid               (ifu_axi_arid),
        .ifu_axi_araddr             (ifu_axi_araddr),
        .ifu_axi_arregion           (ifu_axi_arregion),
        .ifu_axi_arlen              (ifu_axi_arlen),
        .ifu_axi_arsize             (ifu_axi_arsize),
        .ifu_axi_arburst            (ifu_axi_arburst),
        .ifu_axi_arlock             (ifu_axi_arlock),
        .ifu_axi_arcache            (ifu_axi_arcache),
        .ifu_axi_arprot             (ifu_axi_arprot),
        .ifu_axi_arqos              (ifu_axi_arqos),
        .ifu_axi_rvalid             (ifu_axi_rvalid),
        .ifu_axi_rready             (ifu_axi_rready),
        .ifu_axi_rid                (ifu_axi_rid),
        .ifu_axi_rdata              (ifu_axi_rdata),
        .ifu_axi_rresp              (ifu_axi_rresp),
        .ifu_axi_rlast              (ifu_axi_rlast),

        // SB AXI4 master (debug, tied off)
        .sb_axi_awvalid             (sb_axi_awvalid),
        .sb_axi_awready             (sb_axi_awready),
        .sb_axi_awid                (), .sb_axi_awaddr  (),
        .sb_axi_awregion            (), .sb_axi_awlen   (),
        .sb_axi_awsize              (), .sb_axi_awburst (),
        .sb_axi_awlock              (), .sb_axi_awcache (),
        .sb_axi_awprot              (), .sb_axi_awqos   (),
        .sb_axi_wvalid              (sb_axi_wvalid),
        .sb_axi_wready              (sb_axi_wready),
        .sb_axi_wdata               (), .sb_axi_wstrb   (), .sb_axi_wlast (),
        .sb_axi_bvalid              (sb_axi_bvalid),
        .sb_axi_bready              (sb_axi_bready),
        .sb_axi_bresp               (2'b00), .sb_axi_bid (4'h0),
        .sb_axi_arvalid             (sb_axi_arvalid),
        .sb_axi_arready             (sb_axi_arready),
        .sb_axi_arid                (), .sb_axi_araddr  (),
        .sb_axi_arregion            (), .sb_axi_arlen   (),
        .sb_axi_arsize              (), .sb_axi_arburst (),
        .sb_axi_arlock              (), .sb_axi_arcache (),
        .sb_axi_arprot              (), .sb_axi_arqos   (),
        .sb_axi_rvalid              (sb_axi_rvalid),
        .sb_axi_rready              (sb_axi_rready),
        .sb_axi_rid                 (4'h0),  .sb_axi_rdata (64'h0),
        .sb_axi_rresp               (2'b00), .sb_axi_rlast (1'b0),

        // DMA AXI4 slave (tied off)
        .dma_axi_awvalid            (dma_axi_awvalid),
        .dma_axi_awready            (dma_axi_awready),
        .dma_axi_awid               (1'b0), .dma_axi_awaddr (32'h0),
        .dma_axi_awsize             (3'h0), .dma_axi_awprot (3'h0),
        .dma_axi_awlen              (8'h0), .dma_axi_awburst (2'h0),
        .dma_axi_wvalid             (dma_axi_wvalid),
        .dma_axi_wready             (dma_axi_wready),
        .dma_axi_wdata              (64'h0), .dma_axi_wstrb (8'h0), .dma_axi_wlast (1'b0),
        .dma_axi_bvalid             (dma_axi_bvalid),
        .dma_axi_bready             (dma_axi_bready),
        .dma_axi_bresp              (), .dma_axi_bid (),
        .dma_axi_arvalid            (dma_axi_arvalid),
        .dma_axi_arready            (dma_axi_arready),
        .dma_axi_arid               (1'b0), .dma_axi_araddr (32'h0),
        .dma_axi_arsize             (3'h0), .dma_axi_arprot (3'h0),
        .dma_axi_arlen              (8'h0), .dma_axi_arburst (2'h0),
        .dma_axi_rvalid             (dma_axi_rvalid),
        .dma_axi_rready             (dma_axi_rready),
        .dma_axi_rid                (), .dma_axi_rdata (),
        .dma_axi_rresp              (), .dma_axi_rlast (),

        // Clock enables
        .lsu_bus_clk_en             (lsu_bus_clk_en),
        .ifu_bus_clk_en             (ifu_bus_clk_en),
        .dbg_bus_clk_en             (dbg_bus_clk_en),
        .dma_bus_clk_en             (dma_bus_clk_en),

        // ECC (unused)
        .iccm_ecc_single_error      (), .iccm_ecc_double_error (),
        .dccm_ecc_single_error      (), .dccm_ecc_double_error (),
        .dccm_write_readback_error  (),

        // Performance counters (unused)
        .dec_tlu_perfcnt0           (), .dec_tlu_perfcnt1 (),
        .dec_tlu_perfcnt2           (), .dec_tlu_perfcnt3 (),

        // JTAG
        .jtag_tck                   (jtag_tck),
        .jtag_tms                   (jtag_tms),
        .jtag_tdi                   (jtag_tdi),
        .jtag_trst_n                (jtag_trst_n),
        .jtag_tdo                   (jtag_tdo),
        .jtag_tdoEn                 (jtag_tdoEn),

        // Core ID
        .core_id                    (VEER_CORE_ID),

        // On-chip memory export
        .el2_mem_export             (el2_mem_export_if.veer_sram_src),

        // MPC halt/run
        .mpc_debug_halt_req         (1'b0), .mpc_debug_run_req  (1'b1),
        .mpc_reset_run_req          (1'b1), .mpc_debug_halt_ack (),
        .mpc_debug_run_ack          (), .debug_brkpt_status (),
        .i_cpu_halt_req             (1'b0), .o_cpu_halt_ack     (),
        .o_cpu_halt_status          (), .o_debug_mode_status (),
        .i_cpu_run_req              (1'b0), .o_cpu_run_ack      (),

        // Scan / MBIST
        .scan_mode                  (1'b0),
        .mbist_mode                 (1'b0),

        // DMI uncore (unused)
        .dmi_core_enable            (1'b1),
        .dmi_uncore_enable          (1'b0),
        .dmi_uncore_en              (), .dmi_uncore_wr_en   (),
        .dmi_uncore_addr            (), .dmi_uncore_wdata   (),
        .dmi_uncore_rdata           (32'h0), .dmi_active   ()
    );

    // =========================================================================
    // 2.  VeeR On-Chip Memories (ICCM / DCCM)
    // =========================================================================
    el2_mem u_el2_mem (
        .clk             (clk),
        .rst_l           (rst_l),
        .el2_mem_export  (el2_mem_export_if.veer_sram_src)
    );

    // =========================================================================
    // 3.  AXI4 Interconnect  (2 slave ports, 11 master ports)
    // =========================================================================

    // Stub signals for reserved master ports M04..M10
    wire m04_awrdy=1'b0, m04_wrdy=1'b0, m04_bvld=1'b0, m04_arrdy=1'b0, m04_rvld=1'b0;
    wire m05_awrdy=1'b0, m05_wrdy=1'b0, m05_bvld=1'b0, m05_arrdy=1'b0, m05_rvld=1'b0;
    wire m06_awrdy=1'b0, m06_wrdy=1'b0, m06_bvld=1'b0, m06_arrdy=1'b0, m06_rvld=1'b0;
    wire m07_awrdy=1'b0, m07_wrdy=1'b0, m07_bvld=1'b0, m07_arrdy=1'b0, m07_rvld=1'b0;
    wire m08_awrdy=1'b0, m08_wrdy=1'b0, m08_bvld=1'b0, m08_arrdy=1'b0, m08_rvld=1'b0;
    wire m09_awrdy=1'b0, m09_wrdy=1'b0, m09_bvld=1'b0, m09_arrdy=1'b0, m09_rvld=1'b0;
    wire m10_awrdy=1'b0, m10_wrdy=1'b0, m10_bvld=1'b0, m10_arrdy=1'b0, m10_rvld=1'b0;

    axi_interconnect_wrap_2x11 #(
        .DATA_WIDTH     (AXI_DATA_WIDTH),
        .ADDR_WIDTH     (AXI_ADDR_WIDTH),
        .ID_WIDTH       (AXI_ID_WIDTH),
        .M00_BASE_ADDR  (32'h0000_0000), .M00_ADDR_WIDTH ({1{32'd28}}),
        .M01_BASE_ADDR  (UART_BASE_ADDR),.M01_ADDR_WIDTH ({1{PERIPH_ADDR_WIN}}),
        .M02_BASE_ADDR  (AES_BASE_ADDR), .M02_ADDR_WIDTH ({1{PERIPH_ADDR_WIN}}),
        .M03_BASE_ADDR  (I2C_BASE_ADDR), .M03_ADDR_WIDTH ({1{PERIPH_ADDR_WIN}}),
        .M04_BASE_ADDR  (32'h4000_0000), .M04_ADDR_WIDTH ({1{32'd12}}),
        .M05_BASE_ADDR  (32'h5000_0000), .M05_ADDR_WIDTH ({1{32'd12}}),
        .M06_BASE_ADDR  (32'h6000_0000), .M06_ADDR_WIDTH ({1{32'd12}}),
        .M07_BASE_ADDR  (32'h7000_0000), .M07_ADDR_WIDTH ({1{32'd12}}),
        .M08_BASE_ADDR  (32'h8000_0000), .M08_ADDR_WIDTH ({1{32'd12}}),
        .M09_BASE_ADDR  (32'h9000_0000), .M09_ADDR_WIDTH ({1{32'd12}}),
        .M10_BASE_ADDR  (32'hA000_0000), .M10_ADDR_WIDTH ({1{32'd12}})
    ) u_interconnect (
        .clk             (clk),
        .rst             (rst_ah),  // active-high reset

        // Slave port 0: VeeR LSU
        .s00_axi_awid    (lsu_axi_awid[AXI_ID_WIDTH-1:0]),
        .s00_axi_awaddr  (lsu_axi_awaddr),
        .s00_axi_awlen   (lsu_axi_awlen),
        .s00_axi_awsize  (lsu_axi_awsize),
        .s00_axi_awburst (lsu_axi_awburst),
        .s00_axi_awlock  (lsu_axi_awlock),
        .s00_axi_awcache (lsu_axi_awcache),
        .s00_axi_awprot  (lsu_axi_awprot),
        .s00_axi_awqos   (lsu_axi_awqos),
        .s00_axi_awvalid (lsu_axi_awvalid),
        .s00_axi_awready (lsu_axi_awready),
        .s00_axi_wdata   (lsu_axi_wdata_32),
        .s00_axi_wstrb   (lsu_axi_wstrb_4),
        .s00_axi_wlast   (lsu_axi_wlast),
        .s00_axi_wvalid  (lsu_axi_wvalid),
        .s00_axi_wready  (lsu_axi_wready),
        .s00_axi_bid     (lsu_axi_bid[AXI_ID_WIDTH-1:0]),
        .s00_axi_bresp   (lsu_axi_bresp),
        .s00_axi_bvalid  (lsu_axi_bvalid),
        .s00_axi_bready  (lsu_axi_bready),
        .s00_axi_arid    (lsu_axi_arid[AXI_ID_WIDTH-1:0]),
        .s00_axi_araddr  (lsu_axi_araddr),
        .s00_axi_arlen   (lsu_axi_arlen),
        .s00_axi_arsize  (lsu_axi_arsize),
        .s00_axi_arburst (lsu_axi_arburst),
        .s00_axi_arlock  (lsu_axi_arlock),
        .s00_axi_arcache (lsu_axi_arcache),
        .s00_axi_arprot  (lsu_axi_arprot),
        .s00_axi_arqos   (lsu_axi_arqos),
        .s00_axi_arvalid (lsu_axi_arvalid),
        .s00_axi_arready (lsu_axi_arready),
        .s00_axi_rid     (lsu_axi_rid[AXI_ID_WIDTH-1:0]),
        .s00_axi_rdata   (lsu_ic_rdata_32),
        .s00_axi_rresp   (lsu_axi_rresp),
        .s00_axi_rlast   (lsu_axi_rlast),
        .s00_axi_rvalid  (lsu_axi_rvalid),
        .s00_axi_rready  (lsu_axi_rready),

        // Slave port 1: VeeR IFU
        .s01_axi_awid    (ifu_axi_awid[AXI_ID_WIDTH-1:0]),
        .s01_axi_awaddr  (ifu_axi_awaddr),
        .s01_axi_awlen   (ifu_axi_awlen),
        .s01_axi_awsize  (ifu_axi_awsize),
        .s01_axi_awburst (ifu_axi_awburst),
        .s01_axi_awlock  (ifu_axi_awlock),
        .s01_axi_awcache (ifu_axi_awcache),
        .s01_axi_awprot  (ifu_axi_awprot),
        .s01_axi_awqos   (ifu_axi_awqos),
        .s01_axi_awvalid (ifu_axi_awvalid),
        .s01_axi_awready (ifu_axi_awready),
        .s01_axi_wdata   (ifu_axi_wdata_32),
        .s01_axi_wstrb   (ifu_axi_wstrb_4),
        .s01_axi_wlast   (ifu_axi_wlast),
        .s01_axi_wvalid  (ifu_axi_wvalid),
        .s01_axi_wready  (ifu_axi_wready),
        .s01_axi_bid     (ifu_axi_bid[AXI_ID_WIDTH-1:0]),
        .s01_axi_bresp   (ifu_axi_bresp),
        .s01_axi_bvalid  (ifu_axi_bvalid),
        .s01_axi_bready  (ifu_axi_bready),
        .s01_axi_arid    (ifu_axi_arid[AXI_ID_WIDTH-1:0]),
        .s01_axi_araddr  (ifu_axi_araddr),
        .s01_axi_arlen   (ifu_axi_arlen),
        .s01_axi_arsize  (ifu_axi_arsize),
        .s01_axi_arburst (ifu_axi_arburst),
        .s01_axi_arlock  (ifu_axi_arlock),
        .s01_axi_arcache (ifu_axi_arcache),
        .s01_axi_arprot  (ifu_axi_arprot),
        .s01_axi_arqos   (ifu_axi_arqos),
        .s01_axi_arvalid (ifu_axi_arvalid),
        .s01_axi_arready (ifu_axi_arready),
        .s01_axi_rid     (ifu_axi_rid[AXI_ID_WIDTH-1:0]),
        .s01_axi_rdata   (ifu_ic_rdata_32),
        .s01_axi_rresp   (ifu_axi_rresp),
        .s01_axi_rlast   (ifu_axi_rlast),
        .s01_axi_rvalid  (ifu_axi_rvalid),
        .s01_axi_rready  (ifu_axi_rready),

        // Master port 0: External SRAM
        .m00_axi_awid    (mem_axi_awid),   .m00_axi_awaddr  (mem_axi_awaddr),
        .m00_axi_awlen   (mem_axi_awlen),  .m00_axi_awsize  (mem_axi_awsize),
        .m00_axi_awburst (mem_axi_awburst),.m00_axi_awlock  (mem_axi_awlock),
        .m00_axi_awcache (mem_axi_awcache),.m00_axi_awprot  (mem_axi_awprot),
        .m00_axi_awqos   (mem_axi_awqos),  .m00_axi_awvalid (mem_axi_awvalid),
        .m00_axi_awready (mem_axi_awready),
        .m00_axi_wdata   (mem_axi_wdata),  .m00_axi_wstrb   (mem_axi_wstrb),
        .m00_axi_wlast   (mem_axi_wlast),  .m00_axi_wvalid  (mem_axi_wvalid),
        .m00_axi_wready  (mem_axi_wready),
        .m00_axi_bid     (mem_axi_bid),    .m00_axi_bresp   (mem_axi_bresp),
        .m00_axi_bvalid  (mem_axi_bvalid), .m00_axi_bready  (mem_axi_bready),
        .m00_axi_arid    (mem_axi_arid),   .m00_axi_araddr  (mem_axi_araddr),
        .m00_axi_arlen   (mem_axi_arlen),  .m00_axi_arsize  (mem_axi_arsize),
        .m00_axi_arburst (mem_axi_arburst),.m00_axi_arlock  (mem_axi_arlock),
        .m00_axi_arcache (mem_axi_arcache),.m00_axi_arprot  (mem_axi_arprot),
        .m00_axi_arqos   (mem_axi_arqos),  .m00_axi_arvalid (mem_axi_arvalid),
        .m00_axi_arready (mem_axi_arready),
        .m00_axi_rid     (mem_axi_rid),    .m00_axi_rdata   (mem_axi_rdata),
        .m00_axi_rresp   (mem_axi_rresp),  .m00_axi_rlast   (mem_axi_rlast),
        .m00_axi_rvalid  (mem_axi_rvalid), .m00_axi_rready  (mem_axi_rready),

        // Master port 1: UART
        .m01_axi_awid    (ic_m01_awid),    .m01_axi_awaddr  (ic_m01_awaddr),
        .m01_axi_awlen   (ic_m01_awlen),   .m01_axi_awsize  (ic_m01_awsize),
        .m01_axi_awburst (ic_m01_awburst), .m01_axi_awlock  (ic_m01_awlock),
        .m01_axi_awcache (ic_m01_awcache), .m01_axi_awprot  (ic_m01_awprot),
        .m01_axi_awqos   (ic_m01_awqos),   .m01_axi_awvalid (ic_m01_awvalid),
        .m01_axi_awready (ic_m01_awready),
        .m01_axi_wdata   (ic_m01_wdata),   .m01_axi_wstrb   (ic_m01_wstrb),
        .m01_axi_wlast   (ic_m01_wlast),   .m01_axi_wvalid  (ic_m01_wvalid),
        .m01_axi_wready  (ic_m01_wready),
        .m01_axi_bid     (ic_m01_bid),     .m01_axi_bresp   (ic_m01_bresp),
        .m01_axi_bvalid  (ic_m01_bvalid),  .m01_axi_bready  (ic_m01_bready),
        .m01_axi_arid    (ic_m01_arid),    .m01_axi_araddr  (ic_m01_araddr),
        .m01_axi_arlen   (ic_m01_arlen),   .m01_axi_arsize  (ic_m01_arsize),
        .m01_axi_arburst (ic_m01_arburst), .m01_axi_arlock  (ic_m01_arlock),
        .m01_axi_arcache (ic_m01_arcache), .m01_axi_arprot  (ic_m01_arprot),
        .m01_axi_arqos   (ic_m01_arqos),   .m01_axi_arvalid (ic_m01_arvalid),
        .m01_axi_arready (ic_m01_arready),
        .m01_axi_rid     (ic_m01_rid),     .m01_axi_rdata   (ic_m01_rdata),
        .m01_axi_rresp   (ic_m01_rresp),   .m01_axi_rlast   (ic_m01_rlast),
        .m01_axi_rvalid  (ic_m01_rvalid),  .m01_axi_rready  (ic_m01_rready),

        // Master port 2: AES
        .m02_axi_awid    (ic_m02_awid),    .m02_axi_awaddr  (ic_m02_awaddr),
        .m02_axi_awlen   (ic_m02_awlen),   .m02_axi_awsize  (ic_m02_awsize),
        .m02_axi_awburst (ic_m02_awburst), .m02_axi_awlock  (ic_m02_awlock),
        .m02_axi_awcache (ic_m02_awcache), .m02_axi_awprot  (ic_m02_awprot),
        .m02_axi_awqos   (ic_m02_awqos),   .m02_axi_awvalid (ic_m02_awvalid),
        .m02_axi_awready (ic_m02_awready),
        .m02_axi_wdata   (ic_m02_wdata),   .m02_axi_wstrb   (ic_m02_wstrb),
        .m02_axi_wlast   (ic_m02_wlast),   .m02_axi_wvalid  (ic_m02_wvalid),
        .m02_axi_wready  (ic_m02_wready),
        .m02_axi_bid     (ic_m02_bid),     .m02_axi_bresp   (ic_m02_bresp),
        .m02_axi_bvalid  (ic_m02_bvalid),  .m02_axi_bready  (ic_m02_bready),
        .m02_axi_arid    (ic_m02_arid),    .m02_axi_araddr  (ic_m02_araddr),
        .m02_axi_arlen   (ic_m02_arlen),   .m02_axi_arsize  (ic_m02_arsize),
        .m02_axi_arburst (ic_m02_arburst), .m02_axi_arlock  (ic_m02_arlock),
        .m02_axi_arcache (ic_m02_arcache), .m02_axi_arprot  (ic_m02_arprot),
        .m02_axi_arqos   (ic_m02_arqos),   .m02_axi_arvalid (ic_m02_arvalid),
        .m02_axi_arready (ic_m02_arready),
        .m02_axi_rid     (ic_m02_rid),     .m02_axi_rdata   (ic_m02_rdata),
        .m02_axi_rresp   (ic_m02_rresp),   .m02_axi_rlast   (ic_m02_rlast),
        .m02_axi_rvalid  (ic_m02_rvalid),  .m02_axi_rready  (ic_m02_rready),

        // Master port 3: I2C
        .m03_axi_awid    (ic_m03_awid),    .m03_axi_awaddr  (ic_m03_awaddr),
        .m03_axi_awlen   (ic_m03_awlen),   .m03_axi_awsize  (ic_m03_awsize),
        .m03_axi_awburst (ic_m03_awburst), .m03_axi_awlock  (ic_m03_awlock),
        .m03_axi_awcache (ic_m03_awcache), .m03_axi_awprot  (ic_m03_awprot),
        .m03_axi_awqos   (ic_m03_awqos),   .m03_axi_awvalid (ic_m03_awvalid),
        .m03_axi_awready (ic_m03_awready),
        .m03_axi_wdata   (ic_m03_wdata),   .m03_axi_wstrb   (ic_m03_wstrb),
        .m03_axi_wlast   (ic_m03_wlast),   .m03_axi_wvalid  (ic_m03_wvalid),
        .m03_axi_wready  (ic_m03_wready),
        .m03_axi_bid     (ic_m03_bid),     .m03_axi_bresp   (ic_m03_bresp),
        .m03_axi_bvalid  (ic_m03_bvalid),  .m03_axi_bready  (ic_m03_bready),
        .m03_axi_arid    (ic_m03_arid),    .m03_axi_araddr  (ic_m03_araddr),
        .m03_axi_arlen   (ic_m03_arlen),   .m03_axi_arsize  (ic_m03_arsize),
        .m03_axi_arburst (ic_m03_arburst), .m03_axi_arlock  (ic_m03_arlock),
        .m03_axi_arcache (ic_m03_arcache), .m03_axi_arprot  (ic_m03_arprot),
        .m03_axi_arqos   (ic_m03_arqos),   .m03_axi_arvalid (ic_m03_arvalid),
        .m03_axi_arready (ic_m03_arready),
        .m03_axi_rid     (ic_m03_rid),     .m03_axi_rdata   (ic_m03_rdata),
        .m03_axi_rresp   (ic_m03_rresp),   .m03_axi_rlast   (ic_m03_rlast),
        .m03_axi_rvalid  (ic_m03_rvalid),  .m03_axi_rready  (ic_m03_rready),

        // Master ports 4..10: reserved (DECERR stub)
        .m04_axi_awvalid(), .m04_axi_awready(m04_awrdy), .m04_axi_awid(),
        .m04_axi_awaddr(), .m04_axi_awlen(), .m04_axi_awsize(),
        .m04_axi_awburst(), .m04_axi_awlock(), .m04_axi_awcache(),
        .m04_axi_awprot(), .m04_axi_awqos(),
        .m04_axi_wvalid(), .m04_axi_wready(m04_wrdy), .m04_axi_wdata(),
        .m04_axi_wstrb(), .m04_axi_wlast(),
        .m04_axi_bvalid(m04_bvld), .m04_axi_bready(),
        .m04_axi_bid(8'h0), .m04_axi_bresp(2'b10),
        .m04_axi_arvalid(), .m04_axi_arready(m04_arrdy), .m04_axi_arid(),
        .m04_axi_araddr(), .m04_axi_arlen(), .m04_axi_arsize(),
        .m04_axi_arburst(), .m04_axi_arlock(), .m04_axi_arcache(),
        .m04_axi_arprot(), .m04_axi_arqos(),
        .m04_axi_rvalid(m04_rvld), .m04_axi_rready(),
        .m04_axi_rid(8'h0), .m04_axi_rdata(32'h0),
        .m04_axi_rresp(2'b10), .m04_axi_rlast(1'b1),

        .m05_axi_awvalid(), .m05_axi_awready(m05_awrdy), .m05_axi_awid(),
        .m05_axi_awaddr(), .m05_axi_awlen(), .m05_axi_awsize(),
        .m05_axi_awburst(), .m05_axi_awlock(), .m05_axi_awcache(),
        .m05_axi_awprot(), .m05_axi_awqos(),
        .m05_axi_wvalid(), .m05_axi_wready(m05_wrdy), .m05_axi_wdata(),
        .m05_axi_wstrb(), .m05_axi_wlast(),
        .m05_axi_bvalid(m05_bvld), .m05_axi_bready(),
        .m05_axi_bid(8'h0), .m05_axi_bresp(2'b10),
        .m05_axi_arvalid(), .m05_axi_arready(m05_arrdy), .m05_axi_arid(),
        .m05_axi_araddr(), .m05_axi_arlen(), .m05_axi_arsize(),
        .m05_axi_arburst(), .m05_axi_arlock(), .m05_axi_arcache(),
        .m05_axi_arprot(), .m05_axi_arqos(),
        .m05_axi_rvalid(m05_rvld), .m05_axi_rready(),
        .m05_axi_rid(8'h0), .m05_axi_rdata(32'h0),
        .m05_axi_rresp(2'b10), .m05_axi_rlast(1'b1),

        .m06_axi_awvalid(), .m06_axi_awready(m06_awrdy), .m06_axi_awid(),
        .m06_axi_awaddr(), .m06_axi_awlen(), .m06_axi_awsize(),
        .m06_axi_awburst(), .m06_axi_awlock(), .m06_axi_awcache(),
        .m06_axi_awprot(), .m06_axi_awqos(),
        .m06_axi_wvalid(), .m06_axi_wready(m06_wrdy), .m06_axi_wdata(),
        .m06_axi_wstrb(), .m06_axi_wlast(),
        .m06_axi_bvalid(m06_bvld), .m06_axi_bready(),
        .m06_axi_bid(8'h0), .m06_axi_bresp(2'b10),
        .m06_axi_arvalid(), .m06_axi_arready(m06_arrdy), .m06_axi_arid(),
        .m06_axi_araddr(), .m06_axi_arlen(), .m06_axi_arsize(),
        .m06_axi_arburst(), .m06_axi_arlock(), .m06_axi_arcache(),
        .m06_axi_arprot(), .m06_axi_arqos(),
        .m06_axi_rvalid(m06_rvld), .m06_axi_rready(),
        .m06_axi_rid(8'h0), .m06_axi_rdata(32'h0),
        .m06_axi_rresp(2'b10), .m06_axi_rlast(1'b1),

        .m07_axi_awvalid(), .m07_axi_awready(m07_awrdy), .m07_axi_awid(),
        .m07_axi_awaddr(), .m07_axi_awlen(), .m07_axi_awsize(),
        .m07_axi_awburst(), .m07_axi_awlock(), .m07_axi_awcache(),
        .m07_axi_awprot(), .m07_axi_awqos(),
        .m07_axi_wvalid(), .m07_axi_wready(m07_wrdy), .m07_axi_wdata(),
        .m07_axi_wstrb(), .m07_axi_wlast(),
        .m07_axi_bvalid(m07_bvld), .m07_axi_bready(),
        .m07_axi_bid(8'h0), .m07_axi_bresp(2'b10),
        .m07_axi_arvalid(), .m07_axi_arready(m07_arrdy), .m07_axi_arid(),
        .m07_axi_araddr(), .m07_axi_arlen(), .m07_axi_arsize(),
        .m07_axi_arburst(), .m07_axi_arlock(), .m07_axi_arcache(),
        .m07_axi_arprot(), .m07_axi_arqos(),
        .m07_axi_rvalid(m07_rvld), .m07_axi_rready(),
        .m07_axi_rid(8'h0), .m07_axi_rdata(32'h0),
        .m07_axi_rresp(2'b10), .m07_axi_rlast(1'b1),

        .m08_axi_awvalid(), .m08_axi_awready(m08_awrdy), .m08_axi_awid(),
        .m08_axi_awaddr(), .m08_axi_awlen(), .m08_axi_awsize(),
        .m08_axi_awburst(), .m08_axi_awlock(), .m08_axi_awcache(),
        .m08_axi_awprot(), .m08_axi_awqos(),
        .m08_axi_wvalid(), .m08_axi_wready(m08_wrdy), .m08_axi_wdata(),
        .m08_axi_wstrb(), .m08_axi_wlast(),
        .m08_axi_bvalid(m08_bvld), .m08_axi_bready(),
        .m08_axi_bid(8'h0), .m08_axi_bresp(2'b10),
        .m08_axi_arvalid(), .m08_axi_arready(m08_arrdy), .m08_axi_arid(),
        .m08_axi_araddr(), .m08_axi_arlen(), .m08_axi_arsize(),
        .m08_axi_arburst(), .m08_axi_arlock(), .m08_axi_arcache(),
        .m08_axi_arprot(), .m08_axi_arqos(),
        .m08_axi_rvalid(m08_rvld), .m08_axi_rready(),
        .m08_axi_rid(8'h0), .m08_axi_rdata(32'h0),
        .m08_axi_rresp(2'b10), .m08_axi_rlast(1'b1),

        .m09_axi_awvalid(), .m09_axi_awready(m09_awrdy), .m09_axi_awid(),
        .m09_axi_awaddr(), .m09_axi_awlen(), .m09_axi_awsize(),
        .m09_axi_awburst(), .m09_axi_awlock(), .m09_axi_awcache(),
        .m09_axi_awprot(), .m09_axi_awqos(),
        .m09_axi_wvalid(), .m09_axi_wready(m09_wrdy), .m09_axi_wdata(),
        .m09_axi_wstrb(), .m09_axi_wlast(),
        .m09_axi_bvalid(m09_bvld), .m09_axi_bready(),
        .m09_axi_bid(8'h0), .m09_axi_bresp(2'b10),
        .m09_axi_arvalid(), .m09_axi_arready(m09_arrdy), .m09_axi_arid(),
        .m09_axi_araddr(), .m09_axi_arlen(), .m09_axi_arsize(),
        .m09_axi_arburst(), .m09_axi_arlock(), .m09_axi_arcache(),
        .m09_axi_arprot(), .m09_axi_arqos(),
        .m09_axi_rvalid(m09_rvld), .m09_axi_rready(),
        .m09_axi_rid(8'h0), .m09_axi_rdata(32'h0),
        .m09_axi_rresp(2'b10), .m09_axi_rlast(1'b1),

        .m10_axi_awvalid(), .m10_axi_awready(m10_awrdy), .m10_axi_awid(),
        .m10_axi_awaddr(), .m10_axi_awlen(), .m10_axi_awsize(),
        .m10_axi_awburst(), .m10_axi_awlock(), .m10_axi_awcache(),
        .m10_axi_awprot(), .m10_axi_awqos(),
        .m10_axi_wvalid(), .m10_axi_wready(m10_wrdy), .m10_axi_wdata(),
        .m10_axi_wstrb(), .m10_axi_wlast(),
        .m10_axi_bvalid(m10_bvld), .m10_axi_bready(),
        .m10_axi_bid(8'h0), .m10_axi_bresp(2'b10),
        .m10_axi_arvalid(), .m10_axi_arready(m10_arrdy), .m10_axi_arid(),
        .m10_axi_araddr(), .m10_axi_arlen(), .m10_axi_arsize(),
        .m10_axi_arburst(), .m10_axi_arlock(), .m10_axi_arcache(),
        .m10_axi_arprot(), .m10_axi_arqos(),
        .m10_axi_rvalid(m10_rvld), .m10_axi_rready(),
        .m10_axi_rid(8'h0), .m10_axi_rdata(32'h0),
        .m10_axi_rresp(2'b10), .m10_axi_rlast(1'b1)
    );

    // =========================================================================
    // 4.  AXI4-to-AXI4-Lite bridges
    //     Port: rst = active-high synchronous; LITE_ADDR_W=5; ID_WIDTH=8
    // =========================================================================

    // --- Bridge M01 → UART ---
    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (BRIDGE_LITE_AW),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_uart (
        .clk           (clk),
        .rst           (rst_ah),            // active-high
        .s_axi_awid    (ic_m01_awid),
        .s_axi_awaddr  (ic_m01_awaddr),
        .s_axi_awlen   (ic_m01_awlen),
        .s_axi_awsize  (ic_m01_awsize),
        .s_axi_awburst (ic_m01_awburst),
        .s_axi_awlock  (ic_m01_awlock),
        .s_axi_awcache (ic_m01_awcache),
        .s_axi_awprot  (ic_m01_awprot),
        .s_axi_awqos   (ic_m01_awqos),
        .s_axi_awregion(ic_m01_awregion),
        .s_axi_awvalid (ic_m01_awvalid),
        .s_axi_awready (ic_m01_awready),
        .s_axi_wdata   (ic_m01_wdata),
        .s_axi_wstrb   (ic_m01_wstrb),
        .s_axi_wlast   (ic_m01_wlast),
        .s_axi_wvalid  (ic_m01_wvalid),
        .s_axi_wready  (ic_m01_wready),
        .s_axi_bid     (ic_m01_bid),
        .s_axi_bresp   (ic_m01_bresp),
        .s_axi_bvalid  (ic_m01_bvalid),
        .s_axi_bready  (ic_m01_bready),
        .s_axi_arid    (ic_m01_arid),
        .s_axi_araddr  (ic_m01_araddr),
        .s_axi_arlen   (ic_m01_arlen),
        .s_axi_arsize  (ic_m01_arsize),
        .s_axi_arburst (ic_m01_arburst),
        .s_axi_arlock  (ic_m01_arlock),
        .s_axi_arcache (ic_m01_arcache),
        .s_axi_arprot  (ic_m01_arprot),
        .s_axi_arqos   (ic_m01_arqos),
        .s_axi_arregion(ic_m01_arregion),
        .s_axi_arvalid (ic_m01_arvalid),
        .s_axi_arready (ic_m01_arready),
        .s_axi_rid     (ic_m01_rid),
        .s_axi_rdata   (ic_m01_rdata),
        .s_axi_rresp   (ic_m01_rresp),
        .s_axi_rlast   (ic_m01_rlast),
        .s_axi_rvalid  (ic_m01_rvalid),
        .s_axi_rready  (ic_m01_rready),
        // AXI-Lite master → UART
        .m_axil_awid   (uart_axil_awid),
        .m_axil_awaddr (uart_axil_awaddr),
        .m_axil_awvalid(uart_axil_awvalid),
        .m_axil_awready(uart_axil_awready),
        .m_axil_wdata  (uart_axil_wdata),
        .m_axil_wstrb  (uart_axil_wstrb),
        .m_axil_wvalid (uart_axil_wvalid),
        .m_axil_wready (uart_axil_wready),
        .m_axil_bid    (uart_axil_bid),
        .m_axil_bresp  (uart_axil_bresp),
        .m_axil_bvalid (uart_axil_bvalid),
        .m_axil_bready (uart_axil_bready),
        .m_axil_arid   (uart_axil_arid),
        .m_axil_araddr (uart_axil_araddr),
        .m_axil_arvalid(uart_axil_arvalid),
        .m_axil_arready(uart_axil_arready),
        .m_axil_rid    (uart_axil_rid),
        .m_axil_rdata  (uart_axil_rdata),
        .m_axil_rresp  (uart_axil_rresp),
        .m_axil_rvalid (uart_axil_rvalid),
        .m_axil_rready (uart_axil_rready)
    );

    // --- Bridge M02 → AES ---
    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (BRIDGE_LITE_AW),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_aes (
        .clk           (clk),
        .rst           (rst_ah),
        .s_axi_awid    (ic_m02_awid),
        .s_axi_awaddr  (ic_m02_awaddr),
        .s_axi_awlen   (ic_m02_awlen),
        .s_axi_awsize  (ic_m02_awsize),
        .s_axi_awburst (ic_m02_awburst),
        .s_axi_awlock  (ic_m02_awlock),
        .s_axi_awcache (ic_m02_awcache),
        .s_axi_awprot  (ic_m02_awprot),
        .s_axi_awqos   (ic_m02_awqos),
        .s_axi_awregion(ic_m02_awregion),
        .s_axi_awvalid (ic_m02_awvalid),
        .s_axi_awready (ic_m02_awready),
        .s_axi_wdata   (ic_m02_wdata),
        .s_axi_wstrb   (ic_m02_wstrb),
        .s_axi_wlast   (ic_m02_wlast),
        .s_axi_wvalid  (ic_m02_wvalid),
        .s_axi_wready  (ic_m02_wready),
        .s_axi_bid     (ic_m02_bid),
        .s_axi_bresp   (ic_m02_bresp),
        .s_axi_bvalid  (ic_m02_bvalid),
        .s_axi_bready  (ic_m02_bready),
        .s_axi_arid    (ic_m02_arid),
        .s_axi_araddr  (ic_m02_araddr),
        .s_axi_arlen   (ic_m02_arlen),
        .s_axi_arsize  (ic_m02_arsize),
        .s_axi_arburst (ic_m02_arburst),
        .s_axi_arlock  (ic_m02_arlock),
        .s_axi_arcache (ic_m02_arcache),
        .s_axi_arprot  (ic_m02_arprot),
        .s_axi_arqos   (ic_m02_arqos),
        .s_axi_arregion(ic_m02_arregion),
        .s_axi_arvalid (ic_m02_arvalid),
        .s_axi_arready (ic_m02_arready),
        .s_axi_rid     (ic_m02_rid),
        .s_axi_rdata   (ic_m02_rdata),
        .s_axi_rresp   (ic_m02_rresp),
        .s_axi_rlast   (ic_m02_rlast),
        .s_axi_rvalid  (ic_m02_rvalid),
        .s_axi_rready  (ic_m02_rready),
        .m_axil_awid   (aes_axil_awid),
        .m_axil_awaddr (aes_axil_awaddr),
        .m_axil_awvalid(aes_axil_awvalid),
        .m_axil_awready(aes_axil_awready),
        .m_axil_wdata  (aes_axil_wdata),
        .m_axil_wstrb  (aes_axil_wstrb),
        .m_axil_wvalid (aes_axil_wvalid),
        .m_axil_wready (aes_axil_wready),
        .m_axil_bid    (aes_axil_bid),
        .m_axil_bresp  (aes_axil_bresp),
        .m_axil_bvalid (aes_axil_bvalid),
        .m_axil_bready (aes_axil_bready),
        .m_axil_arid   (aes_axil_arid),
        .m_axil_araddr (aes_axil_araddr),
        .m_axil_arvalid(aes_axil_arvalid),
        .m_axil_arready(aes_axil_arready),
        .m_axil_rid    (aes_axil_rid),
        .m_axil_rdata  (aes_axil_rdata),
        .m_axil_rresp  (aes_axil_rresp),
        .m_axil_rvalid (aes_axil_rvalid),
        .m_axil_rready (aes_axil_rready)
    );

    // --- Bridge M03 → wb_to_axilite_bridge ---
    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (BRIDGE_LITE_AW),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_i2c (
        .clk           (clk),
        .rst           (rst_ah),
        .s_axi_awid    (ic_m03_awid),
        .s_axi_awaddr  (ic_m03_awaddr),
        .s_axi_awlen   (ic_m03_awlen),
        .s_axi_awsize  (ic_m03_awsize),
        .s_axi_awburst (ic_m03_awburst),
        .s_axi_awlock  (ic_m03_awlock),
        .s_axi_awcache (ic_m03_awcache),
        .s_axi_awprot  (ic_m03_awprot),
        .s_axi_awqos   (ic_m03_awqos),
        .s_axi_awregion(ic_m03_awregion),
        .s_axi_awvalid (ic_m03_awvalid),
        .s_axi_awready (ic_m03_awready),
        .s_axi_wdata   (ic_m03_wdata),
        .s_axi_wstrb   (ic_m03_wstrb),
        .s_axi_wlast   (ic_m03_wlast),
        .s_axi_wvalid  (ic_m03_wvalid),
        .s_axi_wready  (ic_m03_wready),
        .s_axi_bid     (ic_m03_bid),
        .s_axi_bresp   (ic_m03_bresp),
        .s_axi_bvalid  (ic_m03_bvalid),
        .s_axi_bready  (ic_m03_bready),
        .s_axi_arid    (ic_m03_arid),
        .s_axi_araddr  (ic_m03_araddr),
        .s_axi_arlen   (ic_m03_arlen),
        .s_axi_arsize  (ic_m03_arsize),
        .s_axi_arburst (ic_m03_arburst),
        .s_axi_arlock  (ic_m03_arlock),
        .s_axi_arcache (ic_m03_arcache),
        .s_axi_arprot  (ic_m03_arprot),
        .s_axi_arqos   (ic_m03_arqos),
        .s_axi_arregion(ic_m03_arregion),
        .s_axi_arvalid (ic_m03_arvalid),
        .s_axi_arready (ic_m03_arready),
        .s_axi_rid     (ic_m03_rid),
        .s_axi_rdata   (ic_m03_rdata),
        .s_axi_rresp   (ic_m03_rresp),
        .s_axi_rlast   (ic_m03_rlast),
        .s_axi_rvalid  (ic_m03_rvalid),
        .s_axi_rready  (ic_m03_rready),
        .m_axil_awid   (i2c_axil_awid),
        .m_axil_awaddr (i2c_axil_awaddr),
        .m_axil_awvalid(i2c_axil_awvalid),
        .m_axil_awready(i2c_axil_awready),
        .m_axil_wdata  (i2c_axil_wdata),
        .m_axil_wstrb  (i2c_axil_wstrb),
        .m_axil_wvalid (i2c_axil_wvalid),
        .m_axil_wready (i2c_axil_wready),
        .m_axil_bid    (i2c_axil_bid),
        .m_axil_bresp  (i2c_axil_bresp),
        .m_axil_bvalid (i2c_axil_bvalid),
        .m_axil_bready (i2c_axil_bready),
        .m_axil_arid   (i2c_axil_arid),
        .m_axil_araddr (i2c_axil_araddr),
        .m_axil_arvalid(i2c_axil_arvalid),
        .m_axil_arready(i2c_axil_arready),
        .m_axil_rid    (i2c_axil_rid),
        .m_axil_rdata  (i2c_axil_rdata),
        .m_axil_rresp  (i2c_axil_rresp),
        .m_axil_rvalid (i2c_axil_rvalid),
        .m_axil_rready (i2c_axil_rready)
    );

    // =========================================================================
    // 5.  UART  (axi_uart_top — uses axi_*_i / axi_*_o naming)
    //     UART ID_WIDTH=12, ADDR_WIDTH=5, DATA_WIDTH=32
    //     Bridge produces BRIDGE_ID_W=8 bit IDs; zero-extend to 12 bits.
    // =========================================================================
    axi_uart_top u_uart (
        .fixed_clk_i    (clk),
        .axi_aclk_i     (clk),
        .axi_aresetn_i  (rst_n_s),
        // Write address
        .axi_awid_i     ({{(12-BRIDGE_ID_W){1'b0}}, uart_axil_awid}),
        .axi_awaddr_i   (uart_axil_awaddr),
        .axi_awvalid_i  (uart_axil_awvalid),
        .axi_awready_o  (uart_axil_awready),
        // Write data
        .axi_wdata_i    (uart_axil_wdata),
        .axi_wstrb_i    (uart_axil_wstrb),
        .axi_wvalid_i   (uart_axil_wvalid),
        .axi_wready_o   (uart_axil_wready),
        // Write response
        .axi_bid_o      (uart_axil_bid[BRIDGE_ID_W-1:0]),
        .axi_bresp_o    (uart_axil_bresp),
        .axi_bvalid_o   (uart_axil_bvalid),
        .axi_bready_i   (uart_axil_bready),
        // Read address
        .axi_arid_i     ({{(12-BRIDGE_ID_W){1'b0}}, uart_axil_arid}),
        .axi_araddr_i   (uart_axil_araddr),
        .axi_arvalid_i  (uart_axil_arvalid),
        .axi_arready_o  (uart_axil_arready),
        // Read data
        .axi_rid_o      (uart_axil_rid[BRIDGE_ID_W-1:0]),
        .axi_rdata_o    (uart_axil_rdata),
        .axi_rresp_o    (uart_axil_rresp),
        .axi_rvalid_o   (uart_axil_rvalid),
        .axi_rready_i   (uart_axil_rready),
        // Serial
        .uart_rx_i      (uart_rx),
        .uart_tx_o      (uart_tx),
        // Interrupt (unused at top)
        .read_interrupt_o ()
    );

    // =========================================================================
    // 6.  AES  (aes_axi_slave — uses s_axi_* naming, 6-bit address)
    // =========================================================================
    aes_axi_slave u_aes (
        .s_axi_aclk    (clk),
        .s_axi_aresetn (rst_n_s),
        .s_axi_awaddr  (aes_axil_awaddr[5:0]),  // 5-bit→6-bit (zero MSB OK)
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

    // =========================================================================
    // 7.  WB-to-AXI-Lite bridge
    //     Receives AXI-Lite from axi4_to_axilite_bridge (m_axil_* ports),
    //     produces Wishbone master cycles for i2c_master_top.
    //     The wb_to_axilite_bridge m_axi_* ports are the AXI-Lite MASTER
    //     (it drives AXI-Lite to the downstream core).
    //     Here we wire it in the opposite sense: the axi4_to_axilite_bridge
    //     m_axil_* bus is the "requester", and wb_to_axilite_bridge samples
    //     it and produces WB.  The wb_to_axilite_bridge m_axi ports connect
    //     to the i2c side (not needed for AXI; only WB outputs matter).
    //
    //     Tie the WB bridge's AXI-Lite output (m_axi_*) to the i2c bridge
    //     output lines and use the internal WB master.
    // =========================================================================
    wb_to_axilite_bridge #(
        .ADDR_WIDTH   (AXI_ADDR_WIDTH),
        .WB_BASE_ADDR (I2C_BASE_ADDR)
    ) u_wb_bridge (
        .clk          (clk),
        .rst_n        (rst_n_s),
        // Wishbone master outputs (go to i2c_master_top slave)
        .wb_adr_i     (i2c_wb_adr),
        .wb_dat_i     (i2c_wb_dat_w),
        .wb_dat_o     (i2c_wb_dat_r),
        .wb_we_i      (i2c_wb_we),
        .wb_stb_i     (i2c_wb_stb),
        .wb_cyc_i     (i2c_wb_cyc),
        .wb_ack_o     (i2c_wb_ack),
        // AXI-Lite master port (connected back from axi4_to_axilite_bridge)
        .m_axi_awaddr  ({{(AXI_ADDR_WIDTH-BRIDGE_LITE_AW){1'b0}}, i2c_axil_awaddr}),
        .m_axi_awvalid (i2c_axil_awvalid),
        .m_axi_awready (i2c_axil_awready),
        .m_axi_wdata   (i2c_axil_wdata),
        .m_axi_wstrb   (i2c_axil_wstrb),
        .m_axi_wvalid  (i2c_axil_wvalid),
        .m_axi_wready  (i2c_axil_wready),
        .m_axi_bresp   (i2c_axil_bresp),
        .m_axi_bvalid  (i2c_axil_bvalid),
        .m_axi_bready  (i2c_axil_bready),
        .m_axi_araddr  ({{(AXI_ADDR_WIDTH-BRIDGE_LITE_AW){1'b0}}, i2c_axil_araddr}),
        .m_axi_arvalid (i2c_axil_arvalid),
        .m_axi_arready (i2c_axil_arready),
        .m_axi_rdata   (i2c_axil_rdata),
        .m_axi_rresp   (i2c_axil_rresp),
        .m_axi_rvalid  (i2c_axil_rvalid),
        .m_axi_rready  (i2c_axil_rready)
    );

    // =========================================================================
    // 8.  I2C Master  (Wishbone slave — i2c_master_top)
    // =========================================================================
    i2c_master_top u_i2c (
        .wb_clk_i     (clk),
        .wb_rst_i     (rst_ah),      // synchronous active-high reset
        .arst_i       (1'b0),        // async reset not used (ARST_LVL=1 → 0 = inactive)
        .wb_adr_i     (i2c_wb_adr),
        .wb_dat_i     (i2c_wb_dat_w),
        .wb_dat_o     (i2c_wb_dat_r),
        .wb_we_i      (i2c_wb_we),
        .wb_stb_i     (i2c_wb_stb),
        .wb_cyc_i     (i2c_wb_cyc),
        .wb_ack_o     (i2c_wb_ack),
        .wb_inta_o    (i2c_irq),
        // I2C bus pads
        .scl_pad_i    (i2c_scl_i),
        .scl_pad_o    (i2c_scl_o),
        .scl_padoen_o (i2c_scl_oen),
        .sda_pad_i    (i2c_sda_i),
        .sda_pad_o    (i2c_sda_o),
        .sda_padoen_o (i2c_sda_oen)
    );

endmodule

`default_nettype wire
