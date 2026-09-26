# =============================================================================
# verdi_wave_veer_ic.tcl
# Verdi nWave signal-loading script for TARGET D:
#   VeeR EL2 ↔ AXI Interconnect ↔ UART / AES / I2C verification
#   Top  : tb_veer_interconnect_ip
#   FSDB : dump_veer_ic.fsdb
#
# Usage (from run/ directory):
#   verdi -dbdir simv.daidir        \
#         -ssf  dump_veer_ic.fsdb   \
#         -nologo                   \
#         -tcl  verdi_wave_veer_ic.tcl &
#
# Signal groups:
#   G1  Clock / Reset
#   G2  VeeR LSU (s0) — AXI4 write path to interconnect
#   G3  VeeR LSU (s0) — AXI4 read  path from interconnect
#   G4  VeeR IFU (s1) — AXI4 write path to interconnect
#   G5  VeeR IFU (s1) — AXI4 read  path from interconnect
#   G6  Interconnect M02 → AES bridge  (AXI4 master port)
#   G7  AES AXI-Lite slave interface   (after bridge)
#   G8  Interconnect M03 → I2C bridge  (AXI4 master port)
#   G9  I2C AXI-Lite interface         (after bridge)
#   G10 Wishbone bus (bridge → i2c_master_top)
#   G11 UART serial + IRQ
#   G12 Test scoreboard
# =============================================================================

set TB "tb_veer_interconnect_ip"

# Create waveform window
set nWave [wvCreateWindow]

# Helper: add a visible group header (comment line)
proc add_group {label} {
    global nWave
    wvSetPosition -win $nWave {("G1" 0)}
    wvAddComment -win $nWave $label
}

# =============================================================================
# G1 — Clock / Reset
# What to observe:
#   rst_n  rises cleanly after 20 cycles (no glitches)
#   rst_ah falls cleanly at the same edge
#   clk    toggles every 5 ns at 100 MHz
# =============================================================================
add_group "=== G1: Clock / Reset ==="
wvAddSignal -win $nWave \
    "${TB}.clk" \
    "${TB}.rst_n" \
    "${TB}.rst_ah" \
    "${TB}.pass_count" \
    "${TB}.fail_count"

# =============================================================================
# G2 — VeeR LSU (s0) AXI4 Write Path  →  Interconnect slave port s00
# What to observe:
#   awvalid/awready handshake: 1-cycle or back-to-back ready
#   awaddr  must decode to:
#     0x1000_0000 (UART), 0x2000_0000 (AES), 0x3000_0000 (I2C)
#   bresp   must be 2'b00 (OKAY) for all valid writes
# =============================================================================
add_group "=== G2: s0 Write Channel (VeeR LSU → Interconnect s00) ==="
wvAddSignal -win $nWave \
    "${TB}.s0_awvalid" \
    "${TB}.s0_awready" \
    "${TB}.s0_awaddr" \
    "${TB}.s0_awid" \
    "${TB}.s0_wvalid" \
    "${TB}.s0_wready" \
    "${TB}.s0_wdata" \
    "${TB}.s0_wstrb" \
    "${TB}.s0_wlast" \
    "${TB}.s0_bvalid" \
    "${TB}.s0_bready" \
    "${TB}.s0_bresp" \
    "${TB}.s0_bid"

# =============================================================================
# G3 — VeeR LSU (s0) AXI4 Read Path
# What to observe:
#   arvalid/arready handshake
#   araddr  targets peripheral registers
#   rdata   must match expected values per test:
#     T3 UART LCR  → 0x03
#     T5 AES OUT0  → 0x3925841D
#     T6 I2C CTR   → 0x80
#   rresp   must be 2'b00 (OKAY)
# =============================================================================
add_group "=== G3: s0 Read Channel (VeeR LSU → Interconnect s00) ==="
wvAddSignal -win $nWave \
    "${TB}.s0_arvalid" \
    "${TB}.s0_arready" \
    "${TB}.s0_araddr" \
    "${TB}.s0_arid" \
    "${TB}.s0_rvalid" \
    "${TB}.s0_rready" \
    "${TB}.s0_rdata" \
    "${TB}.s0_rresp" \
    "${TB}.s0_rlast" \
    "${TB}.s0_rid"

