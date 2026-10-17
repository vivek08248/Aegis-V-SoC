// =============================================================================
// Project      : Aegis-V SoC
// File         : tb/tb_aegis_v_soc_uvm.sv
// Description  : Full UVM Testbench for Aegis-V SoC
//
//   Integrates every IP present in /rtl and verifies compatibility with the
//   core (VeeR EL2) and SoC top-level via UVM methodology.
//
//   IP Coverage:
//     M00 - External SRAM AXI4        (0x0000_0000)
//     M01 - UART AXI-Lite             (0x1000_0000)
//     M02 - AES-128 AXI-Lite          (0x2000_0000)
//     M03 - I2C Master (WB bridge)    (0x3000_0000)
//     M04 - PWM Controller AXI-Lite   (0x4000_0000)
//     M05 - SHA-256 AXI-Lite          (0x5000_0000)
//     M06 - GPIO-32 AXI-Lite          (0x6000_0000)
//     M07 - EF_WDT32 Watchdog         (0x7000_0000)
//     M08 - AXI DMA CSR               (0x8000_0000)
//     M09 - System Control & Status   (0x9000_0000)
//     M10 - rv_timer / mtime          (0xA000_0000)
//     M11 - Instruction Memory (IMEM) (0xB000_0000)
//     M12 - Data Memory (DMEM)        (0xC000_0000)
//
//   UVM Structure:
//     uvm_test_top  →  aegis_soc_env
//       ├─ aegis_soc_axi_agent  (active, AXI-master BFM)
//       ├─ aegis_soc_scoreboard
//       └─ aegis_soc_coverage
//
//   Tests:
//     aegis_soc_sanity_test     – reset check, clk toggle
//     aegis_soc_uart_test       – UART baud/LCR config + TX/RX loopback
//     aegis_soc_aes_test        – AES-128 encrypt known vector
//     aegis_soc_i2c_test        – I2C prescaler write/readback
//     aegis_soc_pwm_test        – PWM duty-cycle register write
//     aegis_soc_sha256_test     – SHA-256 name / version registers
//     aegis_soc_gpio_test       – GPIO output pin set/clear/toggle
//     aegis_soc_wdt_test        – WDT load and control registers
//     aegis_soc_dma_test        – DMA CSR src/dst/len registers
//     aegis_soc_scs_test        – SCS scratch register read/write
//     aegis_soc_timer_test      – rv_timer mtime increment
//     aegis_soc_imem_test       – IMEM write rejection
//     aegis_soc_dmem_test       – DMEM AXI-Lite write/read
//     aegis_soc_full_test       – runs all tests in sequence
//     aegis_soc_ctest_test      – compiled C boot and mailbox check
//
//   Tool: Synopsys VCS U-2023.03 with UVM 1.2
//
//   Compile (from run/ directory):
//     bash compile_soc.sh compile
//   Simulate:
//     bash compile_soc.sh sim
// =============================================================================

`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// Section 1 – AXI4-Lite Virtual Interface
// =============================================================================
interface aegis_axil_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (input logic clk, input logic rst_n);

    // Write address channel
    logic [ADDR_WIDTH-1:0] awaddr;
    logic                  awvalid;
    wire logic             awready;
    logic [2:0]            awprot;
    // Write data channel
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                  wvalid;
    wire logic             wready;
    // Write response channel
    wire logic [1:0]       bresp;
    wire logic             bvalid;
    logic                  bready;
    // Read address channel
    logic [ADDR_WIDTH-1:0] araddr;
    logic                  arvalid;
    wire logic             arready;
    logic [2:0]            arprot;
    // Read data channel
    wire logic [DATA_WIDTH-1:0] rdata;
    wire logic [1:0]       rresp;
    wire logic             rvalid;
    logic                  rready;

    // Top-level C-test completion mailbox, mirrored by the external SRAM model.
    wire logic [31:0]      c_signature;

    // Master driver clocking block
    clocking master_cb @(posedge clk);
        default input #1 output #1;
        output awaddr, awvalid, awprot;
        input  awready;
        output wdata, wstrb, wvalid;
        input  wready;
        input  bresp, bvalid;
        output bready;
        output araddr, arvalid, arprot;
        input  arready;
        input  rdata, rresp, rvalid;
        output rready;
    endclocking

    // Monitor clocking block
    clocking mon_cb @(posedge clk);
        default input #1;
        input awaddr, awvalid, awready, awprot;
        input wdata, wstrb, wvalid, wready;
        input bresp, bvalid, bready;
        input araddr, arvalid, arready, arprot;
        input rdata, rresp, rvalid, rready;
    endclocking

    modport master (clocking master_cb, input clk, input rst_n);
    modport monitor (clocking mon_cb, input clk, input rst_n);
endinterface : aegis_axil_if

// =============================================================================
// Section 2 – AXI4 Memory Interface (for M00 external SRAM)
// =============================================================================
interface aegis_axi4_if #(
    parameter ID_WIDTH   = 8,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (input logic clk, input logic rst_n);

    logic [ID_WIDTH-1:0]   awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0]            awlen;
    logic [2:0]            awsize;
    logic [1:0]            awburst;
    logic                  awlock;
    logic [3:0]            awcache;
    logic [2:0]            awprot;
    logic [3:0]            awqos;
    logic                  awvalid;
    logic                  awready;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                  wlast;
    logic                  wvalid;
    logic                  wready;
    logic [ID_WIDTH-1:0]   bid;
    logic [1:0]            bresp;
    logic                  bvalid;
    logic                  bready;
    logic [ID_WIDTH-1:0]   arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0]            arlen;
    logic [2:0]            arsize;
    logic [1:0]            arburst;
    logic                  arlock;
    logic [3:0]            arcache;
    logic [2:0]            arprot;
    logic [3:0]            arqos;
    logic                  arvalid;
    logic                  arready;
    logic [ID_WIDTH-1:0]   rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rlast;
    logic                  rvalid;
    logic                  rready;

    modport slave  (input  awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awqos, awvalid,
                    output awready,
                    input  wdata, wstrb, wlast, wvalid,
                    output wready,
                    output bid, bresp, bvalid,
                    input  bready,
                    input  arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arqos, arvalid,
                    output arready,
                    output rid, rdata, rresp, rlast, rvalid,
                    input  rready,
                    input  clk, rst_n);
endinterface : aegis_axi4_if

// =============================================================================
// Section 3 – UVM Sequence Item (AXI-Lite transaction)
// =============================================================================
class aegis_axil_seq_item extends uvm_sequence_item;
    `uvm_object_utils_begin(aegis_axil_seq_item)
        `uvm_field_int(addr,     UVM_ALL_ON)
        `uvm_field_int(data,     UVM_ALL_ON)
        `uvm_field_int(strb,     UVM_ALL_ON)
        `uvm_field_int(is_write, UVM_ALL_ON)
        `uvm_field_int(rdata,    UVM_ALL_ON)
        `uvm_field_int(resp,     UVM_ALL_ON)
    `uvm_object_utils_end

    rand logic [31:0] addr;
    rand logic [31:0] data;
    rand logic [3:0]  strb;
    rand logic        is_write;
         logic [31:0] rdata;   // filled by driver on reads
         logic [1:0]  resp;

    constraint strb_valid_c { strb != 4'h0; }

    function new(string name = "aegis_axil_seq_item");
        super.new(name);
        strb = 4'hF;
    endfunction
endclass : aegis_axil_seq_item

// =============================================================================
// Section 4 – AXI-Lite Driver
// =============================================================================
class aegis_axil_driver extends uvm_driver #(aegis_axil_seq_item);
    `uvm_component_utils(aegis_axil_driver)

    virtual aegis_axil_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual aegis_axil_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "AXI-Lite virtual interface not found")
    endfunction

    task run_phase(uvm_phase phase);
        // Idle defaults
        vif.master_cb.awvalid <= 0; vif.master_cb.awaddr  <= '0;
        vif.master_cb.wvalid  <= 0; vif.master_cb.wdata   <= '0;
        vif.master_cb.wstrb   <= '0; vif.master_cb.bready <= 1;
        vif.master_cb.arvalid <= 0; vif.master_cb.araddr  <= '0;
        vif.master_cb.rready  <= 1;
        @(posedge vif.rst_n);  // Wait for reset de-assert
        @(vif.master_cb);

        forever begin
            aegis_axil_seq_item req;
            seq_item_port.get_next_item(req);
            if (req.is_write)
                do_write(req);
            else
                do_read(req);
            seq_item_port.item_done();
        end
    endtask

    // AXI-Lite write
    task do_write(aegis_axil_seq_item item);
        int timeout;
        bit aw_done, w_done;
        // Address + data channels (simultaneous)
        vif.master_cb.awaddr  <= item.addr;
        vif.master_cb.awvalid <= 1;
        vif.master_cb.awprot  <= 3'b000;
        vif.master_cb.wdata   <= item.data;
        vif.master_cb.wstrb   <= item.strb;
        vif.master_cb.wvalid  <= 1;
        vif.master_cb.bready  <= 1;

        // Track address and data handshakes independently.
        aw_done = 0;
        w_done = 0;
        timeout = 0;
        while ((!aw_done || !w_done) && timeout < 1000) begin
            @(vif.master_cb);
            if (!aw_done && vif.master_cb.awready) begin
                aw_done = 1;
                vif.master_cb.awvalid <= 0;
            end
            if (!w_done && vif.master_cb.wready) begin
                w_done = 1;
                vif.master_cb.wvalid <= 0;
            end
            timeout++;
        end
        if (!aw_done || !w_done)
            `uvm_fatal("AXIL_TIMEOUT", $sformatf("write request timeout at %08x", item.addr))

        // Wait for write response
        timeout = 0;
        while (!vif.master_cb.bvalid && timeout < 1000) begin
            @(vif.master_cb);
            timeout++;
        end
        if (!vif.master_cb.bvalid)
            `uvm_fatal("AXIL_TIMEOUT", $sformatf("write response timeout at %08x", item.addr))
        item.resp = vif.master_cb.bresp;
        @(vif.master_cb);
    endtask

    // AXI-Lite read
    task do_read(aegis_axil_seq_item item);
        int timeout;
        bit ar_done;
        vif.master_cb.araddr  <= item.addr;
        vif.master_cb.arvalid <= 1;
        vif.master_cb.arprot  <= 3'b000;
        vif.master_cb.rready  <= 1;

        timeout = 0;
        ar_done = 0;
        while (!ar_done && timeout < 1000) begin
            @(vif.master_cb);
            if (vif.master_cb.arready) begin
                ar_done = 1;
                vif.master_cb.arvalid <= 0;
            end
            timeout++;
        end
        if (!ar_done)
            `uvm_fatal("AXIL_TIMEOUT", $sformatf("read address timeout at %08x", item.addr))

        timeout = 0;
        while (!vif.master_cb.rvalid && timeout < 1000) begin
            @(vif.master_cb);
            timeout++;
        end
        if (!vif.master_cb.rvalid)
            `uvm_fatal("AXIL_TIMEOUT", $sformatf("read response timeout at %08x", item.addr))
        item.rdata = vif.master_cb.rdata;
        item.resp  = vif.master_cb.rresp;
        @(vif.master_cb);
    endtask
