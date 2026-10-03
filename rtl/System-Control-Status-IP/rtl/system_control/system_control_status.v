`timescale 1ns/1ps

module system_control_status #(
    parameter [31:0] IP_ID  = 32'hAE61_5001,
    parameter [31:0] VERSION = 32'h0001_0000
)(
    input  wire        aclk,
    input  wire        aresetn,

    input  wire [4:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [4:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    output reg [31:0]  s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    input  wire        uart_ready,
    input  wire        aes_ready,
    input  wire        i2c_ready,
    input  wire        watchdog_active,
    input  wire        security_error,
    input  wire        bus_error,
    input  wire        debug_active,

    output wire        sys_enable,
    output wire        soft_reset,
    output wire        debug_enable,
    output wire        low_power,
    output wire        irq_global_enable,
    output wire        irq
);

    reg [31:0] sys_ctrl;
    reg [31:0] irq_enable;
    reg [31:0] irq_status;
    reg [31:0] scratch;
    reg [31:0] counter;

    wire wr_fire = s_axi_awvalid && s_axi_wvalid && s_axi_awready && s_axi_wready;
    wire rd_fire = s_axi_arvalid && s_axi_arready;

    assign s_axi_awready = ~s_axi_bvalid;
    assign s_axi_wready  = ~s_axi_bvalid;
    assign s_axi_arready = ~s_axi_rvalid;

    assign sys_enable        = sys_ctrl[0];
    assign soft_reset        = sys_ctrl[1];
    assign debug_enable      = sys_ctrl[2];
    assign low_power         = sys_ctrl[3];
    assign irq_global_enable = sys_ctrl[4];

    assign irq = irq_global_enable && (|(irq_status & irq_enable));

    wire [31:0] sys_status = {
        24'b0,
        debug_active,
        bus_error,
        security_error,
        irq,
        watchdog_active,
        i2c_ready,
        aes_ready,
        uart_ready
    };

    always @(posedge aclk) begin
        if (!aresetn) begin
            sys_ctrl      <= 32'b0;
            irq_enable    <= 32'b0;
            irq_status    <= 32'b0;
            scratch       <= 32'b0;
            counter       <= 32'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'b0;
            s_axi_rresp   <= 2'b00;
        end else begin
            counter <= counter + 32'd1;

            irq_status[0] <= security_error;
            irq_status[1] <= bus_error;
            irq_status[2] <= watchdog_active;

            if (wr_fire) begin
                case (s_axi_awaddr)
                    5'h00: begin
                        if (s_axi_wstrb[0]) sys_ctrl[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) sys_ctrl[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) sys_ctrl[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) sys_ctrl[31:24] <= s_axi_wdata[31:24];
                    end
                    5'h08: begin
                        if (s_axi_wstrb[0]) irq_enable[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) irq_enable[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) irq_enable[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) irq_enable[31:24] <= s_axi_wdata[31:24];
                    end
                    5'h0C: begin
                        irq_status <= irq_status & ~s_axi_wdata;
                    end
                    5'h10: begin
                        if (s_axi_wstrb[0]) scratch[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) scratch[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) scratch[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) scratch[31:24] <= s_axi_wdata[31:24];
                    end
                    default: ;
                endcase
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            if (rd_fire) begin
                case (s_axi_araddr)
                    5'h00: s_axi_rdata <= sys_ctrl;
                    5'h04: s_axi_rdata <= sys_status;
                    5'h08: s_axi_rdata <= irq_enable;
                    5'h0C: s_axi_rdata <= irq_status;
                    5'h10: s_axi_rdata <= scratch;
                    5'h14: s_axi_rdata <= IP_ID;
                    5'h18: s_axi_rdata <= VERSION;
                    5'h1C: s_axi_rdata <= counter;
                    default: s_axi_rdata <= 32'h0000_0000;
                endcase
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end
endmodule