# =============================================================================
# G4 — VeeR IFU (s1) AXI4 Write Path  →  Interconnect slave port s01
# What to observe:
#   Tests T4 and T7 drive UART and I2C from s1
#   awvalid/awready: may be delayed by arbitration if s0 is also active
#   bresp must be OKAY
# =============================================================================
add_group "=== G4: s1 Write Channel (VeeR IFU → Interconnect s01) ==="
wvAddSignal -win $nWave \
    "${TB}.s1_awvalid" \
    "${TB}.s1_awready" \
    "${TB}.s1_awaddr" \
    "${TB}.s1_awid" \
    "${TB}.s1_wvalid" \
    "${TB}.s1_wready" \
    "${TB}.s1_wdata" \
    "${TB}.s1_wstrb" \
    "${TB}.s1_wlast" \
    "${TB}.s1_bvalid" \
    "${TB}.s1_bready" \
    "${TB}.s1_bresp"

# =============================================================================
# G5 — VeeR IFU (s1) AXI4 Read Path
# =============================================================================
add_group "=== G5: s1 Read Channel (VeeR IFU → Interconnect s01) ==="
wvAddSignal -win $nWave \
    "${TB}.s1_arvalid" \
    "${TB}.s1_arready" \
    "${TB}.s1_araddr" \
    "${TB}.s1_rvalid" \
    "${TB}.s1_rready" \
    "${TB}.s1_rdata" \
    "${TB}.s1_rresp"

# =============================================================================
# G6 — Interconnect M02 → AES bridge  (AXI4 master port output)
# What to observe:
#   m02_awvalid/awready: interconnect issues single-beat bursts
#   m02_awaddr: offset from AES base 0x2000_0000 (should be 5-bit)
#   m02_bresp fed back from bridge
# =============================================================================
add_group "=== G6: Interconnect M02 → AES Bridge (AXI4) ==="
wvAddSignal -win $nWave \
    "${TB}.m02_awvalid" \
    "${TB}.m02_awready" \
    "${TB}.m02_awaddr" \
    "${TB}.m02_awid" \
    "${TB}.m02_wvalid" \
    "${TB}.m02_wready" \
    "${TB}.m02_wdata" \
    "${TB}.m02_wstrb" \
    "${TB}.m02_bvalid" \
    "${TB}.m02_bready" \
    "${TB}.m02_bresp" \
    "${TB}.m02_arvalid" \
    "${TB}.m02_arready" \
    "${TB}.m02_araddr" \
    "${TB}.m02_rvalid" \
    "${TB}.m02_rready" \
    "${TB}.m02_rdata" \
    "${TB}.m02_rresp"

# =============================================================================
# G7 — AES AXI-Lite Interface (output of axi4_to_axilite_bridge for AES)
# What to observe:
#   aes_axil_awaddr  = 5-bit peripheral offset (KEY0=0x04, CTRL=0x00, etc.)
#   aes_axil_wdata   = register value written
#   aes_axil_bvalid  pulses one cycle per register write
#   aes_axil_rdata   returns OUT0..OUT3 after DONE
# =============================================================================
add_group "=== G7: AES AXI-Lite Slave Interface ==="
wvAddSignal -win $nWave \
    "${TB}.aes_axil_awaddr" \
    "${TB}.aes_axil_awvalid" \
    "${TB}.aes_axil_awready" \
    "${TB}.aes_axil_wdata" \
    "${TB}.aes_axil_wstrb" \
    "${TB}.aes_axil_wvalid" \
    "${TB}.aes_axil_wready" \
    "${TB}.aes_axil_bresp" \
    "${TB}.aes_axil_bvalid" \
    "${TB}.aes_axil_bready" \
    "${TB}.aes_axil_araddr" \
    "${TB}.aes_axil_arvalid" \
    "${TB}.aes_axil_arready" \
    "${TB}.aes_axil_rdata" \
    "${TB}.aes_axil_rresp" \
    "${TB}.aes_axil_rvalid" \
    "${TB}.aes_axil_rready"

# =============================================================================
# G8 — Interconnect M03 → I2C Bridge  (AXI4 master port)
# =============================================================================
add_group "=== G8: Interconnect M03 → I2C Bridge (AXI4) ==="
wvAddSignal -win $nWave \
    "${TB}.m03_awvalid" \
    "${TB}.m03_awready" \
    "${TB}.m03_awaddr" \
    "${TB}.m03_wvalid" \
    "${TB}.m03_wready" \
    "${TB}.m03_wdata" \
    "${TB}.m03_bvalid" \
    "${TB}.m03_bready" \
    "${TB}.m03_bresp" \
    "${TB}.m03_arvalid" \
    "${TB}.m03_arready" \
    "${TB}.m03_araddr" \
    "${TB}.m03_rvalid" \
    "${TB}.m03_rready" \
    "${TB}.m03_rdata" \
    "${TB}.m03_rresp"