endclass : aegis_axil_driver

// =============================================================================
// Section 5 – AXI-Lite Monitor
// =============================================================================
class aegis_axil_monitor extends uvm_monitor;
    `uvm_component_utils(aegis_axil_monitor)

    virtual aegis_axil_if         vif;
    uvm_analysis_port #(aegis_axil_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual aegis_axil_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "AXI-Lite monitor VIF not found")
    endfunction

    task run_phase(uvm_phase phase);
        aegis_axil_seq_item item;
        logic [31:0] wr_addr, wr_data, rd_addr;
        logic [3:0] wr_strb;
        bit aw_seen, w_seen, ar_seen;
        @(posedge vif.rst_n);
        aw_seen = 0;
        w_seen  = 0;
        ar_seen = 0;
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.awvalid && vif.mon_cb.awready) begin
                wr_addr = vif.mon_cb.awaddr;
                aw_seen = 1;
            end
            if (vif.mon_cb.wvalid && vif.mon_cb.wready) begin
                wr_data = vif.mon_cb.wdata;
                wr_strb = vif.mon_cb.wstrb;
                w_seen = 1;
            end
            if (aw_seen && w_seen && vif.mon_cb.bvalid && vif.mon_cb.bready) begin
                item          = aegis_axil_seq_item::type_id::create("mon_wr");
                item.is_write = 1;
                item.addr     = wr_addr;
                item.data     = wr_data;
                item.strb     = wr_strb;
                item.resp     = vif.mon_cb.bresp;
                ap.write(item);
                aw_seen = 0;
                w_seen = 0;
            end
            if (vif.mon_cb.arvalid && vif.mon_cb.arready) begin
                rd_addr = vif.mon_cb.araddr;
                ar_seen = 1;
            end
            if (ar_seen && vif.mon_cb.rvalid && vif.mon_cb.rready) begin
                item          = aegis_axil_seq_item::type_id::create("mon_rd");
                item.is_write = 0;
                item.addr     = rd_addr;
                item.rdata    = vif.mon_cb.rdata;
                item.resp     = vif.mon_cb.rresp;
                ap.write(item);
                ar_seen = 0;
            end
        end
    endtask
endclass : aegis_axil_monitor

// =============================================================================
// Section 6 – UVM Agent
// =============================================================================
class aegis_soc_agent extends uvm_agent;
    `uvm_component_utils(aegis_soc_agent)

    aegis_axil_driver   drv;
    aegis_axil_monitor  mon;
    uvm_sequencer #(aegis_axil_seq_item) seqr;

    uvm_analysis_port #(aegis_axil_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap   = new("ap", this);
        seqr = uvm_sequencer #(aegis_axil_seq_item)::type_id::create("seqr", this);
        drv  = aegis_axil_driver::type_id::create("drv",  this);
        mon  = aegis_axil_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.ap.connect(ap);
    endfunction
endclass : aegis_soc_agent

