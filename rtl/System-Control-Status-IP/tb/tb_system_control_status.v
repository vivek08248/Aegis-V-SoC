`timescale 1ns/1ps

module tb_system_control_status;
    reg clk=0, resetn=0;
    reg [4:0] awaddr, araddr;
    reg awvalid, wvalid, bready, arvalid, rready;
    reg [31:0] wdata;
    reg [3:0] wstrb;
    wire awready,wready,bvalid,arready,rvalid;
    wire [1:0] bresp,rresp;
    wire [31:0] rdata;
    reg uart_ready=1, aes_ready=1, i2c_ready=1;
    reg watchdog_active=0, security_error=0, bus_error=0, debug_active=0;
    wire sys_enable,soft_reset,debug_enable,low_power,irq_global_enable,irq;

    always #5 clk=~clk;

    system_control_status dut(
        .aclk(clk),.aresetn(resetn),
        .s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),
        .s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),
        .s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
        .s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),
        .s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),
        .uart_ready(uart_ready),.aes_ready(aes_ready),.i2c_ready(i2c_ready),
        .watchdog_active(watchdog_active),.security_error(security_error),
        .bus_error(bus_error),.debug_active(debug_active),
        .sys_enable(sys_enable),.soft_reset(soft_reset),.debug_enable(debug_enable),
        .low_power(low_power),.irq_global_enable(irq_global_enable),.irq(irq)
    );

    task write_reg(input [4:0] a, input [31:0] d);
      begin
        @(posedge clk); awaddr<=a; wdata<=d; wstrb<=4'hF; awvalid<=1; wvalid<=1; bready<=0;
        wait(awready && wready); @(posedge clk); awvalid<=0; wvalid<=0;
        bready<=1; wait(bvalid); @(posedge clk); bready<=0;
      end
    endtask

    task read_reg(input [4:0] a);
      begin
        @(posedge clk); araddr<=a; arvalid<=1; rready<=0;
        wait(arready); @(posedge clk); arvalid<=0; rready<=1;
        wait(rvalid); $display("READ %h = %h",a,rdata); @(posedge clk); rready<=0;
      end
    endtask

    initial begin
      awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0;
      #20; resetn=1;
      write_reg(5'h00,32'h0000_0015);
      write_reg(5'h10,32'h1234_5678);
      read_reg(5'h00);
      read_reg(5'h04);
      read_reg(5'h10);
      read_reg(5'h14);
      read_reg(5'h18);
      #50;
      $finish;
    end
endmodule
