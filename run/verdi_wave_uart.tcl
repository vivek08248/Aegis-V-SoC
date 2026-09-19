# =============================================================================
# verdi_wave_uart.tcl
# Verdi nWave signal-loading script for TARGET B:
#   axi_uart_subsystem full integration verification
#   Top: tb_axi_interconnect_uart
#   FSDB: dump_uart.fsdb
#
# Usage (from run/ directory):
#   verdi -dbdir simv.daidir \
#         -ssf dump_uart.fsdb \
#         -nologo \
#         -tcl verdi_wave_uart.tcl &
# =============================================================================

proc add_group {label} {
    global nWave
    wvSetPosition -win $nWave {("G1" 0)}
    wvAddComment -win $nWave $label
}

set nWave [wvCreateWindow]

# =============================================================================
# GROUP 1 — Clock, Reset & Test Status
# What to verify:
#   - rst_n goes high after 10 cycles cleanly
#   - pass_count/fail_count increment correctly at end of each test
# =============================================================================
add_group "=== GROUP 1: Clock / Reset / Test Counters ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_uart.clk" \
    "tb_axi_interconnect_uart.rst_n" \
    "tb_axi_interconnect_uart.pass_count" \
    "tb_axi_interconnect_uart.fail_count"

# =============================================================================
# GROUP 2 — Slave Port 0 (s00) — AXI4 Write Path
# What to verify (Tests 2, 3, 6):
#   - awvalid/awready handshake occurs within a few cycles
#   - awaddr correctly targets UART register offsets:
#       0x1000_0000 THR/RBR, 0x1000_0004 IER,
#       0x1000_0008 BDIV,    0x1000_000C LCR,
#       0x1000_0014 LSR
#   - wdata carries the configured value (0x80 for DLAB, 0x03 for 8N1 etc.)
#   - bresp = 2'b00 (OKAY) for all valid register writes
# =============================================================================
add_group "=== GROUP 2: s00 Write Path (CPU master) ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_uart.s0_awvalid" \
    "tb_axi_interconnect_uart.s0_awready" \
    "tb_axi_interconnect_uart.s0_awaddr" \
    "tb_axi_interconnect_uart.s0_awid" \
    "tb_axi_interconnect_uart.s0_wvalid" \
    "tb_axi_interconnect_uart.s0_wready" \
    "tb_axi_interconnect_uart.s0_wdata" \
    "tb_axi_interconnect_uart.s0_wstrb" \
    "tb_axi_interconnect_uart.s0_wlast" \
    "tb_axi_interconnect_uart.s0_bvalid" \
    "tb_axi_interconnect_uart.s0_bready" \
    "tb_axi_interconnect_uart.s0_bresp" \
    "tb_axi_interconnect_uart.s0_bid"

# =============================================================================
# GROUP 3 — Slave Port 0 (s00) — AXI4 Read Path
# What to verify (Tests 3, 5, 7):
#   - araddr = UART_LSR_ADDR (0x1000_0014) during LSR polling
#   - rdata LSR[0] (DATA_READY bit) toggles 0→1 after TX completes
#   - araddr = UART_THR_ADDR (0x1000_0000) for RBR read
#   - rdata[7:0] == transmitted byte (0xA5, 0x11, 0x22, 0x33 etc.)
#   - rresp = 2'b00 (OKAY)
# =============================================================================
add_group "=== GROUP 3: s00 Read Path (LSR polling + RBR read) ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_uart.s0_arvalid" \
    "tb_axi_interconnect_uart.s0_arready" \
    "tb_axi_interconnect_uart.s0_araddr" \
    "tb_axi_interconnect_uart.s0_arid" \
    "tb_axi_interconnect_uart.s0_rvalid" \
    "tb_axi_interconnect_uart.s0_rready" \
    "tb_axi_interconnect_uart.s0_rdata" \
    "tb_axi_interconnect_uart.s0_rresp" \
    "tb_axi_interconnect_uart.s0_rlast" \
    "tb_axi_interconnect_uart.s0_rid"

