// =============================================================================
// Module  : axi_slave_bfm.v
// Project : Aegis-V SoC – AXI Interconnect 2x9 Testbench
// Purpose : Dummy AXI4 Slave Bus Functional Model (BFM)
//           - Maintains a small internal memory (256 words × 32-bit)
//           - Responds to single-beat write and read transactions
//           - Always returns OKAY on the B and R channels
//           - Read data initialised to 0xAAAA_AAAA pattern (per-slave)
//           - Prints a log line for every accepted transaction
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module axi_slave_bfm #(
    parameter SLAVE_ID   = 0,
    parameter SLAVE_NAME = "SLV ",
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = DATA_WIDTH/8,
    parameter ID_WIDTH   = 8,
    parameter BASE_ADDR  = 32'h0000_0000,
    // Internal memory depth (words).  Address offset bits = log2(MEM_DEPTH)+2
    parameter MEM_DEPTH  = 256
)(
    input  wire                  clk,
    input  wire                  rst,

    // --- Write Address Channel ---
    input  wire [ID_WIDTH-1:0]   awid,
    input  wire [ADDR_WIDTH-1:0] awaddr,
    input  wire [7:0]            awlen,
    input  wire [2:0]            awsize,
    input  wire [1:0]            awburst,
    input  wire                  awlock,
    input  wire [3:0]            awcache,
    input  wire [2:0]            awprot,
    input  wire [3:0]            awqos,
    input  wire [3:0]            awregion,
    input  wire                  awvalid,
    output reg                   awready,

    // --- Write Data Channel ---
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire [STRB_WIDTH-1:0] wstrb,
    input  wire                  wlast,
    input  wire                  wvalid,
    output reg                   wready,

    // --- Write Response Channel ---
    output reg  [ID_WIDTH-1:0]   bid,
    output reg  [1:0]            bresp,
    output reg                   bvalid,
    input  wire                  bready,

    // --- Read Address Channel ---
    input  wire [ID_WIDTH-1:0]   arid,
    input  wire [ADDR_WIDTH-1:0] araddr,
    input  wire [7:0]            arlen,
    input  wire [2:0]            arsize,
    input  wire [1:0]            arburst,
    input  wire                  arlock,
    input  wire [3:0]            arcache,
    input  wire [2:0]            arprot,
    input  wire [3:0]            arqos,
    input  wire [3:0]            arregion,
    input  wire                  arvalid,
    output reg                   arready,

    // --- Read Data Channel ---
    output reg  [ID_WIDTH-1:0]   rid,
    output reg  [DATA_WIDTH-1:0] rdata,
    output reg  [1:0]            rresp,
    output reg                   rlast,
    output reg                   rvalid,
    input  wire                  rready
);

// ---------------------------------------------------------------------------
// Internal memory array
// ---------------------------------------------------------------------------
reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

// Initialise memory to per-slave unique pattern
integer i;
initial begin
    for (i = 0; i < MEM_DEPTH; i = i + 1)
        mem[i] = 32'hAAAA_AAAA ^ ({24'b0, SLAVE_ID[7:0]} << 8) ^ i[31:0];
end

// ---------------------------------------------------------------------------
// Address → word index helper
// ---------------------------------------------------------------------------
function [31:0] addr_to_idx;
    input [ADDR_WIDTH-1:0] a;
    begin
        // Strip base and take word offset (drop byte address bits [1:0])
        addr_to_idx = ((a - BASE_ADDR) >> 2) % MEM_DEPTH;
    end
endfunction

// ---------------------------------------------------------------------------
// FSM States
// ---------------------------------------------------------------------------
localparam ST_IDLE      = 3'd0;
localparam ST_AW_ACCEPT = 3'd1;
localparam ST_W_ACCEPT  = 3'd2;
localparam ST_B_SEND    = 3'd3;
localparam ST_AR_ACCEPT = 3'd4;
localparam ST_R_SEND    = 3'd5;

