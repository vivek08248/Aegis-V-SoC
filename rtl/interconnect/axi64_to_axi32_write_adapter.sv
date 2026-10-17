`default_nettype none

// Downsize VeeR's 64-bit LSU write channel to the SoC's 32-bit AXI fabric.
// RV32 word stores can occupy either 32-bit lane; merged 64-bit beats are
// emitted as two ordered 32-bit writes and their responses are combined.
module axi64_to_axi32_write_adapter #(
    parameter integer ID_WIDTH = 3
) (
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire [ID_WIDTH-1:0]   up_awid,
    input  wire [31:0]           up_awaddr,
    input  wire [2:0]            up_awsize,
    input  wire [1:0]            up_awburst,
    input  wire                  up_awvalid,
    output wire                  up_awready,
    input  wire [63:0]           up_wdata,
    input  wire [7:0]            up_wstrb,
    input  wire                  up_wvalid,
    output wire                  up_wready,
    output reg  [ID_WIDTH-1:0]   up_bid,
    output reg  [1:0]            up_bresp,
    output reg                   up_bvalid,
    input  wire                  up_bready,

    output reg  [ID_WIDTH-1:0]   dn_awid,
    output wire [31:0]           dn_awaddr,
    output wire [7:0]            dn_awlen,
    output wire [2:0]            dn_awsize,
    output reg  [1:0]            dn_awburst,
    output wire                  dn_awvalid,
    input  wire                  dn_awready,
    output wire [31:0]           dn_wdata,
    output wire [3:0]            dn_wstrb,
    output wire                  dn_wlast,
    output wire                  dn_wvalid,
    input  wire                  dn_wready,
    input  wire [1:0]            dn_bresp,
    input  wire                  dn_bvalid,
    output wire                  dn_bready
);
    reg have_aw, have_w;
    reg aw_sent, w_sent, waiting_b;
    reg upper_half;
    reg [ID_WIDTH-1:0] saved_id;
    reg [31:0] saved_addr;
    reg [2:0] saved_size;
    reg [1:0] saved_burst;
    reg [63:0] saved_data;
    reg [7:0] saved_strb;
    reg [1:0] saved_resp;
    wire aw_hs = dn_awvalid && dn_awready;
    wire w_hs  = dn_wvalid && dn_wready;

    assign up_awready = rst_n && !have_aw && !up_bvalid;
    assign up_wready  = rst_n && !have_w && !up_bvalid;
    assign dn_awvalid = have_aw && have_w && !aw_sent && !waiting_b && !up_bvalid;
    assign dn_awaddr  = (saved_size == 3'd3 && upper_half)
                      ? (saved_addr + 32'd4) : saved_addr;
    assign dn_awlen   = 8'b0;
    assign dn_awsize  = (saved_size == 3'd3) ? 3'd2 : saved_size;
    assign dn_wvalid  = have_aw && have_w && aw_sent && !w_sent && !waiting_b;
    assign dn_wdata   = (saved_size == 3'd3)
                      ? (upper_half ? saved_data[63:32] : saved_data[31:0])
                      : ((|saved_strb[7:4]) ? saved_data[63:32] : saved_data[31:0]);
    assign dn_wstrb   = (saved_size == 3'd3)
                      ? (upper_half ? saved_strb[7:4] : saved_strb[3:0])
                      : ((|saved_strb[7:4]) ? saved_strb[7:4] : saved_strb[3:0]);
    assign dn_wlast   = 1'b1;
    assign dn_bready  = waiting_b && !up_bvalid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            have_aw    <= 1'b0;
            have_w     <= 1'b0;
            aw_sent    <= 1'b0;
            w_sent     <= 1'b0;
            waiting_b  <= 1'b0;
            upper_half <= 1'b0;
            saved_id   <= {ID_WIDTH{1'b0}};
            saved_addr <= 32'b0;
            saved_size <= 3'd2;
            saved_burst<= 2'b01;
            saved_data <= 64'b0;
            saved_strb <= 8'b0;
            saved_resp <= 2'b00;
            dn_awid    <= {ID_WIDTH{1'b0}};
            dn_awburst <= 2'b01;
            up_bid     <= {ID_WIDTH{1'b0}};
            up_bresp   <= 2'b00;
            up_bvalid  <= 1'b0;
        end else begin
            if (up_bvalid && up_bready)
                up_bvalid <= 1'b0;

            if (up_awvalid && up_awready) begin
                have_aw     <= 1'b1;
                saved_id    <= up_awid;
                saved_addr  <= up_awaddr;
                saved_size  <= up_awsize;
                saved_burst <= up_awburst;
                dn_awid     <= up_awid;
                dn_awburst  <= up_awburst;
                upper_half  <= 1'b0;
                saved_resp  <= 2'b00;
            end
            if (up_wvalid && up_wready) begin
                have_w    <= 1'b1;
                saved_data<= up_wdata;
                saved_strb<= up_wstrb;
            end

            if (aw_hs) aw_sent <= 1'b1;
            if (w_hs)  w_sent  <= 1'b1;
            if ((aw_sent || aw_hs) && (w_sent || w_hs))
                waiting_b <= 1'b1;

            if (dn_bvalid && dn_bready) begin
                if (dn_bresp != 2'b00)
                    saved_resp <= dn_bresp;
                if ((saved_size == 3'd3) && !upper_half) begin
                    upper_half <= 1'b1;
                    aw_sent    <= 1'b0;
                    w_sent     <= 1'b0;
                    waiting_b  <= 1'b0;
                end else begin
                    up_bid    <= saved_id;
                    up_bresp  <= (dn_bresp != 2'b00) ? dn_bresp : saved_resp;
                    up_bvalid <= 1'b1;
                    have_aw   <= 1'b0;
                    have_w    <= 1'b0;
                    aw_sent   <= 1'b0;
                    w_sent    <= 1'b0;
                    waiting_b <= 1'b0;
                    upper_half<= 1'b0;
                end
            end
        end
    end
endmodule

`default_nettype wire