# =============================================================================
# GROUP 4 — Slave Port 1 (s01) — Secondary Master (Test 4)
# What to verify:
#   - Same address/data routing works from the second initiator
#   - s01 and s00 can be active at different times without conflict
# =============================================================================
add_group "=== GROUP 4: s01 Write & Read Path (DMA master — Test 4) ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_uart.s1_awvalid" \
    "tb_axi_interconnect_uart.s1_awready" \
    "tb_axi_interconnect_uart.s1_awaddr" \
    "tb_axi_interconnect_uart.s1_wvalid" \
    "tb_axi_interconnect_uart.s1_wready" \
    "tb_axi_interconnect_uart.s1_wdata" \
    "tb_axi_interconnect_uart.s1_bvalid" \
    "tb_axi_interconnect_uart.s1_bready" \
    "tb_axi_interconnect_uart.s1_bresp" \
    "tb_axi_interconnect_uart.s1_arvalid" \
    "tb_axi_interconnect_uart.s1_arready" \
    "tb_axi_interconnect_uart.s1_araddr" \
    "tb_axi_interconnect_uart.s1_rvalid" \
    "tb_axi_interconnect_uart.s1_rready" \
    "tb_axi_interconnect_uart.s1_rdata" \
    "tb_axi_interconnect_uart.s1_rresp"

# =============================================================================
# GROUP 5 — AXI4-to-AXI4-Lite Bridge Boundary (Interconnect m10 → Bridge)
# What to verify:
#   - ic_m10_awvalid pulses for each UART register write
#   - ic_m10_awaddr carries full 32-bit address; bridge strips to [4:0]
#   - ic_m10_wdata / ic_m10_wstrb arrive correctly
#   - ic_m10_bvalid comes back after UART responds
# =============================================================================
add_group "=== GROUP 5: Bridge Input — Interconnect m10 → Bridge (ic_m10_*) ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_uart.dut.ic_m10_awvalid" \
    "tb_axi_interconnect_uart.dut.ic_m10_awready" \
    "tb_axi_interconnect_uart.dut.ic_m10_awaddr" \
    "tb_axi_interconnect_uart.dut.ic_m10_wvalid" \
    "tb_axi_interconnect_uart.dut.ic_m10_wready" \
    "tb_axi_interconnect_uart.dut.ic_m10_wdata" \
    "tb_axi_interconnect_uart.dut.ic_m10_bvalid" \
    "tb_axi_interconnect_uart.dut.ic_m10_bready" \
    "tb_axi_interconnect_uart.dut.ic_m10_bresp" \
    "tb_axi_interconnect_uart.dut.ic_m10_arvalid" \
    "tb_axi_interconnect_uart.dut.ic_m10_arready" \
    "tb_axi_interconnect_uart.dut.ic_m10_araddr" \
    "tb_axi_interconnect_uart.dut.ic_m10_rvalid" \
    "tb_axi_interconnect_uart.dut.ic_m10_rready" \
    "tb_axi_interconnect_uart.dut.ic_m10_rdata" \
    "tb_axi_interconnect_uart.dut.ic_m10_rresp"

# =============================================================================
# GROUP 6 — AXI4-Lite UART Interface (Bridge → UART)
# What to verify:
#   - uart_awaddr[4:0] = low 5 bits of register offset (bridge strips upper bits)
#   - uart_wdata carries register value (0x80 DLAB, 0x64 baud divisor etc.)
#   - uart_awvalid/awready, uart_wvalid/wready handshakes occur
#   - uart_bvalid / uart_bresp = OKAY after each register write
#   - For reads: uart_araddr, uart_rdata (LSR, RBR values)
# =============================================================================
add_group "=== GROUP 6: AXI4-Lite UART Slave Port (uart_*) ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_uart.dut.uart_awvalid" \
    "tb_axi_interconnect_uart.dut.uart_awready" \
    "tb_axi_interconnect_uart.dut.uart_awaddr" \
    "tb_axi_interconnect_uart.dut.uart_awid" \
    "tb_axi_interconnect_uart.dut.uart_wvalid" \
    "tb_axi_interconnect_uart.dut.uart_wready" \
    "tb_axi_interconnect_uart.dut.uart_wdata" \
    "tb_axi_interconnect_uart.dut.uart_wstrb" \
    "tb_axi_interconnect_uart.dut.uart_bvalid" \
    "tb_axi_interconnect_uart.dut.uart_bready" \
    "tb_axi_interconnect_uart.dut.uart_bresp" \
    "tb_axi_interconnect_uart.dut.uart_bid" \
    "tb_axi_interconnect_uart.dut.uart_arvalid" \
    "tb_axi_interconnect_uart.dut.uart_arready" \
    "tb_axi_interconnect_uart.dut.uart_araddr" \
    "tb_axi_interconnect_uart.dut.uart_rvalid" \
    "tb_axi_interconnect_uart.dut.uart_rready" \
    "tb_axi_interconnect_uart.dut.uart_rdata" \
    "tb_axi_interconnect_uart.dut.uart_rresp"