// ---------------------------------------------------------------------------
// Write path FSM
// ---------------------------------------------------------------------------
reg [2:0]            wr_state;
reg [ID_WIDTH-1:0]   wr_id_lat;
reg [ADDR_WIDTH-1:0] wr_addr_lat;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_state   <= ST_IDLE;
        awready    <= 1'b0;
        wready     <= 1'b0;
        bvalid     <= 1'b0;
        bid        <= {ID_WIDTH{1'b0}};
        bresp      <= 2'b00;
        wr_id_lat  <= {ID_WIDTH{1'b0}};
        wr_addr_lat<= {ADDR_WIDTH{1'b0}};
    end else begin
        case (wr_state)
            // -------------------------------------------------------
            ST_IDLE : begin
                awready <= 1'b1;   // always ready to accept AW
                wready  <= 1'b0;
                bvalid  <= 1'b0;
                if (awvalid) begin
                    wr_id_lat   <= awid;
                    wr_addr_lat <= awaddr;
                    awready     <= 1'b0;
                    wready      <= 1'b1;   // accept W immediately after AW
                    wr_state    <= ST_W_ACCEPT;
                end
            end
            // -------------------------------------------------------
            ST_W_ACCEPT : begin
                if (wvalid && wready) begin
                    // Write to memory
                    if (wstrb[0]) mem[addr_to_idx(wr_addr_lat)][ 7: 0] <= wdata[ 7: 0];
                    if (wstrb[1]) mem[addr_to_idx(wr_addr_lat)][15: 8] <= wdata[15: 8];
                    if (wstrb[2]) mem[addr_to_idx(wr_addr_lat)][23:16] <= wdata[23:16];
                    if (wstrb[3]) mem[addr_to_idx(wr_addr_lat)][31:24] <= wdata[31:24];

                    $display("  SLAVE[%0d:%s] WR  addr=0x%08X data=0x%08X strb=%0b",
                             SLAVE_ID, SLAVE_NAME, wr_addr_lat, wdata, wstrb);

                    wready   <= 1'b0;
                    bid      <= wr_id_lat;
                    bresp    <= 2'b00;     // OKAY
                    bvalid   <= 1'b1;
                    wr_state <= ST_B_SEND;
                end
            end
            // -------------------------------------------------------
            ST_B_SEND : begin
                if (bvalid && bready) begin
                    bvalid   <= 1'b0;
                    wr_state <= ST_IDLE;
                end
            end
            // -------------------------------------------------------
            default : wr_state <= ST_IDLE;
        endcase
    end
end

// ---------------------------------------------------------------------------
// Read path FSM
// ---------------------------------------------------------------------------
reg [2:0]            rd_state;
reg [ID_WIDTH-1:0]   rd_id_lat;
reg [ADDR_WIDTH-1:0] rd_addr_lat;
reg [DATA_WIDTH-1:0] rd_data_lat;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rd_state    <= ST_IDLE;
        arready     <= 1'b0;
        rvalid      <= 1'b0;
        rlast       <= 1'b0;
        rid         <= {ID_WIDTH{1'b0}};
        rdata       <= {DATA_WIDTH{1'b0}};
        rresp       <= 2'b00;
        rd_id_lat   <= {ID_WIDTH{1'b0}};
        rd_addr_lat <= {ADDR_WIDTH{1'b0}};
        rd_data_lat <= {DATA_WIDTH{1'b0}};
    end else begin
        case (rd_state)
            // -------------------------------------------------------
            ST_IDLE : begin
                arready <= 1'b1;
                rvalid  <= 1'b0;
                rlast   <= 1'b0;
                if (arvalid) begin
                    rd_id_lat   <= arid;
                    rd_addr_lat <= araddr;
                    rd_data_lat <= mem[addr_to_idx(araddr)];
                    arready     <= 1'b0;
                    rd_state    <= ST_R_SEND;
                end
            end
            // -------------------------------------------------------
            ST_R_SEND : begin
                // Present read data one cycle after AR is accepted
                rid    <= rd_id_lat;
                rdata  <= rd_data_lat;
                rresp  <= 2'b00;    // OKAY
                rlast  <= 1'b1;
                rvalid <= 1'b1;
                if (rvalid && rready) begin
                    $display("  SLAVE[%0d:%s] RD  addr=0x%08X data=0x%08X rresp=%0b",
                             SLAVE_ID, SLAVE_NAME, rd_addr_lat, rd_data_lat, 2'b00);
                    rvalid   <= 1'b0;
                    rlast    <= 1'b0;
                    rd_state <= ST_IDLE;
                end
            end
            // -------------------------------------------------------
            default : rd_state <= ST_IDLE;
        endcase
    end
end

endmodule

`default_nettype wire