# =============================================================================
# G9 — I2C AXI-Lite Interface (output of bridge_i2c)
# What to observe:
#   i2c_axil_awaddr = 5-bit offset (PRER_LO=0, PRER_HI=4, CTR=8)
#   i2c_axil_wdata  = byte written (e.g. 0xC8, 0x80)
#   i2c_axil_rdata  = readback value
# =============================================================================
add_group "=== G9: I2C AXI-Lite Interface (after bridge) ==="
wvAddSignal -win $nWave \
    "${TB}.i2c_axil_awaddr" \
    "${TB}.i2c_axil_awvalid" \
    "${TB}.i2c_axil_awready" \
    "${TB}.i2c_axil_wdata" \
    "${TB}.i2c_axil_wstrb" \
    "${TB}.i2c_axil_wvalid" \
    "${TB}.i2c_axil_wready" \
    "${TB}.i2c_axil_bvalid" \
    "${TB}.i2c_axil_bready" \
    "${TB}.i2c_axil_bresp" \
    "${TB}.i2c_axil_araddr" \
    "${TB}.i2c_axil_arvalid" \
    "${TB}.i2c_axil_arready" \
    "${TB}.i2c_axil_rdata" \
    "${TB}.i2c_axil_rresp" \
    "${TB}.i2c_axil_rvalid" \
    "${TB}.i2c_axil_rready"

# =============================================================================
# G10 — Wishbone bus (wb_to_axilite_bridge → i2c_master_top)
# What to observe:
#   wb_cyc / wb_stb  both assert together for a valid cycle
#   wb_we            1 = write, 0 = read
#   wb_adr           3-bit register select (0=PRER_LO, 1=PRER_HI, 2=CTR)
#   wb_dat_w / wb_dat_r  8-bit data in/out
#   wb_ack           pulses one cycle after wb_stb
# =============================================================================
add_group "=== G10: Wishbone Bus (WB bridge → i2c_master_top) ==="
wvAddSignal -win $nWave \
    "${TB}.wb_cyc" \
    "${TB}.wb_stb" \
    "${TB}.wb_we" \
    "${TB}.wb_adr" \
    "${TB}.wb_dat_w" \
    "${TB}.wb_dat_r" \
    "${TB}.wb_ack" \
    "${TB}.wb_inta"

# =============================================================================
# G11 — UART serial interface + IRQ
# What to observe:
#   uart_tx  transitions: start bit (low), 8 data bits LSB-first, stop bit (high)
#   uart_rx  tied to uart_tx — must mirror exactly
#   uart_irq asserts when RBR has data, de-asserts after RBR read
# =============================================================================
add_group "=== G11: UART Serial + IRQ ==="
wvAddSignal -win $nWave \
    "${TB}.uart_tx" \
    "${TB}.uart_rx" \
    "${TB}.uart_irq"

# =============================================================================
# G12 — Internal AXI-Lite signals inside UART subsystem (UART port)
# Verify the interconnect M10 → UART AXI-Lite path
# =============================================================================
add_group "=== G12: Interconnect M10 → UART AXI-Lite (inside subsystem) ==="
wvAddSignal -win $nWave \
    "${TB}.u_subsystem.uart_s_awaddr" \
    "${TB}.u_subsystem.uart_s_awvalid" \
    "${TB}.u_subsystem.uart_s_awready" \
    "${TB}.u_subsystem.uart_s_wdata" \
    "${TB}.u_subsystem.uart_s_wvalid" \
    "${TB}.u_subsystem.uart_s_wready" \
    "${TB}.u_subsystem.uart_s_bvalid" \
    "${TB}.u_subsystem.uart_s_bresp" \
    "${TB}.u_subsystem.uart_s_araddr" \
    "${TB}.u_subsystem.uart_s_arvalid" \
    "${TB}.u_subsystem.uart_s_arready" \
    "${TB}.u_subsystem.uart_s_rdata" \
    "${TB}.u_subsystem.uart_s_rresp" \
    "${TB}.u_subsystem.uart_s_rvalid"

# =============================================================================
# Final: set time range, zoom to see reset + first few tests, save session
# =============================================================================
wvZoomAll -win $nWave
wvSetCursorByValue -win $nWave 0
wvGetUserTime -win $nWave

# Save session so it can be reopened
wvSaveSession -win $nWave veer_ic_session.tcl

puts "\n[verdi_wave_veer_ic.tcl] All signal groups loaded."
puts "FSDB: dump_veer_ic.fsdb"
puts "Groups loaded: G1 Clock/Reset  G2-G5 CPU↔IC  G6-G9 AES/I2C AXI"
puts "               G10 Wishbone  G11 UART serial  G12 UART AXI-Lite"
