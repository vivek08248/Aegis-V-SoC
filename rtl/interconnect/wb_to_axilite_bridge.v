// =============================================================================
// Project      : Aegis-V SoC
// File         : wb_to_axilite_bridge.v
// Description  : Wishbone B4 (8-bit data, 3-bit address) to AXI4-Lite bridge.
//                Connects the OpenCores I2C master (Wishbone slave interface)
//                to the SoC AXI4-Lite interconnect as an AXI master.
//
//                The I2C core's Wishbone interface is:
//                  wb_adr_i [2:0]  - register select (8 registers max)
//                  wb_dat_i [7:0]  - 8-bit write data
//                  wb_dat_o [7:0]  - 8-bit read data
//                  wb_we_i         - write enable
//                  wb_stb_i        - strobe (select)
//                  wb_cyc_i        - cycle valid
//                  wb_ack_o        - acknowledge
//
//                AXI4-Lite master interface (32-bit data, 32-bit address):
//                  The 3-bit Wishbone address maps to AXI byte address
//                  (WB_BASE_ADDR + {wb_adr, 2'b00}) to align to 32-bit words.
//                  8-bit data is placed on the appropriate byte lane.
//
// Limitations  : Single outstanding transaction (no pipelining).
//                Burst transfers not supported (Wishbone single cycle only).
//
// Timing       : AXI and Wishbone share the same clock (clk).
// =============================================================================

