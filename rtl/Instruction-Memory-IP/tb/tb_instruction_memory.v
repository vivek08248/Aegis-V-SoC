`timescale 1ns/1ps

module tb_instruction_memory;

reg clk=0, resetn=0;
reg [31:0] awaddr=0, araddr=0, wdata=0;
reg [3:0] wstrb=0;
reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;
wire awready,wready,bvalid,arready,rvalid;
wire [1:0] bresp,rresp;
wire [31:0] rdata;

always #5 clk=~clk;

instruction_memory #(
    .ADDR_WIDTH(4),
    .DEPTH(16)
) dut (
    .aclk(clk), .aresetn(resetn),
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
);

task read_word(input [31:0] addr);
begin
    @(posedge clk);
    araddr<=addr; arvalid<=1;
    wait(arready);
    @(posedge clk); arvalid<=0; rready<=1;
    wait(rvalid);
    $display("IMEM READ 0x%08h = 0x%08h RESP=%b",addr,rdata,rresp);
    @(posedge clk); rready<=0;
end
endtask

initial begin
    #20 resetn=1;
    read_word(0);
    read_word(4);
    read_word(8);
    #20 $finish;
end

endmodule
