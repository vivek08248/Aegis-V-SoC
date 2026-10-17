`default_nettype none

// Convert VeeR's 64-bit instruction-read beats to 32-bit AXI fabric beats.
// Each upstream beat is returned only after both lower and upper words arrive.
// Keep downstream transfers single-beat because the AXI4-to-AXI-Lite bridges
// service one Lite access per AXI address and report RLAST with that response.
module axi64_to_axi32_read_adapter #(
    parameter integer ID_WIDTH = 3
) (
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire [ID_WIDTH-1:0]   up_arid,
    input  wire [31:0]           up_araddr,
    input  wire [7:0]            up_arlen,
    input  wire [2:0]            up_arsize,
    input  wire [1:0]            up_arburst,
    input  wire                  up_arvalid,
    output wire                  up_arready,
    output reg  [ID_WIDTH-1:0]   up_rid,
    output reg  [63:0]           up_rdata,
    output reg  [1:0]            up_rresp,
    output reg                   up_rlast,
    output reg                   up_rvalid,
    input  wire                  up_rready,

    output reg  [ID_WIDTH-1:0]   dn_arid,
    output reg  [31:0]           dn_araddr,
    output reg  [7:0]            dn_arlen,
    output wire [2:0]            dn_arsize,
    output reg  [1:0]            dn_arburst,
    output reg                   dn_arvalid,
    input  wire                  dn_arready,
    input  wire [ID_WIDTH-1:0]   dn_rid,
    input  wire [31:0]           dn_rdata,
    input  wire [1:0]            dn_rresp,
    input  wire                  dn_rlast,
    input  wire                  dn_rvalid,
    output wire                  dn_rready
);
    reg busy;
    reg ar_sent;
    reg upper_word;
    reg [7:0] upstream_len;
    reg [7:0] upstream_beat;
    reg [2:0] upstream_size;
    reg [31:0] beat_addr;
    reg [31:0] lower_data;
    reg [1:0] lower_resp;

    assign up_arready = rst_n && !busy;
    assign dn_arsize = (upstream_size > 3'd2) ? 3'd2 : upstream_size;
    assign dn_rready = busy && ar_sent && (!up_rvalid || up_rready);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy          <= 1'b0;
            ar_sent       <= 1'b0;
            upper_word    <= 1'b0;
            upstream_len  <= 8'b0;
            upstream_beat <= 8'b0;
            upstream_size <= 3'd2;
            beat_addr     <= 32'b0;
            lower_data    <= 32'b0;
            lower_resp    <= 2'b00;
            dn_arid       <= {ID_WIDTH{1'b0}};
            dn_araddr     <= 32'b0;
            dn_arlen      <= 8'b0;
            dn_arburst    <= 2'b01;
            dn_arvalid    <= 1'b0;
            up_rid        <= {ID_WIDTH{1'b0}};
            up_rdata      <= 64'b0;
            up_rresp      <= 2'b00;
            up_rlast      <= 1'b0;
            up_rvalid     <= 1'b0;
        end else begin
            if (up_rvalid && up_rready) begin
                up_rvalid <= 1'b0;
                up_rlast  <= 1'b0;
            end

            if (up_arvalid && up_arready) begin
                busy          <= 1'b1;
                ar_sent       <= 1'b0;
                upper_word    <= 1'b0;
                upstream_len  <= up_arlen;
                upstream_beat <= 8'b0;
                upstream_size <= up_arsize;
                beat_addr     <= up_araddr;
                dn_arid       <= up_arid;
                dn_araddr     <= up_araddr;
                dn_arlen      <= 8'b0;
                dn_arburst    <= up_arburst;
                dn_arvalid    <= 1'b1;
            end

            if (dn_arvalid && dn_arready) begin
                dn_arvalid <= 1'b0;
                ar_sent    <= 1'b1;
            end

            if (dn_rvalid && dn_rready) begin
                if ((upstream_size == 3'd3) && !upper_word) begin
                    lower_data <= dn_rdata;
                    lower_resp <= dn_rresp;
                    upper_word <= 1'b1;
                    beat_addr  <= beat_addr + 32'd4;
                    dn_araddr  <= beat_addr + 32'd4;
                    dn_arlen   <= 8'b0;
                    dn_arvalid <= 1'b1;
                    ar_sent    <= 1'b0;
                end else if (upstream_size == 3'd3) begin
                    up_rid    <= dn_rid;
                    up_rdata  <= {dn_rdata, lower_data};
                    up_rresp  <= (dn_rresp != 2'b00) ? dn_rresp : lower_resp;
                    up_rlast  <= (upstream_beat == upstream_len);
                    up_rvalid <= 1'b1;
                    upper_word <= 1'b0;

                    if (upstream_beat == upstream_len) begin
                        busy    <= 1'b0;
                        ar_sent <= 1'b0;
                    end else begin
                        upstream_beat <= upstream_beat + 1'b1;
                        beat_addr  <= beat_addr + 32'd4;
                        dn_araddr  <= beat_addr + 32'd4;
                        dn_arlen   <= 8'b0;
                        dn_arvalid <= 1'b1;
                        ar_sent    <= 1'b0;
                    end
                end else begin
                    up_rid   <= dn_rid;
                    up_rdata <= beat_addr[2] ? {dn_rdata, 32'b0} : {32'b0, dn_rdata};
                    up_rresp <= dn_rresp;
                    up_rlast <= (upstream_beat == upstream_len);
                    up_rvalid <= 1'b1;
                    if (upstream_beat == upstream_len) begin
                        busy    <= 1'b0;
                        ar_sent <= 1'b0;
                    end else begin
                        upstream_beat <= upstream_beat + 1'b1;
                        if (dn_arburst != 2'b00)
                            beat_addr <= beat_addr + (1 << upstream_size);
                    end
                end
            end
        end
    end
endmodule

`default_nettype wire