`resetall
`timescale 1ns / 1ps
`default_nettype none

module wb_to_axilite_bridge #(
    parameter ADDR_WIDTH    = 32,
    parameter WB_BASE_ADDR  = 32'h3000_0000  // I2C base in SoC memory map
)(
    input  wire                  clk,
    input  wire                  rst_n,       // active-low reset

    // -------------------------------------------------------------------------
    // Wishbone Slave Interface  (connected FROM i2c_master_top)
    // -------------------------------------------------------------------------
    input  wire [2:0]            wb_adr_i,    // register address (3-bit)
    input  wire [7:0]            wb_dat_i,    // write data (8-bit)
    output reg  [7:0]            wb_dat_o,    // read data (8-bit)
    input  wire                  wb_we_i,     // 1 = write, 0 = read
    input  wire                  wb_stb_i,    // strobe (transaction valid)
    input  wire                  wb_cyc_i,    // bus cycle
    output reg                   wb_ack_o,    // acknowledge

    // -------------------------------------------------------------------------
    // AXI4-Lite Master Interface  (connected TO interconnect slave port)
    // -------------------------------------------------------------------------
    // Write address channel
    output reg  [ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg                   m_axi_awvalid,
    input  wire                  m_axi_awready,

    // Write data channel
    output reg  [31:0]           m_axi_wdata,
    output reg  [3:0]            m_axi_wstrb,
    output reg                   m_axi_wvalid,
    input  wire                  m_axi_wready,

    // Write response channel
    input  wire [1:0]            m_axi_bresp,
    input  wire                  m_axi_bvalid,
    output reg                   m_axi_bready,

    // Read address channel
    output reg  [ADDR_WIDTH-1:0] m_axi_araddr,
    output reg                   m_axi_arvalid,
    input  wire                  m_axi_arready,

    // Read data channel
    input  wire [31:0]           m_axi_rdata,
    input  wire [1:0]            m_axi_rresp,
    input  wire                  m_axi_rvalid,
    output reg                   m_axi_rready
);

    // -------------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------------
    localparam [2:0]
        ST_IDLE      = 3'd0,
        ST_WR_ADDR   = 3'd1,
        ST_WR_DATA   = 3'd2,
        ST_WR_RESP   = 3'd3,
        ST_RD_ADDR   = 3'd4,
        ST_RD_DATA   = 3'd5,
        ST_ACK       = 3'd6;

    reg [2:0] state;

    // Latch Wishbone request
    reg [2:0] wb_adr_lat;
    reg [7:0] wb_dat_lat;
    reg       wb_we_lat;

    // Byte lane: WB address is already byte-aligned within a 32-bit word.
    // WB register width is 8-bit; map each 3-bit address to a 32-bit AXI word.
    // byte_lane selects which byte in the 32-bit word the 8-bit value occupies.
    wire [1:0] byte_lane = wb_adr_lat[1:0];

    // Full AXI address: base + {addr[2], 2'b00}  (4-byte stride)
    wire [ADDR_WIDTH-1:0] axi_addr = WB_BASE_ADDR + {{(ADDR_WIDTH-5){1'b0}}, wb_adr_lat, 2'b00};

    // Expand 8-bit write data to appropriate byte lane of 32-bit AXI word
    wire [31:0] axi_wdata =
        (byte_lane == 2'd0) ? {24'b0, wb_dat_lat} :
        (byte_lane == 2'd1) ? {16'b0, wb_dat_lat, 8'b0} :
        (byte_lane == 2'd2) ? {8'b0,  wb_dat_lat, 16'b0} :
                              {wb_dat_lat, 24'b0};

    wire [3:0] axi_wstrb =
        (byte_lane == 2'd0) ? 4'b0001 :
        (byte_lane == 2'd1) ? 4'b0010 :
        (byte_lane == 2'd2) ? 4'b0100 :
                              4'b1000;

    // Extract 8-bit read data from appropriate byte lane
    wire [7:0] axi_rdata_byte =
        (byte_lane == 2'd0) ? m_axi_rdata[7:0]   :
        (byte_lane == 2'd1) ? m_axi_rdata[15:8]  :
        (byte_lane == 2'd2) ? m_axi_rdata[23:16] :
                              m_axi_rdata[31:24];

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            wb_ack_o       <= 1'b0;
            wb_dat_o       <= 8'h00;
            m_axi_awvalid  <= 1'b0;
            m_axi_awaddr   <= {ADDR_WIDTH{1'b0}};
            m_axi_wvalid   <= 1'b0;
            m_axi_wdata    <= 32'h0;
            m_axi_wstrb    <= 4'h0;
            m_axi_bready   <= 1'b0;
            m_axi_arvalid  <= 1'b0;
            m_axi_araddr   <= {ADDR_WIDTH{1'b0}};
            m_axi_rready   <= 1'b0;
            wb_adr_lat     <= 3'h0;
            wb_dat_lat     <= 8'h0;
            wb_we_lat      <= 1'b0;
        end else begin
            // Default: deassert single-cycle signals
            wb_ack_o <= 1'b0;

            case (state)

                // -------------------------------------------------------
                ST_IDLE: begin
                    if (wb_cyc_i && wb_stb_i) begin
                        // Latch request
                        wb_adr_lat <= wb_adr_i;
                        wb_dat_lat <= wb_dat_i;
                        wb_we_lat  <= wb_we_i;
                        if (wb_we_i)
                            state <= ST_WR_ADDR;
                        else
                            state <= ST_RD_ADDR;
                    end
                end

                // -------------------------------------------------------
                // WRITE: issue address channel
                // -------------------------------------------------------
                ST_WR_ADDR: begin
                    m_axi_awaddr  <= axi_addr;
                    m_axi_awvalid <= 1'b1;
                    m_axi_wdata   <= axi_wdata;
                    m_axi_wstrb   <= axi_wstrb;
                    m_axi_wvalid  <= 1'b1;
                    if (m_axi_awready && m_axi_wready) begin
                        m_axi_awvalid <= 1'b0;
                        m_axi_wvalid  <= 1'b0;
                        m_axi_bready  <= 1'b1;
                        state         <= ST_WR_RESP;
                    end else if (m_axi_awready && !m_axi_wready) begin
                        m_axi_awvalid <= 1'b0;
                        state         <= ST_WR_DATA;
                    end else if (!m_axi_awready && m_axi_wready) begin
                        m_axi_wvalid  <= 1'b0;
                        state         <= ST_WR_ADDR; // wait for awready
                    end
                end

                // -------------------------------------------------------
                // WRITE: data channel still pending
                // -------------------------------------------------------
                ST_WR_DATA: begin
                    if (m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                        m_axi_bready <= 1'b1;
                        state        <= ST_WR_RESP;
                    end
                end

                // -------------------------------------------------------
                // WRITE: wait for write response
                // -------------------------------------------------------
                ST_WR_RESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        state        <= ST_ACK;
                    end
                end

                // -------------------------------------------------------
                // READ: issue address channel
                // -------------------------------------------------------
                ST_RD_ADDR: begin
                    m_axi_araddr  <= axi_addr;
                    m_axi_arvalid <= 1'b1;
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= ST_RD_DATA;
                    end
                end

                // -------------------------------------------------------
                // READ: wait for read data
                // -------------------------------------------------------
                ST_RD_DATA: begin
                    if (m_axi_rvalid) begin
                        wb_dat_o     <= axi_rdata_byte;
                        m_axi_rready <= 1'b0;
                        state        <= ST_ACK;
                    end
                end

                // -------------------------------------------------------
                // ACK: pulse wb_ack_o for one cycle then return to IDLE
                // -------------------------------------------------------
                ST_ACK: begin
                    wb_ack_o <= 1'b1;
                    state    <= ST_IDLE;
                end

                default: state <= ST_IDLE;

            endcase
        end
    end

endmodule

`default_nettype wire
