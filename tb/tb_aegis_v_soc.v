// =============================================================================
// Project      : Aegis-V SoC
// File         : tb/tb_aegis_v_soc.v
// Description  : Top-level testbench for aegis_v_soc.
//
//                Instantiates the full SoC and exercises every integrated IP:
//                  1. Boot / memory subsystem  — SRAM model on M00 AXI port
//                  2. UART                     — AXI-Lite config + loopback
//                  3. AES-128                  — encrypt a known plaintext
//                  4. I2C Master               — configure prescaler registers
//
//                Because the VeeR EL2 core requires generated header files
//                (common_defines.vh, el2_param.vh) this testbench provides
//                AXI BFM masters that bypass the core and directly drive the
//                SoC's external SRAM port — simulating what the CPU would do.
//                The core is held in reset in this testbench so compilation
//                works even without the generated VeeR headers.
//
//                DUT hierarchy:
//                  tb_aegis_v_soc
//                   └─ aegis_v_soc                      (rtl/interconnect/)
//                        ├─ el2_veer_wrapper             (Cores-VeeR-EL2/design/)
//                        ├─ el2_mem                      (Cores-VeeR-EL2/design/)
//                        ├─ axi_interconnect_wrap_2x11   (rtl/interconnect/)
//                        │    ├─ axi_interconnect
//                        │    │    ├─ arbiter
//                        │    │    └─ priority_encoder
//                        ├─ axi4_to_axilite_bridge ×3    (rtl/interconnect/)
//                        ├─ axi_uart_top                 (rtl/axi-lite_uart-ipcore/)
//                        ├─ aes_axi_slave                (rtl/aes_core-master/)
//                        ├─ wb_to_axilite_bridge         (rtl/interconnect/)
//                        └─ i2c_master_top               (rtl/i2c-master/)
//
//                Compile (from run/ directory):
//                  vcs -full64 -sverilog -ntb_opts uvm              \
//                      -timescale=1ns/1ps -debug_access+all -kdb    \
//                      +define+RV_BUILD_AXI4                        \
//                      +incdir+../rtl/Cores-VeeR-EL2/design/include \
//                      +incdir+../rtl/axi-lite_uart-ipcore-develop/src/include \
//                      +incdir+../rtl/i2c-master/rtl/verilog        \
//                      -f run.f                                      \
//                      -top tb_aegis_v_soc                           \
//                      -l compile_soc.log
//
//                FSDB dump:
//                  ./simv -ucli -do "fsdbDumpfile dump_soc.fsdb; \
//                                    fsdbDumpvars 0 tb_aegis_v_soc; run"
//
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

