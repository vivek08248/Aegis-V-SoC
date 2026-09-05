`timescale 1ns/1ps

module tb_aes_axi_slave;

reg clk;
reg resetn;

reg [5:0] awaddr;
reg awvalid;
wire awready;

reg [31:0] wdata;
reg [3:0] wstrb;
reg wvalid;
wire wready;

wire [1:0] bresp;
wire bvalid;
reg bready;

reg [5:0] araddr;
reg arvalid;
wire arready;

wire [31:0] rdata;
wire [1:0] rresp;
wire rvalid;
reg rready;

reg [31:0] rd;
reg [127:0] enc;
reg [127:0] dec;
integer errors;
integer i;

localparam [127:0] KEY =
    128'h2B7E151628AED2A6ABF7158809CF4F3C;
localparam [127:0] PT =
    128'h3243F6A8885A308D313198A2E0370734;
localparam [127:0] CT =
    128'h3925841D02DC09FBDC118597196A0B32;

always #5 clk = ~clk;

aes_axi_slave dut (
    .s_axi_aclk    (clk),
    .s_axi_aresetn (resetn),
    .s_axi_awaddr  (awaddr),
    .s_axi_awvalid (awvalid),
    .s_axi_awready (awready),
    .s_axi_wdata   (wdata),
    .s_axi_wstrb   (wstrb),
    .s_axi_wvalid  (wvalid),
    .s_axi_wready  (wready),
    .s_axi_bresp   (bresp),
    .s_axi_bvalid  (bvalid),
    .s_axi_bready  (bready),
    .s_axi_araddr  (araddr),
    .s_axi_arvalid (arvalid),
    .s_axi_arready (arready),
    .s_axi_rdata   (rdata),
    .s_axi_rresp   (rresp),
    .s_axi_rvalid  (rvalid),
    .s_axi_rready  (rready)
);

initial begin
    $fsdbDumpfile("aes_axi_csr.fsdb");
    $fsdbDumpvars(0,tb_aes_axi_slave);
    $fsdbDumpMDA();
end

task axi_write;
input [5:0] addr;
input [31:0] data;
begin
    @(negedge clk);
    awaddr  = addr;
    awvalid = 1'b1;
    wdata   = data;
    wstrb   = 4'hF;
    wvalid  = 1'b1;

    @(posedge clk);
    while (!awready) @(posedge clk);
    awvalid = 1'b0;

    while (!wready) @(posedge clk);
    wvalid = 1'b0;

    bready = 1'b1;
    while (!bvalid) @(posedge clk);
    @(negedge clk);
    bready = 1'b0;

    $display("[WRITE] ADDR = 0x%02h DATA = 0x%08h",addr,data);
end
endtask

task axi_read;
input [5:0] addr;
output [31:0] data;
begin
    @(negedge clk);
    araddr  = addr;
    arvalid = 1'b1;

    @(posedge clk);
    while (!arready) @(posedge clk);
    arvalid = 1'b0;

    rready = 1'b1;
    while (!rvalid) @(posedge clk);
    data = rdata;

    @(negedge clk);
    rready = 1'b0;

    $display("[READ ] ADDR = 0x%02h DATA = 0x%08h",addr,data);
end
endtask

task wait_done;
begin
    for (i=0;i<100;i=i+1) begin
        axi_read(6'h00,rd);
        if (rd[16]) begin
            $display("PASS: DONE");
            i = 100;
        end
    end
    if (!rd[16]) begin
        $display("ERROR: DONE timeout");
        errors = errors + 1;
    end
end
endtask

task wait_kdone;
begin
    for (i=0;i<100;i=i+1) begin
        axi_read(6'h00,rd);
        if (rd[17]) begin
            $display("PASS: KDONE");
            i = 100;
        end
    end
    if (!rd[17]) begin
        $display("ERROR: KDONE timeout");
        errors = errors + 1;
    end
end
endtask

initial begin
    clk = 0;
    resetn = 0;
    awaddr = 0;
    awvalid = 0;
    wdata = 0;
    wstrb = 0;
    wvalid = 0;
    bready = 0;
    araddr = 0;
    arvalid = 0;
    rready = 0;
    rd = 0;
    enc = 0;
    dec = 0;
    errors = 0;

    repeat(5) @(posedge clk);
    resetn = 1;
    repeat(3) @(posedge clk);

    $display("");
    $display("==============================================================");
    $display(" AES AXI4-LITE CSR TEST");
    $display("==============================================================");

    // CSR reset
    axi_write(6'h00,32'h00000004);
    repeat(3) @(posedge clk);

    // KEY
    axi_write(6'h04,KEY[127:96]);
    axi_write(6'h08,KEY[95:64]);
    axi_write(6'h0C,KEY[63:32]);
    axi_write(6'h10,KEY[31:0]);

    // PLAINTEXT
    axi_write(6'h14,PT[127:96]);
    axi_write(6'h18,PT[95:64]);
    axi_write(6'h1C,PT[63:32]);
    axi_write(6'h20,PT[31:0]);

    // Encryption: DEC_EN=0, LD=1
    $display("");
    $display("----------------------------------------------");
    $display(" AES ENCRYPTION");
    $display("----------------------------------------------");
    axi_write(6'h00,32'h00000001);
    wait_done;

    axi_read(6'h24,enc[127:96]);
    axi_read(6'h28,enc[95:64]);
    axi_read(6'h2C,enc[63:32]);
    axi_read(6'h30,enc[31:0]);

    $display("AES TEXT OUT = %032h",enc);

    if (enc !== CT) begin
        $display("ERROR: AES ENCRYPTION FAILED");
        $display("EXPECTED      = %032h",CT);
        errors = errors + 1;
    end
    else
        $display("PASS: AES ENCRYPTION");

    // Put ciphertext into TEXT registers.
    axi_write(6'h14,CT[127:96]);
    axi_write(6'h18,CT[95:64]);
    axi_write(6'h1C,CT[63:32]);
    axi_write(6'h20,CT[31:0]);

    // Decryption key expansion: DEC_EN=1, KLD=1.
    $display("");
    $display("----------------------------------------------");
    $display(" AES DECRYPTION KEY LOAD");
    $display("----------------------------------------------");
    axi_write(6'h00,32'h0000000A);
    wait_kdone;

    // Decryption: DEC_EN=1, LD=1.
    $display("");
    $display("----------------------------------------------");
    $display(" AES DECRYPTION");
    $display("----------------------------------------------");
    axi_write(6'h00,32'h00000009);
    wait_done;

    axi_read(6'h24,dec[127:96]);
    axi_read(6'h28,dec[95:64]);
    axi_read(6'h2C,dec[63:32]);
    axi_read(6'h30,dec[31:0]);

    $display("AES DECRYPTED TEXT = %032h",dec);

    if (dec !== PT) begin
        $display("ERROR: AES DECRYPTION FAILED");
        $display("EXPECTED          = %032h",PT);
        errors = errors + 1;
    end
    else
        $display("PASS: AES DECRYPTION");

    if (dec === PT)
        $display("PASS: ROUND-TRIP");
    else begin
        $display("ERROR: ROUND-TRIP");
        errors = errors + 1;
    end

    $display("");
    $display("==============================================================");
    if (errors == 0)
        $display(" TEST PASSED : 0 ERROR(S)");
    else
        $display(" TEST FAILED : %0d ERROR(S)",errors);
    $display("==============================================================");

    #50;
    $finish;
end

endmodule
