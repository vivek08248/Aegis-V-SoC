// =============================================================================
// Project      : Aegis-V SoC
// File         : aegis_v_soc.v
// Description  : Top-level SoC integration module.
//
//                Instantiates and wires:
//                  1. el2_veer_wrapper   – VeeR EL2 RISC-V core (RV_BUILD_AXI4)
//                  2. el2_mem            – ICCM/DCCM on-chip memories
//                  3. axi_interconnect_wrap_2x13 – 2 AXI4 masters, 13 targets
//                  4. AXI4-to-AXI-Lite bridges for memory-mapped targets
//                  5. UART, AES-128, I2C, PWM, SHA-256, GPIO, WDT, DMA CSR,
//                     system control/status, timer, instruction and data memory
//                  6. AXI-Lite-to-Wishbone adapter for I2C register access
//
//                Address map (32-bit physical):
//                  0x0000_0000  256 MB  – Instruction/Data SRAM (M00, external)
//                  0x1000_0000    4 KB  – UART  (M01)
//                  0x2000_0000    4 KB  – AES   (M02)
//                  0x3000_0000    4 KB  – I2C   (M03)
//                  0x4000_0000..0xA000_0000 PWM/SHA/GPIO/WDT/DMA/SCS/timer
//                  0xB000_0000   64 KB  – Instruction memory (M11)
//                  0xC000_0000   64 KB  – Data memory (M12)
//
//                VeeR EL2 AXI bus usage:
//                  LSU AXI  → interconnect slave port s00 (data bus)
//                  IFU AXI  → interconnect slave port s01 (instruction fetch)
//                  SB  AXI  → tied off (debug system bus not used in SoC)
//                  DMA engine master → tied inactive in the current flat CSR wrapper
//
//                Port name conventions matched to actual sub-module interfaces:
//                  axi4_to_axilite_bridge  : uses .rst  (active-high sync reset)
//                                           m_axil_* ports, peripheral offset width varies
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
    parameter IMEM_BASE_ADDR  = 32'hB000_0000,
    parameter DMEM_BASE_ADDR  = 32'hC000_0000,

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
    // PWM output
    // -------------------------------------------------------------------------
    output wire        pwm_out,
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
    input  wire [31:1]  extintsrc_req,  // external interrupt sources

    // GPIO pins are exposed at the SoC boundary for board-level integration.
    input  wire [31:0]  gpio_in,
    output wire [31:0] gpio_out,
    output wire [31:0] gpio_tx_en,
    output wire        gpio_irq
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
    wire [2:0]               lsu_axi_awid;
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
    wire [2:0]               lsu_axi_bid;
    wire                     lsu_axi_arvalid, lsu_axi_arready;
    wire [2:0]               lsu_axi_arid;
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
    wire [2:0]               lsu_axi_rid;
    wire [63:0]              lsu_axi_rdata;
    wire [1:0]               lsu_axi_rresp;
    wire                     lsu_axi_rlast;

    // --- IFU AXI4 master ---
    wire                     ifu_axi_awvalid, ifu_axi_awready;
    wire [2:0]               ifu_axi_awid;
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
    wire [2:0]               ifu_axi_bid;
    wire                     ifu_axi_arvalid, ifu_axi_arready;
    wire [2:0]               ifu_axi_arid;
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
    wire [2:0]               ifu_axi_rid;
    wire [63:0]              ifu_axi_rdata;
    wire [1:0]               ifu_axi_rresp;
    wire                     ifu_axi_rlast;

    // IFU reads are 64-bit inside VeeR; the shared AXI fabric is 32-bit.
    wire [2:0]               ifu_bridge_arid;
    wire [31:0]              ifu_bridge_araddr;
    wire [7:0]               ifu_bridge_arlen;
    wire [2:0]               ifu_bridge_arsize;
    wire [1:0]               ifu_bridge_arburst;
    wire                     ifu_bridge_arvalid, ifu_bridge_arready;
    wire [AXI_ID_WIDTH-1:0]  ifu_fabric_arid;
    wire [AXI_ID_WIDTH-1:0]  ifu_fabric_rid;
    wire [31:0]              ifu_fabric_rdata;
    wire [1:0]               ifu_fabric_rresp;
    wire                     ifu_fabric_rlast, ifu_fabric_rvalid, ifu_fabric_rready;

    wire [2:0]               lsu_bridge_arid;
    wire [31:0]              lsu_bridge_araddr;
    wire [7:0]               lsu_bridge_arlen;
    wire [2:0]               lsu_bridge_arsize;
    wire [1:0]               lsu_bridge_arburst;
    wire                     lsu_bridge_arvalid, lsu_bridge_arready;
    wire [AXI_ID_WIDTH-1:0]  lsu_fabric_arid;
    wire [AXI_ID_WIDTH-1:0]  lsu_fabric_rid;
    wire [31:0]              lsu_fabric_rdata;
    wire [1:0]               lsu_fabric_rresp;
    wire                     lsu_fabric_rlast, lsu_fabric_rvalid, lsu_fabric_rready;
    wire [2:0]               lsu_bridge_awid;
    wire [31:0]              lsu_bridge_awaddr;
    wire [7:0]               lsu_bridge_awlen;
    wire [2:0]               lsu_bridge_awsize;
    wire [1:0]               lsu_bridge_awburst;
    wire                     lsu_bridge_awvalid, lsu_bridge_awready;
    wire [31:0]              lsu_bridge_wdata;
    wire [3:0]               lsu_bridge_wstrb;
    wire                     lsu_bridge_wlast, lsu_bridge_wvalid, lsu_bridge_wready;
    wire [2:0]               lsu_bridge_bid;
    wire [1:0]               lsu_bridge_bresp;
    wire                     lsu_bridge_bvalid, lsu_bridge_bready;
    wire [AXI_ID_WIDTH-1:0]  lsu_fabric_awid, lsu_fabric_bid;

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
    // VeeR EL2 data-width adaptation: bridge its 64-bit LSU and IFU reads
    // onto the 32-bit AXI fabric used by the integrated IP blocks.
    // =========================================================================
    wire [31:0] ifu_axi_wdata_32 = ifu_axi_wdata[31:0];
    wire [3:0]  ifu_axi_wstrb_4  = ifu_axi_wstrb[3:0];
    wire [AXI_ID_WIDTH-1:0] ifu_axi_bid_ic;
    assign ifu_axi_bid = ifu_axi_bid_ic[2:0];
    assign ifu_fabric_arid = {{(AXI_ID_WIDTH-3){1'b0}}, ifu_bridge_arid};
    assign lsu_fabric_arid = {{(AXI_ID_WIDTH-3){1'b0}}, lsu_bridge_arid};
    assign lsu_fabric_awid = {{(AXI_ID_WIDTH-3){1'b0}}, lsu_bridge_awid};

    axi64_to_axi32_write_adapter #(.ID_WIDTH(3)) u_lsu_write_adapter (
        .clk          (clk),
        .rst_n        (rst_n_s),
        .up_awid      (lsu_axi_awid),
        .up_awaddr    (lsu_axi_awaddr),
        .up_awsize    (lsu_axi_awsize),
        .up_awburst   (lsu_axi_awburst),
        .up_awvalid   (lsu_axi_awvalid),
        .up_awready   (lsu_axi_awready),
        .up_wdata     (lsu_axi_wdata),
        .up_wstrb     (lsu_axi_wstrb),
        .up_wvalid    (lsu_axi_wvalid),
        .up_wready    (lsu_axi_wready),
        .up_bid       (lsu_axi_bid),
        .up_bresp     (lsu_axi_bresp),
        .up_bvalid    (lsu_axi_bvalid),
        .up_bready    (lsu_axi_bready),
        .dn_awid      (lsu_bridge_awid),
        .dn_awaddr    (lsu_bridge_awaddr),
        .dn_awlen     (lsu_bridge_awlen),
        .dn_awsize    (lsu_bridge_awsize),
        .dn_awburst   (lsu_bridge_awburst),
        .dn_awvalid   (lsu_bridge_awvalid),
        .dn_awready   (lsu_bridge_awready),
        .dn_wdata     (lsu_bridge_wdata),
        .dn_wstrb     (lsu_bridge_wstrb),
        .dn_wlast     (lsu_bridge_wlast),
        .dn_wvalid    (lsu_bridge_wvalid),
        .dn_wready    (lsu_bridge_wready),
        .dn_bresp     (lsu_bridge_bresp),
        .dn_bvalid    (lsu_bridge_bvalid),
        .dn_bready    (lsu_bridge_bready)
    );

    axi64_to_axi32_read_adapter #(.ID_WIDTH(3)) u_lsu_read_adapter (
        .clk          (clk),
        .rst_n        (rst_n_s),
        .up_arid      (lsu_axi_arid),
        .up_araddr    (lsu_axi_araddr),
        .up_arlen     (lsu_axi_arlen),
        .up_arsize    (lsu_axi_arsize),
        .up_arburst   (lsu_axi_arburst),
        .up_arvalid   (lsu_axi_arvalid),
        .up_arready   (lsu_axi_arready),
        .up_rid       (lsu_axi_rid),
        .up_rdata     (lsu_axi_rdata),
        .up_rresp     (lsu_axi_rresp),
        .up_rlast     (lsu_axi_rlast),
        .up_rvalid    (lsu_axi_rvalid),
        .up_rready    (lsu_axi_rready),
        .dn_arid      (lsu_bridge_arid),
        .dn_araddr    (lsu_bridge_araddr),
        .dn_arlen     (lsu_bridge_arlen),
        .dn_arsize    (lsu_bridge_arsize),
        .dn_arburst   (lsu_bridge_arburst),
        .dn_arvalid   (lsu_bridge_arvalid),
        .dn_arready   (lsu_bridge_arready),
        .dn_rid       (lsu_fabric_rid[2:0]),
        .dn_rdata     (lsu_fabric_rdata),
        .dn_rresp     (lsu_fabric_rresp),
        .dn_rlast     (lsu_fabric_rlast),
        .dn_rvalid    (lsu_fabric_rvalid),
        .dn_rready    (lsu_fabric_rready)
    );

    axi64_to_axi32_read_adapter #(.ID_WIDTH(3)) u_ifu_read_adapter (
        .clk          (clk),
        .rst_n        (rst_n_s),
        .up_arid      (ifu_axi_arid),
        .up_araddr    (ifu_axi_araddr),
        .up_arlen     (ifu_axi_arlen),
        .up_arsize    (ifu_axi_arsize),
        .up_arburst   (ifu_axi_arburst),
        .up_arvalid   (ifu_axi_arvalid),
        .up_arready   (ifu_axi_arready),
        .up_rid       (ifu_axi_rid),
        .up_rdata     (ifu_axi_rdata),
        .up_rresp     (ifu_axi_rresp),
        .up_rlast     (ifu_axi_rlast),
        .up_rvalid    (ifu_axi_rvalid),
        .up_rready    (ifu_axi_rready),
        .dn_arid      (ifu_bridge_arid),
        .dn_araddr    (ifu_bridge_araddr),
        .dn_arlen     (ifu_bridge_arlen),
        .dn_arsize    (ifu_bridge_arsize),
        .dn_arburst   (ifu_bridge_arburst),
        .dn_arvalid   (ifu_bridge_arvalid),
        .dn_arready   (ifu_bridge_arready),
        .dn_rid       (ifu_fabric_rid[2:0]),
        .dn_rdata     (ifu_fabric_rdata),
        .dn_rresp     (ifu_fabric_rresp),
        .dn_rlast     (ifu_fabric_rlast),
        .dn_rvalid    (ifu_fabric_rvalid),
        .dn_rready    (ifu_fabric_rready)
    );

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
    // Bridge IDs match the 8-bit interconnect. The offset width is set large
    // enough for memory targets; narrower peripherals truncate at their ports.
    // =========================================================================
    localparam BRIDGE_ID_W    = AXI_ID_WIDTH;
    // Keep enough peripheral offset bits for the 64-KiB memories and 256-B
    // SHA block. Narrow peripherals consume the low address bits at their ports.
    localparam BRIDGE_LITE_AW = 16;

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
    wire        wdt_irq_w, wdt_timeout_w;
    wire        dma_done_w, dma_error_w;
    wire        timer_irq_w;
    wire        scs_irq_w;
    wire        uart_irq_w;
    wire        gpio_irq_w, gpio_irq_combined;
    wire [31:0] gpio_tx_en_w, gpio_in_sync_w, gpio_pin_irq_w, gpio_out_w;
    wire [31:1] core_extintsrc_req;
    wire        scs_sys_enable, scs_soft_reset, scs_debug_en, scs_low_power;
    wire        scs_irq_global_en;

    // VeeR clock enables
    wire lsu_bus_clk_en = 1'b1;
    wire ifu_bus_clk_en = 1'b1;
    wire dbg_bus_clk_en = 1'b1;
    wire dma_bus_clk_en = 1'b1;

    // el2_mem_if interfaces for VeeR internal memory export
    el2_mem_if el2_mem_export_if();
    el2_mem_if el2_icache_export_if();

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
        .timer_int                  (timer_irq_w),
        .soft_int                   (1'b0),
        .extintsrc_req              (core_extintsrc_req),

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
        .sb_axi_bresp               (2'b00), .sb_axi_bid (1'b0),
        .sb_axi_arvalid             (sb_axi_arvalid),
        .sb_axi_arready             (sb_axi_arready),
        .sb_axi_arid                (), .sb_axi_araddr  (),
        .sb_axi_arregion            (), .sb_axi_arlen   (),
        .sb_axi_arsize              (), .sb_axi_arburst (),
        .sb_axi_arlock              (), .sb_axi_arcache (),
        .sb_axi_arprot              (), .sb_axi_arqos   (),
        .sb_axi_rvalid              (sb_axi_rvalid),
        .sb_axi_rready              (sb_axi_rready),
        .sb_axi_rid                 (1'b0),  .sb_axi_rdata (64'h0),
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
        .el2_icache_export          (el2_icache_export_if.veer_icache_src),

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
    // 2.  VeeR On-Chip Memories (ICCM / DCCM / ICache)
    //
    // NOTE: el2_mem is already instantiated inside el2_veer_wrapper.
    //       The el2_mem_export_if and el2_icache_export_if interfaces are
    //       driven by the el2_veer_wrapper's exported ports above.
    //       No separate el2_mem instantiation is needed here.
    // =========================================================================

    // =========================================================================
    // 3.  AXI4 Interconnect  (2 initiators, 13 target ports)
    // =========================================================================

    // AXI target wires M04..M12 connect the remaining memory-mapped IPs.

    // -------------------------------------------------------------------------
    // Interconnect M04 (PWM)
    // -------------------------------------------------------------------------
    wire [AXI_ID_WIDTH-1:0]   ic_m04_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m04_awaddr;
    wire [7:0]  ic_m04_awlen;  wire [2:0] ic_m04_awsize; wire [1:0] ic_m04_awburst;
    wire        ic_m04_awlock; wire [3:0] ic_m04_awcache; wire [2:0] ic_m04_awprot;
    wire [3:0]  ic_m04_awqos;  wire [3:0] ic_m04_awregion;
    wire        ic_m04_awvalid, ic_m04_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m04_wdata;
    wire [3:0]  ic_m04_wstrb;  wire ic_m04_wlast; wire ic_m04_wvalid; wire ic_m04_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m04_bid;
    wire [1:0]  ic_m04_bresp;  wire ic_m04_bvalid; wire ic_m04_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m04_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m04_araddr;
    wire [7:0]  ic_m04_arlen;  wire [2:0] ic_m04_arsize; wire [1:0] ic_m04_arburst;
    wire        ic_m04_arlock; wire [3:0] ic_m04_arcache; wire [2:0] ic_m04_arprot;
    wire [3:0]  ic_m04_arqos;  wire [3:0] ic_m04_arregion;
    wire        ic_m04_arvalid, ic_m04_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m04_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m04_rdata;
    wire [1:0]  ic_m04_rresp;  wire ic_m04_rlast; wire ic_m04_rvalid; wire ic_m04_rready;
    wire m04_awrdy=1'b0, m04_wrdy=1'b0, m04_bvld=1'b0, m04_arrdy=1'b0, m04_rvld=1'b0;

    // -------------------------------------------------------------------------
    // Interconnect M05 (SHA256)
    // -------------------------------------------------------------------------
    wire [AXI_ID_WIDTH-1:0]   ic_m05_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m05_awaddr;
    wire [7:0]  ic_m05_awlen;  wire [2:0] ic_m05_awsize; wire [1:0] ic_m05_awburst;
    wire        ic_m05_awlock; wire [3:0] ic_m05_awcache; wire [2:0] ic_m05_awprot;
    wire [3:0]  ic_m05_awqos;  wire [3:0] ic_m05_awregion;
    wire        ic_m05_awvalid, ic_m05_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m05_wdata;
    wire [3:0]  ic_m05_wstrb;  wire ic_m05_wlast; wire ic_m05_wvalid; wire ic_m05_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m05_bid;
    wire [1:0]  ic_m05_bresp;  wire ic_m05_bvalid; wire ic_m05_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m05_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m05_araddr;
    wire [7:0]  ic_m05_arlen;  wire [2:0] ic_m05_arsize; wire [1:0] ic_m05_arburst;
    wire        ic_m05_arlock; wire [3:0] ic_m05_arcache; wire [2:0] ic_m05_arprot;
    wire [3:0]  ic_m05_arqos;  wire [3:0] ic_m05_arregion;
    wire        ic_m05_arvalid, ic_m05_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m05_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m05_rdata;
    wire [1:0]  ic_m05_rresp;  wire ic_m05_rlast; wire ic_m05_rvalid; wire ic_m05_rready;

    // -------------------------------------------------------------------------
    // Interconnect M06 (GPIO)
    // -------------------------------------------------------------------------
    wire [AXI_ID_WIDTH-1:0]   ic_m06_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m06_awaddr;
    wire [7:0]  ic_m06_awlen;  wire [2:0] ic_m06_awsize; wire [1:0] ic_m06_awburst;
    wire        ic_m06_awlock; wire [3:0] ic_m06_awcache; wire [2:0] ic_m06_awprot;
    wire [3:0]  ic_m06_awqos;  wire [3:0] ic_m06_awregion;
    wire        ic_m06_awvalid, ic_m06_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m06_wdata;
    wire [3:0]  ic_m06_wstrb;  wire ic_m06_wlast; wire ic_m06_wvalid; wire ic_m06_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m06_bid;
    wire [1:0]  ic_m06_bresp;  wire ic_m06_bvalid; wire ic_m06_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m06_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m06_araddr;
    wire [7:0]  ic_m06_arlen;  wire [2:0] ic_m06_arsize; wire [1:0] ic_m06_arburst;
    wire        ic_m06_arlock; wire [3:0] ic_m06_arcache; wire [2:0] ic_m06_arprot;
    wire [3:0]  ic_m06_arqos;  wire [3:0] ic_m06_arregion;
    wire        ic_m06_arvalid, ic_m06_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m06_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m06_rdata;
    wire [1:0]  ic_m06_rresp;  wire ic_m06_rlast; wire ic_m06_rvalid; wire ic_m06_rready;

    // -------------------------------------------------------------------------
    // Interconnect M07 (EF_WDT32 Watchdog)
    // -------------------------------------------------------------------------
    wire [AXI_ID_WIDTH-1:0]   ic_m07_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m07_awaddr;
    wire [7:0]  ic_m07_awlen;  wire [2:0] ic_m07_awsize; wire [1:0] ic_m07_awburst;
    wire        ic_m07_awlock; wire [3:0] ic_m07_awcache; wire [2:0] ic_m07_awprot;
    wire [3:0]  ic_m07_awqos;  wire [3:0] ic_m07_awregion;
    wire        ic_m07_awvalid, ic_m07_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m07_wdata;
    wire [3:0]  ic_m07_wstrb;  wire ic_m07_wlast; wire ic_m07_wvalid; wire ic_m07_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m07_bid;
    wire [1:0]  ic_m07_bresp;  wire ic_m07_bvalid; wire ic_m07_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m07_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m07_araddr;
    wire [7:0]  ic_m07_arlen;  wire [2:0] ic_m07_arsize; wire [1:0] ic_m07_arburst;
    wire        ic_m07_arlock; wire [3:0] ic_m07_arcache; wire [2:0] ic_m07_arprot;
    wire [3:0]  ic_m07_arqos;  wire [3:0] ic_m07_arregion;
    wire        ic_m07_arvalid, ic_m07_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m07_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m07_rdata;
    wire [1:0]  ic_m07_rresp;  wire ic_m07_rlast; wire ic_m07_rvalid; wire ic_m07_rready;

    // -------------------------------------------------------------------------
    // Interconnect M08 (DMA)
    // -------------------------------------------------------------------------
    wire [AXI_ID_WIDTH-1:0]   ic_m08_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m08_awaddr;
    wire [7:0]  ic_m08_awlen;  wire [2:0] ic_m08_awsize; wire [1:0] ic_m08_awburst;
    wire        ic_m08_awlock; wire [3:0] ic_m08_awcache; wire [2:0] ic_m08_awprot;
    wire [3:0]  ic_m08_awqos;  wire [3:0] ic_m08_awregion;
    wire        ic_m08_awvalid, ic_m08_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m08_wdata;
    wire [3:0]  ic_m08_wstrb;  wire ic_m08_wlast; wire ic_m08_wvalid; wire ic_m08_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m08_bid;
    wire [1:0]  ic_m08_bresp;  wire ic_m08_bvalid; wire ic_m08_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m08_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m08_araddr;
    wire [7:0]  ic_m08_arlen;  wire [2:0] ic_m08_arsize; wire [1:0] ic_m08_arburst;
    wire        ic_m08_arlock; wire [3:0] ic_m08_arcache; wire [2:0] ic_m08_arprot;
    wire [3:0]  ic_m08_arqos;  wire [3:0] ic_m08_arregion;
    wire        ic_m08_arvalid, ic_m08_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m08_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m08_rdata;
    wire [1:0]  ic_m08_rresp;  wire ic_m08_rlast; wire ic_m08_rvalid; wire ic_m08_rready;

    // -------------------------------------------------------------------------
    // Interconnect M09 (System Control & Status)
    // -------------------------------------------------------------------------
    wire [AXI_ID_WIDTH-1:0]   ic_m09_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m09_awaddr;
    wire [7:0]  ic_m09_awlen;  wire [2:0] ic_m09_awsize; wire [1:0] ic_m09_awburst;
    wire        ic_m09_awlock; wire [3:0] ic_m09_awcache; wire [2:0] ic_m09_awprot;
    wire [3:0]  ic_m09_awqos;  wire [3:0] ic_m09_awregion;
    wire        ic_m09_awvalid, ic_m09_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m09_wdata;
    wire [3:0]  ic_m09_wstrb;  wire ic_m09_wlast; wire ic_m09_wvalid; wire ic_m09_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m09_bid;
    wire [1:0]  ic_m09_bresp;  wire ic_m09_bvalid; wire ic_m09_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m09_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m09_araddr;
    wire [7:0]  ic_m09_arlen;  wire [2:0] ic_m09_arsize; wire [1:0] ic_m09_arburst;
    wire        ic_m09_arlock; wire [3:0] ic_m09_arcache; wire [2:0] ic_m09_arprot;
    wire [3:0]  ic_m09_arqos;  wire [3:0] ic_m09_arregion;
    wire        ic_m09_arvalid, ic_m09_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m09_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m09_rdata;
    wire [1:0]  ic_m09_rresp;  wire ic_m09_rlast; wire ic_m09_rvalid; wire ic_m09_rready;

    // -------------------------------------------------------------------------
    // Interconnect M10 (rv_timer)
    // -------------------------------------------------------------------------
    wire [AXI_ID_WIDTH-1:0]   ic_m10_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m10_awaddr;
    wire [7:0]  ic_m10_awlen;  wire [2:0] ic_m10_awsize; wire [1:0] ic_m10_awburst;
    wire        ic_m10_awlock; wire [3:0] ic_m10_awcache; wire [2:0] ic_m10_awprot;
    wire [3:0]  ic_m10_awqos;  wire [3:0] ic_m10_awregion;
    wire        ic_m10_awvalid, ic_m10_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m10_wdata;
    wire [3:0]  ic_m10_wstrb;  wire ic_m10_wlast; wire ic_m10_wvalid; wire ic_m10_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m10_bid;
    wire [1:0]  ic_m10_bresp;  wire ic_m10_bvalid; wire ic_m10_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m10_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m10_araddr;
    wire [7:0]  ic_m10_arlen;  wire [2:0] ic_m10_arsize; wire [1:0] ic_m10_arburst;
    wire        ic_m10_arlock; wire [3:0] ic_m10_arcache; wire [2:0] ic_m10_arprot;
    wire [3:0]  ic_m10_arqos;  wire [3:0] ic_m10_arregion;
    wire        ic_m10_arvalid, ic_m10_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m10_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m10_rdata;
    wire [1:0]  ic_m10_rresp;  wire ic_m10_rlast; wire ic_m10_rvalid; wire ic_m10_rready;

    // M11: Instruction Memory
    wire [AXI_ID_WIDTH-1:0]   ic_m11_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m11_awaddr;
    wire [7:0]  ic_m11_awlen;  wire [2:0] ic_m11_awsize; wire [1:0] ic_m11_awburst;
    wire        ic_m11_awlock; wire [3:0] ic_m11_awcache; wire [2:0] ic_m11_awprot;
    wire [3:0]  ic_m11_awqos;  wire [3:0] ic_m11_awregion;
    wire        ic_m11_awvalid, ic_m11_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m11_wdata;
    wire [3:0]  ic_m11_wstrb;  wire ic_m11_wlast; wire ic_m11_wvalid; wire ic_m11_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m11_bid;
    wire [1:0]  ic_m11_bresp;  wire ic_m11_bvalid; wire ic_m11_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m11_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m11_araddr;
    wire [7:0]  ic_m11_arlen;  wire [2:0] ic_m11_arsize; wire [1:0] ic_m11_arburst;
    wire        ic_m11_arlock; wire [3:0] ic_m11_arcache; wire [2:0] ic_m11_arprot;
    wire [3:0]  ic_m11_arqos;  wire [3:0] ic_m11_arregion;
    wire        ic_m11_arvalid, ic_m11_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m11_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m11_rdata;
    wire [1:0]  ic_m11_rresp;  wire ic_m11_rlast; wire ic_m11_rvalid; wire ic_m11_rready;

    // M12: Data Memory
    wire [AXI_ID_WIDTH-1:0]   ic_m12_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m12_awaddr;
    wire [7:0]  ic_m12_awlen;  wire [2:0] ic_m12_awsize; wire [1:0] ic_m12_awburst;
    wire        ic_m12_awlock; wire [3:0] ic_m12_awcache; wire [2:0] ic_m12_awprot;
    wire [3:0]  ic_m12_awqos;  wire [3:0] ic_m12_awregion;
    wire        ic_m12_awvalid, ic_m12_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m12_wdata;
    wire [3:0]  ic_m12_wstrb;  wire ic_m12_wlast; wire ic_m12_wvalid; wire ic_m12_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m12_bid;
    wire [1:0]  ic_m12_bresp;  wire ic_m12_bvalid; wire ic_m12_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m12_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m12_araddr;
    wire [7:0]  ic_m12_arlen;  wire [2:0] ic_m12_arsize; wire [1:0] ic_m12_arburst;
    wire        ic_m12_arlock; wire [3:0] ic_m12_arcache; wire [2:0] ic_m12_arprot;
    wire [3:0]  ic_m12_arqos;  wire [3:0] ic_m12_arregion;
    wire        ic_m12_arvalid, ic_m12_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m12_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m12_rdata;
    wire [1:0]  ic_m12_rresp;  wire ic_m12_rlast; wire ic_m12_rvalid; wire ic_m12_rready;

    axi_interconnect_wrap_2x13 #(
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
        .M10_BASE_ADDR  (32'hA000_0000), .M10_ADDR_WIDTH ({1{32'd12}}),
        .M11_BASE_ADDR  (IMEM_BASE_ADDR),.M11_ADDR_WIDTH ({1{32'd16}}),
        .M12_BASE_ADDR  (DMEM_BASE_ADDR),.M12_ADDR_WIDTH ({1{32'd16}})
    ) u_interconnect (
        .clk             (clk),
        .rst             (rst_ah),  // active-high reset

        // Slave port 0: VeeR LSU
        .s00_axi_awid    (lsu_fabric_awid),
        .s00_axi_awaddr  (lsu_bridge_awaddr),
        .s00_axi_awlen   (lsu_bridge_awlen),
        .s00_axi_awsize  (lsu_bridge_awsize),
        .s00_axi_awburst (lsu_bridge_awburst),
        .s00_axi_awlock  (lsu_axi_awlock),
        .s00_axi_awcache (lsu_axi_awcache),
        .s00_axi_awprot  (lsu_axi_awprot),
        .s00_axi_awqos   (lsu_axi_awqos),
        .s00_axi_awvalid (lsu_bridge_awvalid),
        .s00_axi_awready (lsu_bridge_awready),
        .s00_axi_wdata   (lsu_bridge_wdata),
        .s00_axi_wstrb   (lsu_bridge_wstrb),
        .s00_axi_wlast   (lsu_bridge_wlast),
        .s00_axi_wvalid  (lsu_bridge_wvalid),
        .s00_axi_wready  (lsu_bridge_wready),
        .s00_axi_bid     (lsu_fabric_bid),
        .s00_axi_bresp   (lsu_bridge_bresp),
        .s00_axi_bvalid  (lsu_bridge_bvalid),
        .s00_axi_bready  (lsu_bridge_bready),
        .s00_axi_arid    (lsu_fabric_arid),
        .s00_axi_araddr  (lsu_bridge_araddr),
        .s00_axi_arlen   (lsu_bridge_arlen),
        .s00_axi_arsize  (lsu_bridge_arsize),
        .s00_axi_arburst (lsu_bridge_arburst),
        .s00_axi_arlock  (lsu_axi_arlock),
        .s00_axi_arcache (lsu_axi_arcache),
        .s00_axi_arprot  (lsu_axi_arprot),
        .s00_axi_arqos   (lsu_axi_arqos),
        .s00_axi_arvalid (lsu_bridge_arvalid),
        .s00_axi_arready (lsu_bridge_arready),
        .s00_axi_rid     (lsu_fabric_rid),
        .s00_axi_rdata   (lsu_fabric_rdata),
        .s00_axi_rresp   (lsu_fabric_rresp),
        .s00_axi_rlast   (lsu_fabric_rlast),
        .s00_axi_rvalid  (lsu_fabric_rvalid),
        .s00_axi_rready  (lsu_fabric_rready),

        // Slave port 1: VeeR IFU
        .s01_axi_awid    ({{(AXI_ID_WIDTH-3){1'b0}}, ifu_axi_awid}),
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
        .s01_axi_bid     (ifu_axi_bid_ic),
        .s01_axi_bresp   (ifu_axi_bresp),
        .s01_axi_bvalid  (ifu_axi_bvalid),
        .s01_axi_bready  (ifu_axi_bready),
        .s01_axi_arid    (ifu_fabric_arid),
        .s01_axi_araddr  (ifu_bridge_araddr),
        .s01_axi_arlen   (ifu_bridge_arlen),
        .s01_axi_arsize  (ifu_bridge_arsize),
        .s01_axi_arburst (ifu_bridge_arburst),
        .s01_axi_arlock  (ifu_axi_arlock),
        .s01_axi_arcache (ifu_axi_arcache),
        .s01_axi_arprot  (ifu_axi_arprot),
        .s01_axi_arqos   (ifu_axi_arqos),
        .s01_axi_arvalid (ifu_bridge_arvalid),
        .s01_axi_arready (ifu_bridge_arready),
        .s01_axi_rid     (ifu_fabric_rid),
        .s01_axi_rdata   (ifu_fabric_rdata),
        .s01_axi_rresp   (ifu_fabric_rresp),
        .s01_axi_rlast   (ifu_fabric_rlast),
        .s01_axi_rvalid  (ifu_fabric_rvalid),
        .s01_axi_rready  (ifu_fabric_rready),

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

        // Master ports 4..10: PWM, SHA-256, GPIO, WDT, DMA CSR, SCS, timer
        // Master port 4: PWM
        .m04_axi_awid    (ic_m04_awid),    .m04_axi_awaddr  (ic_m04_awaddr),
        .m04_axi_awlen   (ic_m04_awlen),   .m04_axi_awsize  (ic_m04_awsize),
        .m04_axi_awburst (ic_m04_awburst), .m04_axi_awlock  (ic_m04_awlock),
        .m04_axi_awcache (ic_m04_awcache), .m04_axi_awprot  (ic_m04_awprot),
        .m04_axi_awqos   (ic_m04_awqos),   .m04_axi_awvalid (ic_m04_awvalid),
        .m04_axi_awready (ic_m04_awready),
        .m04_axi_wdata   (ic_m04_wdata),   .m04_axi_wstrb   (ic_m04_wstrb),
        .m04_axi_wlast   (ic_m04_wlast),   .m04_axi_wvalid  (ic_m04_wvalid),
        .m04_axi_wready  (ic_m04_wready),
        .m04_axi_bid     (ic_m04_bid),     .m04_axi_bresp   (ic_m04_bresp),
        .m04_axi_bvalid  (ic_m04_bvalid),  .m04_axi_bready  (ic_m04_bready),
        .m04_axi_arid    (ic_m04_arid),    .m04_axi_araddr  (ic_m04_araddr),
        .m04_axi_arlen   (ic_m04_arlen),   .m04_axi_arsize  (ic_m04_arsize),
        .m04_axi_arburst (ic_m04_arburst), .m04_axi_arlock  (ic_m04_arlock),
        .m04_axi_arcache (ic_m04_arcache), .m04_axi_arprot  (ic_m04_arprot),
        .m04_axi_arqos   (ic_m04_arqos),   .m04_axi_arvalid (ic_m04_arvalid),
        .m04_axi_arready (ic_m04_arready),
        .m04_axi_rid     (ic_m04_rid),     .m04_axi_rdata   (ic_m04_rdata),
        .m04_axi_rresp   (ic_m04_rresp),   .m04_axi_rlast   (ic_m04_rlast),
        .m04_axi_rvalid  (ic_m04_rvalid),  .m04_axi_rready  (ic_m04_rready),


        // Master port 5: SHA256
        .m05_axi_awid    (ic_m05_awid),    .m05_axi_awaddr  (ic_m05_awaddr),
        .m05_axi_awlen   (ic_m05_awlen),   .m05_axi_awsize  (ic_m05_awsize),
        .m05_axi_awburst (ic_m05_awburst), .m05_axi_awlock  (ic_m05_awlock),
        .m05_axi_awcache (ic_m05_awcache), .m05_axi_awprot  (ic_m05_awprot),
        .m05_axi_awqos   (ic_m05_awqos),   .m05_axi_awvalid (ic_m05_awvalid),
        .m05_axi_awready (ic_m05_awready),
        .m05_axi_wdata   (ic_m05_wdata),   .m05_axi_wstrb   (ic_m05_wstrb),
        .m05_axi_wlast   (ic_m05_wlast),   .m05_axi_wvalid  (ic_m05_wvalid),
        .m05_axi_wready  (ic_m05_wready),
        .m05_axi_bid     (ic_m05_bid),     .m05_axi_bresp   (ic_m05_bresp),
        .m05_axi_bvalid  (ic_m05_bvalid),  .m05_axi_bready  (ic_m05_bready),
        .m05_axi_arid    (ic_m05_arid),    .m05_axi_araddr  (ic_m05_araddr),
        .m05_axi_arlen   (ic_m05_arlen),   .m05_axi_arsize  (ic_m05_arsize),
        .m05_axi_arburst (ic_m05_arburst), .m05_axi_arlock  (ic_m05_arlock),
        .m05_axi_arcache (ic_m05_arcache), .m05_axi_arprot  (ic_m05_arprot),
        .m05_axi_arqos   (ic_m05_arqos),   .m05_axi_arvalid (ic_m05_arvalid),
        .m05_axi_arready (ic_m05_arready),
        .m05_axi_rid     (ic_m05_rid),     .m05_axi_rdata   (ic_m05_rdata),
        .m05_axi_rresp   (ic_m05_rresp),   .m05_axi_rlast   (ic_m05_rlast),
        .m05_axi_rvalid  (ic_m05_rvalid),  .m05_axi_rready  (ic_m05_rready),

        // Master port 6: GPIO
        .m06_axi_awid    (ic_m06_awid),    .m06_axi_awaddr  (ic_m06_awaddr),
        .m06_axi_awlen   (ic_m06_awlen),   .m06_axi_awsize  (ic_m06_awsize),
        .m06_axi_awburst (ic_m06_awburst), .m06_axi_awlock  (ic_m06_awlock),
        .m06_axi_awcache (ic_m06_awcache), .m06_axi_awprot  (ic_m06_awprot),
        .m06_axi_awqos   (ic_m06_awqos),   .m06_axi_awvalid (ic_m06_awvalid),
        .m06_axi_awready (ic_m06_awready),
        .m06_axi_wdata   (ic_m06_wdata),   .m06_axi_wstrb   (ic_m06_wstrb),
        .m06_axi_wlast   (ic_m06_wlast),   .m06_axi_wvalid  (ic_m06_wvalid),
        .m06_axi_wready  (ic_m06_wready),
        .m06_axi_bid     (ic_m06_bid),     .m06_axi_bresp   (ic_m06_bresp),
        .m06_axi_bvalid  (ic_m06_bvalid),  .m06_axi_bready  (ic_m06_bready),
        .m06_axi_arid    (ic_m06_arid),    .m06_axi_araddr  (ic_m06_araddr),
        .m06_axi_arlen   (ic_m06_arlen),   .m06_axi_arsize  (ic_m06_arsize),
        .m06_axi_arburst (ic_m06_arburst), .m06_axi_arlock  (ic_m06_arlock),
        .m06_axi_arcache (ic_m06_arcache), .m06_axi_arprot  (ic_m06_arprot),
        .m06_axi_arqos   (ic_m06_arqos),   .m06_axi_arvalid (ic_m06_arvalid),
        .m06_axi_arready (ic_m06_arready),
        .m06_axi_rid     (ic_m06_rid),     .m06_axi_rdata   (ic_m06_rdata),
        .m06_axi_rresp   (ic_m06_rresp),   .m06_axi_rlast   (ic_m06_rlast),
        .m06_axi_rvalid  (ic_m06_rvalid),  .m06_axi_rready  (ic_m06_rready),

        // Master port 7: EF_WDT32
        .m07_axi_awid    (ic_m07_awid),    .m07_axi_awaddr  (ic_m07_awaddr),
        .m07_axi_awlen   (ic_m07_awlen),   .m07_axi_awsize  (ic_m07_awsize),
        .m07_axi_awburst (ic_m07_awburst), .m07_axi_awlock  (ic_m07_awlock),
        .m07_axi_awcache (ic_m07_awcache), .m07_axi_awprot  (ic_m07_awprot),
        .m07_axi_awqos   (ic_m07_awqos),   .m07_axi_awvalid (ic_m07_awvalid),
        .m07_axi_awready (ic_m07_awready),
        .m07_axi_wdata   (ic_m07_wdata),   .m07_axi_wstrb   (ic_m07_wstrb),
        .m07_axi_wlast   (ic_m07_wlast),   .m07_axi_wvalid  (ic_m07_wvalid),
        .m07_axi_wready  (ic_m07_wready),
        .m07_axi_bid     (ic_m07_bid),     .m07_axi_bresp   (ic_m07_bresp),
        .m07_axi_bvalid  (ic_m07_bvalid),  .m07_axi_bready  (ic_m07_bready),
        .m07_axi_arid    (ic_m07_arid),    .m07_axi_araddr  (ic_m07_araddr),
        .m07_axi_arlen   (ic_m07_arlen),   .m07_axi_arsize  (ic_m07_arsize),
        .m07_axi_arburst (ic_m07_arburst), .m07_axi_arlock  (ic_m07_arlock),
        .m07_axi_arcache (ic_m07_arcache), .m07_axi_arprot  (ic_m07_arprot),
        .m07_axi_arqos   (ic_m07_arqos),   .m07_axi_arvalid (ic_m07_arvalid),
        .m07_axi_arready (ic_m07_arready),
        .m07_axi_rid     (ic_m07_rid),     .m07_axi_rdata   (ic_m07_rdata),
        .m07_axi_rresp   (ic_m07_rresp),   .m07_axi_rlast   (ic_m07_rlast),
        .m07_axi_rvalid  (ic_m07_rvalid),  .m07_axi_rready  (ic_m07_rready),

        // Master port 8: DMA
        .m08_axi_awid    (ic_m08_awid),    .m08_axi_awaddr  (ic_m08_awaddr),
        .m08_axi_awlen   (ic_m08_awlen),   .m08_axi_awsize  (ic_m08_awsize),
        .m08_axi_awburst (ic_m08_awburst), .m08_axi_awlock  (ic_m08_awlock),
        .m08_axi_awcache (ic_m08_awcache), .m08_axi_awprot  (ic_m08_awprot),
        .m08_axi_awqos   (ic_m08_awqos),   .m08_axi_awvalid (ic_m08_awvalid),
        .m08_axi_awready (ic_m08_awready),
        .m08_axi_wdata   (ic_m08_wdata),   .m08_axi_wstrb   (ic_m08_wstrb),
        .m08_axi_wlast   (ic_m08_wlast),   .m08_axi_wvalid  (ic_m08_wvalid),
        .m08_axi_wready  (ic_m08_wready),
        .m08_axi_bid     (ic_m08_bid),     .m08_axi_bresp   (ic_m08_bresp),
        .m08_axi_bvalid  (ic_m08_bvalid),  .m08_axi_bready  (ic_m08_bready),
        .m08_axi_arid    (ic_m08_arid),    .m08_axi_araddr  (ic_m08_araddr),
        .m08_axi_arlen   (ic_m08_arlen),   .m08_axi_arsize  (ic_m08_arsize),
        .m08_axi_arburst (ic_m08_arburst), .m08_axi_arlock  (ic_m08_arlock),
        .m08_axi_arcache (ic_m08_arcache), .m08_axi_arprot  (ic_m08_arprot),
        .m08_axi_arqos   (ic_m08_arqos),   .m08_axi_arvalid (ic_m08_arvalid),
        .m08_axi_arready (ic_m08_arready),
        .m08_axi_rid     (ic_m08_rid),     .m08_axi_rdata   (ic_m08_rdata),
        .m08_axi_rresp   (ic_m08_rresp),   .m08_axi_rlast   (ic_m08_rlast),
        .m08_axi_rvalid  (ic_m08_rvalid),  .m08_axi_rready  (ic_m08_rready),

        // Master port 9: System Control & Status
        .m09_axi_awid    (ic_m09_awid),    .m09_axi_awaddr  (ic_m09_awaddr),
        .m09_axi_awlen   (ic_m09_awlen),   .m09_axi_awsize  (ic_m09_awsize),
        .m09_axi_awburst (ic_m09_awburst), .m09_axi_awlock  (ic_m09_awlock),
        .m09_axi_awcache (ic_m09_awcache), .m09_axi_awprot  (ic_m09_awprot),
        .m09_axi_awqos   (ic_m09_awqos),   .m09_axi_awvalid (ic_m09_awvalid),
        .m09_axi_awready (ic_m09_awready),
        .m09_axi_wdata   (ic_m09_wdata),   .m09_axi_wstrb   (ic_m09_wstrb),
        .m09_axi_wlast   (ic_m09_wlast),   .m09_axi_wvalid  (ic_m09_wvalid),
        .m09_axi_wready  (ic_m09_wready),
        .m09_axi_bid     (ic_m09_bid),     .m09_axi_bresp   (ic_m09_bresp),
        .m09_axi_bvalid  (ic_m09_bvalid),  .m09_axi_bready  (ic_m09_bready),
        .m09_axi_arid    (ic_m09_arid),    .m09_axi_araddr  (ic_m09_araddr),
        .m09_axi_arlen   (ic_m09_arlen),   .m09_axi_arsize  (ic_m09_arsize),
        .m09_axi_arburst (ic_m09_arburst), .m09_axi_arlock  (ic_m09_arlock),
        .m09_axi_arcache (ic_m09_arcache), .m09_axi_arprot  (ic_m09_arprot),
        .m09_axi_arqos   (ic_m09_arqos),   .m09_axi_arvalid (ic_m09_arvalid),
        .m09_axi_arready (ic_m09_arready),
        .m09_axi_rid     (ic_m09_rid),     .m09_axi_rdata   (ic_m09_rdata),
        .m09_axi_rresp   (ic_m09_rresp),   .m09_axi_rlast   (ic_m09_rlast),
        .m09_axi_rvalid  (ic_m09_rvalid),  .m09_axi_rready  (ic_m09_rready),

        // Master port 10: rv_timer
        .m10_axi_awid    (ic_m10_awid),    .m10_axi_awaddr  (ic_m10_awaddr),
        .m10_axi_awlen   (ic_m10_awlen),   .m10_axi_awsize  (ic_m10_awsize),
        .m10_axi_awburst (ic_m10_awburst), .m10_axi_awlock  (ic_m10_awlock),
        .m10_axi_awcache (ic_m10_awcache), .m10_axi_awprot  (ic_m10_awprot),
        .m10_axi_awqos   (ic_m10_awqos),   .m10_axi_awvalid (ic_m10_awvalid),
        .m10_axi_awready (ic_m10_awready),
        .m10_axi_wdata   (ic_m10_wdata),   .m10_axi_wstrb   (ic_m10_wstrb),
        .m10_axi_wlast   (ic_m10_wlast),   .m10_axi_wvalid  (ic_m10_wvalid),
        .m10_axi_wready  (ic_m10_wready),
        .m10_axi_bid     (ic_m10_bid),     .m10_axi_bresp   (ic_m10_bresp),
        .m10_axi_bvalid  (ic_m10_bvalid),  .m10_axi_bready  (ic_m10_bready),
        .m10_axi_arid    (ic_m10_arid),    .m10_axi_araddr  (ic_m10_araddr),
        .m10_axi_arlen   (ic_m10_arlen),   .m10_axi_arsize  (ic_m10_arsize),
        .m10_axi_arburst (ic_m10_arburst), .m10_axi_arlock  (ic_m10_arlock),
        .m10_axi_arcache (ic_m10_arcache), .m10_axi_arprot  (ic_m10_arprot),
        .m10_axi_arqos   (ic_m10_arqos),   .m10_axi_arvalid (ic_m10_arvalid),
        .m10_axi_arready (ic_m10_arready),
        .m10_axi_rid     (ic_m10_rid),     .m10_axi_rdata   (ic_m10_rdata),
        .m10_axi_rresp   (ic_m10_rresp),   .m10_axi_rlast   (ic_m10_rlast),
        .m10_axi_rvalid  (ic_m10_rvalid),  .m10_axi_rready  (ic_m10_rready),

        // Master port 11: Instruction Memory (direct AXI4, no bridge needed)
        .m11_axi_awid    (ic_m11_awid),    .m11_axi_awaddr  (ic_m11_awaddr),
        .m11_axi_awlen   (ic_m11_awlen),   .m11_axi_awsize  (ic_m11_awsize),
        .m11_axi_awburst (ic_m11_awburst), .m11_axi_awlock  (ic_m11_awlock),
        .m11_axi_awcache (ic_m11_awcache), .m11_axi_awprot  (ic_m11_awprot),
        .m11_axi_awqos   (ic_m11_awqos),   .m11_axi_awvalid (ic_m11_awvalid),
        .m11_axi_awready (ic_m11_awready),
        .m11_axi_wdata   (ic_m11_wdata),   .m11_axi_wstrb   (ic_m11_wstrb),
        .m11_axi_wlast   (ic_m11_wlast),   .m11_axi_wvalid  (ic_m11_wvalid),
        .m11_axi_wready  (ic_m11_wready),
        .m11_axi_bid     (ic_m11_bid),     .m11_axi_bresp   (ic_m11_bresp),
        .m11_axi_bvalid  (ic_m11_bvalid),  .m11_axi_bready  (ic_m11_bready),
        .m11_axi_arid    (ic_m11_arid),    .m11_axi_araddr  (ic_m11_araddr),
        .m11_axi_arlen   (ic_m11_arlen),   .m11_axi_arsize  (ic_m11_arsize),
        .m11_axi_arburst (ic_m11_arburst), .m11_axi_arlock  (ic_m11_arlock),
        .m11_axi_arcache (ic_m11_arcache), .m11_axi_arprot  (ic_m11_arprot),
        .m11_axi_arqos   (ic_m11_arqos),   .m11_axi_arvalid (ic_m11_arvalid),
        .m11_axi_arready (ic_m11_arready),
        .m11_axi_rid     (ic_m11_rid),     .m11_axi_rdata   (ic_m11_rdata),
        .m11_axi_rresp   (ic_m11_rresp),   .m11_axi_rlast   (ic_m11_rlast),
        .m11_axi_rvalid  (ic_m11_rvalid),  .m11_axi_rready  (ic_m11_rready),

        // Master port 12: Data Memory (direct AXI4, no bridge needed)
        .m12_axi_awid    (ic_m12_awid),    .m12_axi_awaddr  (ic_m12_awaddr),
        .m12_axi_awlen   (ic_m12_awlen),   .m12_axi_awsize  (ic_m12_awsize),
        .m12_axi_awburst (ic_m12_awburst), .m12_axi_awlock  (ic_m12_awlock),
        .m12_axi_awcache (ic_m12_awcache), .m12_axi_awprot  (ic_m12_awprot),
        .m12_axi_awqos   (ic_m12_awqos),   .m12_axi_awvalid (ic_m12_awvalid),
        .m12_axi_awready (ic_m12_awready),
        .m12_axi_wdata   (ic_m12_wdata),   .m12_axi_wstrb   (ic_m12_wstrb),
        .m12_axi_wlast   (ic_m12_wlast),   .m12_axi_wvalid  (ic_m12_wvalid),
        .m12_axi_wready  (ic_m12_wready),
        .m12_axi_bid     (ic_m12_bid),     .m12_axi_bresp   (ic_m12_bresp),
        .m12_axi_bvalid  (ic_m12_bvalid),  .m12_axi_bready  (ic_m12_bready),
        .m12_axi_arid    (ic_m12_arid),    .m12_axi_araddr  (ic_m12_araddr),
        .m12_axi_arlen   (ic_m12_arlen),   .m12_axi_arsize  (ic_m12_arsize),
        .m12_axi_arburst (ic_m12_arburst), .m12_axi_arlock  (ic_m12_arlock),
        .m12_axi_arcache (ic_m12_arcache), .m12_axi_arprot  (ic_m12_arprot),
        .m12_axi_arqos   (ic_m12_arqos),   .m12_axi_arvalid (ic_m12_arvalid),
        .m12_axi_arready (ic_m12_arready),
        .m12_axi_rid     (ic_m12_rid),     .m12_axi_rdata   (ic_m12_rdata),
        .m12_axi_rresp   (ic_m12_rresp),   .m12_axi_rlast   (ic_m12_rlast),
        .m12_axi_rvalid  (ic_m12_rvalid),  .m12_axi_rready  (ic_m12_rready)
    );

    // =========================================================================
    // 4.  AXI4-to-AXI4-Lite bridges
    //     Port: rst = active-high synchronous; bridge offset width = 16; ID_WIDTH=8
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
    wire [11:0] uart_ip_bid, uart_ip_rid;
    assign uart_axil_bid = uart_ip_bid[BRIDGE_ID_W-1:0];
    assign uart_axil_rid = uart_ip_rid[BRIDGE_ID_W-1:0];

    axi_uart_top u_uart (
        .fixed_clk_i    (clk),
        .axi_aclk_i     (clk),
        .axi_aresetn_i  (rst_n_s),
        // Write address
        .axi_awid_i     ({{(12-BRIDGE_ID_W){1'b0}}, uart_axil_awid}),
        .axi_awaddr_i   (uart_axil_awaddr[4:0]),
        .axi_awvalid_i  (uart_axil_awvalid),
        .axi_awready_o  (uart_axil_awready),
        // Write data
        .axi_wdata_i    (uart_axil_wdata),
        .axi_wstrb_i    (uart_axil_wstrb),
        .axi_wvalid_i   (uart_axil_wvalid),
        .axi_wready_o   (uart_axil_wready),
        // Write response
        .axi_bid_o      (uart_ip_bid),
        .axi_bresp_o    (uart_axil_bresp),
        .axi_bvalid_o   (uart_axil_bvalid),
        .axi_bready_i   (uart_axil_bready),
        // Read address
        .axi_arid_i     ({{(12-BRIDGE_ID_W){1'b0}}, uart_axil_arid}),
        .axi_araddr_i   (uart_axil_araddr[4:0]),
        .axi_arvalid_i  (uart_axil_arvalid),
        .axi_arready_o  (uart_axil_arready),
        // Read data
        .axi_rid_o      (uart_ip_rid),
        .axi_rdata_o    (uart_axil_rdata),
        .axi_rresp_o    (uart_axil_rresp),
        .axi_rvalid_o   (uart_axil_rvalid),
        .axi_rready_i   (uart_axil_rready),
        // Serial
        .uart_rx_i      (uart_rx),
        .uart_tx_o      (uart_tx),
        // Interrupt (unused at top)
        .read_interrupt_o (uart_irq_w)
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
    // 7. AXI-Lite-to-Wishbone bridge: CPU/AXI requests become register
    //    cycles on the Wishbone slave interface of the I2C controller.
    // =========================================================================
    axilite_to_wb_bridge #(
        .ADDR_WIDTH (BRIDGE_LITE_AW)
    ) u_axilite_to_wb (
        .clk             (clk),
        .rst_n           (rst_n_s),
        .s_axil_awaddr   (i2c_axil_awaddr),
        .s_axil_awvalid  (i2c_axil_awvalid),
        .s_axil_awready  (i2c_axil_awready),
        .s_axil_wdata    (i2c_axil_wdata),
        .s_axil_wstrb    (i2c_axil_wstrb),
        .s_axil_wvalid   (i2c_axil_wvalid),
        .s_axil_wready   (i2c_axil_wready),
        .s_axil_bresp    (i2c_axil_bresp),
        .s_axil_bvalid   (i2c_axil_bvalid),
        .s_axil_bready   (i2c_axil_bready),
        .s_axil_araddr   (i2c_axil_araddr),
        .s_axil_arvalid  (i2c_axil_arvalid),
        .s_axil_arready  (i2c_axil_arready),
        .s_axil_rdata    (i2c_axil_rdata),
        .s_axil_rresp    (i2c_axil_rresp),
        .s_axil_rvalid   (i2c_axil_rvalid),
        .s_axil_rready   (i2c_axil_rready),
        .wb_adr_o        (i2c_wb_adr),
        .wb_dat_o        (i2c_wb_dat_w),
        .wb_dat_i        (i2c_wb_dat_r),
        .wb_we_o         (i2c_wb_we),
        .wb_stb_o        (i2c_wb_stb),
        .wb_cyc_o        (i2c_wb_cyc),
        .wb_ack_i        (i2c_wb_ack)
    );
    assign i2c_axil_bid = {BRIDGE_ID_W{1'b0}};
    assign i2c_axil_rid = {BRIDGE_ID_W{1'b0}};

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


    // =========================================================================
    // PWM AXI-Lite wires (bridge output → PWM IP input)
    // PWM IP has no AXI ID ports; bridge ID outputs are declared but unused,
    // bridge ID inputs (bid, rid) are tied to 0.
    // LITE_ADDR_W=4 for PWM IP (4-bit address space, 16 bytes).
    // =========================================================================
    wire [BRIDGE_ID_W-1:0]    pwm_axil_awid;   // bridge output (unused by PWM IP)
    wire [3:0]               pwm_axil_awaddr;  // LITE_ADDR_W=4
    wire                     pwm_axil_awvalid, pwm_axil_awready;
    wire [31:0]              pwm_axil_wdata;
    wire [3:0]               pwm_axil_wstrb;
    wire                     pwm_axil_wvalid, pwm_axil_wready;
    wire [BRIDGE_ID_W-1:0]   pwm_axil_bid;    // bridge input (tied to 0)
    wire [1:0]               pwm_axil_bresp;
    wire                     pwm_axil_bvalid, pwm_axil_bready;
    wire [BRIDGE_ID_W-1:0]   pwm_axil_arid;   // bridge output (unused by PWM IP)
    wire [3:0]               pwm_axil_araddr;
    wire                     pwm_axil_arvalid, pwm_axil_arready;
    wire [BRIDGE_ID_W-1:0]   pwm_axil_rid;    // bridge input (tied to 0)
    wire [31:0]              pwm_axil_rdata;
    wire [1:0]               pwm_axil_rresp;
    wire                     pwm_axil_rvalid, pwm_axil_rready;

    // =========================================================================
    // 9.  PWM Controller  (M04 — axi4_to_axilite_bridge → myip_v1_0)
    //     Address map: 0x4000_0000, 4-bit addr (16 bytes, 4 registers)
    //     Bridge: same axi4_to_axilite_bridge as other peripherals,
    //             LITE_ADDR_W=4, ID_WIDTH=BRIDGE_ID_W (8)
    //     PWM IP: myip_v1_0, active-low reset (aresetn)
    // =========================================================================
    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (4),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_pwm (
        .clk            (clk),
        .rst            (rst_ah),       // active-high synchronous reset

        // AXI4 slave interface (from interconnect M04)
        .s_axi_awid    (ic_m04_awid),
        .s_axi_awaddr  (ic_m04_awaddr),
        .s_axi_awlen   (ic_m04_awlen),
        .s_axi_awsize  (ic_m04_awsize),
        .s_axi_awburst (ic_m04_awburst),
        .s_axi_awlock  (ic_m04_awlock),
        .s_axi_awcache (ic_m04_awcache),
        .s_axi_awprot  (ic_m04_awprot),
        .s_axi_awqos   (ic_m04_awqos),
        .s_axi_awregion(ic_m04_awregion),
        .s_axi_awvalid (ic_m04_awvalid),
        .s_axi_awready (ic_m04_awready),
        .s_axi_wdata   (ic_m04_wdata),
        .s_axi_wstrb   (ic_m04_wstrb),
        .s_axi_wlast   (ic_m04_wlast),
        .s_axi_wvalid  (ic_m04_wvalid),
        .s_axi_wready  (ic_m04_wready),
        .s_axi_bid     (ic_m04_bid),
        .s_axi_bresp   (ic_m04_bresp),
        .s_axi_bvalid  (ic_m04_bvalid),
        .s_axi_bready  (ic_m04_bready),
        .s_axi_arid    (ic_m04_arid),
        .s_axi_araddr  (ic_m04_araddr),
        .s_axi_arlen   (ic_m04_arlen),
        .s_axi_arsize  (ic_m04_arsize),
        .s_axi_arburst (ic_m04_arburst),
        .s_axi_arlock  (ic_m04_arlock),
        .s_axi_arcache (ic_m04_arcache),
        .s_axi_arprot  (ic_m04_arprot),
        .s_axi_arqos   (ic_m04_arqos),
        .s_axi_arregion(ic_m04_arregion),
        .s_axi_arvalid (ic_m04_arvalid),
        .s_axi_arready (ic_m04_arready),
        .s_axi_rid     (ic_m04_rid),
        .s_axi_rdata   (ic_m04_rdata),
        .s_axi_rresp   (ic_m04_rresp),
        .s_axi_rlast   (ic_m04_rlast),
        .s_axi_rvalid  (ic_m04_rvalid),
        .s_axi_rready  (ic_m04_rready),

        // AXI-Lite master interface (to PWM IP)
        .m_axil_awid    (pwm_axil_awid),
        .m_axil_awaddr  (pwm_axil_awaddr),
        .m_axil_awvalid (pwm_axil_awvalid),
        .m_axil_awready (pwm_axil_awready),
        .m_axil_wdata   (pwm_axil_wdata),
        .m_axil_wstrb   (pwm_axil_wstrb),
        .m_axil_wvalid  (pwm_axil_wvalid),
        .m_axil_wready  (pwm_axil_wready),
        .m_axil_bid     (pwm_axil_bid),
        .m_axil_bresp   (pwm_axil_bresp),
        .m_axil_bvalid  (pwm_axil_bvalid),
        .m_axil_bready  (pwm_axil_bready),
        .m_axil_arid    (pwm_axil_arid),
        .m_axil_araddr  (pwm_axil_araddr),
        .m_axil_arvalid (pwm_axil_arvalid),
        .m_axil_arready (pwm_axil_arready),
        .m_axil_rid     (pwm_axil_rid),
        .m_axil_rdata   (pwm_axil_rdata),
        .m_axil_rresp   (pwm_axil_rresp),
        .m_axil_rvalid  (pwm_axil_rvalid),
        .m_axil_rready  (pwm_axil_rready)
    );

    myip_v1_0 #(
        .C_S00_AXI_DATA_WIDTH (32),
        .C_S00_AXI_ADDR_WIDTH (4)
    ) u_pwm (
        .s00_axi_aclk    (clk),
        .s00_axi_aresetn (rst_n_s),    // active-low reset

        .s00_axi_awaddr  (pwm_axil_awaddr),
        .s00_axi_awprot  (3'b000),     // bridge has no awprot output; tie to 0
        .s00_axi_awvalid (pwm_axil_awvalid),
        .s00_axi_awready (pwm_axil_awready),

        .s00_axi_wdata   (pwm_axil_wdata),
        .s00_axi_wstrb   (pwm_axil_wstrb),
        .s00_axi_wvalid  (pwm_axil_wvalid),
        .s00_axi_wready  (pwm_axil_wready),

        .s00_axi_bresp   (pwm_axil_bresp),
        .s00_axi_bvalid  (pwm_axil_bvalid),
        .s00_axi_bready  (pwm_axil_bready),

        .s00_axi_araddr  (pwm_axil_araddr),
        .s00_axi_arprot  (3'b000),     // bridge has no arprot output; tie to 0
        .s00_axi_arvalid (pwm_axil_arvalid),
        .s00_axi_arready (pwm_axil_arready),

        .s00_axi_rdata   (pwm_axil_rdata),
        .s00_axi_rresp   (pwm_axil_rresp),
        .s00_axi_rvalid  (pwm_axil_rvalid),
        .s00_axi_rready  (pwm_axil_rready),

        .PWM_OUT         (pwm_out)
    );

    // Tie bridge ID inputs to 0 (PWM IP has no ID outputs)
    assign pwm_axil_bid = {BRIDGE_ID_W{1'b0}};
    assign pwm_axil_rid = {BRIDGE_ID_W{1'b0}};

    // =========================================================================
    // Internal interrupt / status wires
    // =========================================================================
    assign gpio_irq_combined = gpio_irq_w | (|gpio_pin_irq_w);
    assign gpio_irq = gpio_irq_combined;
    assign gpio_out = gpio_out_w;
    assign gpio_tx_en = gpio_tx_en_w;
    assign core_extintsrc_req[1] = extintsrc_req[1];
    assign core_extintsrc_req[2] = extintsrc_req[2] | uart_irq_w;
    assign core_extintsrc_req[3] = extintsrc_req[3] | i2c_irq;
    assign core_extintsrc_req[4] = extintsrc_req[4] | wdt_irq_w;
    assign core_extintsrc_req[5] = extintsrc_req[5] | dma_done_w | dma_error_w;
    assign core_extintsrc_req[6] = extintsrc_req[6] | scs_irq_w | gpio_irq_combined;
    assign core_extintsrc_req[31:7] = extintsrc_req[31:7];

    // =========================================================================
    // AXI-Lite wires for M05-M10 (after axi4_to_axilite_bridge)
    // =========================================================================
    localparam SHA256_ADDR_W = 8;
    localparam GPIO_ADDR_W   = 5;   // BRIDGE_LITE_AW – only lower bits used
    localparam WDT_ADDR_W    = 5;
    localparam DMA_ADDR_W    = 8;
    localparam SCS_ADDR_W    = 5;
    localparam TIMER_ADDR_W  = 5;

    // SHA256 AXI-Lite (M05)
    wire [BRIDGE_ID_W-1:0]   sha256_axil_awid;
    wire [SHA256_ADDR_W-1:0] sha256_axil_awaddr;
    wire                     sha256_axil_awvalid, sha256_axil_awready;
    wire [31:0]              sha256_axil_wdata;
    wire [3:0]               sha256_axil_wstrb;
    wire                     sha256_axil_wvalid, sha256_axil_wready;
    wire [BRIDGE_ID_W-1:0]   sha256_axil_bid;
    wire [1:0]               sha256_axil_bresp;
    wire                     sha256_axil_bvalid, sha256_axil_bready;
    wire [BRIDGE_ID_W-1:0]   sha256_axil_arid;
    wire [SHA256_ADDR_W-1:0] sha256_axil_araddr;
    wire                     sha256_axil_arvalid, sha256_axil_arready;
    wire [BRIDGE_ID_W-1:0]   sha256_axil_rid;
    wire [31:0]              sha256_axil_rdata;
    wire [1:0]               sha256_axil_rresp;
    wire                     sha256_axil_rvalid, sha256_axil_rready;

    // GPIO AXI-Lite (M06)
    wire [BRIDGE_ID_W-1:0]  gpio_axil_awid;
    wire [BRIDGE_LITE_AW-1:0] gpio_axil_awaddr;
    wire                    gpio_axil_awvalid, gpio_axil_awready;
    wire [31:0]             gpio_axil_wdata;
    wire [3:0]              gpio_axil_wstrb;
    wire                    gpio_axil_wvalid, gpio_axil_wready;
    wire [BRIDGE_ID_W-1:0]  gpio_axil_bid;
    wire [1:0]              gpio_axil_bresp;
    wire                    gpio_axil_bvalid, gpio_axil_bready;
    wire [BRIDGE_ID_W-1:0]  gpio_axil_arid;
    wire [BRIDGE_LITE_AW-1:0] gpio_axil_araddr;
    wire                    gpio_axil_arvalid, gpio_axil_arready;
    wire [BRIDGE_ID_W-1:0]  gpio_axil_rid;
    wire [31:0]             gpio_axil_rdata;
    wire [1:0]              gpio_axil_rresp;
    wire                    gpio_axil_rvalid, gpio_axil_rready;

    // WDT AXI-Lite (M07)
    wire [BRIDGE_ID_W-1:0]  wdt_axil_awid;
    wire [BRIDGE_LITE_AW-1:0] wdt_axil_awaddr;
    wire                    wdt_axil_awvalid, wdt_axil_awready;
    wire [31:0]             wdt_axil_wdata;
    wire [3:0]              wdt_axil_wstrb;
    wire                    wdt_axil_wvalid, wdt_axil_wready;
    wire [BRIDGE_ID_W-1:0]  wdt_axil_bid;
    wire [1:0]              wdt_axil_bresp;
    wire                    wdt_axil_bvalid, wdt_axil_bready;
    wire [BRIDGE_ID_W-1:0]  wdt_axil_arid;
    wire [BRIDGE_LITE_AW-1:0] wdt_axil_araddr;
    wire                    wdt_axil_arvalid, wdt_axil_arready;
    wire [BRIDGE_ID_W-1:0]  wdt_axil_rid;
    wire [31:0]             wdt_axil_rdata;
    wire [1:0]              wdt_axil_rresp;
    wire                    wdt_axil_rvalid, wdt_axil_rready;

    // DMA AXI-Lite (M08)
    wire [BRIDGE_ID_W-1:0]  dma_axil_awid;
    wire [BRIDGE_LITE_AW-1:0] dma_axil_awaddr;
    wire                    dma_axil_awvalid, dma_axil_awready;
    wire [31:0]             dma_axil_wdata;
    wire [3:0]              dma_axil_wstrb;
    wire                    dma_axil_wvalid, dma_axil_wready;
    wire [BRIDGE_ID_W-1:0]  dma_axil_bid;
    wire [1:0]              dma_axil_bresp;
    wire                    dma_axil_bvalid, dma_axil_bready;
    wire [BRIDGE_ID_W-1:0]  dma_axil_arid;
    wire [BRIDGE_LITE_AW-1:0] dma_axil_araddr;
    wire                    dma_axil_arvalid, dma_axil_arready;
    wire [BRIDGE_ID_W-1:0]  dma_axil_rid;
    wire [31:0]             dma_axil_rdata;
    wire [1:0]              dma_axil_rresp;
    wire                    dma_axil_rvalid, dma_axil_rready;

    // SCS AXI-Lite (M09)
    wire [BRIDGE_ID_W-1:0]  scs_axil_awid;
    wire [BRIDGE_LITE_AW-1:0] scs_axil_awaddr;
    wire                    scs_axil_awvalid, scs_axil_awready;
    wire [31:0]             scs_axil_wdata;
    wire [3:0]              scs_axil_wstrb;
    wire                    scs_axil_wvalid, scs_axil_wready;
    wire [BRIDGE_ID_W-1:0]  scs_axil_bid;
    wire [1:0]              scs_axil_bresp;
    wire                    scs_axil_bvalid, scs_axil_bready;
    wire [BRIDGE_ID_W-1:0]  scs_axil_arid;
    wire [BRIDGE_LITE_AW-1:0] scs_axil_araddr;
    wire                    scs_axil_arvalid, scs_axil_arready;
    wire [BRIDGE_ID_W-1:0]  scs_axil_rid;
    wire [31:0]             scs_axil_rdata;
    wire [1:0]              scs_axil_rresp;
    wire                    scs_axil_rvalid, scs_axil_rready;

    // Timer AXI-Lite (M10)
    wire [BRIDGE_ID_W-1:0]  timer_axil_awid;
    wire [BRIDGE_LITE_AW-1:0] timer_axil_awaddr;
    wire                    timer_axil_awvalid, timer_axil_awready;
    wire [31:0]             timer_axil_wdata;
    wire [3:0]              timer_axil_wstrb;
    wire                    timer_axil_wvalid, timer_axil_wready;
    wire [BRIDGE_ID_W-1:0]  timer_axil_bid;
    wire [1:0]              timer_axil_bresp;
    wire                    timer_axil_bvalid, timer_axil_bready;
    wire [BRIDGE_ID_W-1:0]  timer_axil_arid;
    wire [BRIDGE_LITE_AW-1:0] timer_axil_araddr;
    wire                    timer_axil_arvalid, timer_axil_arready;
    wire [BRIDGE_ID_W-1:0]  timer_axil_rid;
    wire [31:0]             timer_axil_rdata;
    wire [1:0]              timer_axil_rresp;
    wire                    timer_axil_rvalid, timer_axil_rready;

    // =========================================================================
    // 10. AXI4-to-AXI-Lite bridges M05-M10
    // =========================================================================

    // --- Bridge M05 → SHA256 (LITE_ADDR_W=8) ---
    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (SHA256_ADDR_W),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_sha256 (
        .clk           (clk), .rst (rst_ah),
        .s_axi_awid    (ic_m05_awid),    .s_axi_awaddr  (ic_m05_awaddr),
        .s_axi_awlen   (ic_m05_awlen),   .s_axi_awsize  (ic_m05_awsize),
        .s_axi_awburst (ic_m05_awburst), .s_axi_awlock  (ic_m05_awlock),
        .s_axi_awcache (ic_m05_awcache), .s_axi_awprot  (ic_m05_awprot),
        .s_axi_awqos   (ic_m05_awqos),   .s_axi_awregion(ic_m05_awregion),
        .s_axi_awvalid (ic_m05_awvalid), .s_axi_awready (ic_m05_awready),
        .s_axi_wdata   (ic_m05_wdata),   .s_axi_wstrb   (ic_m05_wstrb),
        .s_axi_wlast   (ic_m05_wlast),   .s_axi_wvalid  (ic_m05_wvalid),
        .s_axi_wready  (ic_m05_wready),
        .s_axi_bid     (ic_m05_bid),     .s_axi_bresp   (ic_m05_bresp),
        .s_axi_bvalid  (ic_m05_bvalid),  .s_axi_bready  (ic_m05_bready),
        .s_axi_arid    (ic_m05_arid),    .s_axi_araddr  (ic_m05_araddr),
        .s_axi_arlen   (ic_m05_arlen),   .s_axi_arsize  (ic_m05_arsize),
        .s_axi_arburst (ic_m05_arburst), .s_axi_arlock  (ic_m05_arlock),
        .s_axi_arcache (ic_m05_arcache), .s_axi_arprot  (ic_m05_arprot),
        .s_axi_arqos   (ic_m05_arqos),   .s_axi_arregion(ic_m05_arregion),
        .s_axi_arvalid (ic_m05_arvalid), .s_axi_arready (ic_m05_arready),
        .s_axi_rid     (ic_m05_rid),     .s_axi_rdata   (ic_m05_rdata),
        .s_axi_rresp   (ic_m05_rresp),   .s_axi_rlast   (ic_m05_rlast),
        .s_axi_rvalid  (ic_m05_rvalid),  .s_axi_rready  (ic_m05_rready),
        .m_axil_awid   (sha256_axil_awid),  .m_axil_awaddr (sha256_axil_awaddr),
        .m_axil_awvalid(sha256_axil_awvalid),.m_axil_awready(sha256_axil_awready),
        .m_axil_wdata  (sha256_axil_wdata), .m_axil_wstrb  (sha256_axil_wstrb),
        .m_axil_wvalid (sha256_axil_wvalid),.m_axil_wready (sha256_axil_wready),
        .m_axil_bid    (sha256_axil_bid),   .m_axil_bresp  (sha256_axil_bresp),
        .m_axil_bvalid (sha256_axil_bvalid),.m_axil_bready (sha256_axil_bready),
        .m_axil_arid   (sha256_axil_arid),  .m_axil_araddr (sha256_axil_araddr),
        .m_axil_arvalid(sha256_axil_arvalid),.m_axil_arready(sha256_axil_arready),
        .m_axil_rid    (sha256_axil_rid),   .m_axil_rdata  (sha256_axil_rdata),
        .m_axil_rresp  (sha256_axil_rresp), .m_axil_rvalid (sha256_axil_rvalid),
        .m_axil_rready (sha256_axil_rready)
    );

    // --- Bridge M06 → GPIO ---
    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (BRIDGE_LITE_AW),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_gpio (
        .clk           (clk), .rst (rst_ah),
        .s_axi_awid    (ic_m06_awid),    .s_axi_awaddr  (ic_m06_awaddr),
        .s_axi_awlen   (ic_m06_awlen),   .s_axi_awsize  (ic_m06_awsize),
        .s_axi_awburst (ic_m06_awburst), .s_axi_awlock  (ic_m06_awlock),
        .s_axi_awcache (ic_m06_awcache), .s_axi_awprot  (ic_m06_awprot),
        .s_axi_awqos   (ic_m06_awqos),   .s_axi_awregion(ic_m06_awregion),
        .s_axi_awvalid (ic_m06_awvalid), .s_axi_awready (ic_m06_awready),
        .s_axi_wdata   (ic_m06_wdata),   .s_axi_wstrb   (ic_m06_wstrb),
        .s_axi_wlast   (ic_m06_wlast),   .s_axi_wvalid  (ic_m06_wvalid),
        .s_axi_wready  (ic_m06_wready),
        .s_axi_bid     (ic_m06_bid),     .s_axi_bresp   (ic_m06_bresp),
        .s_axi_bvalid  (ic_m06_bvalid),  .s_axi_bready  (ic_m06_bready),
        .s_axi_arid    (ic_m06_arid),    .s_axi_araddr  (ic_m06_araddr),
        .s_axi_arlen   (ic_m06_arlen),   .s_axi_arsize  (ic_m06_arsize),
        .s_axi_arburst (ic_m06_arburst), .s_axi_arlock  (ic_m06_arlock),
        .s_axi_arcache (ic_m06_arcache), .s_axi_arprot  (ic_m06_arprot),
        .s_axi_arqos   (ic_m06_arqos),   .s_axi_arregion(ic_m06_arregion),
        .s_axi_arvalid (ic_m06_arvalid), .s_axi_arready (ic_m06_arready),
        .s_axi_rid     (ic_m06_rid),     .s_axi_rdata   (ic_m06_rdata),
        .s_axi_rresp   (ic_m06_rresp),   .s_axi_rlast   (ic_m06_rlast),
        .s_axi_rvalid  (ic_m06_rvalid),  .s_axi_rready  (ic_m06_rready),
        .m_axil_awid   (gpio_axil_awid),  .m_axil_awaddr (gpio_axil_awaddr),
        .m_axil_awvalid(gpio_axil_awvalid),.m_axil_awready(gpio_axil_awready),
        .m_axil_wdata  (gpio_axil_wdata), .m_axil_wstrb  (gpio_axil_wstrb),
        .m_axil_wvalid (gpio_axil_wvalid),.m_axil_wready (gpio_axil_wready),
        .m_axil_bid    (gpio_axil_bid),   .m_axil_bresp  (gpio_axil_bresp),
        .m_axil_bvalid (gpio_axil_bvalid),.m_axil_bready (gpio_axil_bready),
        .m_axil_arid   (gpio_axil_arid),  .m_axil_araddr (gpio_axil_araddr),
        .m_axil_arvalid(gpio_axil_arvalid),.m_axil_arready(gpio_axil_arready),
        .m_axil_rid    (gpio_axil_rid),   .m_axil_rdata  (gpio_axil_rdata),
        .m_axil_rresp  (gpio_axil_rresp), .m_axil_rvalid (gpio_axil_rvalid),
        .m_axil_rready (gpio_axil_rready)
    );

    // --- Bridge M07 → WDT ---
    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (BRIDGE_LITE_AW),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_wdt (
        .clk           (clk), .rst (rst_ah),
        .s_axi_awid    (ic_m07_awid),    .s_axi_awaddr  (ic_m07_awaddr),
        .s_axi_awlen   (ic_m07_awlen),   .s_axi_awsize  (ic_m07_awsize),
        .s_axi_awburst (ic_m07_awburst), .s_axi_awlock  (ic_m07_awlock),
        .s_axi_awcache (ic_m07_awcache), .s_axi_awprot  (ic_m07_awprot),
        .s_axi_awqos   (ic_m07_awqos),   .s_axi_awregion(ic_m07_awregion),
        .s_axi_awvalid (ic_m07_awvalid), .s_axi_awready (ic_m07_awready),
        .s_axi_wdata   (ic_m07_wdata),   .s_axi_wstrb   (ic_m07_wstrb),
        .s_axi_wlast   (ic_m07_wlast),   .s_axi_wvalid  (ic_m07_wvalid),
        .s_axi_wready  (ic_m07_wready),
        .s_axi_bid     (ic_m07_bid),     .s_axi_bresp   (ic_m07_bresp),
        .s_axi_bvalid  (ic_m07_bvalid),  .s_axi_bready  (ic_m07_bready),
        .s_axi_arid    (ic_m07_arid),    .s_axi_araddr  (ic_m07_araddr),
        .s_axi_arlen   (ic_m07_arlen),   .s_axi_arsize  (ic_m07_arsize),
        .s_axi_arburst (ic_m07_arburst), .s_axi_arlock  (ic_m07_arlock),
        .s_axi_arcache (ic_m07_arcache), .s_axi_arprot  (ic_m07_arprot),
        .s_axi_arqos   (ic_m07_arqos),   .s_axi_arregion(ic_m07_arregion),
        .s_axi_arvalid (ic_m07_arvalid), .s_axi_arready (ic_m07_arready),
        .s_axi_rid     (ic_m07_rid),     .s_axi_rdata   (ic_m07_rdata),
        .s_axi_rresp   (ic_m07_rresp),   .s_axi_rlast   (ic_m07_rlast),
        .s_axi_rvalid  (ic_m07_rvalid),  .s_axi_rready  (ic_m07_rready),
        .m_axil_awid   (wdt_axil_awid),  .m_axil_awaddr (wdt_axil_awaddr),
        .m_axil_awvalid(wdt_axil_awvalid),.m_axil_awready(wdt_axil_awready),
        .m_axil_wdata  (wdt_axil_wdata), .m_axil_wstrb  (wdt_axil_wstrb),
        .m_axil_wvalid (wdt_axil_wvalid),.m_axil_wready (wdt_axil_wready),
        .m_axil_bid    (wdt_axil_bid),   .m_axil_bresp  (wdt_axil_bresp),
        .m_axil_bvalid (wdt_axil_bvalid),.m_axil_bready (wdt_axil_bready),
        .m_axil_arid   (wdt_axil_arid),  .m_axil_araddr (wdt_axil_araddr),
        .m_axil_arvalid(wdt_axil_arvalid),.m_axil_arready(wdt_axil_arready),
        .m_axil_rid    (wdt_axil_rid),   .m_axil_rdata  (wdt_axil_rdata),
        .m_axil_rresp  (wdt_axil_rresp), .m_axil_rvalid (wdt_axil_rvalid),
        .m_axil_rready (wdt_axil_rready)
    );

    // --- Bridge M08 → DMA ---
    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (BRIDGE_LITE_AW),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_dma (
        .clk           (clk), .rst (rst_ah),
        .s_axi_awid    (ic_m08_awid),    .s_axi_awaddr  (ic_m08_awaddr),
        .s_axi_awlen   (ic_m08_awlen),   .s_axi_awsize  (ic_m08_awsize),
        .s_axi_awburst (ic_m08_awburst), .s_axi_awlock  (ic_m08_awlock),
        .s_axi_awcache (ic_m08_awcache), .s_axi_awprot  (ic_m08_awprot),
        .s_axi_awqos   (ic_m08_awqos),   .s_axi_awregion(ic_m08_awregion),
        .s_axi_awvalid (ic_m08_awvalid), .s_axi_awready (ic_m08_awready),
        .s_axi_wdata   (ic_m08_wdata),   .s_axi_wstrb   (ic_m08_wstrb),
        .s_axi_wlast   (ic_m08_wlast),   .s_axi_wvalid  (ic_m08_wvalid),
        .s_axi_wready  (ic_m08_wready),
        .s_axi_bid     (ic_m08_bid),     .s_axi_bresp   (ic_m08_bresp),
        .s_axi_bvalid  (ic_m08_bvalid),  .s_axi_bready  (ic_m08_bready),
        .s_axi_arid    (ic_m08_arid),    .s_axi_araddr  (ic_m08_araddr),
        .s_axi_arlen   (ic_m08_arlen),   .s_axi_arsize  (ic_m08_arsize),
        .s_axi_arburst (ic_m08_arburst), .s_axi_arlock  (ic_m08_arlock),
        .s_axi_arcache (ic_m08_arcache), .s_axi_arprot  (ic_m08_arprot),
        .s_axi_arqos   (ic_m08_arqos),   .s_axi_arregion(ic_m08_arregion),
        .s_axi_arvalid (ic_m08_arvalid), .s_axi_arready (ic_m08_arready),
        .s_axi_rid     (ic_m08_rid),     .s_axi_rdata   (ic_m08_rdata),
        .s_axi_rresp   (ic_m08_rresp),   .s_axi_rlast   (ic_m08_rlast),
        .s_axi_rvalid  (ic_m08_rvalid),  .s_axi_rready  (ic_m08_rready),
        .m_axil_awid   (dma_axil_awid),  .m_axil_awaddr (dma_axil_awaddr),
        .m_axil_awvalid(dma_axil_awvalid),.m_axil_awready(dma_axil_awready),
        .m_axil_wdata  (dma_axil_wdata), .m_axil_wstrb  (dma_axil_wstrb),
        .m_axil_wvalid (dma_axil_wvalid),.m_axil_wready (dma_axil_wready),
        .m_axil_bid    (dma_axil_bid),   .m_axil_bresp  (dma_axil_bresp),
        .m_axil_bvalid (dma_axil_bvalid),.m_axil_bready (dma_axil_bready),
        .m_axil_arid   (dma_axil_arid),  .m_axil_araddr (dma_axil_araddr),
        .m_axil_arvalid(dma_axil_arvalid),.m_axil_arready(dma_axil_arready),
        .m_axil_rid    (dma_axil_rid),   .m_axil_rdata  (dma_axil_rdata),
        .m_axil_rresp  (dma_axil_rresp), .m_axil_rvalid (dma_axil_rvalid),
        .m_axil_rready (dma_axil_rready)
    );

    // --- Bridge M09 → System Control & Status ---
    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (BRIDGE_LITE_AW),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_scs (
        .clk           (clk), .rst (rst_ah),
        .s_axi_awid    (ic_m09_awid),    .s_axi_awaddr  (ic_m09_awaddr),
        .s_axi_awlen   (ic_m09_awlen),   .s_axi_awsize  (ic_m09_awsize),
        .s_axi_awburst (ic_m09_awburst), .s_axi_awlock  (ic_m09_awlock),
        .s_axi_awcache (ic_m09_awcache), .s_axi_awprot  (ic_m09_awprot),
        .s_axi_awqos   (ic_m09_awqos),   .s_axi_awregion(ic_m09_awregion),
        .s_axi_awvalid (ic_m09_awvalid), .s_axi_awready (ic_m09_awready),
        .s_axi_wdata   (ic_m09_wdata),   .s_axi_wstrb   (ic_m09_wstrb),
        .s_axi_wlast   (ic_m09_wlast),   .s_axi_wvalid  (ic_m09_wvalid),
        .s_axi_wready  (ic_m09_wready),
        .s_axi_bid     (ic_m09_bid),     .s_axi_bresp   (ic_m09_bresp),
        .s_axi_bvalid  (ic_m09_bvalid),  .s_axi_bready  (ic_m09_bready),
        .s_axi_arid    (ic_m09_arid),    .s_axi_araddr  (ic_m09_araddr),
        .s_axi_arlen   (ic_m09_arlen),   .s_axi_arsize  (ic_m09_arsize),
        .s_axi_arburst (ic_m09_arburst), .s_axi_arlock  (ic_m09_arlock),
        .s_axi_arcache (ic_m09_arcache), .s_axi_arprot  (ic_m09_arprot),
        .s_axi_arqos   (ic_m09_arqos),   .s_axi_arregion(ic_m09_arregion),
        .s_axi_arvalid (ic_m09_arvalid), .s_axi_arready (ic_m09_arready),
        .s_axi_rid     (ic_m09_rid),     .s_axi_rdata   (ic_m09_rdata),
        .s_axi_rresp   (ic_m09_rresp),   .s_axi_rlast   (ic_m09_rlast),
        .s_axi_rvalid  (ic_m09_rvalid),  .s_axi_rready  (ic_m09_rready),
        .m_axil_awid   (scs_axil_awid),  .m_axil_awaddr (scs_axil_awaddr),
        .m_axil_awvalid(scs_axil_awvalid),.m_axil_awready(scs_axil_awready),
        .m_axil_wdata  (scs_axil_wdata), .m_axil_wstrb  (scs_axil_wstrb),
        .m_axil_wvalid (scs_axil_wvalid),.m_axil_wready (scs_axil_wready),
        .m_axil_bid    (scs_axil_bid),   .m_axil_bresp  (scs_axil_bresp),
        .m_axil_bvalid (scs_axil_bvalid),.m_axil_bready (scs_axil_bready),
        .m_axil_arid   (scs_axil_arid),  .m_axil_araddr (scs_axil_araddr),
        .m_axil_arvalid(scs_axil_arvalid),.m_axil_arready(scs_axil_arready),
        .m_axil_rid    (scs_axil_rid),   .m_axil_rdata  (scs_axil_rdata),
        .m_axil_rresp  (scs_axil_rresp), .m_axil_rvalid (scs_axil_rvalid),
        .m_axil_rready (scs_axil_rready)
    );

    // --- Bridge M10 → rv_timer ---
    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (BRIDGE_LITE_AW),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_timer (
        .clk           (clk), .rst (rst_ah),
        .s_axi_awid    (ic_m10_awid),    .s_axi_awaddr  (ic_m10_awaddr),
        .s_axi_awlen   (ic_m10_awlen),   .s_axi_awsize  (ic_m10_awsize),
        .s_axi_awburst (ic_m10_awburst), .s_axi_awlock  (ic_m10_awlock),
        .s_axi_awcache (ic_m10_awcache), .s_axi_awprot  (ic_m10_awprot),
        .s_axi_awqos   (ic_m10_awqos),   .s_axi_awregion(ic_m10_awregion),
        .s_axi_awvalid (ic_m10_awvalid), .s_axi_awready (ic_m10_awready),
        .s_axi_wdata   (ic_m10_wdata),   .s_axi_wstrb   (ic_m10_wstrb),
        .s_axi_wlast   (ic_m10_wlast),   .s_axi_wvalid  (ic_m10_wvalid),
        .s_axi_wready  (ic_m10_wready),
        .s_axi_bid     (ic_m10_bid),     .s_axi_bresp   (ic_m10_bresp),
        .s_axi_bvalid  (ic_m10_bvalid),  .s_axi_bready  (ic_m10_bready),
        .s_axi_arid    (ic_m10_arid),    .s_axi_araddr  (ic_m10_araddr),
        .s_axi_arlen   (ic_m10_arlen),   .s_axi_arsize  (ic_m10_arsize),
        .s_axi_arburst (ic_m10_arburst), .s_axi_arlock  (ic_m10_arlock),
        .s_axi_arcache (ic_m10_arcache), .s_axi_arprot  (ic_m10_arprot),
        .s_axi_arqos   (ic_m10_arqos),   .s_axi_arregion(ic_m10_arregion),
        .s_axi_arvalid (ic_m10_arvalid), .s_axi_arready (ic_m10_arready),
        .s_axi_rid     (ic_m10_rid),     .s_axi_rdata   (ic_m10_rdata),
        .s_axi_rresp   (ic_m10_rresp),   .s_axi_rlast   (ic_m10_rlast),
        .s_axi_rvalid  (ic_m10_rvalid),  .s_axi_rready  (ic_m10_rready),
        .m_axil_awid   (timer_axil_awid),  .m_axil_awaddr (timer_axil_awaddr),
        .m_axil_awvalid(timer_axil_awvalid),.m_axil_awready(timer_axil_awready),
        .m_axil_wdata  (timer_axil_wdata), .m_axil_wstrb  (timer_axil_wstrb),
        .m_axil_wvalid (timer_axil_wvalid),.m_axil_wready (timer_axil_wready),
        .m_axil_bid    (timer_axil_bid),   .m_axil_bresp  (timer_axil_bresp),
        .m_axil_bvalid (timer_axil_bvalid),.m_axil_bready (timer_axil_bready),
        .m_axil_arid   (timer_axil_arid),  .m_axil_araddr (timer_axil_araddr),
        .m_axil_arvalid(timer_axil_arvalid),.m_axil_arready(timer_axil_arready),
        .m_axil_rid    (timer_axil_rid),   .m_axil_rdata  (timer_axil_rdata),
        .m_axil_rresp  (timer_axil_rresp), .m_axil_rvalid (timer_axil_rvalid),
        .m_axil_rready (timer_axil_rready)
    );

    // =========================================================================
    // 11. SHA256 (M05 — 0x5000_0000, 256-byte addr)
    // =========================================================================
    sha256_axi4 #(
        .C_S00_AXI_DATA_WIDTH (32),
        .C_S00_AXI_ADDR_WIDTH (SHA256_ADDR_W)
    ) u_sha256 (
        .s00_axi_aclk    (clk),
        .s00_axi_aresetn (rst_n_s),
        .s00_axi_awaddr  (sha256_axil_awaddr),
        .s00_axi_awprot  (3'b000),
        .s00_axi_awvalid (sha256_axil_awvalid),
        .s00_axi_awready (sha256_axil_awready),
        .s00_axi_wdata   (sha256_axil_wdata),
        .s00_axi_wstrb   (sha256_axil_wstrb),
        .s00_axi_wvalid  (sha256_axil_wvalid),
        .s00_axi_wready  (sha256_axil_wready),
        .s00_axi_bresp   (sha256_axil_bresp),
        .s00_axi_bvalid  (sha256_axil_bvalid),
        .s00_axi_bready  (sha256_axil_bready),
        .s00_axi_araddr  (sha256_axil_araddr),
        .s00_axi_arprot  (3'b000),
        .s00_axi_arvalid (sha256_axil_arvalid),
        .s00_axi_arready (sha256_axil_arready),
        .s00_axi_rdata   (sha256_axil_rdata),
        .s00_axi_rresp   (sha256_axil_rresp),
        .s00_axi_rvalid  (sha256_axil_rvalid),
        .s00_axi_rready  (sha256_axil_rready),
        .hash_complete   ()
    );
    assign sha256_axil_bid = {BRIDGE_ID_W{1'b0}};
    assign sha256_axil_rid = {BRIDGE_ID_W{1'b0}};

    // =========================================================================
    // 12. GPIO (M06 — 0x6000_0000)
    //     Uses gpio_axilite_wrap_flat; address mapped via BRIDGE_LITE_AW=5
    // =========================================================================
    gpio_axilite_wrap_flat #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32)
    ) u_gpio (
        .clk_i              (clk),
        .rst_ni             (rst_n_s),
        .s_axi_awaddr       ({{(32-BRIDGE_LITE_AW){1'b0}}, gpio_axil_awaddr}),
        .s_axi_awprot       (3'b000),
        .s_axi_awvalid      (gpio_axil_awvalid),
        .s_axi_awready      (gpio_axil_awready),
        .s_axi_wdata        (gpio_axil_wdata),
        .s_axi_wstrb        (gpio_axil_wstrb),
        .s_axi_wvalid       (gpio_axil_wvalid),
        .s_axi_wready       (gpio_axil_wready),
        .s_axi_bresp        (gpio_axil_bresp),
        .s_axi_bvalid       (gpio_axil_bvalid),
        .s_axi_bready       (gpio_axil_bready),
        .s_axi_araddr       ({{(32-BRIDGE_LITE_AW){1'b0}}, gpio_axil_araddr}),
        .s_axi_arprot       (3'b000),
        .s_axi_arvalid      (gpio_axil_arvalid),
        .s_axi_arready      (gpio_axil_arready),
        .s_axi_rdata        (gpio_axil_rdata),
        .s_axi_rresp        (gpio_axil_rresp),
        .s_axi_rvalid       (gpio_axil_rvalid),
        .s_axi_rready       (gpio_axil_rready),
        .gpio_in            (gpio_in),
        .gpio_out           (gpio_out_w),
        .gpio_tx_en_o       (gpio_tx_en_w),
        .gpio_in_sync_o     (gpio_in_sync_w),
        .global_interrupt_o (gpio_irq_w),
        .pin_level_interrupts_o(gpio_pin_irq_w)
    );
    assign gpio_axil_bid = {BRIDGE_ID_W{1'b0}};
    assign gpio_axil_rid = {BRIDGE_ID_W{1'b0}};

    // =========================================================================
    // 13. EF_WDT32 Watchdog (M07 — 0x7000_0000)
    // =========================================================================
    EF_WDT32_AXI #(
        .C_S_AXI_DATA_WIDTH (32),
        .C_S_AXI_ADDR_WIDTH (BRIDGE_LITE_AW)
    ) u_wdt (
        .s_axi_aclk    (clk),
        .s_axi_aresetn (rst_n_s),
        .s_axi_awaddr  (wdt_axil_awaddr),
        .s_axi_awprot  (3'b000),
        .s_axi_awvalid (wdt_axil_awvalid),
        .s_axi_awready (wdt_axil_awready),
        .s_axi_wdata   (wdt_axil_wdata),
        .s_axi_wstrb   (wdt_axil_wstrb),
        .s_axi_wvalid  (wdt_axil_wvalid),
        .s_axi_wready  (wdt_axil_wready),
        .s_axi_bresp   (wdt_axil_bresp),
        .s_axi_bvalid  (wdt_axil_bvalid),
        .s_axi_bready  (wdt_axil_bready),
        .s_axi_araddr  (wdt_axil_araddr),
        .s_axi_arprot  (3'b000),
        .s_axi_arvalid (wdt_axil_arvalid),
        .s_axi_arready (wdt_axil_arready),
        .s_axi_rdata   (wdt_axil_rdata),
        .s_axi_rresp   (wdt_axil_rresp),
        .s_axi_rvalid  (wdt_axil_rvalid),
        .s_axi_rready  (wdt_axil_rready),
        .wdt_irq     (wdt_irq_w),
        .wdt_timeout (wdt_timeout_w)
    );
    assign wdt_axil_bid = {BRIDGE_ID_W{1'b0}};
    assign wdt_axil_rid = {BRIDGE_ID_W{1'b0}};

    // =========================================================================
    // 14. DMA CSR (M08 — 0x8000_0000)
    // =========================================================================
    dma_axi_flat #(
        .C_S_AXI_DATA_WIDTH (32),
        .C_S_AXI_ADDR_WIDTH (BRIDGE_LITE_AW),
        .C_M_AXI_ADDR_WIDTH (32),
        .C_M_AXI_DATA_WIDTH (32),
        .C_M_AXI_ID_WIDTH   (4)
    ) u_dma (
        .aclk           (clk),
        .aresetn        (rst_n_s),
        .s_axil_awaddr  (dma_axil_awaddr),
        .s_axil_awprot  (3'b000),
        .s_axil_awvalid (dma_axil_awvalid),
        .s_axil_awready (dma_axil_awready),
        .s_axil_wdata   (dma_axil_wdata),
        .s_axil_wstrb   (dma_axil_wstrb),
        .s_axil_wvalid  (dma_axil_wvalid),
        .s_axil_wready  (dma_axil_wready),
        .s_axil_bresp   (dma_axil_bresp),
        .s_axil_bvalid  (dma_axil_bvalid),
        .s_axil_bready  (dma_axil_bready),
        .s_axil_araddr  (dma_axil_araddr),
        .s_axil_arprot  (3'b000),
        .s_axil_arvalid (dma_axil_arvalid),
        .s_axil_arready (dma_axil_arready),
        .s_axil_rdata   (dma_axil_rdata),
        .s_axil_rresp   (dma_axil_rresp),
        .s_axil_rvalid  (dma_axil_rvalid),
        .s_axil_rready  (dma_axil_rready),
        // DMA master bus (tied off inside dma_axi_flat)
        .m_axi_awid    (), .m_axi_awaddr (), .m_axi_awlen  (), .m_axi_awsize  (),
        .m_axi_awburst (), .m_axi_awlock (), .m_axi_awcache(), .m_axi_awprot  (),
        .m_axi_awvalid (), .m_axi_awready(1'b0),
        .m_axi_wdata   (), .m_axi_wstrb  (), .m_axi_wlast  (),
        .m_axi_wvalid  (), .m_axi_wready (1'b0),
        .m_axi_bid     (4'h0), .m_axi_bresp(2'b00), .m_axi_bvalid(1'b0), .m_axi_bready(),
        .m_axi_arid    (), .m_axi_araddr (), .m_axi_arlen  (), .m_axi_arsize  (),
        .m_axi_arburst (), .m_axi_arlock (), .m_axi_arcache(), .m_axi_arprot  (),
        .m_axi_arvalid (), .m_axi_arready(1'b0),
        .m_axi_rid     (4'h0), .m_axi_rdata(32'h0), .m_axi_rresp(2'b00),
        .m_axi_rlast   (1'b0), .m_axi_rvalid(1'b0), .m_axi_rready(),
        .dma_done_irq  (dma_done_w),
        .dma_error_irq (dma_error_w)
    );
    assign dma_axil_bid = {BRIDGE_ID_W{1'b0}};
    assign dma_axil_rid = {BRIDGE_ID_W{1'b0}};

    // =========================================================================
    // 15. System Control & Status (M09 — 0x9000_0000)
    // =========================================================================
    system_control_status #(
        .IP_ID   (32'hAE61_5001),
        .VERSION (32'h0001_0000)
    ) u_scs (
        .aclk          (clk),
        .aresetn       (rst_n_s),
        .s_axi_awaddr  (scs_axil_awaddr[4:0]),
        .s_axi_awvalid (scs_axil_awvalid),
        .s_axi_awready (scs_axil_awready),
        .s_axi_wdata   (scs_axil_wdata),
        .s_axi_wstrb   (scs_axil_wstrb),
        .s_axi_wvalid  (scs_axil_wvalid),
        .s_axi_wready  (scs_axil_wready),
        .s_axi_bresp   (scs_axil_bresp),
        .s_axi_bvalid  (scs_axil_bvalid),
        .s_axi_bready  (scs_axil_bready),
        .s_axi_araddr  (scs_axil_araddr[4:0]),
        .s_axi_arvalid (scs_axil_arvalid),
        .s_axi_arready (scs_axil_arready),
        .s_axi_rdata   (scs_axil_rdata),
        .s_axi_rresp   (scs_axil_rresp),
        .s_axi_rvalid  (scs_axil_rvalid),
        .s_axi_rready  (scs_axil_rready),
        // Status inputs from peripherals
        .uart_ready     (1'b1),
        .aes_ready      (1'b1),
        .i2c_ready      (1'b1),
        .watchdog_active(wdt_timeout_w),
        .security_error (1'b0),
        .bus_error      (1'b0),
        .debug_active   (1'b0),
        // Control outputs
        .sys_enable     (scs_sys_enable),
        .soft_reset     (scs_soft_reset),
        .debug_enable   (scs_debug_en),
        .low_power      (scs_low_power),
        .irq_global_enable(scs_irq_global_en),
        .irq            (scs_irq_w)
    );
    assign scs_axil_bid = {BRIDGE_ID_W{1'b0}};
    assign scs_axil_rid = {BRIDGE_ID_W{1'b0}};

    // =========================================================================
    // 16. rv_timer / mtime (M10 — 0xA000_0000)
    // =========================================================================
    rv_timer_axi #(
        .C_S_AXI_DATA_WIDTH (32),
        .C_S_AXI_ADDR_WIDTH (BRIDGE_LITE_AW)
    ) u_timer (
        .s_axi_aclk    (clk),
        .s_axi_aresetn (rst_n_s),
        .s_axi_awaddr  (timer_axil_awaddr),
        .s_axi_awprot  (3'b000),
        .s_axi_awvalid (timer_axil_awvalid),
        .s_axi_awready (timer_axil_awready),
        .s_axi_wdata   (timer_axil_wdata),
        .s_axi_wstrb   (timer_axil_wstrb),
        .s_axi_wvalid  (timer_axil_wvalid),
        .s_axi_wready  (timer_axil_wready),
        .s_axi_bresp   (timer_axil_bresp),
        .s_axi_bvalid  (timer_axil_bvalid),
        .s_axi_bready  (timer_axil_bready),
        .s_axi_araddr  (timer_axil_araddr),
        .s_axi_arprot  (3'b000),
        .s_axi_arvalid (timer_axil_arvalid),
        .s_axi_arready (timer_axil_arready),
        .s_axi_rdata   (timer_axil_rdata),
        .s_axi_rresp   (timer_axil_rresp),
        .s_axi_rvalid  (timer_axil_rvalid),
        .s_axi_rready  (timer_axil_rready),
        .timer_irq     (timer_irq_w)
    );
    assign timer_axil_bid = {BRIDGE_ID_W{1'b0}};
    assign timer_axil_rid = {BRIDGE_ID_W{1'b0}};

    // =========================================================================
    // 17. Instruction Memory (M11 — 0xB000_0000, 64 KB)
    //     AXI4-Lite slave, read-only from bus (writes return SLVERR)
    // =========================================================================
    // AXI-Lite wires for IMEM (after bridge)
    localparam IMEM_ADDR_W = 5;  // 5-bit addr from bridge, IMEM uses lower bits
    wire [BRIDGE_ID_W-1:0]  imem_axil_awid;
    wire [BRIDGE_LITE_AW-1:0] imem_axil_awaddr;
    wire                    imem_axil_awvalid, imem_axil_awready;
    wire [31:0]             imem_axil_wdata;
    wire [3:0]              imem_axil_wstrb;
    wire                    imem_axil_wvalid, imem_axil_wready;
    wire [BRIDGE_ID_W-1:0]  imem_axil_bid;
    wire [1:0]              imem_axil_bresp;
    wire                    imem_axil_bvalid, imem_axil_bready;
    wire [BRIDGE_ID_W-1:0]  imem_axil_arid;
    wire [BRIDGE_LITE_AW-1:0] imem_axil_araddr;
    wire                    imem_axil_arvalid, imem_axil_arready;
    wire [BRIDGE_ID_W-1:0]  imem_axil_rid;
    wire [31:0]             imem_axil_rdata;
    wire [1:0]              imem_axil_rresp;
    wire                    imem_axil_rvalid, imem_axil_rready;

    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (BRIDGE_LITE_AW),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_imem (
        .clk           (clk), .rst (rst_ah),
        .s_axi_awid    (ic_m11_awid),    .s_axi_awaddr  (ic_m11_awaddr),
        .s_axi_awlen   (ic_m11_awlen),   .s_axi_awsize  (ic_m11_awsize),
        .s_axi_awburst (ic_m11_awburst), .s_axi_awlock  (ic_m11_awlock),
        .s_axi_awcache (ic_m11_awcache), .s_axi_awprot  (ic_m11_awprot),
        .s_axi_awqos   (ic_m11_awqos),   .s_axi_awregion(ic_m11_awregion),
        .s_axi_awvalid (ic_m11_awvalid), .s_axi_awready (ic_m11_awready),
        .s_axi_wdata   (ic_m11_wdata),   .s_axi_wstrb   (ic_m11_wstrb),
        .s_axi_wlast   (ic_m11_wlast),   .s_axi_wvalid  (ic_m11_wvalid),
        .s_axi_wready  (ic_m11_wready),
        .s_axi_bid     (ic_m11_bid),     .s_axi_bresp   (ic_m11_bresp),
        .s_axi_bvalid  (ic_m11_bvalid),  .s_axi_bready  (ic_m11_bready),
        .s_axi_arid    (ic_m11_arid),    .s_axi_araddr  (ic_m11_araddr),
        .s_axi_arlen   (ic_m11_arlen),   .s_axi_arsize  (ic_m11_arsize),
        .s_axi_arburst (ic_m11_arburst), .s_axi_arlock  (ic_m11_arlock),
        .s_axi_arcache (ic_m11_arcache), .s_axi_arprot  (ic_m11_arprot),
        .s_axi_arqos   (ic_m11_arqos),   .s_axi_arregion(ic_m11_arregion),
        .s_axi_arvalid (ic_m11_arvalid), .s_axi_arready (ic_m11_arready),
        .s_axi_rid     (ic_m11_rid),     .s_axi_rdata   (ic_m11_rdata),
        .s_axi_rresp   (ic_m11_rresp),   .s_axi_rlast   (ic_m11_rlast),
        .s_axi_rvalid  (ic_m11_rvalid),  .s_axi_rready  (ic_m11_rready),
        .m_axil_awid   (imem_axil_awid),  .m_axil_awaddr (imem_axil_awaddr),
        .m_axil_awvalid(imem_axil_awvalid),.m_axil_awready(imem_axil_awready),
        .m_axil_wdata  (imem_axil_wdata), .m_axil_wstrb  (imem_axil_wstrb),
        .m_axil_wvalid (imem_axil_wvalid),.m_axil_wready (imem_axil_wready),
        .m_axil_bid    (imem_axil_bid),   .m_axil_bresp  (imem_axil_bresp),
        .m_axil_bvalid (imem_axil_bvalid),.m_axil_bready (imem_axil_bready),
        .m_axil_arid   (imem_axil_arid),  .m_axil_araddr (imem_axil_araddr),
        .m_axil_arvalid(imem_axil_arvalid),.m_axil_arready(imem_axil_arready),
        .m_axil_rid    (imem_axil_rid),   .m_axil_rdata  (imem_axil_rdata),
        .m_axil_rresp  (imem_axil_rresp), .m_axil_rvalid (imem_axil_rvalid),
        .m_axil_rready (imem_axil_rready)
    );

    instruction_memory u_imem (
        .aclk           (clk),
        .aresetn        (rst_n_s),
        .s_axi_awaddr   ({{(32-BRIDGE_LITE_AW){1'b0}}, imem_axil_awaddr}),
        .s_axi_awvalid  (imem_axil_awvalid),
        .s_axi_awready  (imem_axil_awready),
        .s_axi_wdata    (imem_axil_wdata),
        .s_axi_wstrb    (imem_axil_wstrb),
        .s_axi_wvalid   (imem_axil_wvalid),
        .s_axi_wready   (imem_axil_wready),
        .s_axi_bresp    (imem_axil_bresp),
        .s_axi_bvalid   (imem_axil_bvalid),
        .s_axi_bready   (imem_axil_bready),
        .s_axi_araddr   ({{(32-BRIDGE_LITE_AW){1'b0}}, imem_axil_araddr}),
        .s_axi_arvalid  (imem_axil_arvalid),
        .s_axi_arready  (imem_axil_arready),
        .s_axi_rdata    (imem_axil_rdata),
        .s_axi_rresp    (imem_axil_rresp),
        .s_axi_rvalid   (imem_axil_rvalid),
        .s_axi_rready   (imem_axil_rready)
    );
    assign imem_axil_bid = {BRIDGE_ID_W{1'b0}};
    assign imem_axil_rid = {BRIDGE_ID_W{1'b0}};

    // =========================================================================
    // 18. Data Memory (M12 — 0xC000_0000, 64 KB)
    //     AXI4-Lite slave, read/write with byte strobes
    // =========================================================================
    wire [BRIDGE_ID_W-1:0]  dmem_axil_awid;
    wire [BRIDGE_LITE_AW-1:0] dmem_axil_awaddr;
    wire                    dmem_axil_awvalid, dmem_axil_awready;
    wire [31:0]             dmem_axil_wdata;
    wire [3:0]              dmem_axil_wstrb;
    wire                    dmem_axil_wvalid, dmem_axil_wready;
    wire [BRIDGE_ID_W-1:0]  dmem_axil_bid;
    wire [1:0]              dmem_axil_bresp;
    wire                    dmem_axil_bvalid, dmem_axil_bready;
    wire [BRIDGE_ID_W-1:0]  dmem_axil_arid;
    wire [BRIDGE_LITE_AW-1:0] dmem_axil_araddr;
    wire                    dmem_axil_arvalid, dmem_axil_arready;
    wire [BRIDGE_ID_W-1:0]  dmem_axil_rid;
    wire [31:0]             dmem_axil_rdata;
    wire [1:0]              dmem_axil_rresp;
    wire                    dmem_axil_rvalid, dmem_axil_rready;

    axi4_to_axilite_bridge #(
        .DATA_WIDTH  (AXI_DATA_WIDTH),
        .ADDR_WIDTH  (AXI_ADDR_WIDTH),
        .LITE_ADDR_W (BRIDGE_LITE_AW),
        .ID_WIDTH    (BRIDGE_ID_W)
    ) u_bridge_dmem (
        .clk           (clk), .rst (rst_ah),
        .s_axi_awid    (ic_m12_awid),    .s_axi_awaddr  (ic_m12_awaddr),
        .s_axi_awlen   (ic_m12_awlen),   .s_axi_awsize  (ic_m12_awsize),
        .s_axi_awburst (ic_m12_awburst), .s_axi_awlock  (ic_m12_awlock),
        .s_axi_awcache (ic_m12_awcache), .s_axi_awprot  (ic_m12_awprot),
        .s_axi_awqos   (ic_m12_awqos),   .s_axi_awregion(ic_m12_awregion),
        .s_axi_awvalid (ic_m12_awvalid), .s_axi_awready (ic_m12_awready),
        .s_axi_wdata   (ic_m12_wdata),   .s_axi_wstrb   (ic_m12_wstrb),
        .s_axi_wlast   (ic_m12_wlast),   .s_axi_wvalid  (ic_m12_wvalid),
        .s_axi_wready  (ic_m12_wready),
        .s_axi_bid     (ic_m12_bid),     .s_axi_bresp   (ic_m12_bresp),
        .s_axi_bvalid  (ic_m12_bvalid),  .s_axi_bready  (ic_m12_bready),
        .s_axi_arid    (ic_m12_arid),    .s_axi_araddr  (ic_m12_araddr),
        .s_axi_arlen   (ic_m12_arlen),   .s_axi_arsize  (ic_m12_arsize),
        .s_axi_arburst (ic_m12_arburst), .s_axi_arlock  (ic_m12_arlock),
        .s_axi_arcache (ic_m12_arcache), .s_axi_arprot  (ic_m12_arprot),
        .s_axi_arqos   (ic_m12_arqos),   .s_axi_arregion(ic_m12_arregion),
        .s_axi_arvalid (ic_m12_arvalid), .s_axi_arready (ic_m12_arready),
        .s_axi_rid     (ic_m12_rid),     .s_axi_rdata   (ic_m12_rdata),
        .s_axi_rresp   (ic_m12_rresp),   .s_axi_rlast   (ic_m12_rlast),
        .s_axi_rvalid  (ic_m12_rvalid),  .s_axi_rready  (ic_m12_rready),
        .m_axil_awid   (dmem_axil_awid),  .m_axil_awaddr (dmem_axil_awaddr),
        .m_axil_awvalid(dmem_axil_awvalid),.m_axil_awready(dmem_axil_awready),
        .m_axil_wdata  (dmem_axil_wdata), .m_axil_wstrb  (dmem_axil_wstrb),
        .m_axil_wvalid (dmem_axil_wvalid),.m_axil_wready (dmem_axil_wready),
        .m_axil_bid    (dmem_axil_bid),   .m_axil_bresp  (dmem_axil_bresp),
        .m_axil_bvalid (dmem_axil_bvalid),.m_axil_bready (dmem_axil_bready),
        .m_axil_arid   (dmem_axil_arid),  .m_axil_araddr (dmem_axil_araddr),
        .m_axil_arvalid(dmem_axil_arvalid),.m_axil_arready(dmem_axil_arready),
        .m_axil_rid    (dmem_axil_rid),   .m_axil_rdata  (dmem_axil_rdata),
        .m_axil_rresp  (dmem_axil_rresp), .m_axil_rvalid (dmem_axil_rvalid),
        .m_axil_rready (dmem_axil_rready)
    );

    data_memory u_dmem (
        .aclk           (clk),
        .aresetn        (rst_n_s),
        .s_axi_awaddr   ({{(32-BRIDGE_LITE_AW){1'b0}}, dmem_axil_awaddr}),
        .s_axi_awvalid  (dmem_axil_awvalid),
        .s_axi_awready  (dmem_axil_awready),
        .s_axi_wdata    (dmem_axil_wdata),
        .s_axi_wstrb    (dmem_axil_wstrb),
        .s_axi_wvalid   (dmem_axil_wvalid),
        .s_axi_wready   (dmem_axil_wready),
        .s_axi_bresp    (dmem_axil_bresp),
        .s_axi_bvalid   (dmem_axil_bvalid),
        .s_axi_bready   (dmem_axil_bready),
        .s_axi_araddr   ({{(32-BRIDGE_LITE_AW){1'b0}}, dmem_axil_araddr}),
        .s_axi_arvalid  (dmem_axil_arvalid),
        .s_axi_arready  (dmem_axil_arready),
        .s_axi_rdata    (dmem_axil_rdata),
        .s_axi_rresp    (dmem_axil_rresp),
        .s_axi_rvalid   (dmem_axil_rvalid),
        .s_axi_rready   (dmem_axil_rready)
    );
    assign dmem_axil_bid = {BRIDGE_ID_W{1'b0}};
    assign dmem_axil_rid = {BRIDGE_ID_W{1'b0}};

endmodule

`default_nettype wire
