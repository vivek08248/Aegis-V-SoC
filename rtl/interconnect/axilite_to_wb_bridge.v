`timescale 1ns/1ps
`default_nettype none

// AXI4-Lite slave to 8-bit Wishbone master. Used to let the SoC's AXI
// peripheral path access the OpenCores I2C controller's Wishbone register
// slave. AXI addresses are byte addresses; I2C registers are word-spaced.
module axilite_to_wb_bridge #(
    parameter integer ADDR_WIDTH = 16
) (
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire [ADDR_WIDTH-1:0] s_axil_awaddr,
    input  wire                  s_axil_awvalid,
    output wire                  s_axil_awready,
    input  wire [31:0]           s_axil_wdata,
    input  wire [3:0]            s_axil_wstrb,
    input  wire                  s_axil_wvalid,
    output wire                  s_axil_wready,
    output reg  [1:0]            s_axil_bresp,
    output reg                   s_axil_bvalid,
    input  wire                  s_axil_bready,

    input  wire [ADDR_WIDTH-1:0] s_axil_araddr,
    input  wire                  s_axil_arvalid,
    output wire                  s_axil_arready,
    output reg  [31:0]           s_axil_rdata,
    output reg  [1:0]            s_axil_rresp,
    output reg                   s_axil_rvalid,
    input  wire                  s_axil_rready,

    output reg  [2:0]            wb_adr_o,
    output reg  [7:0]            wb_dat_o,
    input  wire [7:0]            wb_dat_i,
    output reg                   wb_we_o,
    output reg                   wb_stb_o,
    output reg                   wb_cyc_o,
    input  wire                  wb_ack_i
);

    reg [ADDR_WIDTH-1:0] awaddr_q, araddr_q;
    reg [31:0] wdata_q;
    reg [3:0] wstrb_q;
    reg aw_pending, w_pending;
    reg busy;
    reg is_write;

    wire aw_hs = s_axil_awvalid && s_axil_awready;
    wire w_hs  = s_axil_wvalid && s_axil_wready;
    wire wr_have_aw = aw_pending || aw_hs;
    wire wr_have_w  = w_pending || w_hs;
    wire wr_launch = !busy && !s_axil_bvalid && wr_have_aw && wr_have_w;
    wire [ADDR_WIDTH-1:0] wr_addr = aw_pending ? awaddr_q : s_axil_awaddr;
    wire [31:0] wr_data = w_pending ? wdata_q : s_axil_wdata;
    wire [3:0] wr_strb = w_pending ? wstrb_q : s_axil_wstrb;

    assign s_axil_awready = !aw_pending && !s_axil_bvalid && !busy;
    assign s_axil_wready  = !w_pending && !s_axil_bvalid && !busy;
    assign s_axil_arready = !busy && !s_axil_rvalid && !s_axil_bvalid &&
                            !aw_pending && !w_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awaddr_q    <= '0;
            wdata_q     <= '0;
            wstrb_q     <= '0;
            araddr_q    <= '0;
            aw_pending  <= 1'b0;
            w_pending   <= 1'b0;
            busy        <= 1'b0;
            is_write    <= 1'b0;
            wb_adr_o    <= 3'b0;
            wb_dat_o    <= 8'b0;
            wb_we_o     <= 1'b0;
            wb_stb_o    <= 1'b0;
            wb_cyc_o    <= 1'b0;
            s_axil_bresp <= 2'b00;
            s_axil_bvalid <= 1'b0;
            s_axil_rdata  <= 32'b0;
            s_axil_rresp  <= 2'b00;
            s_axil_rvalid <= 1'b0;
        end else begin
            if (aw_hs) begin
                awaddr_q <= s_axil_awaddr;
                aw_pending <= 1'b1;
            end
            if (w_hs) begin
                wdata_q <= s_axil_wdata;
                wstrb_q <= s_axil_wstrb;
                w_pending <= 1'b1;
            end

            if (wr_launch) begin
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
                if ((wr_addr[1:0] != 2'b00) || !wr_strb[0]) begin
                    s_axil_bresp <= 2'b10;
                    s_axil_bvalid <= 1'b1;
                end else begin
                    busy <= 1'b1;
                    is_write <= 1'b1;
                    wb_adr_o <= wr_addr[4:2];
                    wb_dat_o <= wr_data[7:0];
                    wb_we_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    wb_cyc_o <= 1'b1;
                end
            end else if (s_axil_arvalid && s_axil_arready) begin
                araddr_q <= s_axil_araddr;
                busy <= 1'b1;
                is_write <= 1'b0;
                wb_adr_o <= s_axil_araddr[4:2];
                wb_we_o <= 1'b0;
                wb_stb_o <= 1'b1;
                wb_cyc_o <= 1'b1;
            end else if (busy && wb_ack_i) begin
                wb_stb_o <= 1'b0;
                wb_cyc_o <= 1'b0;
                wb_we_o <= 1'b0;
                busy <= 1'b0;
                if (is_write) begin
                    s_axil_bresp <= 2'b00;
                    s_axil_bvalid <= 1'b1;
                end else begin
                    s_axil_rdata <= {24'b0, wb_dat_i};
                    s_axil_rresp <= 2'b00;
                    s_axil_rvalid <= 1'b1;
                end
            end

            if (s_axil_bvalid && s_axil_bready)
                s_axil_bvalid <= 1'b0;
            if (s_axil_rvalid && s_axil_rready)
                s_axil_rvalid <= 1'b0;
        end
    end

    wire _unused_ok = &{1'b0, araddr_q, wr_strb[3:1], wr_addr[ADDR_WIDTH-1:5]};
endmodule

`default_nettype wire
