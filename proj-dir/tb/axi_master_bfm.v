// =============================================================================
// Module  : axi_master_bfm.v
// Project : Aegis-V SoC – AXI Interconnect 2x9 Testbench
// Purpose : Dummy AXI4 Master Bus Functional Model (BFM)
//           Provides two public tasks:
//             do_write(id, addr, data, strb) – single-beat write transaction
//             do_read (id, addr)             – single-beat read transaction
//           Result checking and pass/fail counting are done internally.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module axi_master_bfm #(
    parameter MASTER_ID  = 0,          // Master index (0=CPU, 1=DMA)
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = DATA_WIDTH/8,
    parameter ID_WIDTH   = 8,
    // Timeout in clock cycles before an error is flagged
    parameter TIMEOUT    = 200
)(
    input  wire                  clk,
    input  wire                  rst,

    // --- Write Address Channel ---
    output reg  [ID_WIDTH-1:0]   awid,
    output reg  [ADDR_WIDTH-1:0] awaddr,
    output reg  [7:0]            awlen,
    output reg  [2:0]            awsize,
    output reg  [1:0]            awburst,
    output reg                   awlock,
    output reg  [3:0]            awcache,
    output reg  [2:0]            awprot,
    output reg  [3:0]            awqos,
    output reg                   awvalid,
    input  wire                  awready,

    // --- Write Data Channel ---
    output reg  [DATA_WIDTH-1:0] wdata,
    output reg  [STRB_WIDTH-1:0] wstrb,
    output reg                   wlast,
    output reg                   wvalid,
    input  wire                  wready,

    // --- Write Response Channel ---
    input  wire [ID_WIDTH-1:0]   bid,
    input  wire [1:0]            bresp,
    input  wire                  bvalid,
    output reg                   bready,

    // --- Read Address Channel ---
    output reg  [ID_WIDTH-1:0]   arid,
    output reg  [ADDR_WIDTH-1:0] araddr,
    output reg  [7:0]            arlen,
    output reg  [2:0]            arsize,
    output reg  [1:0]            arburst,
    output reg                   arlock,
    output reg  [3:0]            arcache,
    output reg  [2:0]            arprot,
    output reg  [3:0]            arqos,
    output reg                   arvalid,
    input  wire                  arready,

    // --- Read Data Channel ---
    input  wire [ID_WIDTH-1:0]   rid,
    input  wire [DATA_WIDTH-1:0] rdata,
    input  wire [1:0]            rresp,
    input  wire                  rlast,
    input  wire                  rvalid,
    output reg                   rready
);

// ---------------------------------------------------------------------------
// Internal state & statistics
// ---------------------------------------------------------------------------
integer pass_cnt;
integer fail_cnt;

// Captured read data from last do_read
reg [DATA_WIDTH-1:0] last_rdata;
reg [1:0]            last_rresp;
reg [1:0]            last_bresp;

// ---- AXI response decode ----
localparam RESP_OKAY   = 2'b00;
localparam RESP_EXOKAY = 2'b01;
localparam RESP_SLVERR = 2'b10;
localparam RESP_DECERR = 2'b11;

// ---- INCR burst ----
localparam BURST_INCR = 2'b01;

// ---- 4-byte (word) transfer size ----
localparam SIZE_4B = 3'b010;