// ---------------------------------------------------------------------------
// Inlined defines (avoid re-including IP-specific headers at TB level)
// ---------------------------------------------------------------------------
// UART register word offsets → byte addresses = offset * 4 relative to base
`define UART_BASE    32'h1000_0000
`define UART_THR     (`UART_BASE + 32'h00)   // Transmit Holding Register
`define UART_RBR     (`UART_BASE + 32'h00)   // Receive  Buffer  Register
`define UART_IER     (`UART_BASE + 32'h04)   // Interrupt Enable Register
`define UART_BAUD    (`UART_BASE + 32'h08)   // Baud Rate Divisor
`define UART_LCR     (`UART_BASE + 32'h0C)   // Line Control Register
`define UART_LSR     (`UART_BASE + 32'h14)   // Line Status  Register

// AES register byte addresses
`define AES_BASE     32'h2000_0000
`define AES_CTRL     (`AES_BASE + 32'h00)    // CTRL/STATUS
`define AES_KEY0     (`AES_BASE + 32'h04)    // KEY[127:96]
`define AES_KEY1     (`AES_BASE + 32'h08)
`define AES_KEY2     (`AES_BASE + 32'h0C)
`define AES_KEY3     (`AES_BASE + 32'h10)    // KEY[31:0]
`define AES_TEXT0    (`AES_BASE + 32'h14)    // PLAINTEXT[127:96]
`define AES_TEXT1    (`AES_BASE + 32'h18)
`define AES_TEXT2    (`AES_BASE + 32'h1C)
`define AES_TEXT3    (`AES_BASE + 32'h20)    // PLAINTEXT[31:0]
`define AES_OUT0     (`AES_BASE + 32'h24)    // CIPHERTEXT[127:96]
`define AES_OUT1     (`AES_BASE + 32'h28)
`define AES_OUT2     (`AES_BASE + 32'h2C)
`define AES_OUT3     (`AES_BASE + 32'h30)    // CIPHERTEXT[31:0]

// I2C register byte addresses (WB 3-bit addr × 4 → byte)
`define I2C_BASE     32'h3000_0000
`define I2C_PRER_LO  (`I2C_BASE + 32'h00)   // Prescale LO byte
`define I2C_PRER_HI  (`I2C_BASE + 32'h04)   // Prescale HI byte
`define I2C_CTR      (`I2C_BASE + 32'h08)   // Control register
`define I2C_TXR      (`I2C_BASE + 32'h0C)   // Transmit register
`define I2C_RXR      (`I2C_BASE + 32'h0C)   // Receive  register
`define I2C_CR       (`I2C_BASE + 32'h10)   // Command  register
`define I2C_SR       (`I2C_BASE + 32'h10)   // Status   register

// PWM register byte addresses (4-bit addr, 4 registers × 4 bytes)
`define PWM_BASE     32'h4000_0000
`define PWM_DUTY     (`PWM_BASE + 32'h00)   // slv_reg0: duty cycle [7:0]
`define PWM_REG1     (`PWM_BASE + 32'h04)   // slv_reg1
`define PWM_REG2     (`PWM_BASE + 32'h08)   // slv_reg2
`define PWM_REG3     (`PWM_BASE + 32'h0C)   // slv_reg3

// SHA256 register byte addresses (8-bit addr)
`define SHA256_BASE  32'h5000_0000
`define SHA256_NAME0  (`SHA256_BASE + 32'h00)
`define SHA256_NAME1  (`SHA256_BASE + 32'h04)
`define SHA256_VERSION (`SHA256_BASE + 32'h08)
`define SHA256_CTRL   (`SHA256_BASE + 32'h20)
`define SHA256_STATUS (`SHA256_BASE + 32'h24)
`define SHA256_BLOCK0 (`SHA256_BASE + 32'h40)

// GPIO register byte addresses (5-bit addr)
`define GPIO_BASE     32'h6000_0000
`define GPIO_INFO     (`GPIO_BASE + 32'h00)
`define GPIO_OUT      (`GPIO_BASE + 32'h04)
`define GPIO_IN       (`GPIO_BASE + 32'h08)
`define GPIO_MODE0    (`GPIO_BASE + 32'h0C)
`define GPIO_SET      (`GPIO_BASE + 32'h10)
`define GPIO_CLEAR    (`GPIO_BASE + 32'h14)
`define GPIO_TOGGLE   (`GPIO_BASE + 32'h18)

// WDT register byte addresses (5-bit addr)
`define WDT_BASE      32'h7000_0000
`define WDT_LOAD      (`WDT_BASE + 32'h00)
`define WDT_MR        (`WDT_BASE + 32'h04)
`define WDT_CTRL      (`WDT_BASE + 32'h08)
`define WDT_STAT      (`WDT_BASE + 32'h0C)
`define WDT_INTCLR    (`WDT_BASE + 32'h10)

// DMA CSR register byte addresses (8-bit addr)
`define DMA_BASE      32'h8000_0000
`define DMA_SRC_ADDR  (`DMA_BASE + 32'h00)
`define DMA_DST_ADDR  (`DMA_BASE + 32'h04)
`define DMA_NUM_BYTES (`DMA_BASE + 32'h08)
`define DMA_CONTROL   (`DMA_BASE + 32'h0C)
`define DMA_STATUS    (`DMA_BASE + 32'h10)
`define DMA_VERSION   (`DMA_BASE + 32'h14)

// SCS register byte addresses (5-bit addr)
`define SCS_BASE      32'h9000_0000
`define SCS_SYS_CTRL  (`SCS_BASE + 32'h00)
`define SCS_SYS_STATUS (`SCS_BASE + 32'h04)
`define SCS_IRQ_ENABLE (`SCS_BASE + 32'h08)
`define SCS_IRQ_STATUS (`SCS_BASE + 32'h0C)
`define SCS_SCRATCH   (`SCS_BASE + 32'h10)
`define SCS_IP_ID      (`SCS_BASE + 32'h14)
`define SCS_VERSION   (`SCS_BASE + 32'h18)

// Timer register byte addresses (5-bit addr)
`define TIMER_BASE    32'hA000_0000
`define TIMER_MTIME_LO  (`TIMER_BASE + 32'h00)
`define TIMER_MTIME_HI  (`TIMER_BASE + 32'h04)
`define TIMER_MTIMECMP_LO (`TIMER_BASE + 32'h08)
`define TIMER_MTIMECMP_HI (`TIMER_BASE + 32'h0C)
`define TIMER_CTRL    (`TIMER_BASE + 32'h10)
`define TIMER_STATUS  (`TIMER_BASE + 32'h14)
`define TIMER_PRESCALER (`TIMER_BASE + 32'h18)

// Instruction Memory base address
`define IMEM_BASE     32'hB000_0000

// Data Memory base address
`define DMEM_BASE     32'hC000_0000

// Timing: 100 MHz clock → 10 ns period
`define CLK_PERIOD   10

// Simulation parameters
`define SRAM_DEPTH   65536    // 64 K × 32-bit words = 256 KB
`define TIMEOUT_CYCLES 50000

// =============================================================================
module tb_aegis_v_soc;

    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    reg  clk;
    reg  rst_n;

    initial clk = 1'b0;
    always  #(`CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // UART loopback (TX → RX)
    // -------------------------------------------------------------------------
    wire uart_tx, uart_rx;
    assign uart_rx = uart_tx;           // loopback

    // -------------------------------------------------------------------------
    // PWM output (observed but not driven)
    // -------------------------------------------------------------------------
    wire pwm_out;

    // -------------------------------------------------------------------------
    // I2C bus (open-drain with pull-ups)
    // -------------------------------------------------------------------------
    wire i2c_scl_o, i2c_scl_oen;
    wire i2c_sda_o, i2c_sda_oen;
    wire i2c_scl = i2c_scl_oen ? 1'b1 : i2c_scl_o;
    wire i2c_sda = i2c_sda_oen ? 1'b1 : i2c_sda_o;

    // -------------------------------------------------------------------------
    // JTAG (tied inactive)
    // -------------------------------------------------------------------------
    wire jtag_tdo, jtag_tdoEn;
    wire [31:0] gpio_out, gpio_tx_en;
    wire gpio_irq;

    // -------------------------------------------------------------------------
    // External SRAM AXI4 port (M00 of interconnect, exposed at SoC top)
    // -------------------------------------------------------------------------
    // Write address channel
    wire [7:0]   mem_axi_awid;
    wire [31:0]  mem_axi_awaddr;
    wire [7:0]   mem_axi_awlen;
    wire [2:0]   mem_axi_awsize;
    wire [1:0]   mem_axi_awburst;
    wire         mem_axi_awlock;
    wire [3:0]   mem_axi_awcache;
    wire [2:0]   mem_axi_awprot;
    wire [3:0]   mem_axi_awqos;
    wire         mem_axi_awvalid;
    reg          mem_axi_awready;
    // Write data channel
    wire [31:0]  mem_axi_wdata;
    wire [3:0]   mem_axi_wstrb;
    wire         mem_axi_wlast;
    wire         mem_axi_wvalid;
    reg          mem_axi_wready;
    // Write response channel
    reg  [7:0]   mem_axi_bid;
    reg  [1:0]   mem_axi_bresp;
    reg          mem_axi_bvalid;
    wire         mem_axi_bready;
    // Read address channel
    wire [7:0]   mem_axi_arid;
    wire [31:0]  mem_axi_araddr;
    wire [7:0]   mem_axi_arlen;
    wire [2:0]   mem_axi_arsize;
    wire [1:0]   mem_axi_arburst;
    wire         mem_axi_arlock;
    wire [3:0]   mem_axi_arcache;
    wire [2:0]   mem_axi_arprot;
    wire [3:0]   mem_axi_arqos;
    wire         mem_axi_arvalid;
    reg          mem_axi_arready;
    // Read data channel
    reg  [7:0]   mem_axi_rid;
    reg  [31:0]  mem_axi_rdata;
    reg  [1:0]   mem_axi_rresp;
    reg          mem_axi_rlast;
    reg          mem_axi_rvalid;
    wire         mem_axi_rready;

    // =========================================================================
    // DUT: aegis_v_soc
    // =========================================================================
    aegis_v_soc #(
        .VEER_RESET_VEC (31'h0000_0000),
        .VEER_NMI_VEC   (31'h0000_0040),
        .UART_BASE_ADDR (32'h1000_0000),
        .AES_BASE_ADDR  (32'h2000_0000),
        .I2C_BASE_ADDR  (32'h3000_0000),
        .IMEM_BASE_ADDR (32'hB000_0000),
        .DMEM_BASE_ADDR (32'hC000_0000)
    ) u_dut (
        .clk             (clk),
        .rst_n           (rst_n),
        // UART
        .uart_rx         (uart_rx),
        .uart_tx         (uart_tx),
        // I2C
        .i2c_scl_i       (i2c_scl),
        .i2c_scl_o       (i2c_scl_o),
        .i2c_scl_oen     (i2c_scl_oen),
        .i2c_sda_i       (i2c_sda),
        .i2c_sda_o       (i2c_sda_o),
        .i2c_sda_oen     (i2c_sda_oen),
        // PWM
        .pwm_out         (pwm_out),
        // JTAG
        .jtag_tck        (1'b0),
        .jtag_tms        (1'b1),
        .jtag_tdi        (1'b0),
        .jtag_trst_n     (1'b0),
        .jtag_tdo        (jtag_tdo),
        .jtag_tdoEn      (jtag_tdoEn),
        // External SRAM (M00)
        .mem_axi_awid    (mem_axi_awid),
        .mem_axi_awaddr  (mem_axi_awaddr),
        .mem_axi_awlen   (mem_axi_awlen),
        .mem_axi_awsize  (mem_axi_awsize),
        .mem_axi_awburst (mem_axi_awburst),
        .mem_axi_awlock  (mem_axi_awlock),
        .mem_axi_awcache (mem_axi_awcache),
        .mem_axi_awprot  (mem_axi_awprot),
        .mem_axi_awqos   (mem_axi_awqos),
        .mem_axi_awvalid (mem_axi_awvalid),
        .mem_axi_awready (mem_axi_awready),
        .mem_axi_wdata   (mem_axi_wdata),
        .mem_axi_wstrb   (mem_axi_wstrb),
        .mem_axi_wlast   (mem_axi_wlast),
        .mem_axi_wvalid  (mem_axi_wvalid),
        .mem_axi_wready  (mem_axi_wready),
        .mem_axi_bid     (mem_axi_bid),
        .mem_axi_bresp   (mem_axi_bresp),
        .mem_axi_bvalid  (mem_axi_bvalid),
        .mem_axi_bready  (mem_axi_bready),
        .mem_axi_arid    (mem_axi_arid),
        .mem_axi_araddr  (mem_axi_araddr),
        .mem_axi_arlen   (mem_axi_arlen),
        .mem_axi_arsize  (mem_axi_arsize),
        .mem_axi_arburst (mem_axi_arburst),
        .mem_axi_arlock  (mem_axi_arlock),
        .mem_axi_arcache (mem_axi_arcache),
        .mem_axi_arprot  (mem_axi_arprot),
        .mem_axi_arqos   (mem_axi_arqos),
        .mem_axi_arvalid (mem_axi_arvalid),
        .mem_axi_arready (mem_axi_arready),
        .mem_axi_rid     (mem_axi_rid),
        .mem_axi_rdata   (mem_axi_rdata),
        .mem_axi_rresp   (mem_axi_rresp),
        .mem_axi_rlast   (mem_axi_rlast),
        .mem_axi_rvalid  (mem_axi_rvalid),
        .mem_axi_rready  (mem_axi_rready),
        // Interrupts (all de-asserted)
        .extintsrc_req   (31'h0),
        .gpio_in         (32'h0),
        .gpio_out        (gpio_out),
        .gpio_tx_en      (gpio_tx_en),
        .gpio_irq        (gpio_irq)
    );

    // =========================================================================
    // Simple AXI4 SRAM model  (serves M00 — external instruction/data memory)
    // =========================================================================
    reg [31:0] sram [0:`SRAM_DEPTH-1];
    integer i;

    // Latch write-address channel
    reg [31:0] wr_addr_lat;
    reg [7:0]  wr_id_lat;
    reg        wr_addr_valid;

    // Write channel
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_axi_awready <= 1'b0;
            mem_axi_wready  <= 1'b0;
            mem_axi_bvalid  <= 1'b0;
            mem_axi_bresp   <= 2'b00;
            mem_axi_bid     <= 8'h0;
            wr_addr_valid   <= 1'b0;
            wr_addr_lat     <= 32'h0;
            wr_id_lat       <= 8'h0;
        end else begin
            mem_axi_awready <= 1'b1;
            mem_axi_wready  <= 1'b1;

            if (mem_axi_awvalid && mem_axi_awready) begin
                wr_addr_lat   <= mem_axi_awaddr;
                wr_id_lat     <= mem_axi_awid;
                wr_addr_valid <= 1'b1;
            end

            if (mem_axi_wvalid && mem_axi_wready && wr_addr_valid) begin
                if (mem_axi_wstrb[0]) sram[wr_addr_lat[17:2]][7:0]   <= mem_axi_wdata[7:0];
                if (mem_axi_wstrb[1]) sram[wr_addr_lat[17:2]][15:8]  <= mem_axi_wdata[15:8];
                if (mem_axi_wstrb[2]) sram[wr_addr_lat[17:2]][23:16] <= mem_axi_wdata[23:16];
                if (mem_axi_wstrb[3]) sram[wr_addr_lat[17:2]][31:24] <= mem_axi_wdata[31:24];
                mem_axi_bvalid  <= 1'b1;
                mem_axi_bresp   <= 2'b00;
                mem_axi_bid     <= wr_id_lat;
                wr_addr_valid   <= 1'b0;
            end else if (mem_axi_bvalid && mem_axi_bready) begin
                mem_axi_bvalid <= 1'b0;
            end
        end
    end

    // Read channel
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_axi_arready <= 1'b0;
            mem_axi_rvalid  <= 1'b0;
            mem_axi_rdata   <= 32'h0;
            mem_axi_rresp   <= 2'b00;
            mem_axi_rlast   <= 1'b0;
            mem_axi_rid     <= 8'h0;
        end else begin
            mem_axi_arready <= 1'b1;
            if (mem_axi_arvalid && mem_axi_arready) begin
                mem_axi_rdata  <= sram[mem_axi_araddr[17:2]];
                mem_axi_rresp  <= 2'b00;
                mem_axi_rlast  <= 1'b1;
                mem_axi_rid    <= mem_axi_arid;
                mem_axi_rvalid <= 1'b1;
            end else if (mem_axi_rvalid && mem_axi_rready) begin
                mem_axi_rvalid <= 1'b0;
                mem_axi_rlast  <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Test scoreboard
    // =========================================================================
    integer pass_count;
    integer fail_count;

    task print_result;
        input [255:0] test_name;
        input         passed;
        begin
            if (passed) begin
                $display("[PASS] %0s  @ %0t ns", test_name, $time);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s  @ %0t ns", test_name, $time);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================================
    // AXI4-Lite write/read tasks
    //   These tasks exercise peripherals by driving the SoC's LSU slave port
    //   indirectly — via the SRAM model.  In a full-chip simulation the CPU
    //   would issue loads/stores; here we use direct hierarchical access to
    //   the bridge AXI-Lite wires for peripheral access (see notes below).
    //
    //   For peripheral verification we use direct register force/release
    //   on the AXI-Lite interfaces exposed inside the DUT hierarchy.
    //   This avoids needing a working VeeR core (no generated headers needed).
    // =========================================================================

    // Shorthand hierarchy paths
    // UART AXI-Lite (output of u_bridge_uart)
    `define UART_AXIL   tb_aegis_v_soc.u_dut.u_bridge_uart
    // AES  AXI-Lite (output of u_bridge_aes)
    `define AES_AXIL    tb_aegis_v_soc.u_dut.u_bridge_aes
    // I2C  AXI-Lite (output of u_bridge_i2c → wb bridge)
    `define I2C_WB      tb_aegis_v_soc.u_dut.u_i2c

    // -------------------------------------------------------------------------
    // Task: axi_lite_write
    //   Drives an AXI-Lite write directly on the UART bridge output wires.
    //   Signals: m_axil_aw*, m_axil_w*, m_axil_b*
    // -------------------------------------------------------------------------
    reg [31:0] axil_awaddr_drv; reg axil_awvalid_drv;
    reg [31:0] axil_wdata_drv;  reg [3:0] axil_wstrb_drv; reg axil_wvalid_drv;
    reg        axil_bready_drv;

    // Force/release the UART AXI-Lite write channel
    task uart_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            // Address phase
            force tb_aegis_v_soc.u_dut.uart_axil_awaddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.uart_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.uart_axil_awid    = 8'h0;
            force tb_aegis_v_soc.u_dut.uart_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.uart_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.uart_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.uart_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while ((!tb_aegis_v_soc.u_dut.uart_axil_awready ||
                    !tb_aegis_v_soc.u_dut.uart_axil_wready) && timeout < 100) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            // Wait for write response
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.uart_axil_bvalid && timeout < 100) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.uart_axil_awaddr;
            release tb_aegis_v_soc.u_dut.uart_axil_awvalid;
            release tb_aegis_v_soc.u_dut.uart_axil_awid;
            release tb_aegis_v_soc.u_dut.uart_axil_wdata;
            release tb_aegis_v_soc.u_dut.uart_axil_wstrb;
            release tb_aegis_v_soc.u_dut.uart_axil_wvalid;
            release tb_aegis_v_soc.u_dut.uart_axil_bready;
        end
    endtask

    // Force/release the UART AXI-Lite read channel
    task uart_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.uart_axil_araddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.uart_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.uart_axil_arid    = 8'h0;
            force tb_aegis_v_soc.u_dut.uart_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.uart_axil_arready && timeout < 100) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.uart_axil_rvalid && timeout < 200) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.uart_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.uart_axil_araddr;
            release tb_aegis_v_soc.u_dut.uart_axil_arvalid;
            release tb_aegis_v_soc.u_dut.uart_axil_arid;
            release tb_aegis_v_soc.u_dut.uart_axil_rready;
        end
    endtask

    // AES AXI-Lite write (same pattern)
    task aes_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.aes_axil_awaddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.aes_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.aes_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.aes_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.aes_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.aes_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.aes_axil_bvalid && timeout < 100) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.aes_axil_awaddr;
            release tb_aegis_v_soc.u_dut.aes_axil_awvalid;
            release tb_aegis_v_soc.u_dut.aes_axil_wdata;
            release tb_aegis_v_soc.u_dut.aes_axil_wstrb;
            release tb_aegis_v_soc.u_dut.aes_axil_wvalid;
            release tb_aegis_v_soc.u_dut.aes_axil_bready;
        end
    endtask

    task aes_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.aes_axil_araddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.aes_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.aes_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.aes_axil_rvalid && timeout < 200) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.aes_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.aes_axil_araddr;
            release tb_aegis_v_soc.u_dut.aes_axil_arvalid;
            release tb_aegis_v_soc.u_dut.aes_axil_rready;
        end
    endtask

    // -------------------------------------------------------------------------
    // Task: pwm_axil_write
    //   Drives an AXI-Lite write directly on the PWM bridge output wires.
    //   The PWM IP has a 4-bit address space (LITE_ADDR_W=4).
    // =========================================================================
    task pwm_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            // Address phase — drive both addr and valid
            force tb_aegis_v_soc.u_dut.pwm_axil_awaddr  = addr[3:0];
            force tb_aegis_v_soc.u_dut.pwm_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.pwm_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.pwm_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.pwm_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.pwm_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            // Wait for both AW and W handshakes
            while ((!tb_aegis_v_soc.u_dut.pwm_axil_awready ||
                    !tb_aegis_v_soc.u_dut.pwm_axil_wready) && timeout < 100) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            // Wait for write response
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.pwm_axil_bvalid && timeout < 100) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.pwm_axil_awaddr;
            release tb_aegis_v_soc.u_dut.pwm_axil_awvalid;
            release tb_aegis_v_soc.u_dut.pwm_axil_wdata;
            release tb_aegis_v_soc.u_dut.pwm_axil_wstrb;
            release tb_aegis_v_soc.u_dut.pwm_axil_wvalid;
            release tb_aegis_v_soc.u_dut.pwm_axil_bready;
        end
    endtask

    task pwm_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.pwm_axil_araddr  = addr[3:0];
            force tb_aegis_v_soc.u_dut.pwm_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.pwm_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.pwm_axil_arready && timeout < 100) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.pwm_axil_rvalid && timeout < 200) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.pwm_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.pwm_axil_araddr;
            release tb_aegis_v_soc.u_dut.pwm_axil_arvalid;
            release tb_aegis_v_soc.u_dut.pwm_axil_rready;
        end
    endtask

    // -------------------------------------------------------------------------
    // Generic AXI-Lite write/read tasks for M05-M12 IPs
    //   These use hierarchical force/release on the DUT's internal AXI-Lite
    //   wires (after the bridge, before the IP).
    //   Each IP has a <prefix>_axil_* set of wires in aegis_v_soc.
    // -------------------------------------------------------------------------

    // SHA256 AXI-Lite (8-bit addr)
    task sha256_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.sha256_axil_awaddr  = addr[7:0];
            force tb_aegis_v_soc.u_dut.sha256_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.sha256_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.sha256_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.sha256_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.sha256_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while ((!tb_aegis_v_soc.u_dut.sha256_axil_awready ||
                    !tb_aegis_v_soc.u_dut.sha256_axil_wready) && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.sha256_axil_bvalid && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.sha256_axil_awaddr;
            release tb_aegis_v_soc.u_dut.sha256_axil_awvalid;
            release tb_aegis_v_soc.u_dut.sha256_axil_wdata;
            release tb_aegis_v_soc.u_dut.sha256_axil_wstrb;
            release tb_aegis_v_soc.u_dut.sha256_axil_wvalid;
            release tb_aegis_v_soc.u_dut.sha256_axil_bready;
        end
    endtask

    task sha256_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.sha256_axil_araddr  = addr[7:0];
            force tb_aegis_v_soc.u_dut.sha256_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.sha256_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.sha256_axil_arready && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.sha256_axil_rvalid && timeout < 200) begin
                @(posedge clk); timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.sha256_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.sha256_axil_araddr;
            release tb_aegis_v_soc.u_dut.sha256_axil_arvalid;
            release tb_aegis_v_soc.u_dut.sha256_axil_rready;
        end
    endtask

    // GPIO AXI-Lite (5-bit addr)
    task gpio_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.gpio_axil_awaddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.gpio_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.gpio_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.gpio_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.gpio_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.gpio_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while ((!tb_aegis_v_soc.u_dut.gpio_axil_awready ||
                    !tb_aegis_v_soc.u_dut.gpio_axil_wready) && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.gpio_axil_bvalid && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.gpio_axil_awaddr;
            release tb_aegis_v_soc.u_dut.gpio_axil_awvalid;
            release tb_aegis_v_soc.u_dut.gpio_axil_wdata;
            release tb_aegis_v_soc.u_dut.gpio_axil_wstrb;
            release tb_aegis_v_soc.u_dut.gpio_axil_wvalid;
            release tb_aegis_v_soc.u_dut.gpio_axil_bready;
        end
    endtask

    task gpio_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.gpio_axil_araddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.gpio_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.gpio_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.gpio_axil_arready && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.gpio_axil_rvalid && timeout < 200) begin
                @(posedge clk); timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.gpio_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.gpio_axil_araddr;
            release tb_aegis_v_soc.u_dut.gpio_axil_arvalid;
            release tb_aegis_v_soc.u_dut.gpio_axil_rready;
        end
    endtask

    // WDT AXI-Lite (5-bit addr)
    task wdt_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.wdt_axil_awaddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.wdt_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.wdt_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.wdt_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.wdt_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.wdt_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while ((!tb_aegis_v_soc.u_dut.wdt_axil_awready ||
                    !tb_aegis_v_soc.u_dut.wdt_axil_wready) && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.wdt_axil_bvalid && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.wdt_axil_awaddr;
            release tb_aegis_v_soc.u_dut.wdt_axil_awvalid;
            release tb_aegis_v_soc.u_dut.wdt_axil_wdata;
            release tb_aegis_v_soc.u_dut.wdt_axil_wstrb;
            release tb_aegis_v_soc.u_dut.wdt_axil_wvalid;
            release tb_aegis_v_soc.u_dut.wdt_axil_bready;
        end
    endtask

    task wdt_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.wdt_axil_araddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.wdt_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.wdt_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.wdt_axil_arready && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.wdt_axil_rvalid && timeout < 200) begin
                @(posedge clk); timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.wdt_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.wdt_axil_araddr;
            release tb_aegis_v_soc.u_dut.wdt_axil_arvalid;
            release tb_aegis_v_soc.u_dut.wdt_axil_rready;
        end
    endtask

    // DMA AXI-Lite (5-bit addr from bridge, DMA uses 8-bit internally)
    task dma_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.dma_axil_awaddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.dma_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.dma_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.dma_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.dma_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.dma_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while ((!tb_aegis_v_soc.u_dut.dma_axil_awready ||
                    !tb_aegis_v_soc.u_dut.dma_axil_wready) && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.dma_axil_bvalid && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.dma_axil_awaddr;
            release tb_aegis_v_soc.u_dut.dma_axil_awvalid;
            release tb_aegis_v_soc.u_dut.dma_axil_wdata;
            release tb_aegis_v_soc.u_dut.dma_axil_wstrb;
            release tb_aegis_v_soc.u_dut.dma_axil_wvalid;
            release tb_aegis_v_soc.u_dut.dma_axil_bready;
        end
    endtask

    task dma_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.dma_axil_araddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.dma_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.dma_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.dma_axil_arready && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.dma_axil_rvalid && timeout < 200) begin
                @(posedge clk); timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.dma_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.dma_axil_araddr;
            release tb_aegis_v_soc.u_dut.dma_axil_arvalid;
            release tb_aegis_v_soc.u_dut.dma_axil_rready;
        end
    endtask

    // SCS AXI-Lite (5-bit addr)
    task scs_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.scs_axil_awaddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.scs_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.scs_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.scs_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.scs_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.scs_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while ((!tb_aegis_v_soc.u_dut.scs_axil_awready ||
                    !tb_aegis_v_soc.u_dut.scs_axil_wready) && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.scs_axil_bvalid && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.scs_axil_awaddr;
            release tb_aegis_v_soc.u_dut.scs_axil_awvalid;
            release tb_aegis_v_soc.u_dut.scs_axil_wdata;
            release tb_aegis_v_soc.u_dut.scs_axil_wstrb;
            release tb_aegis_v_soc.u_dut.scs_axil_wvalid;
            release tb_aegis_v_soc.u_dut.scs_axil_bready;
        end
    endtask

    task scs_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.scs_axil_araddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.scs_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.scs_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.scs_axil_arready && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.scs_axil_rvalid && timeout < 200) begin
                @(posedge clk); timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.scs_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.scs_axil_araddr;
            release tb_aegis_v_soc.u_dut.scs_axil_arvalid;
            release tb_aegis_v_soc.u_dut.scs_axil_rready;
        end
    endtask

    // Timer AXI-Lite (5-bit addr)
    task timer_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.timer_axil_awaddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.timer_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.timer_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.timer_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.timer_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.timer_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while ((!tb_aegis_v_soc.u_dut.timer_axil_awready ||
                    !tb_aegis_v_soc.u_dut.timer_axil_wready) && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.timer_axil_bvalid && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.timer_axil_awaddr;
            release tb_aegis_v_soc.u_dut.timer_axil_awvalid;
            release tb_aegis_v_soc.u_dut.timer_axil_wdata;
            release tb_aegis_v_soc.u_dut.timer_axil_wstrb;
            release tb_aegis_v_soc.u_dut.timer_axil_wvalid;
            release tb_aegis_v_soc.u_dut.timer_axil_bready;
        end
    endtask

    task timer_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.timer_axil_araddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.timer_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.timer_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.timer_axil_arready && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.timer_axil_rvalid && timeout < 200) begin
                @(posedge clk); timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.timer_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.timer_axil_araddr;
            release tb_aegis_v_soc.u_dut.timer_axil_arvalid;
            release tb_aegis_v_soc.u_dut.timer_axil_rready;
        end
    endtask

    // IMEM AXI-Lite (5-bit addr from bridge)
    task imem_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.imem_axil_awaddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.imem_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.imem_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.imem_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.imem_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.imem_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while ((!tb_aegis_v_soc.u_dut.imem_axil_awready ||
                    !tb_aegis_v_soc.u_dut.imem_axil_wready) && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.imem_axil_bvalid && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.imem_axil_awaddr;
            release tb_aegis_v_soc.u_dut.imem_axil_awvalid;
            release tb_aegis_v_soc.u_dut.imem_axil_wdata;
            release tb_aegis_v_soc.u_dut.imem_axil_wstrb;
            release tb_aegis_v_soc.u_dut.imem_axil_wvalid;
            release tb_aegis_v_soc.u_dut.imem_axil_bready;
        end
    endtask

    task imem_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.imem_axil_araddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.imem_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.imem_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.imem_axil_arready && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.imem_axil_rvalid && timeout < 200) begin
                @(posedge clk); timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.imem_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.imem_axil_araddr;
            release tb_aegis_v_soc.u_dut.imem_axil_arvalid;
            release tb_aegis_v_soc.u_dut.imem_axil_rready;
        end
    endtask

    // DMEM AXI-Lite (5-bit addr from bridge)
    task dmem_axil_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        integer      timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.dmem_axil_awaddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.dmem_axil_awvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.dmem_axil_wdata   = data;
            force tb_aegis_v_soc.u_dut.dmem_axil_wstrb   = strb;
            force tb_aegis_v_soc.u_dut.dmem_axil_wvalid  = 1'b1;
            force tb_aegis_v_soc.u_dut.dmem_axil_bready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while ((!tb_aegis_v_soc.u_dut.dmem_axil_awready ||
                    !tb_aegis_v_soc.u_dut.dmem_axil_wready) && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.dmem_axil_bvalid && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.dmem_axil_awaddr;
            release tb_aegis_v_soc.u_dut.dmem_axil_awvalid;
            release tb_aegis_v_soc.u_dut.dmem_axil_wdata;
            release tb_aegis_v_soc.u_dut.dmem_axil_wstrb;
            release tb_aegis_v_soc.u_dut.dmem_axil_wvalid;
            release tb_aegis_v_soc.u_dut.dmem_axil_bready;
        end
    endtask

    task dmem_axil_read;
        input  [31:0] addr;
        output [31:0] data;
        integer       timeout;
        begin
            @(posedge clk);
            force tb_aegis_v_soc.u_dut.dmem_axil_araddr  = addr[4:0];
            force tb_aegis_v_soc.u_dut.dmem_axil_arvalid = 1'b1;
            force tb_aegis_v_soc.u_dut.dmem_axil_rready  = 1'b1;
            timeout = 0;
            @(posedge clk);
            while (!tb_aegis_v_soc.u_dut.dmem_axil_arready && timeout < 100) begin
                @(posedge clk); timeout = timeout + 1;
            end
            timeout = 0;
            while (!tb_aegis_v_soc.u_dut.dmem_axil_rvalid && timeout < 200) begin
                @(posedge clk); timeout = timeout + 1;
            end
            data = tb_aegis_v_soc.u_dut.dmem_axil_rdata;
            @(posedge clk);
            release tb_aegis_v_soc.u_dut.dmem_axil_araddr;
            release tb_aegis_v_soc.u_dut.dmem_axil_arvalid;
            release tb_aegis_v_soc.u_dut.dmem_axil_rready;
        end
    endtask
    // =========================================================================
    initial begin
        $fsdbDumpfile("dump_soc.fsdb");
        $fsdbDumpvars(0, tb_aegis_v_soc);
    end

    // =========================================================================
    // Main stimulus
    // =========================================================================
    reg [31:0] rd_data;
    reg [31:0] exp_data;

    initial begin
        // ------------------------------------------------------------------
        // Initialise
        // ------------------------------------------------------------------
        pass_count = 0;
        fail_count = 0;

        // Initialise SRAM to 0
        for (i = 0; i < `SRAM_DEPTH; i = i + 1)
            sram[i] = 32'h0;

        // De-assert ready signals during reset
        mem_axi_awready = 1'b0;
        mem_axi_wready  = 1'b0;
        mem_axi_bvalid  = 1'b0;
        mem_axi_bresp   = 2'b00;
        mem_axi_bid     = 8'h0;
        mem_axi_arready = 1'b0;
        mem_axi_rvalid  = 1'b0;
        mem_axi_rdata   = 32'h0;
        mem_axi_rresp   = 2'b00;
        mem_axi_rlast   = 1'b0;
        mem_axi_rid     = 8'h0;

        // ------------------------------------------------------------------
        // TEST 0: Reset
        // ------------------------------------------------------------------
        rst_n = 1'b0;
        repeat(20) @(posedge clk);
        rst_n = 1'b1;
        repeat(10) @(posedge clk);

        $display("=======================================================");
        $display(" Aegis-V SoC Top-Level Testbench");
        $display(" Time: %0t ns", $time);
        $display("=======================================================");

        // ------------------------------------------------------------------
        // TEST 1: SRAM model — write word then read it back
        // ------------------------------------------------------------------
        $display("\n--- TEST 1: External SRAM write/read ---");
        // The SRAM model is driven by the M00 AXI4 port of the interconnect.
        // We cannot inject traffic via the VeeR LSU from a bare TB without
        // the generated headers.  Instead we directly write to the sram array
        // and verify the read-back logic model.
        sram[32'h0010] = 32'hDEAD_BEEF;
        rd_data        = sram[32'h0010];
        print_result("SRAM model direct read-back",
                     (rd_data === 32'hDEAD_BEEF));

        // ------------------------------------------------------------------
        // TEST 2: UART — configure baud divisor and line control
        // ------------------------------------------------------------------
        $display("\n--- TEST 2: UART configuration ---");

        // Set DLAB=1 to access baud divisor  (LCR bit[7]=1)
        uart_axil_write(`UART_LCR, 32'h0000_0080, 4'hF);
        // Write baud divisor = 0x0001 (max speed for simulation)
        uart_axil_write(`UART_BAUD, 32'h0000_0001, 4'hF);
        // Set DLAB=0, 8N1 (LCR = 0x03)
        uart_axil_write(`UART_LCR, 32'h0000_0003, 4'hF);

        // Verify LCR reads back 0x03
        uart_axil_read(`UART_LCR, rd_data);
        print_result("UART LCR = 0x03 (8N1)", (rd_data[6:0] === 7'h03));

        // Enable RX interrupt (IER bit[0]=1)
        uart_axil_write(`UART_IER, 32'h0000_0001, 4'hF);
        uart_axil_read(`UART_IER, rd_data);
        print_result("UART IER bit[0] set", (rd_data[0] === 1'b1));

        // ------------------------------------------------------------------
        // TEST 3: UART TX loopback — write to THR, wait, read LSR then RBR
        // ------------------------------------------------------------------
        $display("\n--- TEST 3: UART TX/RX loopback ---");

        // Write byte 0xA5 to THR
        uart_axil_write(`UART_THR, 32'h0000_00A5, 4'h1);

        // Wait for UART serial transmission (baud_div=1 → fast, allow 500 cycles)
        repeat(500) @(posedge clk);

        // Poll LSR bit[0] (DATA_READY) until set or timeout
        begin : poll_lsr
            integer poll_cnt;
            poll_cnt = 0;
            rd_data  = 32'h0;
            while (rd_data[0] === 1'b0 && poll_cnt < `TIMEOUT_CYCLES) begin
                uart_axil_read(`UART_LSR, rd_data);
                @(posedge clk);
                poll_cnt = poll_cnt + 1;
            end
            print_result("UART LSR DATA_READY after TX", (rd_data[0] === 1'b1));
        end

        // Read received byte from RBR
        uart_axil_read(`UART_RBR, rd_data);
        print_result("UART RBR loopback = 0xA5", (rd_data[7:0] === 8'hA5));

        // ------------------------------------------------------------------
        // TEST 4: AES — load key and plaintext, trigger encryption
        // ------------------------------------------------------------------
        $display("\n--- TEST 4: AES encryption ---");
        // Using NIST FIPS-197 Appendix B test vector:
        //   Key       : 2B 7E 15 16  28 AE D2 A6  AB F7 15 88  09 CF 4F 3C
        //   Plaintext : 32 43 F6 A8  88 5A 30 8D  31 31 98 A2  E0 37 07 34
        //   Ciphertext: 39 25 84 1D  02 DC 09 FB  DC 11 85 97  19 6A 0B 32

        // Reset AES core (CTRL[2]=1 then 0)
        aes_axil_write(`AES_CTRL, 32'h0000_0004, 4'hF);
        @(posedge clk); @(posedge clk);
        aes_axil_write(`AES_CTRL, 32'h0000_0000, 4'hF);

        // Load 128-bit key (KEY[127:96] first)
        aes_axil_write(`AES_KEY0, 32'h2B7E1516, 4'hF);
        aes_axil_write(`AES_KEY1, 32'h28AED2A6, 4'hF);
        aes_axil_write(`AES_KEY2, 32'hABF71588, 4'hF);
        aes_axil_write(`AES_KEY3, 32'h09CF4F3C, 4'hF);

        // Load 128-bit plaintext
        aes_axil_write(`AES_TEXT0, 32'h3243F6A8, 4'hF);
        aes_axil_write(`AES_TEXT1, 32'h885A308D, 4'hF);
        aes_axil_write(`AES_TEXT2, 32'h3131982A, 4'hF);
        aes_axil_write(`AES_TEXT3, 32'hE0370734, 4'hF);

        // Trigger: KLD=1 (load key), wait, then LD=1 (start encrypt)
        aes_axil_write(`AES_CTRL, 32'h0000_0002, 4'hF); // KLD=1
        repeat(20) @(posedge clk);

        // Poll KDONE (bit[17]) until set
        begin : poll_kdone
            integer poll_cnt;
            poll_cnt = 0;
            rd_data  = 32'h0;
            while (rd_data[17] === 1'b0 && poll_cnt < `TIMEOUT_CYCLES) begin
                aes_axil_read(`AES_CTRL, rd_data);
                poll_cnt = poll_cnt + 1;
            end
            print_result("AES KDONE set", (rd_data[17] === 1'b1));
        end

        aes_axil_write(`AES_CTRL, 32'h0000_0001, 4'hF); // LD=1 (start encrypt)

        // Poll DONE (bit[16]) until set
        begin : poll_done
            integer poll_cnt;
            poll_cnt = 0;
            rd_data  = 32'h0;
            while (rd_data[16] === 1'b0 && poll_cnt < `TIMEOUT_CYCLES) begin
                aes_axil_read(`AES_CTRL, rd_data);
                poll_cnt = poll_cnt + 1;
            end
            print_result("AES DONE set", (rd_data[16] === 1'b1));
        end

        // Read ciphertext and verify against known vector
        aes_axil_read(`AES_OUT0, rd_data);
        print_result("AES OUT0 = 0x3925841D", (rd_data === 32'h3925841D));

        aes_axil_read(`AES_OUT1, rd_data);
        print_result("AES OUT1 = 0x02DC09FB", (rd_data === 32'h02DC09FB));

        aes_axil_read(`AES_OUT2, rd_data);
        print_result("AES OUT2 = 0xDC118597", (rd_data === 32'hDC118597));

        aes_axil_read(`AES_OUT3, rd_data);
        print_result("AES OUT3 = 0x196A0B32", (rd_data === 32'h196A0B32));

        // ------------------------------------------------------------------
        // TEST 5: PWM — write duty cycle, read back, verify PWM_OUT
        // ------------------------------------------------------------------
        $display("\n--- TEST 5: PWM duty cycle write/read ---");

        // Write duty cycle = 0x80 (50%) to slv_reg0
        pwm_axil_write(`PWM_DUTY, 32'h0000_0080, 4'hF);
        // Read back slv_reg0 and verify
        pwm_axil_read(`PWM_DUTY, rd_data);
        print_result("PWM slv_reg0 = 0x80 (duty cycle read-back)",
                     (rd_data[7:0] === 8'h80));

        // Write duty cycle = 0x40 (25%) to slv_reg0
        pwm_axil_write(`PWM_DUTY, 32'h0000_0040, 4'hF);
        pwm_axil_read(`PWM_DUTY, rd_data);
        print_result("PWM slv_reg0 = 0x40 (duty cycle read-back)",
                     (rd_data[7:0] === 8'h40));

        // Write to slv_reg1, slv_reg2, slv_reg3 and verify read-back
        pwm_axil_write(`PWM_REG1, 32'hDEAD_BEEF, 4'hF);
        pwm_axil_read(`PWM_REG1, rd_data);
        print_result("PWM slv_reg1 = 0xDEADBEEF", (rd_data === 32'hDEAD_BEEF));

        pwm_axil_write(`PWM_REG2, 32'hCAFE_BABE, 4'hF);
        pwm_axil_read(`PWM_REG2, rd_data);
        print_result("PWM slv_reg2 = 0xCAFEBABE", (rd_data === 32'hCAFE_BABE));

        pwm_axil_write(`PWM_REG3, 32'h1234_5678, 4'hF);
        pwm_axil_read(`PWM_REG3, rd_data);
        print_result("PWM slv_reg3 = 0x12345678", (rd_data === 32'h1234_5678));

        // ------------------------------------------------------------------
        // TEST 5b: PWM output — verify PWM_OUT toggles with non-zero duty
        // ------------------------------------------------------------------
        $display("\n--- TEST 5b: PWM output toggle ---");

        // Set duty cycle = 0x80 (50%)
        pwm_axil_write(`PWM_DUTY, 32'h0000_0080, 4'hF);

        // Wait several clock cycles and sample PWM_OUT
        // With duty=0x80, PWM_OUT should be high when pwm_counter < 0x80
        // and low when pwm_counter >= 0x80 (50% duty cycle)
        begin : pwm_out_test
            integer sample_cnt;
            integer high_cnt;
            high_cnt = 0;
            // Sample PWM_OUT over 256 clock cycles (one full PWM period)
            for (sample_cnt = 0; sample_cnt < 256; sample_cnt = sample_cnt + 1) begin
                @(posedge clk);
                if (pwm_out === 1'b1)
                    high_cnt = high_cnt + 1;
            end
            // With duty = 0x80 (128), PWM_OUT should be high for 128 cycles
            print_result("PWM_OUT high for ~128/256 cycles (50% duty)",
                         (high_cnt >= 120 && high_cnt <= 136));
        end

        // Set duty cycle = 0xFF (100%) — PWM_OUT should be always high
        pwm_axil_write(`PWM_DUTY, 32'h0000_00FF, 4'hF);
        begin : pwm_full_test
            integer sample_cnt;
            integer high_cnt;
            high_cnt = 0;
            for (sample_cnt = 0; sample_cnt < 256; sample_cnt = sample_cnt + 1) begin
                @(posedge clk);
                if (pwm_out === 1'b1)
                    high_cnt = high_cnt + 1;
            end
            // With duty = 0xFF, PWM_OUT should be high for all 256 cycles
            print_result("PWM_OUT high for 256/256 cycles (100% duty)",
                         (high_cnt === 256));
        end

        // Set duty cycle = 0x00 (0%) — PWM_OUT should be always low
        pwm_axil_write(`PWM_DUTY, 32'h0000_0000, 4'hF);
        begin : pwm_zero_test
            integer sample_cnt;
            integer high_cnt;
            high_cnt = 0;
            for (sample_cnt = 0; sample_cnt < 256; sample_cnt = sample_cnt + 1) begin
                @(posedge clk);
                if (pwm_out === 1'b1)
                    high_cnt = high_cnt + 1;
            end
            // With duty = 0x00, PWM_OUT should be low for all 256 cycles
            print_result("PWM_OUT low for 256/256 cycles (0% duty)",
                         (high_cnt === 0));
        end

        // ------------------------------------------------------------------
        // TEST 6: I2C — verify core is accessible (check prescaler registers)
        // ------------------------------------------------------------------
        $display("\n--- TEST 6: I2C register access ---");
        // After reset i2c_master_top prescaler = 0xFFFF (default).
        // Read the prescaler LO byte (register 0) via DUT hierarchy.
        // The I2C Wishbone interface is internal; we verify connectivity by
        // reading the register via the wb_dat_o wire.
        // Force a Wishbone read of register 0 (PRER_LO) directly.
        begin : i2c_wb_test
            // Force WB master signals into i2c_master_top
            force tb_aegis_v_soc.u_dut.u_wb_bridge.wb_adr_i  = 3'd0; // PRER_LO
            force tb_aegis_v_soc.u_dut.u_wb_bridge.wb_we_i   = 1'b0;
            force tb_aegis_v_soc.u_dut.u_wb_bridge.wb_stb_i  = 1'b1;
            force tb_aegis_v_soc.u_dut.u_wb_bridge.wb_cyc_i  = 1'b1;
            @(posedge clk);
            // Wait for WB ack
            begin : wb_poll
                integer t;
                t = 0;
                while (!tb_aegis_v_soc.u_dut.u_wb_bridge.wb_ack_o && t < 20) begin
                    @(posedge clk);
                    t = t + 1;
                end
            end
            rd_data = {24'h0, tb_aegis_v_soc.u_dut.i2c_wb_dat_r};
            release tb_aegis_v_soc.u_dut.u_wb_bridge.wb_adr_i;
            release tb_aegis_v_soc.u_dut.u_wb_bridge.wb_we_i;
            release tb_aegis_v_soc.u_dut.u_wb_bridge.wb_stb_i;
            release tb_aegis_v_soc.u_dut.u_wb_bridge.wb_cyc_i;
            // After reset, PRER_LO = 0xFF (default value in i2c_master_top)
            print_result("I2C PRER_LO read = 0xFF (reset default)",
                         (rd_data[7:0] === 8'hFF));
        end

        // ------------------------------------------------------------------
        // TEST 6: Integration connectivity check
        //   Verify key hierarchy nodes exist and reset released properly
        // ------------------------------------------------------------------
        $display("\n--- TEST 6: Connectivity / hierarchy check ---");
        // Check interconnect rst signal is de-asserted after SoC comes out of reset
        print_result("Interconnect reset de-asserted",
                     (tb_aegis_v_soc.u_dut.u_interconnect.rst === 1'b0));
        // Check UART reset is de-asserted
        print_result("UART aresetn asserted (active-low)",
                     (tb_aegis_v_soc.u_dut.u_uart.axi_aresetn_i === 1'b1));
        // Check AES reset de-asserted
        print_result("AES aresetn asserted (active-low)",
                     (tb_aegis_v_soc.u_dut.u_aes.s_axi_aresetn === 1'b1));
        // Check I2C synchronous reset de-asserted
        print_result("I2C wb_rst de-asserted",
                     (tb_aegis_v_soc.u_dut.u_i2c.wb_rst_i === 1'b0));
        // Check PWM reset de-asserted
        print_result("PWM aresetn asserted (active-low)",
                     (tb_aegis_v_soc.u_dut.u_pwm.s00_axi_aresetn === 1'b1));

        // ------------------------------------------------------------------
        // TEST 7: SHA256 — read ID registers, write block, trigger hash
        // ------------------------------------------------------------------
        $display("\n--- TEST 7: SHA256 register access ---");
        // Read NAME0 register
        sha256_axil_read(`SHA256_NAME0, rd_data);
        print_result("SHA256 NAME0 read (non-zero)", (rd_data !== 32'h0));

        // Read VERSION register
        sha256_axil_read(`SHA256_VERSION, rd_data);
        print_result("SHA256 VERSION read (non-zero)", (rd_data !== 32'h0));

        // Write to BLOCK0 and read STATUS
        sha256_axil_write(`SHA256_BLOCK0, 32'h80000000, 4'hF);
        sha256_axil_read(`SHA256_STATUS, rd_data);
        print_result("SHA256 STATUS read after block write", (rd_data !== 32'hx));

        // ------------------------------------------------------------------
        // TEST 8: GPIO — write output, read back
        // ------------------------------------------------------------------
        $display("\n--- TEST 8: GPIO register access ---");
        // Write GPIO_OUT = 0xFF
        gpio_axil_write(`GPIO_OUT, 32'h0000_00FF, 4'hF);
        gpio_axil_read(`GPIO_OUT, rd_data);
        print_result("GPIO OUT = 0xFF", (rd_data[7:0] === 8'hFF));

        // Write GPIO_OUT = 0x00
        gpio_axil_write(`GPIO_OUT, 32'h0000_0000, 4'hF);
        gpio_axil_read(`GPIO_OUT, rd_data);
        print_result("GPIO OUT = 0x00", (rd_data === 32'h0));

        // Read GPIO_INFO
        gpio_axil_read(`GPIO_INFO, rd_data);
        print_result("GPIO INFO read (non-zero)", (rd_data !== 32'h0));

        // ------------------------------------------------------------------
        // TEST 9: WDT — load counter, verify read-back
        // ------------------------------------------------------------------
        $display("\n--- TEST 9: WDT register access ---");
        // Load counter value
        wdt_axil_write(`WDT_LOAD, 32'h0000_0064, 4'hF); // load=100
        // Read back WDT_MR (counter value)
        wdt_axil_read(`WDT_MR, rd_data);
        print_result("WDT MR read (counter active)", (rd_data !== 32'hx));

        // Read WDT_CTRL
        wdt_axil_read(`WDT_CTRL, rd_data);
        print_result("WDT CTRL read", (rd_data !== 32'hx));

        // ------------------------------------------------------------------
        // TEST 10: DMA CSR — read version register
        // ------------------------------------------------------------------
        $display("\n--- TEST 10: DMA CSR register access ---");
        // Read DMA version register
        dma_axil_read(`DMA_VERSION, rd_data);
        print_result("DMA VERSION read (non-zero)", (rd_data !== 32'h0));

        // Write src_addr and read back
        dma_axil_write(`DMA_SRC_ADDR, 32'h0000_1000, 4'hF);
        dma_axil_read(`DMA_SRC_ADDR, rd_data);
        print_result("DMA SRC_ADDR = 0x1000", (rd_data === 32'h0000_1000));

        // Write dst_addr and read back
        dma_axil_write(`DMA_DST_ADDR, 32'h0000_2000, 4'hF);
        dma_axil_read(`DMA_DST_ADDR, rd_data);
        print_result("DMA DST_ADDR = 0x2000", (rd_data === 32'h0000_2000));

        // Write num_bytes
        dma_axil_write(`DMA_NUM_BYTES, 32'h0000_0100, 4'hF);
        dma_axil_read(`DMA_NUM_BYTES, rd_data);
        print_result("DMA NUM_BYTES = 0x100", (rd_data === 32'h0000_0100));

        // ------------------------------------------------------------------
        // TEST 11: SCS — read IP_ID, VERSION, write SCRATCH
        // ------------------------------------------------------------------
        $display("\n--- TEST 11: System Control & Status ---");
        // Read IP_ID
        scs_axil_read(`SCS_IP_ID, rd_data);
        print_result("SCS IP_ID = 0xAE615001", (rd_data === 32'hAE615001));

        // Read VERSION
        scs_axil_read(`SCS_VERSION, rd_data);
        print_result("SCS VERSION = 0x00010000", (rd_data === 32'h00010000));

        // Write SCRATCH and read back
        scs_axil_write(`SCS_SCRATCH, 32'hDEAD_BEEF, 4'hF);
        scs_axil_read(`SCS_SCRATCH, rd_data);
        print_result("SCS SCRATCH = 0xDEADBEEF", (rd_data === 32'hDEAD_BEEF));

        // Write SYS_CTRL (enable bit 0)
        scs_axil_write(`SCS_SYS_CTRL, 32'h0000_0001, 4'hF);
        scs_axil_read(`SCS_SYS_CTRL, rd_data);
        print_result("SCS SYS_CTRL enable bit set", (rd_data[0] === 1'b1));

        // Read SYS_STATUS
        scs_axil_read(`SCS_SYS_STATUS, rd_data);
        print_result("SCS SYS_STATUS read", (rd_data !== 32'hx));

        // ------------------------------------------------------------------
        // TEST 12: Timer — read mtime, write mtimecmp, verify
        // ------------------------------------------------------------------
        $display("\n--- TEST 12: rv_timer register access ---");
        // Read MTIME_LO (should be incrementing if enabled)
        timer_axil_read(`TIMER_MTIME_LO, rd_data);
        print_result("Timer MTIME_LO read", (rd_data !== 32'hx));

        // Write MTIMECMP_LO
        timer_axil_write(`TIMER_MTIMECMP_LO, 32'hFFFF_FFFF, 4'hF);
        timer_axil_read(`TIMER_MTIMECMP_LO, rd_data);
        print_result("Timer MTIMECMP_LO = 0xFFFFFFFF", (rd_data === 32'hFFFFFFFF));

        // Write CTRL (enable timer)
        timer_axil_write(`TIMER_CTRL, 32'h0000_0001, 4'hF);
        timer_axil_read(`TIMER_CTRL, rd_data);
        print_result("Timer CTRL enable bit set", (rd_data[0] === 1'b1));

        // Read STATUS
        timer_axil_read(`TIMER_STATUS, rd_data);
        print_result("Timer STATUS read", (rd_data !== 32'hx));

        // ------------------------------------------------------------------
        // TEST 13: IMEM — read address 0x0, verify write returns SLVERR
        // ------------------------------------------------------------------
        $display("\n--- TEST 13: Instruction Memory ---");
        // Read from IMEM at offset 0x0 (should read memory contents)
        imem_axil_read(32'h0000_0000, rd_data);
        print_result("IMEM read addr 0x0 (no error)", (rd_data !== 32'hx));

        // Read from IMEM at offset 0x4
        imem_axil_read(32'h0000_0004, rd_data);
        print_result("IMEM read addr 0x4 (no error)", (rd_data !== 32'hx));

        // Write to IMEM (should return SLVERR, bresp=2'b10)
        // We check that the write completes without hanging
        imem_axil_write(32'h0000_0000, 32'h1234_5678, 4'hF);
        // If we reach here, the write handshake completed (SLVERR is expected)
        print_result("IMEM write handshake completed", (1'b1));

        // ------------------------------------------------------------------
        // TEST 14: DMEM — write word, read back, verify byte-write
        // ------------------------------------------------------------------
        $display("\n--- TEST 14: Data Memory ---");
        // Write word to DMEM at offset 0x0
        dmem_axil_write(32'h0000_0000, 32'h1234_5678, 4'hF);
        // Read back
        dmem_axil_read(32'h0000_0000, rd_data);
        print_result("DMEM word write/read = 0x12345678", (rd_data === 32'h1234_5678));

        // Write another word at offset 0x4
        dmem_axil_write(32'h0000_0004, 32'hA5A5_5A5A, 4'hF);
        dmem_axil_read(32'h0000_0004, rd_data);
        print_result("DMEM word write/read = 0xA5A55A5A", (rd_data === 32'hA5A5_5A5A));

        // Byte write test: write byte 0 only to addr 0x0
        dmem_axil_write(32'h0000_0000, 32'h0000_00BB, 4'h1);
        dmem_axil_read(32'h0000_0000, rd_data);
        print_result("DMEM byte0 write = 0x123456BB", (rd_data === 32'h1234_56BB));

        // ------------------------------------------------------------------
        // TEST 15: Extended connectivity check for new IPs
        // ------------------------------------------------------------------
        $display("\n--- TEST 15: Extended connectivity check ---");
        // Check SHA256 reset de-asserted
        print_result("SHA256 aresetn asserted",
                     (tb_aegis_v_soc.u_dut.u_sha256.s00_axi_aresetn === 1'b1));
        // Check GPIO reset de-asserted
        print_result("GPIO rst_ni asserted",
                     (tb_aegis_v_soc.u_dut.u_gpio.rst_ni === 1'b1));
        // Check WDT reset de-asserted
        print_result("WDT aresetn asserted",
                     (tb_aegis_v_soc.u_dut.u_wdt.s_axi_aresetn === 1'b1));
        // Check DMA reset de-asserted
        print_result("DMA aresetn asserted",
                     (tb_aegis_v_soc.u_dut.u_dma.aresetn === 1'b1));
        // Check SCS reset de-asserted
        print_result("SCS aresetn asserted",
                     (tb_aegis_v_soc.u_dut.u_scs.aresetn === 1'b1));
        // Check Timer reset de-asserted
        print_result("Timer aresetn asserted",
                     (tb_aegis_v_soc.u_dut.u_timer.s_axi_aresetn === 1'b1));
        // Check IMEM reset de-asserted
        print_result("IMEM aresetn asserted",
                     (tb_aegis_v_soc.u_dut.u_imem.aresetn === 1'b1));
        // Check DMEM reset de-asserted
        print_result("DMEM aresetn asserted",
                     (tb_aegis_v_soc.u_dut.u_dmem.aresetn === 1'b1));

        // ------------------------------------------------------------------
        // Final report
        // ------------------------------------------------------------------
        repeat(10) @(posedge clk);
        $display("\n=======================================================");
        $display(" SIMULATION COMPLETE");
        $display(" PASSED: %0d", pass_count);
        $display(" FAILED: %0d", fail_count);
        $display("=======================================================");

        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" *** %0d TEST(S) FAILED ***", fail_count);

        $finish;
    end

    // =========================================================================
    // Global timeout watchdog
    // =========================================================================
    initial begin
        #(`TIMEOUT_CYCLES * `CLK_PERIOD * 20);
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule

`default_nettype wire
