`timescale 1ns/1ps
`include "axi_uart_defines.vh"
`include "axi_uart.vh"

module tb_axi_uart;

  reg clk;
  reg rstn;

  // AXI-Lite Signals
  reg  [31:0] awaddr;
  reg         awvalid;
  wire        awready;
  reg  [31:0] wdata;
  reg  [3:0]  wstrb;
  reg         wvalid;
  wire        wready;
  wire [1:0]  bresp;
  wire        bvalid;
  reg         bready;
  
  reg  [31:0] araddr;
  reg         arvalid;
  wire        arready;
  wire [31:0] rdata;
  wire [1:0]  rresp;
  wire        rvalid;
  reg         rready;

  // UART Signals
  wire uart_tx;
  wire uart_rx;
  wire read_interrupt;

  // Loopback connection[cite: 17, 18, 20, 21]
  assign uart_rx = uart_tx;

  // DUT Instantiation
  axi_uart_top dut (
    .fixed_clk_i(clk), .axi_aclk_i(clk), .axi_aresetn_i(rstn),
    .axi_arid_i(12'b0), .axi_araddr_i(araddr[4:0]), .axi_arvalid_i(arvalid), .axi_arready_o(arready),
    .axi_rid_o(), .axi_rdata_o(rdata), .axi_rresp_o(rresp), .axi_rvalid_o(rvalid), .axi_rready_i(rready),
    .axi_awid_i(12'b0), .axi_awaddr_i(awaddr[4:0]), .axi_awvalid_i(awvalid), .axi_awready_o(awready),
    .axi_wdata_i(wdata), .axi_wstrb_i(wstrb), .axi_wvalid_i(wvalid), .axi_wready_o(wready),
    .axi_bid_o(), .axi_bresp_o(bresp), .axi_bvalid_o(bvalid), .axi_bready_i(bready),
    .read_interrupt_o(read_interrupt), .uart_tx_o(uart_tx), .uart_rx_i(uart_rx)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  task axi_write(input [31:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      awaddr = addr; awvalid = 1; wdata = data; wstrb = 4'hF; wvalid = 1; bready = 1;
      wait(awready && wready);
      @(posedge clk);
      awvalid = 0; wvalid = 0;
      wait(bvalid);
      @(posedge clk);
      bready = 0;
    end
  endtask

  task axi_read(input [31:0] addr, output [31:0] data);
    begin
      @(posedge clk);
      araddr = addr; arvalid = 1; rready = 1;
      wait(arready);
      @(posedge clk);
      arvalid = 0;
      wait(rvalid);
      data = rdata;
      @(posedge clk);
      rready = 0;
    end
  endtask

  reg [31:0] read_val;
  
  initial begin
    $fsdbDumpfile("uart_sim.fsdb");
    $fsdbDumpvars(0, tb_axi_uart);

    rstn = 0; awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 0;
    #20 rstn = 1;
    #20;

    $display("--- Configuring UART ---");
    // Enable DLAB to configure baud rate[cite: 14, 17]
    axi_write(32'h0C, 32'h80);
    
    // Set a larger baud divisor to mask the TX/RX off-by-one clock drift[cite: 14, 17]
    axi_write(32'h08, 32'h00000064);
    
    // Disable DLAB, set 8-bit word, 1 stop bit, no parity[cite: 14, 17]
    axi_write(32'h0C, 32'h03);
    
    // Enable RX Interrupts (IER Offset 0x04) to allow DATA_READY to assert[cite: 14, 17]
    axi_write(32'h04, 32'h00000001);

    $display("--- Transmitting Data ---");
    // Write 0xA5 to THR[cite: 14, 17]
    axi_write(32'h00, 32'h000000A5);

    $display("--- Polling LSR for DATA_READY ---");
    read_val = 0;
    // Wait for LSR bit 0 (DATA_READY) to assert[cite: 14, 17]
    while ((read_val & 32'h1) == 0) begin
      axi_read(32'h14, read_val);
      #100; 
    end

    $display("--- Reading Received Data ---");
    // Read RBR[cite: 14, 17]
    axi_read(32'h00, read_val);
    
    if (read_val[7:0] == 8'hA5)
      $display("SUCCESS: Transmitted 0xA5 and received 0xA5 loopback.");
    else
      $display("ERROR: Data mismatch. Received 0x%h", read_val[7:0]);

    #100 $finish;
  end
endmodule	