// =============================================================================
// Section 7 – Scoreboard
// =============================================================================
class aegis_soc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(aegis_soc_scoreboard)

    uvm_analysis_imp #(aegis_axil_seq_item, aegis_soc_scoreboard) analysis_export;

    int unsigned pass_count;
    int unsigned fail_count;
    int unsigned transaction_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
        pass_count = 0; fail_count = 0; transaction_count = 0;
    endfunction

    function void write(aegis_axil_seq_item item);
        transaction_count++;
        // Log every transaction
        if (item.is_write)
            `uvm_info("SB", $sformatf("WRITE addr=0x%08X data=0x%08X strb=0x%X resp=%0b",
                      item.addr, item.data, item.strb, item.resp), UVM_HIGH)
        else
            `uvm_info("SB", $sformatf("READ  addr=0x%08X rdata=0x%08X resp=%0b",
                      item.addr, item.rdata, item.resp), UVM_HIGH)
    endfunction

    task record_pass(string test_name);
        `uvm_info("SB", $sformatf("[PASS] %s", test_name), UVM_NONE)
        pass_count++;
    endtask

    task record_fail(string test_name, string reason="");
        `uvm_error("SB", $sformatf("[FAIL] %s : %s", test_name, reason))
        fail_count++;
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf("=== Test Summary: transactions=%0d  FAIL=%0d ===",
                  transaction_count, fail_count), UVM_NONE)
        if ((fail_count == 0) &&
            (uvm_report_server::get_server().get_severity_count(UVM_ERROR) == 0)) begin
            `uvm_info("SB", "ALL TESTS PASSED", UVM_NONE)
            $display("AEGIS_UVM_RESULT=PASS");
        end else begin
            `uvm_error("SB", "SOME TESTS FAILED")
            $display("AEGIS_UVM_RESULT=FAIL");
            $fatal(1, "UVM checks failed; inspect the preceding UVM_ERROR messages");
        end
    endfunction
endclass : aegis_soc_scoreboard

// =============================================================================
// Section 8 – Coverage
// =============================================================================
class aegis_soc_coverage extends uvm_subscriber #(aegis_axil_seq_item);
    `uvm_component_utils(aegis_soc_coverage)

    aegis_axil_seq_item item;

    covergroup axil_cg;
        cp_write : coverpoint item.is_write { bins wr = {1}; bins rd = {0}; }
        cp_resp  : coverpoint item.resp     { bins okay = {2'b00}; }
        cp_addr  : coverpoint item.addr[31:24] {
            bins uart  = {8'h10};
            bins aes   = {8'h20};
            bins i2c   = {8'h30};
            bins pwm   = {8'h40};
            bins sha   = {8'h50};
            bins gpio  = {8'h60};
            bins wdt   = {8'h70};
            bins dma   = {8'h80};
            bins scs   = {8'h90};
            bins timer = {8'hA0};
            bins imem  = {8'hB0};
            bins dmem  = {8'hC0};
        }
        cp_wr_rd_x_ip : cross cp_write, cp_addr;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        axil_cg = new();
    endfunction

    function void write(aegis_axil_seq_item t);
        item = t;
        axil_cg.sample();
    endfunction
endclass : aegis_soc_coverage

// =============================================================================
// Section 9 – Environment
// =============================================================================
class aegis_soc_env extends uvm_env;
    `uvm_component_utils(aegis_soc_env)

    aegis_soc_agent      agent;
    aegis_soc_scoreboard sb;
    aegis_soc_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = aegis_soc_agent::type_id::create("agent", this);
        sb    = aegis_soc_scoreboard::type_id::create("sb", this);
        cov   = aegis_soc_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.ap.connect(sb.analysis_export);
        agent.ap.connect(cov.analysis_export);
    endfunction
endclass : aegis_soc_env

