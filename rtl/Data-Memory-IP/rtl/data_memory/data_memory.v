`timescale 1ns/1ps

// Aegis-V Data Memory
// AXI4-Lite slave, 32-bit data, byte-write support.
// 16K words = 64 KB by default.

module data_memory #(
    parameter integer ADDR_WIDTH = 14,
    parameter integer DEPTH      = 1 << ADDR_WIDTH,
    parameter [31:0] INIT_FILE   = 32'b0
)(
    input  wire        aclk,
    input  wire        aresetn,

    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    output reg [1:0]   s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire         s_axi_bready,

    input  wire [31:0] s_axi_araddr,
    input  wire         s_axi_arvalid,
    output wire        s_axi_arready,

    output reg [31:0]  s_axi_rdata,
    output reg [1:0]   s_axi_rresp,
    output reg         s_axi_rvalid,
    input wire         s_axi_rready
);

    reg [31:0] mem [0:DEPTH-1];

    wire rd_fire = s_axi_arvalid && s_axi_arready;

    reg aw_pending, w_pending;
    reg [31:0] awaddr_q, wdata_q;
    reg [3:0] wstrb_q;
    wire aw_fire = s_axi_awvalid && s_axi_awready;
    wire w_fire  = s_axi_wvalid && s_axi_wready;
    wire wr_fire = !s_axi_bvalid && (aw_pending || aw_fire) && (w_pending || w_fire);
    wire [31:0] wr_addr = aw_pending ? awaddr_q : s_axi_awaddr;
    wire [31:0] wr_data = w_pending ? wdata_q : s_axi_wdata;
    wire [3:0]  wr_strb = w_pending ? wstrb_q : s_axi_wstrb;

    assign s_axi_awready = ~aw_pending && ~s_axi_bvalid;
    assign s_axi_wready  = ~w_pending && ~s_axi_bvalid;
    assign s_axi_arready = ~s_axi_rvalid;

    initial begin
        if (INIT_FILE != 32'b0)
            $readmemh(INIT_FILE, mem);
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            aw_pending <= 1'b0;
            w_pending  <= 1'b0;
            awaddr_q   <= 32'b0;
            wdata_q    <= 32'b0;
            wstrb_q    <= 4'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= 32'b0;
        end else begin
            if (aw_fire) begin
                awaddr_q <= s_axi_awaddr;
                aw_pending <= 1'b1;
            end
            if (w_fire) begin
                wdata_q <= s_axi_wdata;
                wstrb_q <= s_axi_wstrb;
                w_pending <= 1'b1;
            end

            if (wr_fire) begin
                if (wr_strb[0]) mem[wr_addr[ADDR_WIDTH+1:2]][7:0]   <= wr_data[7:0];
                if (wr_strb[1]) mem[wr_addr[ADDR_WIDTH+1:2]][15:8]  <= wr_data[15:8];
                if (wr_strb[2]) mem[wr_addr[ADDR_WIDTH+1:2]][23:16] <= wr_data[23:16];
                if (wr_strb[3]) mem[wr_addr[ADDR_WIDTH+1:2]][31:24] <= wr_data[31:24];

                aw_pending <= 1'b0;
                w_pending  <= 1'b0;
                s_axi_bresp  <= 2'b00;
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            if (rd_fire) begin
                s_axi_rdata  <= mem[s_axi_araddr[ADDR_WIDTH+1:2]];
                s_axi_rresp  <= 2'b00;
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
