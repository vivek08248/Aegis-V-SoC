// =============================================================================
// File         : rv_timer_axi.v
// Description  : Simple 64-bit RISC-V compatible machine timer with AXI4-Lite
//                slave interface.  Compatible with the RISC-V Privileged Spec
//                MTIME / MTIMECMP registers.
//
//  Register Map (byte addresses):
//    0x00  MTIME_LO    (R/W) lower 32 bits of mtime counter
//    0x04  MTIME_HI    (R/W) upper 32 bits of mtime counter
//    0x08  MTIMECMP_LO (R/W) lower 32 bits of mtimecmp
//    0x0C  MTIMECMP_HI (R/W) upper 32 bits of mtimecmp
//    0x10  CTRL        (R/W) bit0: timer enable, bit1: interrupt enable
//    0x14  STATUS      (RO)  bit0: timer_expired interrupt pending
//    0x18  PRESCALER   (R/W) 16-bit prescaler value (default=0 = divide by 1)
//
//  Interrupt:  timer_irq asserted when (mtime >= mtimecmp) && CTRL[1]
// =============================================================================
`timescale 1ns/1ps
`default_nettype none

module rv_timer_axi #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5
)(
    // AXI4-Lite Slave Interface
    input  wire                              s_axi_aclk,
    input  wire                              s_axi_aresetn,

    // Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [2:0]                        s_axi_awprot,
    input  wire                              s_axi_awvalid,
    output wire                              s_axi_awready,

    // Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output wire                              s_axi_wready,

    // Write Response Channel
    output wire [1:0]                        s_axi_bresp,
    output wire                              s_axi_bvalid,
    input  wire                              s_axi_bready,

    // Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [2:0]                        s_axi_arprot,
    input  wire                              s_axi_arvalid,
    output wire                              s_axi_arready,

    // Read Data Channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]                        s_axi_rresp,
    output wire                              s_axi_rvalid,
    input  wire                              s_axi_rready,

    // Timer interrupt output
    output wire                              timer_irq
);

    // -------------------------------------------------------------------------
    // AXI4-Lite handshake
    // -------------------------------------------------------------------------
    reg  aw_act, w_act, bvalid_r;
    reg  ar_act, rvalid_r;
    reg  [C_S_AXI_ADDR_WIDTH-1:0] aw_addr_r, ar_addr_r;
    reg  [C_S_AXI_DATA_WIDTH-1:0] wdata_r, rdata_r;

    assign s_axi_awready = ~aw_act;
    assign s_axi_wready  = ~w_act;
    assign s_axi_bvalid  = bvalid_r;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_arready = ~ar_act;
    assign s_axi_rvalid  = rvalid_r;
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = 2'b00;

    // -------------------------------------------------------------------------
    // Timer registers
    // -------------------------------------------------------------------------
    reg [63:0] mtime;
    reg [63:0] mtimecmp;
    reg [1:0]  ctrl_reg;    // [0] = enable, [1] = int_en
    reg [15:0] prescaler;
    reg [15:0] prescaler_cnt;
    reg        irq_pending;

    // -------------------------------------------------------------------------
    // Timer logic
    // -------------------------------------------------------------------------
    wire timer_en  = ctrl_reg[0];
    wire int_en    = ctrl_reg[1];
    wire cmp_hit   = (mtime >= mtimecmp);

    assign timer_irq = int_en & irq_pending;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            mtime         <= 64'h0;
            mtimecmp      <= 64'hFFFF_FFFF_FFFF_FFFF;
            prescaler     <= 16'h0;
            prescaler_cnt <= 16'h0;
            irq_pending   <= 1'b0;
        end else begin
            // Prescaled tick
            if (timer_en) begin
                if (prescaler == 16'h0 || prescaler_cnt == prescaler) begin
                    prescaler_cnt <= 16'h0;
                    mtime         <= mtime + 64'h1;
                end else begin
                    prescaler_cnt <= prescaler_cnt + 16'h1;
                end
            end

            // IRQ flag
            if (cmp_hit && timer_en)
                irq_pending <= 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Write state machine
    // -------------------------------------------------------------------------
    reg wfire;
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            aw_act <= 0; w_act <= 0; bvalid_r <= 0; wfire <= 0;
            ctrl_reg <= 2'b00;
            aw_addr_r <= 0; wdata_r <= 0;
        end else begin
            wfire <= 0;
            if (s_axi_awvalid && !aw_act) begin aw_act <= 1; aw_addr_r <= s_axi_awaddr; end
            if (s_axi_wvalid  && !w_act)  begin w_act  <= 1; wdata_r   <= s_axi_wdata; end
            if (aw_act && w_act && !bvalid_r) begin
                wfire <= 1; aw_act <= 0; w_act <= 0; bvalid_r <= 1;
                case (aw_addr_r[4:2])
                    3'h0: mtime[31:0]    <= wdata_r;
                    3'h1: mtime[63:32]   <= wdata_r;
                    3'h2: mtimecmp[31:0] <= wdata_r;
                    3'h3: mtimecmp[63:32]<= wdata_r;
                    3'h4: begin ctrl_reg <= wdata_r[1:0]; irq_pending <= irq_pending & ~wdata_r[2]; end
                    3'h5: ; // STATUS is RO
                    3'h6: prescaler      <= wdata_r[15:0];
                    default: ;
                endcase
            end
            if (bvalid_r && s_axi_bready) bvalid_r <= 0;
        end
    end

    // -------------------------------------------------------------------------
    // Read state machine
    // -------------------------------------------------------------------------
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            ar_act <= 0; ar_addr_r <= 0; rvalid_r <= 0; rdata_r <= 0;
        end else begin
            if (s_axi_arvalid && !ar_act) begin ar_act <= 1; ar_addr_r <= s_axi_araddr; end
            if (ar_act && !rvalid_r) begin
                rvalid_r <= 1; ar_act <= 0;
                case (ar_addr_r[4:2])
                    3'h0: rdata_r <= mtime[31:0];
                    3'h1: rdata_r <= mtime[63:32];
                    3'h2: rdata_r <= mtimecmp[31:0];
                    3'h3: rdata_r <= mtimecmp[63:32];
                    3'h4: rdata_r <= {30'h0, ctrl_reg};
                    3'h5: rdata_r <= {31'h0, irq_pending};
                    3'h6: rdata_r <= {16'h0, prescaler};
                    default: rdata_r <= 32'h0;
                endcase
            end
            if (rvalid_r && s_axi_rready) rvalid_r <= 0;
        end
    end

endmodule

`default_nettype wire