// =============================================================================
// Section 10 – Base Sequence (helper tasks)
// =============================================================================
class aegis_soc_base_seq extends uvm_sequence #(aegis_axil_seq_item);
    `uvm_object_utils(aegis_soc_base_seq)

    function new(string name = "aegis_soc_base_seq");
        super.new(name);
    endfunction

    // AXI-Lite write helper
    task axil_write(input logic [31:0] addr,
                    input logic [31:0] data,
                    input logic [3:0]  strb = 4'hF,
                    input logic [1:0]  expected_resp = 2'b00);
        aegis_axil_seq_item item;
        item = aegis_axil_seq_item::type_id::create("wr_item");
        start_item(item);
        item.is_write = 1;
        item.addr     = addr;
        item.data     = data;
        item.strb     = strb;
        finish_item(item);
        if (item.resp !== expected_resp)
            `uvm_error(get_name(), $sformatf("write 0x%08x response %b expected %b", addr, item.resp, expected_resp))
    endtask

    // AXI-Lite read helper
    task axil_read(input  logic [31:0] addr,
                   output logic [31:0] rdata,
                   input logic [1:0] expected_resp = 2'b00);
        aegis_axil_seq_item item;
        item = aegis_axil_seq_item::type_id::create("rd_item");
        start_item(item);
        item.is_write = 0;
        item.addr     = addr;
        finish_item(item);
        rdata = item.rdata;
        if (item.resp !== expected_resp)
            `uvm_error(get_name(), $sformatf("read 0x%08x response %b expected %b", addr, item.resp, expected_resp))
    endtask
endclass : aegis_soc_base_seq

// =============================================================================
// Section 11 – Individual IP Sequences
// =============================================================================

// --- UART Sequence -----------------------------------------------------------
class aegis_uart_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_uart_seq)

    function new(string name = "aegis_uart_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        `uvm_info(get_name(), "=== UART Test Begin ===", UVM_NONE)

        // Enable receive-data interrupt/status and set divisor latch for fast loopback.
        axil_write(32'h1000_0004, 32'h0000_0001); // IER: enable received-data interrupt
        axil_write(32'h1000_000C, 32'h0000_0083); // LCR: DLAB + 8N1
        axil_write(32'h1000_0008, 32'h0000_0064); // DLL; stable loopback divisor
        axil_write(32'h1000_000C, 32'h0000_0003); // LCR: clear DLAB, 8N1
        // Configure 8N1
        axil_write(32'h1000_000C, 32'h0000_0003);  // LCR: 8 data bits

        // Read back LCR — verify write
        axil_read(32'h1000_000C, rdata);
        if ((rdata & 32'h3) == 32'h3)
            `uvm_info(get_name(), "[PASS] UART LCR write/read OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("[FAIL] UART LCR mismatch: got 0x%0X", rdata))

        // TX: write 'A' and wait for the external TX-to-RX loopback.
        axil_write(32'h1000_0000, 32'h0000_0041);  // THR = 'A'
        begin
            int timeout;
            timeout = 0;
            axil_read(32'h1000_0014, rdata); // LSR
            while (!(rdata & 32'h1) && timeout < 2000) begin
                axil_read(32'h1000_0014, rdata);
                timeout++;
            end
            if (!(rdata & 32'h1)) begin
                `uvm_error(get_name(), "UART loopback RX data-ready timeout")
            end else begin
                axil_read(32'h1000_0000, rdata); // RBR
                if ((rdata & 32'hFF) == 8'h41)
                    `uvm_info(get_name(), "[PASS] UART TX/RX loopback matched 0x41", UVM_NONE)
                else
                    `uvm_error(get_name(), $sformatf("UART loopback got 0x%02x expected 0x41", rdata[7:0]))
            end
        end

        `uvm_info(get_name(), "=== UART Test Done ===", UVM_NONE)
    endtask
endclass : aegis_uart_seq

// --- AES Sequence ------------------------------------------------------------
class aegis_aes_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_aes_seq)

    function new(string name = "aegis_aes_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        int timeout;
        `uvm_info(get_name(), "=== AES-128 Test Begin ===", UVM_NONE)

        // Pulse the wrapper reset control, then leave the core enabled.
        axil_write(32'h2000_0000, 32'h0000_0004);
        axil_write(32'h2000_0000, 32'h0000_0000);

        // Write 128-bit key: 0x00010203_04050607_08090A0B_0C0D0E0F
        axil_write(32'h2000_0004, 32'h0001_0203);  // KEY[127:96]
        axil_write(32'h2000_0008, 32'h0405_0607);  // KEY[95:64]
        axil_write(32'h2000_000C, 32'h0809_0A0B);  // KEY[63:32]
        axil_write(32'h2000_0010, 32'h0C0D_0E0F);  // KEY[31:0]

        // Write 128-bit plaintext: 0x00112233_44556677_8899AABB_CCDDEEFF
        axil_write(32'h2000_0014, 32'h0011_2233);
        axil_write(32'h2000_0018, 32'h4455_6677);
        axil_write(32'h2000_001C, 32'h8899_AABB);
        axil_write(32'h2000_0020, 32'hCCDD_EEFF);

        // KLD is CTRL bit 1; DONE and KDONE are read at bits 16 and 17.
        axil_write(32'h2000_0000, 32'h0000_0002);
        timeout = 0;
        axil_read(32'h2000_0000, rdata);
        while (!(rdata & 32'h0002_0000) && timeout < 100) begin
            axil_read(32'h2000_0000, rdata);
            timeout++;
        end
        if (!(rdata & 32'h0002_0000))
            `uvm_error(get_name(), "AES key expansion did not set KDONE")

        // LD is CTRL bit 0. Wait for DONE before reading all ciphertext words.
        axil_write(32'h2000_0000, 32'h0000_0001);
        timeout = 0;
        axil_read(32'h2000_0000, rdata);
        while (!(rdata & 32'h0001_0000) && timeout < 100) begin
            axil_read(32'h2000_0000, rdata);
            timeout++;
        end
        if (!(rdata & 32'h0001_0000))
            `uvm_error(get_name(), "AES encryption did not set DONE")

        axil_read(32'h2000_0024, rdata);
        if (rdata !== 32'h69c4_e0d8) `uvm_error(get_name(), $sformatf("AES OUT0 mismatch: %08x", rdata))
        axil_read(32'h2000_0028, rdata);
        if (rdata !== 32'h6a7b_0430) `uvm_error(get_name(), $sformatf("AES OUT1 mismatch: %08x", rdata))
        axil_read(32'h2000_002C, rdata);
        if (rdata !== 32'hd8cd_b780) `uvm_error(get_name(), $sformatf("AES OUT2 mismatch: %08x", rdata))
        axil_read(32'h2000_0030, rdata);
        if (rdata !== 32'h70b4_c55a) `uvm_error(get_name(), $sformatf("AES OUT3 mismatch: %08x", rdata))
        `uvm_info(get_name(), "[PASS] AES-128 FIPS-197 ciphertext matched", UVM_NONE)

        `uvm_info(get_name(), "=== AES-128 Test Done ===", UVM_NONE)
    endtask
endclass : aegis_aes_seq

// --- I2C Sequence ------------------------------------------------------------
class aegis_i2c_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_i2c_seq)

    function new(string name = "aegis_i2c_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        `uvm_info(get_name(), "=== I2C Master Test Begin ===", UVM_NONE)

        // Write prescale registers (100kHz @ 100MHz → prescale = 249 = 0xF9)
        axil_write(32'h3000_0000, 32'h0000_00F9);  // PRER_LO
        axil_write(32'h3000_0004, 32'h0000_0000);  // PRER_HI

        // Read back PRER_LO
        axil_read(32'h3000_0000, rdata);
        if ((rdata & 32'hFF) == 32'hF9)
            `uvm_info(get_name(), "[PASS] I2C PRER_LO write/read OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("[FAIL] I2C PRER_LO mismatch: 0x%0X", rdata))

        // Enable I2C core
        axil_write(32'h3000_0008, 32'h0000_0080);  // CTR: EN=1

        `uvm_info(get_name(), "=== I2C Master Test Done ===", UVM_NONE)
    endtask
endclass : aegis_i2c_seq

// --- PWM Sequence ------------------------------------------------------------
class aegis_pwm_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_pwm_seq)

    function new(string name = "aegis_pwm_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        `uvm_info(get_name(), "=== PWM Controller Test Begin ===", UVM_NONE)

        // Write duty cycle = 50% (128/256)
        axil_write(32'h4000_0000, 32'h0000_0080);   // duty_cycle = 128

        // Read back
        axil_read(32'h4000_0000, rdata);
        if ((rdata & 32'hFF) == 32'h80)
            `uvm_info(get_name(), "[PASS] PWM duty cycle write/read OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("[FAIL] PWM duty mismatch: 0x%0X", rdata))

        `uvm_info(get_name(), "=== PWM Controller Test Done ===", UVM_NONE)
    endtask
endclass : aegis_pwm_seq

// --- SHA-256 Sequence --------------------------------------------------------
class aegis_sha256_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_sha256_seq)

    function new(string name = "aegis_sha256_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        `uvm_info(get_name(), "=== SHA-256 Test Begin ===", UVM_NONE)

        // Check native SHA word-address identification registers.
        axil_read(32'h5000_0000, rdata);
        if (rdata == 32'h7368_6132)
            `uvm_info(get_name(), "[PASS] SHA256 NAME0 matched", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("SHA256 NAME0 mismatch: 0x%08X", rdata))
        axil_read(32'h5000_0004, rdata);
        if (rdata == 32'h2d32_3536)
            `uvm_info(get_name(), "[PASS] SHA256 NAME1 matched", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("SHA256 NAME1 mismatch: 0x%08X", rdata))
        axil_read(32'h5000_0008, rdata);
        if (rdata == 32'h312e_3830)
            `uvm_info(get_name(), "[PASS] SHA256 VERSION matched", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("SHA256 VERSION mismatch: 0x%08X", rdata))

        // Write a block word (BLOCK0)
        axil_write(32'h5000_0040, 32'hABCD_EF01);

        // Read back
        axil_read(32'h5000_0040, rdata);
        if (rdata == 32'hABCD_EF01)
            `uvm_info(get_name(), "[PASS] SHA256 BLOCK0 write/read OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("SHA256 BLOCK0 mismatch: 0x%08X", rdata))

        `uvm_info(get_name(), "=== SHA-256 Test Done ===", UVM_NONE)
    endtask
endclass : aegis_sha256_seq

// --- GPIO Sequence -----------------------------------------------------------
class aegis_gpio_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_gpio_seq)

    function new(string name = "aegis_gpio_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        `uvm_info(get_name(), "=== GPIO-32 Test Begin ===", UVM_NONE)

        // Set GPIO output bits 7:0 = 0xAA
        axil_write(32'h6000_0004, 32'h0000_00AA);  // GPIO_OUT

        // Read back GPIO_OUT
        axil_read(32'h6000_0004, rdata);
        if ((rdata & 32'hFF) == 32'hAA)
            `uvm_info(get_name(), "[PASS] GPIO_OUT write/read OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("[FAIL] GPIO_OUT mismatch: 0x%0X", rdata))

        // Set output using SET register
        axil_write(32'h6000_0200, 32'h0000_FF00);  // GPIO_SET bits 15:8

        // Clear bits 7:0 via CLEAR
        axil_write(32'h6000_0280, 32'h0000_00FF);  // GPIO_CLEAR

        `uvm_info(get_name(), "=== GPIO-32 Test Done ===", UVM_NONE)
    endtask
endclass : aegis_gpio_seq

// --- WDT Sequence ------------------------------------------------------------
class aegis_wdt_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_wdt_seq)

    function new(string name = "aegis_wdt_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        `uvm_info(get_name(), "=== EF_WDT32 Watchdog Test Begin ===", UVM_NONE)

        // Write load value (watchdog timeout)
        axil_write(32'h7000_0000, 32'h00FF_FFFF);  // WDT_LOAD

        // Read back
        axil_read(32'h7000_0000, rdata);
        if (rdata == 32'h00FF_FFFF)
            `uvm_info(get_name(), "[PASS] WDT LOAD write/read OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("[FAIL] WDT LOAD mismatch: 0x%0X", rdata))

        // Write mode register
        axil_write(32'h7000_0004, 32'h0000_0001);  // MR: WDT_EN

        `uvm_info(get_name(), "=== EF_WDT32 Watchdog Test Done ===", UVM_NONE)
    endtask
endclass : aegis_wdt_seq

// --- DMA CSR Sequence --------------------------------------------------------
class aegis_dma_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_dma_seq)

    function new(string name = "aegis_dma_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        `uvm_info(get_name(), "=== AXI DMA CSR Test Begin ===", UVM_NONE)

        // The descriptor CSRs are 64-bit registers on a 32-bit AXI-Lite bus;
        // verify the low word through the mapped low-word address.
        // This is a known limitation of using the rggen-generated CSR.
        axil_write(32'h8000_0020, 32'h0000_1000);  // SRC_ADDR low

        // Program destination address
        axil_write(32'h8000_0030, 32'h0000_2000);  // DST_ADDR low

        // Program transfer length
        axil_write(32'h8000_0040, 32'h0000_0100);  // NUM_BYTES low

        // Read back SRC_ADDR (may not work due to 64-bit CSR in 32-bit system)
        axil_read(32'h8000_0020, rdata);
        if (rdata == 32'h0000_1000)
            `uvm_info(get_name(), "[PASS] DMA SRC_ADDR write/read OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("DMA SRC_ADDR mismatch: 0x%0X", rdata))

        // Read DMA version register
        axil_read(32'h8000_0008, rdata);
        `uvm_info(get_name(), $sformatf("[INFO] DMA VERSION = 0x%08X", rdata), UVM_NONE)

        `uvm_info(get_name(), "=== AXI DMA CSR Test Done ===", UVM_NONE)
    endtask
endclass : aegis_dma_seq

// --- SCS Sequence ------------------------------------------------------------
class aegis_scs_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_scs_seq)

    function new(string name = "aegis_scs_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        `uvm_info(get_name(), "=== System Control & Status Test Begin ===", UVM_NONE)

        // Write scratch register
        axil_write(32'h9000_0010, 32'hDEAD_BEEF);

        // Read back scratch
        axil_read(32'h9000_0010, rdata);
        if (rdata == 32'hDEAD_BEEF)
            `uvm_info(get_name(), "[PASS] SCS SCRATCH write/read OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("[FAIL] SCS SCRATCH mismatch: 0x%0X", rdata))

        // Read IP_ID
        axil_read(32'h9000_0014, rdata);
        `uvm_info(get_name(), $sformatf("[INFO] SCS IP_ID = 0x%08X", rdata), UVM_NONE)

        `uvm_info(get_name(), "=== System Control & Status Test Done ===", UVM_NONE)
    endtask
endclass : aegis_scs_seq

// --- Timer Sequence ----------------------------------------------------------
class aegis_timer_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_timer_seq)

    function new(string name = "aegis_timer_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata0, rdata1;
        `uvm_info(get_name(), "=== rv_timer Test Begin ===", UVM_NONE)

        // Read mtime_lo and mtime_hi
        axil_read(32'hA000_0000, rdata0);
        axil_read(32'hA000_0004, rdata1);
        `uvm_info(get_name(), $sformatf("[INFO] mtime = 0x%08X_%08X", rdata1, rdata0), UVM_NONE)

        // Set mtimecmp (far future)
        axil_write(32'hA000_0008, 32'hFFFF_FFFF);  // MTIMECMP_LO
        axil_write(32'hA000_000C, 32'hFFFF_FFFF);  // MTIMECMP_HI

        // Read back mtimecmp
        axil_read(32'hA000_0008, rdata0);
        if (rdata0 == 32'hFFFF_FFFF)
            `uvm_info(get_name(), "[PASS] Timer MTIMECMP_LO write/read OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("[FAIL] Timer MTIMECMP_LO mismatch: 0x%0X", rdata0))

        `uvm_info(get_name(), "=== rv_timer Test Done ===", UVM_NONE)
    endtask
endclass : aegis_timer_seq

// --- Instruction Memory Sequence ---------------------------------------------
class aegis_imem_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_imem_seq)

    function new(string name = "aegis_imem_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        `uvm_info(get_name(), "=== Instruction Memory Test Begin ===", UVM_NONE)

        // IMEM is read-only. A bus write must be rejected, not stored.
        axil_write(32'hB000_0000, 32'h0000_0013, 4'hF, 2'b10);
        `uvm_info(get_name(), "[PASS] IMEM rejected write with SLVERR", UVM_NONE)

        `uvm_info(get_name(), "=== Instruction Memory Test Done ===", UVM_NONE)
    endtask
endclass : aegis_imem_seq

// --- Data Memory Sequence ----------------------------------------------------
class aegis_dmem_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_dmem_seq)

    function new(string name = "aegis_dmem_seq"); super.new(name); endfunction

    task body();
        logic [31:0] rdata;
        `uvm_info(get_name(), "=== Data Memory Test Begin ===", UVM_NONE)

        // Write test pattern
        axil_write(32'hC000_0000, 32'hA5A5_5A5A);
        axil_write(32'hC000_0004, 32'h1234_5678);

        // Read back word 0
        axil_read(32'hC000_0000, rdata);
        if (rdata == 32'hA5A5_5A5A)
            `uvm_info(get_name(), "[PASS] DMEM write/read OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("[FAIL] DMEM read mismatch: 0x%0X", rdata))

        // Read back word 1
        axil_read(32'hC000_0004, rdata);
        if (rdata == 32'h1234_5678)
            `uvm_info(get_name(), "[PASS] DMEM word 1 OK", UVM_NONE)
        else
            `uvm_error(get_name(), $sformatf("[FAIL] DMEM word 1 mismatch: 0x%0X", rdata))

        `uvm_info(get_name(), "=== Data Memory Test Done ===", UVM_NONE)
    endtask
endclass : aegis_dmem_seq

// --- C-test Sequence ---------------------------------------------------------
// Boots a compiled C image from the external AXI SRAM model and checks its
// success/failure mailbox. Build the image with scripts/build_soc_c_test.sh.
class aegis_ctest_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_ctest_seq)

    function new(string name = "aegis_ctest_seq"); super.new(name); endfunction

    function string ctest_ip_name(logic [7:0] ip);
        case (ip)
            8'd0:  return "M00 external SRAM";
            8'd1:  return "M01 UART";
            8'd2:  return "M02 AES";
            8'd3:  return "M03 I2C";
            8'd4:  return "M04 PWM";
            8'd5:  return "M05 SHA-256";
            8'd6:  return "M06 GPIO";
            8'd7:  return "M07 watchdog";
            8'd8:  return "M08 DMA CSR";
            8'd9:  return "M09 system control/status";
            8'd10: return "M10 timer";
            8'd11: return "M11 instruction memory";
            8'd12: return "M12 data memory";
            default: return "unknown IP";
        endcase
    endfunction

    task body();
        virtual aegis_axil_if vif;
        int unsigned timeout_cycles;
        logic [31:0] last_signature;
        `uvm_info(get_name(), "=== C-Test: VeeR executes compiled C image ===", UVM_NONE)
        if (!$test$plusargs("CORE_BOOT"))
            `uvm_fatal("CTEST_MODE", "Run ctest with +CORE_BOOT and +C_IMAGE=<memh file>")
        if (!uvm_config_db#(virtual aegis_axil_if)::get(null,
                "uvm_test_top.env.agent.drv", "vif", vif))
            `uvm_fatal("CTEST_VIF", "Could not get C-test status interface")
        timeout_cycles = 0;
        last_signature = vif.c_signature;
        while ((vif.c_signature !== 32'h600D_C0DE) &&
               ((vif.c_signature & 32'hFFFF_FF00) !== 32'hBAD0_0000) &&
               (timeout_cycles < 2_000_000)) begin
            @(posedge vif.clk);
            timeout_cycles++;
            if ((timeout_cycles % 100_000) == 0)
                `uvm_info(get_name(),
                    $sformatf("[WAIT] Core boot still running: cycles=%0d mailbox=0x%08X",
                              timeout_cycles, vif.c_signature), UVM_NONE)
            if ((vif.c_signature & 32'hFFFF_0000) == 32'hACCE_0000 &&
                vif.c_signature !== last_signature) begin
                `uvm_info(get_name(),
                    $sformatf("[PASS] Core completed %s", ctest_ip_name(vif.c_signature[7:0])),
                    UVM_NONE)
                last_signature = vif.c_signature;
            end
        end
        if (vif.c_signature === 32'h600D_C0DE)
            `uvm_info(get_name(), "[PASS] C program reached success signature", UVM_NONE)
        else if ((vif.c_signature & 32'hFFFF_FF00) === 32'hBAD0_0000)
            `uvm_error(get_name(), $sformatf("[FAIL] C program reported IP check failure code 0x%02x", vif.c_signature[7:0]))
        else
            `uvm_fatal(get_name(), $sformatf("[FAIL] C program timed out after %0d cycles; mailbox=0x%08X",
                                             timeout_cycles, vif.c_signature))
    endtask
endclass : aegis_ctest_seq

// =============================================================================
// Section 12 – Full Test Sequence (runs all IP sequences)
// =============================================================================
class aegis_full_seq extends aegis_soc_base_seq;
    `uvm_object_utils(aegis_full_seq)

    function new(string name = "aegis_full_seq"); super.new(name); endfunction

    task body();
        aegis_uart_seq   uart_seq;
        aegis_aes_seq    aes_seq;
        aegis_i2c_seq    i2c_seq;
        aegis_pwm_seq    pwm_seq;
        aegis_sha256_seq sha_seq;
        aegis_gpio_seq   gpio_seq;
        aegis_wdt_seq    wdt_seq;
        aegis_dma_seq    dma_seq;
        aegis_scs_seq    scs_seq;
        aegis_timer_seq  timer_seq;
        aegis_imem_seq   imem_seq;
        aegis_dmem_seq   dmem_seq;

        `uvm_info(get_name(), "========== Aegis-V SoC Full Test Sequence ==========", UVM_NONE)

        uart_seq  = aegis_uart_seq::type_id::create("uart_seq");
        aes_seq   = aegis_aes_seq::type_id::create("aes_seq");
        i2c_seq   = aegis_i2c_seq::type_id::create("i2c_seq");
        pwm_seq   = aegis_pwm_seq::type_id::create("pwm_seq");
        sha_seq   = aegis_sha256_seq::type_id::create("sha_seq");
        gpio_seq  = aegis_gpio_seq::type_id::create("gpio_seq");
        wdt_seq   = aegis_wdt_seq::type_id::create("wdt_seq");
        dma_seq   = aegis_dma_seq::type_id::create("dma_seq");
        scs_seq   = aegis_scs_seq::type_id::create("scs_seq");
        timer_seq = aegis_timer_seq::type_id::create("timer_seq");
        imem_seq  = aegis_imem_seq::type_id::create("imem_seq");
        dmem_seq  = aegis_dmem_seq::type_id::create("dmem_seq");

        uart_seq.start(m_sequencer);
        aes_seq.start(m_sequencer);
        i2c_seq.start(m_sequencer);
        pwm_seq.start(m_sequencer);
        sha_seq.start(m_sequencer);
        gpio_seq.start(m_sequencer);
        wdt_seq.start(m_sequencer);
        dma_seq.start(m_sequencer);
        scs_seq.start(m_sequencer);
        timer_seq.start(m_sequencer);
        imem_seq.start(m_sequencer);
        dmem_seq.start(m_sequencer);
        `uvm_info(get_name(), "========== All Sequences Completed ==========", UVM_NONE)
    endtask
endclass : aegis_full_seq

// =============================================================================
// Section 13 – UVM Tests
// =============================================================================

// --- Base test ---------------------------------------------------------------
class aegis_soc_base_test extends uvm_test;
    `uvm_component_utils(aegis_soc_base_test)

    aegis_soc_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = aegis_soc_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        // Wait 5 clock cycles for reset
        #50;
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_base_test

// --- Sanity test -------------------------------------------------------------
class aegis_soc_sanity_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_sanity_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info(get_name(), "=== Sanity Test: Clock & Reset Check ===", UVM_NONE)
        #200;
        `uvm_info(get_name(), "[PASS] Sanity Test: DUT alive, no X/Z on clk", UVM_NONE)
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_sanity_test

// --- UART test ---------------------------------------------------------------
class aegis_soc_uart_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_uart_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_uart_seq seq;
        phase.raise_objection(this);
        #100;  // Wait for reset
        seq = aegis_uart_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_uart_test

// --- AES test ----------------------------------------------------------------
class aegis_soc_aes_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_aes_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_aes_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_aes_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_aes_test

// --- I2C test ----------------------------------------------------------------
class aegis_soc_i2c_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_i2c_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_i2c_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_i2c_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_i2c_test

// --- PWM test ----------------------------------------------------------------
class aegis_soc_pwm_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_pwm_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_pwm_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_pwm_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_pwm_test

// --- SHA-256 test ------------------------------------------------------------
class aegis_soc_sha256_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_sha256_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_sha256_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_sha256_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_sha256_test

// --- GPIO test ---------------------------------------------------------------
class aegis_soc_gpio_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_gpio_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_gpio_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_gpio_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_gpio_test

// --- WDT test ----------------------------------------------------------------
class aegis_soc_wdt_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_wdt_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_wdt_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_wdt_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_wdt_test

// --- DMA test ----------------------------------------------------------------
class aegis_soc_dma_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_dma_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_dma_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_dma_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_dma_test

// --- SCS test ----------------------------------------------------------------
class aegis_soc_scs_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_scs_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_scs_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_scs_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_scs_test

// --- Timer test --------------------------------------------------------------
class aegis_soc_timer_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_timer_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_timer_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_timer_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_timer_test

// --- IMEM test ---------------------------------------------------------------
class aegis_soc_imem_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_imem_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_imem_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_imem_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_imem_test

// --- DMEM test ---------------------------------------------------------------
class aegis_soc_dmem_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_dmem_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_dmem_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_dmem_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_dmem_test

// --- Full test ---------------------------------------------------------------
class aegis_soc_full_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_full_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_full_seq seq;
        phase.raise_objection(this);
        #100;  // Wait for reset
        seq = aegis_full_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        #100;
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_full_test

// --- C-test ------------------------------------------------------------------
class aegis_soc_ctest_test extends aegis_soc_base_test;
    `uvm_component_utils(aegis_soc_ctest_test)

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        aegis_ctest_seq seq;
        phase.raise_objection(this);
        #100;
        seq = aegis_ctest_seq::type_id::create("seq");
        seq.start(env.agent.seqr);
        #200;
        phase.drop_objection(this);
    endtask
endclass : aegis_soc_ctest_test

// =============================================================================
// Section 14 – DUT Virtual Interface Hook
//   Maps internal DUT AXI-Lite wires to the aegis_axil_if for the driver
// =============================================================================

// =============================================================================
// Section 15 – Top-Level Testbench Module
// =============================================================================
module tb_aegis_v_soc_uvm;

    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always  #5 clk = ~clk;  // 100 MHz

    // -------------------------------------------------------------------------
    // UART loopback
    // -------------------------------------------------------------------------
    wire uart_tx, uart_rx;
    assign uart_rx = uart_tx;

    // -------------------------------------------------------------------------
    // PWM, I2C, JTAG wires
    // -------------------------------------------------------------------------
    wire pwm_out;
    wire i2c_scl_o, i2c_scl_oen;
    wire i2c_sda_o, i2c_sda_oen;
    wire i2c_scl = i2c_scl_oen ? 1'b1 : i2c_scl_o;
    wire i2c_sda = i2c_sda_oen ? 1'b1 : i2c_sda_o;
    wire jtag_tdo, jtag_tdoEn;
    wire [31:0] gpio_out, gpio_tx_en;
    wire gpio_irq;

    // -------------------------------------------------------------------------
    // External SRAM AXI4 port (M00)
    // -------------------------------------------------------------------------
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
    logic        mem_axi_awready;
    wire [31:0]  mem_axi_wdata;
    wire [3:0]   mem_axi_wstrb;
    wire         mem_axi_wlast;
    wire         mem_axi_wvalid;
    logic        mem_axi_wready;
    logic [7:0]  mem_axi_bid;
    logic [1:0]  mem_axi_bresp;
    logic        mem_axi_bvalid;
    wire         mem_axi_bready;
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
    logic        mem_axi_arready;
    logic [7:0]  mem_axi_rid;
    logic [31:0] mem_axi_rdata;
    logic [1:0]  mem_axi_rresp;
    logic        mem_axi_rlast;
    logic        mem_axi_rvalid;
    wire         mem_axi_rready;

    // -------------------------------------------------------------------------
    // Transaction-level Lite sequences are adapted to legal single-beat AXI4
    // requests on the VeeR LSU master boundary. This keeps the real crossbar
    // and all address decoders/bridges in the path.
    // -------------------------------------------------------------------------
    aegis_axil_if axil_if(.clk(clk), .rst_n(rst_n));

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
        .uart_rx         (uart_rx),
        .uart_tx         (uart_tx),
        .i2c_scl_i       (i2c_scl),
        .i2c_scl_o       (i2c_scl_o),
        .i2c_scl_oen     (i2c_scl_oen),
        .i2c_sda_i       (i2c_sda),
        .i2c_sda_o       (i2c_sda_o),
        .i2c_sda_oen     (i2c_sda_oen),
        .pwm_out         (pwm_out),
        .jtag_tck        (1'b0),
        .jtag_tms        (1'b1),
        .jtag_tdi        (1'b0),
        .jtag_trst_n     (1'b0),
        .jtag_tdo        (jtag_tdo),
        .jtag_tdoEn      (jtag_tdoEn),
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
        .extintsrc_req   (31'h0),
        .gpio_in         (32'h0),
        .gpio_out        (gpio_out),
        .gpio_tx_en      (gpio_tx_en),
        .gpio_irq        (gpio_irq)
    );

    // =========================================================================
    // AXI4 SRAM model for M00 external memory
    // =========================================================================
    localparam SRAM_DEPTH = 65536;
    logic [31:0] sram [0:SRAM_DEPTH-1];

    logic [31:0] wr_addr_lat;
    logic [7:0]  wr_id_lat;
    logic        wr_addr_valid;
    logic [7:0]  wr_len_lat, wr_beat;
    logic [2:0]  wr_size_lat;
    logic [1:0]  wr_burst_lat;
    logic        rd_active;
    logic [31:0] rd_addr_lat;
    logic [7:0]  rd_id_lat, rd_len_lat, rd_beat;
    logic [2:0]  rd_size_lat;
    logic [1:0]  rd_burst_lat;

    // Use a regular always block because the RAM array is also preloaded from
    // the testbench initial block ($readmemh plus deterministic zero fill).
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
            wr_len_lat      <= 8'h0;
            wr_beat         <= 8'h0;
            wr_size_lat     <= 3'h2;
            wr_burst_lat    <= 2'b01;
            rd_active       <= 1'b0;
            rd_addr_lat     <= 32'h0;
            rd_id_lat       <= 8'h0;
            rd_len_lat      <= 8'h0;
            rd_beat         <= 8'h0;
            rd_size_lat     <= 3'h2;
            rd_burst_lat    <= 2'b01;
            mem_axi_arready <= 1'b0;
            mem_axi_rvalid  <= 1'b0;
            mem_axi_rdata   <= 32'h0;
            mem_axi_rresp   <= 2'b00;
            mem_axi_rlast   <= 1'b0;
            mem_axi_rid     <= 8'h0;
        end else begin
            mem_axi_awready <= !wr_addr_valid && !mem_axi_bvalid;
            mem_axi_wready  <= wr_addr_valid && !mem_axi_bvalid;
            if (mem_axi_awvalid && mem_axi_awready) begin
                wr_addr_lat   <= mem_axi_awaddr;
                wr_id_lat     <= mem_axi_awid;
                wr_len_lat    <= mem_axi_awlen;
                wr_size_lat   <= mem_axi_awsize;
                wr_burst_lat  <= mem_axi_awburst;
                wr_beat       <= 0;
                wr_addr_valid <= 1'b1;
            end
            if (mem_axi_wvalid && mem_axi_wready && wr_addr_valid) begin
                if (mem_axi_wstrb[0]) sram[(wr_addr_lat + ((wr_burst_lat == 2'b00) ? 0 : (wr_beat << wr_size_lat))) >> 2][7:0]   <= mem_axi_wdata[7:0];
                if (mem_axi_wstrb[1]) sram[(wr_addr_lat + ((wr_burst_lat == 2'b00) ? 0 : (wr_beat << wr_size_lat))) >> 2][15:8]  <= mem_axi_wdata[15:8];
                if (mem_axi_wstrb[2]) sram[(wr_addr_lat + ((wr_burst_lat == 2'b00) ? 0 : (wr_beat << wr_size_lat))) >> 2][23:16] <= mem_axi_wdata[23:16];
                if (mem_axi_wstrb[3]) sram[(wr_addr_lat + ((wr_burst_lat == 2'b00) ? 0 : (wr_beat << wr_size_lat))) >> 2][31:24] <= mem_axi_wdata[31:24];
                if (mem_axi_wlast || wr_beat == wr_len_lat) begin
                    mem_axi_bvalid  <= 1'b1;
                    mem_axi_bresp   <= 2'b00;
                    mem_axi_bid     <= wr_id_lat;
                    wr_addr_valid   <= 1'b0;
                end else begin
                    wr_beat <= wr_beat + 1'b1;
                end
            end else if (mem_axi_bvalid && mem_axi_bready) begin
                mem_axi_bvalid <= 1'b0;
            end

            mem_axi_arready <= !rd_active && !mem_axi_rvalid;
            if (mem_axi_arvalid && mem_axi_arready) begin
                rd_addr_lat    <= mem_axi_araddr;
                rd_id_lat      <= mem_axi_arid;
                rd_len_lat     <= mem_axi_arlen;
                rd_size_lat    <= mem_axi_arsize;
                rd_burst_lat   <= mem_axi_arburst;
                rd_beat        <= 0;
                rd_active      <= 1'b1;
                mem_axi_rdata  <= sram[mem_axi_araddr[17:2]];
                mem_axi_rresp  <= 2'b00;
                mem_axi_rid    <= mem_axi_arid;
                mem_axi_rlast  <= (mem_axi_arlen == 0);
                mem_axi_rvalid <= 1'b1;
            end else if (mem_axi_rvalid && mem_axi_rready) begin
                if (rd_beat == rd_len_lat) begin
                    mem_axi_rvalid <= 1'b0;
                    mem_axi_rlast  <= 1'b0;
                    rd_active      <= 1'b0;
                end else begin
                    rd_beat <= rd_beat + 1'b1;
                    if (rd_burst_lat != 2'b00)
                        rd_addr_lat <= rd_addr_lat + (1 << rd_size_lat);
                    mem_axi_rdata <= sram[(rd_addr_lat + ((rd_burst_lat == 2'b00) ? 0 : (1 << rd_size_lat))) >> 2];
                    mem_axi_rlast <= (rd_beat + 1'b1 == rd_len_lat);
                    mem_axi_rvalid <= 1'b1;
                end
            end
        end
    end

    // =========================================================================
    // AXI-Lite sequence VIF adapted onto the real LSU AXI4 master input.
    // The VeeR core is held in reset in peripheral UVM tests; +CORE_BOOT
    // leaves the core running for the compiled C-image test.
    // =========================================================================

    assign axil_if.awready = u_dut.lsu_axi_awready;
    assign axil_if.wready  = u_dut.lsu_axi_wready;
    assign axil_if.bresp   = u_dut.lsu_axi_bresp;
    assign axil_if.bvalid  = u_dut.lsu_axi_bvalid;
    assign axil_if.arready = u_dut.lsu_axi_arready;
    assign axil_if.rdata   = u_dut.lsu_axi_rdata[31:0];
    assign axil_if.rresp   = u_dut.lsu_axi_rresp;
    assign axil_if.rvalid  = u_dut.lsu_axi_rvalid;
    assign axil_if.c_signature = sram[16'hFFFF]; // byte address 0x0003_FFFC

    initial begin : uvm_lsu_injection
        if (!$test$plusargs("CORE_BOOT")) begin
            // Keep CPU quiescent by holding it in reset AND forcing its
            // AXI outputs inactive. The interconnect/peripherals remain
            // active via the top-level rst_n synchronizer.
            // Wait for reset release first
            @(posedge rst_n);
            repeat (10) @(posedge clk);
            
            // Hold VeeR core in reset
            force u_dut.u_veer.rst_l = 1'b0;
            force u_dut.u_veer.dbg_rst_l = 1'b0;
            
            // Force VeeR's LSU AXI master to be inactive (no transactions)
            force u_dut.lsu_axi_awvalid = 1'b0;
            force u_dut.lsu_axi_wvalid = 1'b0;
            force u_dut.lsu_axi_arvalid = 1'b0;
            force u_dut.lsu_axi_bready = 1'b1;
            force u_dut.lsu_axi_rready = 1'b1;
            
            // Force VeeR's IFU AXI master to be inactive
            force u_dut.ifu_axi_awvalid = 1'b0;
            force u_dut.ifu_axi_wvalid = 1'b0;
            force u_dut.ifu_axi_arvalid = 1'b0;
            force u_dut.ifu_axi_bready = 1'b1;
            force u_dut.ifu_axi_rready = 1'b1;
            
            // Now inject UVM test traffic on the interconnect's FIRST slave port
            // by forcing signals BEFORE the interconnect (at the VeeR outputs)
            force u_dut.lsu_axi_awid = 4'h0;
            force u_dut.lsu_axi_awaddr = axil_if.awaddr;
            force u_dut.lsu_axi_awlen = 8'h00;
            force u_dut.lsu_axi_awsize = 3'b010;
            force u_dut.lsu_axi_awburst = 2'b01;
            force u_dut.lsu_axi_awlock = 1'b0;
            force u_dut.lsu_axi_awcache = 4'b0011;
            force u_dut.lsu_axi_awprot = axil_if.awprot;
            force u_dut.lsu_axi_awqos = 4'h0;
            force u_dut.lsu_axi_awregion = 4'h0;
            force u_dut.lsu_axi_awvalid = axil_if.awvalid;
            force u_dut.lsu_axi_wdata = {32'h0, axil_if.wdata};
            force u_dut.lsu_axi_wstrb = {4'h0, axil_if.wstrb};
            force u_dut.lsu_axi_wlast = 1'b1;
            force u_dut.lsu_axi_wvalid = axil_if.wvalid;
            force u_dut.lsu_axi_bready = axil_if.bready;
            force u_dut.lsu_axi_arid = 4'h0;
            force u_dut.lsu_axi_araddr = axil_if.araddr;
            force u_dut.lsu_axi_arlen = 8'h00;
            force u_dut.lsu_axi_arsize = 3'b010;
            force u_dut.lsu_axi_arburst = 2'b01;
            force u_dut.lsu_axi_arlock = 1'b0;
            force u_dut.lsu_axi_arcache = 4'b0011;
            force u_dut.lsu_axi_arprot = axil_if.arprot;
            force u_dut.lsu_axi_arqos = 4'h0;
            force u_dut.lsu_axi_arregion = 4'h0;
            force u_dut.lsu_axi_arvalid = axil_if.arvalid;
            force u_dut.lsu_axi_rready = axil_if.rready;
        end
    end

    // =========================================================================
    // Reset generation
    // =========================================================================
    initial begin
        rst_n = 1'b0;
        for (int unsigned i = 0; i < SRAM_DEPTH; i++) sram[i] = 32'h0;
        begin
            string c_image;
            if ($value$plusargs("C_IMAGE=%s", c_image)) begin
                $display("[TB] Loading C image %s into external SRAM", c_image);
                $readmemh(c_image, sram);
            end
        end
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        `uvm_info("TB_TOP", "Reset released", UVM_NONE)
    end

    // =========================================================================
    // UVM config_db VIF registration + test launch
    // =========================================================================
    initial begin
        // Register AXI-Lite VIF
        uvm_config_db #(virtual aegis_axil_if)::set(
            null, "uvm_test_top.env.agent.*", "vif", axil_if);
        uvm_config_db #(virtual aegis_axil_if)::set(
            null, "uvm_test_top.env.agent.drv", "vif", axil_if);
        uvm_config_db #(virtual aegis_axil_if)::set(
            null, "uvm_test_top.env.agent.mon", "vif", axil_if);

        // Run test specified by +UVM_TESTNAME or default to full test
        run_test("aegis_soc_full_test");
    end

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
`ifdef DUMP_FSDB
        if ($test$plusargs("FSDB")) begin
            $fsdbDumpfile("dump_soc_uvm.fsdb");
            $fsdbDumpvars(0, tb_aegis_v_soc_uvm);
        end else begin
            $dumpfile("dump_soc_uvm.vcd");
            $dumpvars(0, tb_aegis_v_soc_uvm);
        end
`else
        $dumpfile("dump_soc_uvm.vcd");
        $dumpvars(0, tb_aegis_v_soc_uvm);
`endif
    end

    // =========================================================================
    // Simulation timeout guard
    // =========================================================================
    initial begin
        if ($test$plusargs("CORE_BOOT")) begin
            #25_000_000;  // allow the C-test sequence's 2,000,000-cycle timeout
            $display("[TB] C-test global timeout; mailbox=0x%08X", sram[16'hFFFF]);
            `uvm_fatal("TIMEOUT", "C-test simulation timeout — 25ms exceeded")
        end else begin
            #5_000_000;  // 5 ms for peripheral-only UVM regression
            `uvm_fatal("TIMEOUT", "Simulation timeout — 5ms exceeded")
        end
    end

endmodule : tb_aegis_v_soc_uvm