// ---------------------------------------------------------------------------
// Initialise all outputs to idle / de-asserted
// ---------------------------------------------------------------------------
initial begin
    pass_cnt = 0;
    fail_cnt = 0;
    awid     = {ID_WIDTH{1'b0}};   awaddr = {ADDR_WIDTH{1'b0}};
    awlen    = 8'd0;               awsize  = SIZE_4B;
    awburst  = BURST_INCR;         awlock  = 1'b0;
    awcache  = 4'b0011;            awprot  = 3'b000;
    awqos    = 4'b0000;            awvalid = 1'b0;
    wdata    = {DATA_WIDTH{1'b0}}; wstrb   = {STRB_WIDTH{1'b1}};
    wlast    = 1'b0;               wvalid  = 1'b0;
    bready   = 1'b0;
    arid     = {ID_WIDTH{1'b0}};   araddr  = {ADDR_WIDTH{1'b0}};
    arlen    = 8'd0;               arsize  = SIZE_4B;
    arburst  = BURST_INCR;         arlock  = 1'b0;
    arcache  = 4'b0011;            arprot  = 3'b000;
    arqos    = 4'b0000;            arvalid = 1'b0;
    rready   = 1'b0;
    last_rdata = {DATA_WIDTH{1'b0}};
    last_rresp = 2'b00;
    last_bresp = 2'b00;
end

// ---------------------------------------------------------------------------
// TASK: do_write
//   Performs a single-beat AXI4 write and checks the B-channel response.
//   id    – transaction ID
//   addr  – target address
//   data  – write data
//   strb  – byte strobes (4'hF = all bytes)
// ---------------------------------------------------------------------------
task do_write;
    input [ID_WIDTH-1:0]   id;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    input [STRB_WIDTH-1:0] strb;

    integer timer;
    begin
        // ---------- AW phase ----------
        @(posedge clk); #1;
        awid    = id;
        awaddr  = addr;
        awlen   = 8'd0;        // 1 beat
        awsize  = SIZE_4B;
        awburst = BURST_INCR;
        awlock  = 1'b0;
        awcache = 4'b0011;
        awprot  = 3'b000;
        awqos   = 4'b0000;
        awvalid = 1'b1;

        // W phase presented simultaneously
        wdata   = data;
        wstrb   = strb;
        wlast   = 1'b1;
        wvalid  = 1'b1;

        // Wait for AW handshake
        timer = 0;
        while (!awready) begin
            @(posedge clk); #1;
            timer = timer + 1;
            if (timer >= TIMEOUT) begin
                $display("ERROR [M%0d WR TIMEOUT] AW phase at addr=0x%08X",
                         MASTER_ID, addr);
                fail_cnt = fail_cnt + 1;
                awvalid = 1'b0; wvalid = 1'b0;
                disable do_write;
            end
        end
        // AW accepted – de-assert on next cycle
        @(posedge clk); #1;
        awvalid = 1'b0;

        // Wait for W handshake
        timer = 0;
        while (!wready) begin
            @(posedge clk); #1;
            timer = timer + 1;
            if (timer >= TIMEOUT) begin
                $display("ERROR [M%0d WR TIMEOUT] W phase at addr=0x%08X",
                         MASTER_ID, addr);
                fail_cnt = fail_cnt + 1;
                wvalid = 1'b0;
                disable do_write;
            end
        end
        @(posedge clk); #1;
        wvalid = 1'b0;
        wlast  = 1'b0;

        // ---------- B phase ----------
        bready = 1'b1;
        timer = 0;
        while (!bvalid) begin
            @(posedge clk); #1;
            timer = timer + 1;
            if (timer >= TIMEOUT) begin
                $display("ERROR [M%0d WR TIMEOUT] B phase at addr=0x%08X",
                         MASTER_ID, addr);
                fail_cnt = fail_cnt + 1;
                bready = 1'b0;
                disable do_write;
            end
        end
        last_bresp = bresp;
        @(posedge clk); #1;
        bready = 1'b0;

        // Check response
        if (last_bresp == RESP_OKAY || last_bresp == RESP_EXOKAY) begin
            $display("  PASS [M%0d WR] addr=0x%08X data=0x%08X  bresp=%0b (OKAY)",
                     MASTER_ID, addr, data, last_bresp);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [M%0d WR] addr=0x%08X data=0x%08X  bresp=%0b (%s)",
                     MASTER_ID, addr, data, last_bresp,
                     (last_bresp == RESP_SLVERR) ? "SLVERR" : "DECERR");
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

// ---------------------------------------------------------------------------
// TASK: do_read
//   Performs a single-beat AXI4 read and captures the R-channel data.
//   id   – transaction ID
//   addr – target address
// ---------------------------------------------------------------------------
task do_read;
    input [ID_WIDTH-1:0]   id;
    input [ADDR_WIDTH-1:0] addr;

    integer timer;
    begin
        // ---------- AR phase ----------
        @(posedge clk); #1;
        arid    = id;
        araddr  = addr;
        arlen   = 8'd0;        // 1 beat
        arsize  = SIZE_4B;
        arburst = BURST_INCR;
        arlock  = 1'b0;
        arcache = 4'b0011;
        arprot  = 3'b000;
        arqos   = 4'b0000;
        arvalid = 1'b1;

        timer = 0;
        while (!arready) begin
            @(posedge clk); #1;
            timer = timer + 1;
            if (timer >= TIMEOUT) begin
                $display("ERROR [M%0d RD TIMEOUT] AR phase at addr=0x%08X",
                         MASTER_ID, addr);
                fail_cnt = fail_cnt + 1;
                arvalid = 1'b0;
                disable do_read;
            end
        end
        @(posedge clk); #1;
        arvalid = 1'b0;

        // ---------- R phase ----------
        rready = 1'b1;
        timer = 0;
        while (!rvalid) begin
            @(posedge clk); #1;
            timer = timer + 1;
            if (timer >= TIMEOUT) begin
                $display("ERROR [M%0d RD TIMEOUT] R phase at addr=0x%08X",
                         MASTER_ID, addr);
                fail_cnt = fail_cnt + 1;
                rready = 1'b0;
                disable do_read;
            end
        end
        last_rdata = rdata;
        last_rresp = rresp;
        @(posedge clk); #1;
        rready = 1'b0;

        if (last_rresp == RESP_OKAY || last_rresp == RESP_EXOKAY) begin
            $display("  PASS [M%0d RD] addr=0x%08X rdata=0x%08X  rresp=%0b (OKAY)",
                     MASTER_ID, addr, last_rdata, last_rresp);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  FAIL [M%0d RD] addr=0x%08X rdata=0x%08X  rresp=%0b (%s)",
                     MASTER_ID, addr, last_rdata, last_rresp,
                     (last_rresp == RESP_SLVERR) ? "SLVERR" : "DECERR");
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

endmodule

`default_nettype wire
