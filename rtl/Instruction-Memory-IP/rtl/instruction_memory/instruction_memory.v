`timescale 1ns/1ps

// Aegis-V Instruction Memory
// AXI4-Lite slave, 32-bit data, 32-bit address.
// Read-only from software/bus perspective.
// Program contents can be initialized from instruction_memory.hex.

module instruction_memory #(
    parameter integer ADDR_WIDTH = 14,          // 16K words = 64 KB
    parameter integer DEPTH      = 1 << ADDR_WIDTH,
    parameter INIT_FILE           = "../rtl/Instruction-Memory-IP/mem/instruction_memory.hex"
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
    input  wire        s_axi_bready,

    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    output reg [31:0]  s_axi_rdata,
    output reg [1:0]   s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready
);

    reg [31:0] mem [0:DEPTH-1];

    wire rd_fire = s_axi_arvalid && s_axi_arready;

    reg aw_pending, w_pending;
    wire aw_fire = s_axi_awvalid && s_axi_awready;
    wire w_fire  = s_axi_wvalid && s_axi_wready;
    wire wr_fire = !s_axi_bvalid && (aw_pending || aw_fire) && (w_pending || w_fire);

    assign s_axi_awready = ~aw_pending && ~s_axi_bvalid;
    assign s_axi_wready  = ~w_pending && ~s_axi_bvalid;
    assign s_axi_arready = ~s_axi_rvalid;

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            aw_pending <= 1'b0;
            w_pending  <= 1'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= 32'b0;
        end else begin
            if (aw_fire)
                aw_pending <= 1'b1;
            if (w_fire)
                w_pending <= 1'b1;

            // Instruction memory is read-only.
            // Any write receives SLVERR.
            if (wr_fire) begin
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b10;
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
