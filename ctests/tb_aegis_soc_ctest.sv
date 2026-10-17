`timescale 1ns/1ps
`default_nettype none

// Standalone boot test for the compiled Core-VeeR C firmware.
module tb_aegis_soc_ctest;
    localparam integer SRAM_DEPTH = 65536;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;

    wire uart_tx;
    wire uart_rx = uart_tx;
    wire i2c_scl_o, i2c_scl_oen;
    wire i2c_sda_o, i2c_sda_oen;
    wire i2c_scl_i = i2c_scl_oen ? 1'b1 : i2c_scl_o;
    wire i2c_sda_i = i2c_sda_oen ? 1'b1 : i2c_sda_o;
    wire pwm_out, jtag_tdo, jtag_tdoEn;
    wire [31:0] gpio_out, gpio_tx_en;
    wire gpio_irq;

    wire [3:0] mem_axi_awid;
    wire [31:0] mem_axi_awaddr;
    wire [7:0] mem_axi_awlen;
    wire [2:0] mem_axi_awsize;
    wire [1:0] mem_axi_awburst;
    wire mem_axi_awlock;
    wire [3:0] mem_axi_awcache;
    wire [2:0] mem_axi_awprot;
    wire [3:0] mem_axi_awqos;
    wire mem_axi_awvalid;
    reg mem_axi_awready;
    wire [31:0] mem_axi_wdata;
    wire [3:0] mem_axi_wstrb;
    wire mem_axi_wlast, mem_axi_wvalid;
    reg mem_axi_wready;
    reg [3:0] mem_axi_bid;
    reg [1:0] mem_axi_bresp;
    reg mem_axi_bvalid;
    wire mem_axi_bready;
    wire [3:0] mem_axi_arid;
    wire [31:0] mem_axi_araddr;
    wire [7:0] mem_axi_arlen;
    wire [2:0] mem_axi_arsize;
    wire [1:0] mem_axi_arburst;
    wire mem_axi_arlock;
    wire [3:0] mem_axi_arcache;
    wire [2:0] mem_axi_arprot;
    wire [3:0] mem_axi_arqos;
    wire mem_axi_arvalid;
    reg mem_axi_arready;
    reg [3:0] mem_axi_rid;
    reg [31:0] mem_axi_rdata;
    reg [1:0] mem_axi_rresp;
    reg mem_axi_rlast, mem_axi_rvalid;
    wire mem_axi_rready;

    aegis_v_soc #(
        .VEER_RESET_VEC (31'h0000_0000),
        .VEER_NMI_VEC   (31'h0000_0040),
        .UART_BASE_ADDR (32'h1000_0000),
        .AES_BASE_ADDR  (32'h2000_0000),
        .I2C_BASE_ADDR  (32'h3000_0000),
        .IMEM_BASE_ADDR (32'hB000_0000),
        .DMEM_BASE_ADDR (32'hC000_0000)
    ) u_dut (
        .clk(clk), .rst_n(rst_n),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .i2c_scl_i(i2c_scl_i), .i2c_scl_o(i2c_scl_o), .i2c_scl_oen(i2c_scl_oen),
        .i2c_sda_i(i2c_sda_i), .i2c_sda_o(i2c_sda_o), .i2c_sda_oen(i2c_sda_oen),
        .pwm_out(pwm_out),
        .jtag_tck(1'b0), .jtag_tms(1'b1), .jtag_tdi(1'b0), .jtag_trst_n(1'b0),
        .jtag_tdo(jtag_tdo), .jtag_tdoEn(jtag_tdoEn),
        .mem_axi_awid(mem_axi_awid), .mem_axi_awaddr(mem_axi_awaddr),
        .mem_axi_awlen(mem_axi_awlen), .mem_axi_awsize(mem_axi_awsize),
        .mem_axi_awburst(mem_axi_awburst), .mem_axi_awlock(mem_axi_awlock),
        .mem_axi_awcache(mem_axi_awcache), .mem_axi_awprot(mem_axi_awprot),
        .mem_axi_awqos(mem_axi_awqos), .mem_axi_awvalid(mem_axi_awvalid),
        .mem_axi_awready(mem_axi_awready), .mem_axi_wdata(mem_axi_wdata),
        .mem_axi_wstrb(mem_axi_wstrb), .mem_axi_wlast(mem_axi_wlast),
        .mem_axi_wvalid(mem_axi_wvalid), .mem_axi_wready(mem_axi_wready),
        .mem_axi_bid(mem_axi_bid), .mem_axi_bresp(mem_axi_bresp),
        .mem_axi_bvalid(mem_axi_bvalid), .mem_axi_bready(mem_axi_bready),
        .mem_axi_arid(mem_axi_arid), .mem_axi_araddr(mem_axi_araddr),
        .mem_axi_arlen(mem_axi_arlen), .mem_axi_arsize(mem_axi_arsize),
        .mem_axi_arburst(mem_axi_arburst), .mem_axi_arlock(mem_axi_arlock),
        .mem_axi_arcache(mem_axi_arcache), .mem_axi_arprot(mem_axi_arprot),
        .mem_axi_arqos(mem_axi_arqos), .mem_axi_arvalid(mem_axi_arvalid),
        .mem_axi_arready(mem_axi_arready), .mem_axi_rid(mem_axi_rid),
        .mem_axi_rdata(mem_axi_rdata), .mem_axi_rresp(mem_axi_rresp),
        .mem_axi_rlast(mem_axi_rlast), .mem_axi_rvalid(mem_axi_rvalid),
        .mem_axi_rready(mem_axi_rready),
        .extintsrc_req(31'b0), .gpio_in(32'b0),
        .gpio_out(gpio_out), .gpio_tx_en(gpio_tx_en), .gpio_irq(gpio_irq)
    );

    reg [31:0] sram [0:SRAM_DEPTH-1];
    reg [31:0] wr_addr;
    reg [3:0] wr_id;
    reg [7:0] wr_len, wr_beat;
    reg [2:0] wr_size;
    reg [1:0] wr_burst;
    reg wr_addr_valid;
    reg [31:0] rd_addr;
    reg [3:0] rd_id;
    reg [7:0] rd_len, rd_beat;
    reg [2:0] rd_size;
    reg [1:0] rd_burst;
    reg rd_active;

    integer word_i;
    reg [31:0] access_addr;
    reg [31:0] completion_signature;
    reg [31:0] previous_signature;
    integer ip_i;
    integer sram_read_count;
    integer trace_count;
    reg uart_tx_frame_seen;
    reg [7:0] uart_tx_sampled;
    integer uart_bit_i;
    reg [8*40-1:0] image_path;

    initial begin
        for (word_i = 0; word_i < SRAM_DEPTH; word_i = word_i + 1)
            sram[word_i] = 32'b0;
        if (!$value$plusargs("C_IMAGE=%s", image_path))
            image_path = "./soc_c_test.memh";
        $display("[CTEST] Loading firmware image %0s", image_path);
        $readmemh(image_path, sram);
    end

`ifdef DUMP_FSDB
    initial begin
        if ($test$plusargs("FSDB")) begin
            $fsdbDumpfile("soc_c_test.fsdb");
            $fsdbDumpvars(0, tb_aegis_soc_ctest.u_dut);
            $fsdbDumpvars(0, tb_aegis_soc_ctest);
            $display("[FSDB] Dumping SoC and c-test signals to soc_c_test.fsdb");
        end
    end
`endif

    // Independently decode the UART TX pin; the firmware checks RX data-ready.
    initial begin
        uart_tx_frame_seen = 1'b0;
        uart_tx_sampled = 8'b0;
        wait (rst_n === 1'b1);
        forever begin
            @(negedge uart_tx);
            #500;
            if (uart_tx === 1'b0) begin
                #1000;
                for (uart_bit_i = 0; uart_bit_i < 8; uart_bit_i = uart_bit_i + 1) begin
                    uart_tx_sampled[uart_bit_i] = uart_tx;
                    #1000;
                end
                if (uart_tx === 1'b1 && uart_tx_sampled == 8'h41) begin
                    uart_tx_frame_seen = 1'b1;
                    $display("[PASS] UART TX serial frame 0x%02x captured", uart_tx_sampled);
                end else begin
                    $display("[UART] TX frame sampled=0x%02x stop=%b", uart_tx_sampled, uart_tx);
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_axi_awready <= 1'b0;
            mem_axi_wready  <= 1'b0;
            mem_axi_bvalid  <= 1'b0;
            mem_axi_bresp   <= 2'b00;
            mem_axi_bid     <= 4'b0;
            wr_addr_valid   <= 1'b0;
            wr_addr         <= 32'b0;
            wr_id           <= 4'b0;
            wr_len          <= 8'b0;
            wr_size         <= 3'd2;
            wr_burst        <= 2'b01;
            wr_beat         <= 8'b0;
            mem_axi_arready <= 1'b0;
            mem_axi_rvalid  <= 1'b0;
            mem_axi_rdata   <= 32'b0;
            mem_axi_rresp   <= 2'b00;
            mem_axi_rid     <= 4'b0;
            mem_axi_rlast   <= 1'b0;
            rd_active       <= 1'b0;
            rd_addr         <= 32'b0;
            rd_id           <= 4'b0;
            rd_len          <= 8'b0;
            rd_size         <= 3'd2;
            rd_burst        <= 2'b01;
            rd_beat         <= 8'b0;
        end else begin
            mem_axi_awready <= !wr_addr_valid && !mem_axi_bvalid;
            mem_axi_wready  <= wr_addr_valid && !mem_axi_bvalid;
            if (mem_axi_awvalid && mem_axi_awready) begin
                wr_addr       <= mem_axi_awaddr;
                wr_id         <= mem_axi_awid;
                wr_len        <= mem_axi_awlen;
                wr_size       <= mem_axi_awsize;
                wr_burst      <= mem_axi_awburst;
                wr_beat       <= 0;
                wr_addr_valid <= 1'b1;
            end
            if (mem_axi_wvalid && mem_axi_wready && wr_addr_valid) begin
                access_addr = wr_addr + ((wr_burst == 2'b00) ? 0 : (wr_beat << wr_size));
                if ((access_addr == 32'h0003_0000) || (access_addr == 32'h0003_fffc))
                    $display("[SRAM] Write addr=0x%08x data=0x%08x strb=0x%x last=%b",
                             access_addr, mem_axi_wdata, mem_axi_wstrb, mem_axi_wlast);
                if (mem_axi_wstrb[0]) sram[access_addr[17:2]][7:0]   <= mem_axi_wdata[7:0];
                if (mem_axi_wstrb[1]) sram[access_addr[17:2]][15:8]  <= mem_axi_wdata[15:8];
                if (mem_axi_wstrb[2]) sram[access_addr[17:2]][23:16] <= mem_axi_wdata[23:16];
                if (mem_axi_wstrb[3]) sram[access_addr[17:2]][31:24] <= mem_axi_wdata[31:24];
                if (mem_axi_wlast || wr_beat == wr_len) begin
                    mem_axi_bvalid <= 1'b1;
                    mem_axi_bid <= wr_id;
                    mem_axi_bresp <= 2'b00;
                    wr_addr_valid <= 1'b0;
                end else wr_beat <= wr_beat + 1'b1;
            end else if (mem_axi_bvalid && mem_axi_bready) begin
                mem_axi_bvalid <= 1'b0;
            end

            mem_axi_arready <= !rd_active && !mem_axi_rvalid;
            if (mem_axi_arvalid && mem_axi_arready) begin
                sram_read_count = sram_read_count + 1;
                if ((mem_axi_araddr == 32'h0003_0000) || (mem_axi_araddr == 32'h0003_fffc))
                    $display("[SRAM] Read request addr=0x%08x data=0x%08x size=%0d len=%0d",
                             mem_axi_araddr, sram[mem_axi_araddr[17:2]],
                             mem_axi_arsize, mem_axi_arlen);
                if (sram_read_count <= 16)
                    $display("[SRAM] Fetch/read #%0d addr=0x%08x data=0x%08x size=%0d len=%0d",
                             sram_read_count, mem_axi_araddr,
                             sram[mem_axi_araddr[17:2]], mem_axi_arsize, mem_axi_arlen);
                rd_addr <= mem_axi_araddr;
                rd_id <= mem_axi_arid;
                rd_len <= mem_axi_arlen;
                rd_size <= mem_axi_arsize;
                rd_burst <= mem_axi_arburst;
                rd_beat <= 0;
                rd_active <= 1'b1;
                mem_axi_rdata <= sram[mem_axi_araddr[17:2]];
                mem_axi_rresp <= 2'b00;
                mem_axi_rid <= mem_axi_arid;
                mem_axi_rlast <= (mem_axi_arlen == 0);
                mem_axi_rvalid <= 1'b1;
            end else if (mem_axi_rvalid && mem_axi_rready) begin
                if (rd_beat == rd_len) begin
                    mem_axi_rvalid <= 1'b0;
                    mem_axi_rlast <= 1'b0;
                    rd_active <= 1'b0;
                end else begin
                    rd_beat <= rd_beat + 1'b1;
                    if (rd_burst != 2'b00) rd_addr <= rd_addr + (1 << rd_size);
                    access_addr = rd_addr + ((rd_burst == 2'b00) ? 0 : (1 << rd_size));
                    mem_axi_rdata <= sram[access_addr[17:2]];
                    mem_axi_rlast <= (rd_beat + 1'b1 == rd_len);
                end
            end
        end
    end

    function automatic [8*24-1:0] ip_name(input integer ip);
        case (ip)
            0: ip_name = "M00 external SRAM";
            1: ip_name = "M01 UART";
            2: ip_name = "M02 AES";
            3: ip_name = "M03 I2C";
            4: ip_name = "M04 PWM";
            5: ip_name = "M05 SHA-256";
            6: ip_name = "M06 GPIO";
            7: ip_name = "M07 watchdog";
            8: ip_name = "M08 DMA CSR";
            9: ip_name = "M09 system control";
            10: ip_name = "M10 timer";
            11: ip_name = "M11 instruction memory";
            12: ip_name = "M12 data memory";
            default: ip_name = "unknown IP";
        endcase
    endfunction

    initial begin
        sram_read_count = 0;
        trace_count = 0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);
        $display("[CTEST] Reset released; reset sync=%b core reset=%b IFU arvalid=%b araddr=0x%08x",
                 u_dut.rst_sync2, u_dut.u_veer.core_rst_l,
                 u_dut.u_veer.ifu_axi_arvalid, u_dut.u_veer.ifu_axi_araddr);
        previous_signature = 32'b0;
        for (ip_i = 0; ip_i < 2_500_000; ip_i = ip_i + 1) begin
            @(posedge clk);
            if (sram[16'hffff] !== previous_signature) begin
                previous_signature = sram[16'hffff];
                if ((previous_signature & 32'hffff_0000) == 32'hacce_0000)
                    $display("[PASS] Core completed %0s", ip_name(previous_signature[7:0]));
                else if ((previous_signature & 32'hffff_ff00) == 32'hbad0_0000) begin
                    $display("[FAIL] C firmware check failed at IP %0d", previous_signature[7:0]);
                    $fatal(1, "SOC_CTEST_RESULT=FAIL signature=0x%08x", previous_signature);
                end
            end
            if (sram[16'hffff] === 32'h600d_c0de) begin
                if (!uart_tx_frame_seen)
                    $fatal(1, "SOC_CTEST_RESULT=FAIL UART TX frame 0x41 not observed");
                $display("[PASS] Core-VeeR C firmware completed all IP checks.");
                $display("SOC_CTEST_RESULT=PASS");
                $finish;
            end
            if ((ip_i % 100_000) == 99_999)
                $display("[CTEST] Waiting for firmware; cycles=%0d mailbox=0x%08x SRAM_reads=%0d core_reset=%b IFU_arvalid=%b IFU_araddr=0x%08x LSU_AR=%b/%b addr=%08x size=%0d adapter_busy=%b dn_AR=%b/%b addr=%08x fabric_R=%b/%b IMEM_AR=%b/%b addr=%08x IMEM_R=%b/%b data=%08x",
                         ip_i + 1, sram[16'hffff], sram_read_count,
                         u_dut.u_veer.core_rst_l,
                         u_dut.u_veer.ifu_axi_arvalid, u_dut.u_veer.ifu_axi_araddr,
                         u_dut.lsu_axi_arvalid, u_dut.lsu_axi_arready,
                         u_dut.lsu_axi_araddr, u_dut.lsu_axi_arsize,
                         u_dut.u_lsu_read_adapter.busy,
                         u_dut.lsu_bridge_arvalid, u_dut.lsu_bridge_arready,
                         u_dut.lsu_bridge_araddr,
                         u_dut.lsu_fabric_rvalid, u_dut.lsu_fabric_rready,
                         u_dut.imem_axil_arvalid, u_dut.imem_axil_arready,
                         u_dut.imem_axil_araddr,
                         u_dut.imem_axil_rvalid, u_dut.imem_axil_rready,
                         u_dut.imem_axil_rdata);
        end
        $fatal(1, "SOC_CTEST_RESULT=FAIL timeout mailbox=0x%08x", sram[16'hffff]);
    end

    always @(posedge clk) begin
        if (rst_n && u_dut.lsu_axi_arvalid && u_dut.lsu_axi_arready)
            $display("[LSU] upstream AR addr=%08x size=%0d len=%0d", u_dut.lsu_axi_araddr,
                     u_dut.lsu_axi_arsize, u_dut.lsu_axi_arlen);
        if (rst_n && u_dut.lsu_bridge_arvalid && u_dut.lsu_bridge_arready)
            $display("[LSU] fabric AR addr=%08x size=%0d len=%0d", u_dut.lsu_bridge_araddr,
                     u_dut.lsu_bridge_arsize, u_dut.lsu_bridge_arlen);
        if (rst_n && u_dut.lsu_fabric_rvalid && u_dut.lsu_fabric_rready)
            $display("[LSU] fabric R data=%08x resp=%0d last=%b", u_dut.lsu_fabric_rdata,
                     u_dut.lsu_fabric_rresp, u_dut.lsu_fabric_rlast);
        if (rst_n && u_dut.lsu_axi_rvalid && u_dut.lsu_axi_rready)
            $display("[LSU] upstream R data=%016x resp=%0d last=%b", u_dut.lsu_axi_rdata,
                     u_dut.lsu_axi_rresp, u_dut.lsu_axi_rlast);
        if (rst_n && u_dut.u_veer.trace_rv_i_valid_ip && trace_count < 64) begin
            $display("[TRACE] pc=0x%08x insn=0x%08x",
                     u_dut.u_veer.trace_rv_i_address_ip,
                     u_dut.u_veer.trace_rv_i_insn_ip);
            trace_count = trace_count + 1;
        end
    end
endmodule

`default_nettype wire
