`timescale 1ns/1ps

module tb_data_memory;

reg clk=0, resetn=0;
reg [31:0] awaddr=0, araddr=0, wdata=0;
reg [3:0] wstrb=0;
reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0;
wire awready,wready,bvalid,arready,rvalid;
wire [1:0] bresp,rresp;
wire [31:0] rdata;

always #5 clk=~clk;

data_memory #(
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

task write_word(input [31:0] addr, input [31:0] data);
begin
    @(posedge clk);
    awaddr<=addr; wdata<=data; wstrb<=4'hF;
    awvalid<=1; wvalid<=1;
    wait(awready && wready);
    @(posedge clk); awvalid<=0; wvalid<=0; bready<=1;
    wait(bvalid);
    @(posedge clk); bready<=0;
end
endtask

task read_word(input [31:0] addr);
begin
    @(posedge clk);
    araddr<=addr; arvalid<=1;
    wait(arready);
    @(posedge clk); arvalid<=0; rready<=1;
    wait(rvalid);
    $display("DMEM READ 0x%08h = 0x%08h RESP=%b",addr,rdata,rresp);
    @(posedge clk); rready<=0;
end
endtask

initial begin
    #20 resetn=1;
    write_word(0,32'h12345678);
    write_word(4,32'hA5A55A5A);
    read_word(0);
    read_word(4);
    #20 $finish;
end

endmodule