# =============================================================================
# GROUP 7 — UART Physical Pins & IRQ (Tests 3-5)
# What to verify:
#   - uart_tx: serial bit stream visible after THR write
#   - uart_rx: loopback — identical waveform to uart_tx (wire assignment)
#   - uart_irq: asserts when RX FIFO has data (after serial reception completes)
#             de-asserts after RBR read drains the FIFO (Test 5)
# =============================================================================
add_group "=== GROUP 7: UART Physical Pins — TX / RX / IRQ ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_uart.uart_tx" \
    "tb_axi_interconnect_uart.uart_rx" \
    "tb_axi_interconnect_uart.uart_irq"

# =============================================================================
# GROUP 8 — UART Internal: LSR, THR, RBR visibility
# What to verify:
#   - LSR register bit[0] (DATA_READY) goes high after serial reception
#   - LSR bit[5] (THRE) and bit[6] (TEMT) show TX FIFO empty after drain
#   - axi_rdata reflects LSR value on each read cycle
# Note: signal paths go through axi_uart_top internal registers.
# =============================================================================
add_group "=== GROUP 8: UART Top Internals — LSR / TX / RX state ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_uart.dut.u_uart.axi_aclk_i" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_aresetn_i" \
    "tb_axi_interconnect_uart.dut.u_uart.uart_tx_o" \
    "tb_axi_interconnect_uart.dut.u_uart.uart_rx_i" \
    "tb_axi_interconnect_uart.dut.u_uart.read_interrupt_o" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_awaddr_i" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_awvalid_i" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_awready_o" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_wdata_i" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_wvalid_i" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_wready_o" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_bvalid_o" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_bresp_o" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_araddr_i" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_arvalid_i" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_arready_o" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_rdata_o" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_rvalid_o" \
    "tb_axi_interconnect_uart.dut.u_uart.axi_rresp_o"

# ─── Final formatting ────────────────────────────────────────────────────────
wvZoomAll -win $nWave
wvSelectAll -win $nWave
wvDeselect -win $nWave

puts "\n[Verdi TCL] verdi_wave_uart.tcl loaded."
puts "Groups loaded:"
puts "  1. Clock / Reset / Test Counters"
puts "  2. s00 Write Path (CPU AXI4)"
puts "  3. s00 Read Path  (LSR poll + RBR read)"
puts "  4. s01 Write & Read Path (DMA)"
puts "  5. Bridge boundary — ic_m10_* signals"
puts "  6. AXI4-Lite UART slave port — uart_*"
puts "  7. UART physical pins — TX / RX / IRQ"
puts "  8. UART top internals"
puts "\nKey things to verify in waveform:"
puts "  - Tests 2: awaddr = LCR(0x0C), BDIV(0x08), IER(0x04), bvalid+OKAY each"
puts "  - Test  3: uart_tx serial pulses after THR write; LSR[0] goes 1; rdata[7:0]=0xA5"
puts "  - Test  4: s01 channel active; uart_tx again; s01 rdata[7:0]=0x3C"
puts "  - Test  5: uart_irq de-asserts after s0_rvalid (RBR read)"
puts "  - Test  7: LSR rdata[5] and rdata[6] = 1 (TX empty)\n"
