# =============================================================================
# verdi_wave_interconnect.tcl
# Verdi nWave signal-loading script for TARGET A:
#   axi_interconnect_wrap_2x11 standalone verification
#   Top: tb_axi_interconnect_wrap_2x11
#   FSDB: dump_interconnect.fsdb
#
# Usage (from run/ directory — after ./simv has produced the FSDB):
#   verdi -dbdir simv.daidir \
#         -ssf dump_interconnect.fsdb \
#         -nologo \
#         -tcl verdi_wave_interconnect.tcl &
#
# Or open Verdi first, load the FSDB, then source this script:
#   File → Open Database → dump_interconnect.fsdb
#   Tools → TCL → Source TCL File → verdi_wave_interconnect.tcl
# =============================================================================

# ─── Helper proc: add a labelled group separator ───────────────────────────
proc add_group {label} {
    global nWave
    wvSetPosition -win $nWave {("G1" 0)}
    wvAddComment -win $nWave $label
}

# ─── Open a new waveform window ─────────────────────────────────────────────
set nWave [wvCreateWindow]

# =============================================================================
# GROUP 1 — Clock & Reset
# What to verify: reset de-asserts cleanly, clock is stable throughout sim.
# =============================================================================
add_group "=== GROUP 1: Clock & Reset ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_wrap_2x11.clk" \
    "tb_axi_interconnect_wrap_2x11.rst"

# =============================================================================
# GROUP 2 — Master BFM 0 (CPU) — Slave Port s00 of DUT
# What to verify:
#   - AW channel: awvalid/awready handshake, awaddr routes to correct slave
#   - W  channel: wvalid/wready, wdata, wstrb, wlast
#   - B  channel: bvalid/bready, bresp = 2'b00 (OKAY) for mapped addrs
#   - AR channel: arvalid/arready, araddr
#   - R  channel: rvalid/rready, rdata, rresp = 2'b00 (OKAY)
# =============================================================================
add_group "=== GROUP 2: Master BFM 0 (CPU) — s00 Write Path ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_wrap_2x11.u_master0.awvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master0.awready" \
    "tb_axi_interconnect_wrap_2x11.u_master0.awaddr" \
    "tb_axi_interconnect_wrap_2x11.u_master0.awid" \
    "tb_axi_interconnect_wrap_2x11.u_master0.wvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master0.wready" \
    "tb_axi_interconnect_wrap_2x11.u_master0.wdata" \
    "tb_axi_interconnect_wrap_2x11.u_master0.wstrb" \
    "tb_axi_interconnect_wrap_2x11.u_master0.wlast" \
    "tb_axi_interconnect_wrap_2x11.u_master0.bvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master0.bready" \
    "tb_axi_interconnect_wrap_2x11.u_master0.bresp" \
    "tb_axi_interconnect_wrap_2x11.u_master0.bid"

add_group "--- Master BFM 0 Read Path ---"

wvAddSignal -win $nWave \
    "tb_axi_interconnect_wrap_2x11.u_master0.arvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master0.arready" \
    "tb_axi_interconnect_wrap_2x11.u_master0.araddr" \
    "tb_axi_interconnect_wrap_2x11.u_master0.arid" \
    "tb_axi_interconnect_wrap_2x11.u_master0.rvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master0.rready" \
    "tb_axi_interconnect_wrap_2x11.u_master0.rdata" \
    "tb_axi_interconnect_wrap_2x11.u_master0.rresp" \
    "tb_axi_interconnect_wrap_2x11.u_master0.rid"

# =============================================================================
# GROUP 3 — Master BFM 1 (DMA) — Slave Port s01 of DUT
# Same checks as Group 2 but for the second initiator.
# Key for T08/T09: both groups should show overlapping handshakes in time
#   when the concurrent tests run.
# =============================================================================
add_group "=== GROUP 3: Master BFM 1 (DMA) — s01 Write Path ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_wrap_2x11.u_master1.awvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master1.awready" \
    "tb_axi_interconnect_wrap_2x11.u_master1.awaddr" \
    "tb_axi_interconnect_wrap_2x11.u_master1.awid" \
    "tb_axi_interconnect_wrap_2x11.u_master1.wvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master1.wready" \
    "tb_axi_interconnect_wrap_2x11.u_master1.wdata" \
    "tb_axi_interconnect_wrap_2x11.u_master1.wstrb" \
    "tb_axi_interconnect_wrap_2x11.u_master1.wlast" \
    "tb_axi_interconnect_wrap_2x11.u_master1.bvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master1.bready" \
    "tb_axi_interconnect_wrap_2x11.u_master1.bresp" \
    "tb_axi_interconnect_wrap_2x11.u_master1.bid"

add_group "--- Master BFM 1 Read Path ---"

wvAddSignal -win $nWave \
    "tb_axi_interconnect_wrap_2x11.u_master1.arvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master1.arready" \
    "tb_axi_interconnect_wrap_2x11.u_master1.araddr" \
    "tb_axi_interconnect_wrap_2x11.u_master1.arid" \
    "tb_axi_interconnect_wrap_2x11.u_master1.rvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master1.rready" \
    "tb_axi_interconnect_wrap_2x11.u_master1.rdata" \
    "tb_axi_interconnect_wrap_2x11.u_master1.rresp" \
    "tb_axi_interconnect_wrap_2x11.u_master1.rid"

# =============================================================================
# GROUP 4 — DUT Master Port 00 → Slave BFM 00
# What to verify:
#   - Correct slave is selected when awaddr/araddr falls in M00 window
#   - awvalid rises on DUT output when master targets 0x0000_xxxx
#   - awregion: should be 0 for single-region config
#   - Slave BFM wr_state / rd_state FSM transitions (optional deep-dive)
# =============================================================================
add_group "=== GROUP 4: DUT m00 Port → Slave BFM 00 (0x0000_0000) ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_wrap_2x11.m00_awvalid_o" \
    "tb_axi_interconnect_wrap_2x11.m00_awready_i" \
    "tb_axi_interconnect_wrap_2x11.m00_awaddr_o" \
    "tb_axi_interconnect_wrap_2x11.m00_awid_o" \
    "tb_axi_interconnect_wrap_2x11.m00_wvalid_o" \
    "tb_axi_interconnect_wrap_2x11.m00_wready_i" \
    "tb_axi_interconnect_wrap_2x11.m00_wdata_o" \
    "tb_axi_interconnect_wrap_2x11.m00_bvalid_i" \
    "tb_axi_interconnect_wrap_2x11.m00_bready_o" \
    "tb_axi_interconnect_wrap_2x11.m00_bresp_i" \
    "tb_axi_interconnect_wrap_2x11.m00_arvalid_o" \
    "tb_axi_interconnect_wrap_2x11.m00_arready_i" \
    "tb_axi_interconnect_wrap_2x11.m00_araddr_o" \
    "tb_axi_interconnect_wrap_2x11.m00_rvalid_i" \
    "tb_axi_interconnect_wrap_2x11.m00_rready_o" \
    "tb_axi_interconnect_wrap_2x11.m00_rdata_i" \
    "tb_axi_interconnect_wrap_2x11.m00_rresp_i"

# =============================================================================
# GROUP 5 — DUT Master Port 01 → Slave BFM 01  (spot-check routing)
# =============================================================================
add_group "=== GROUP 5: DUT m01 Port → Slave BFM 01 (0x0100_0000) ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_wrap_2x11.m01_awvalid_o" \
    "tb_axi_interconnect_wrap_2x11.m01_awready_i" \
    "tb_axi_interconnect_wrap_2x11.m01_awaddr_o" \
    "tb_axi_interconnect_wrap_2x11.m01_wvalid_o" \
    "tb_axi_interconnect_wrap_2x11.m01_wdata_o" \
    "tb_axi_interconnect_wrap_2x11.m01_bvalid_i" \
    "tb_axi_interconnect_wrap_2x11.m01_bresp_i" \
    "tb_axi_interconnect_wrap_2x11.m01_arvalid_o" \
    "tb_axi_interconnect_wrap_2x11.m01_araddr_o" \
    "tb_axi_interconnect_wrap_2x11.m01_rvalid_i" \
    "tb_axi_interconnect_wrap_2x11.m01_rdata_i" \
    "tb_axi_interconnect_wrap_2x11.m01_rresp_i"

# =============================================================================
# GROUP 6 — DUT Master Port 10 → Slave BFM 10  (far address routing)
# T11: Master 1 targets 0x1000_0000 — verify traffic reaches m10 NOT m00..m09
# =============================================================================
add_group "=== GROUP 6: DUT m10 Port → Slave BFM 10 (0x1000_0000) ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_wrap_2x11.m10_awvalid_o" \
    "tb_axi_interconnect_wrap_2x11.m10_awready_i" \
    "tb_axi_interconnect_wrap_2x11.m10_awaddr_o" \
    "tb_axi_interconnect_wrap_2x11.m10_wvalid_o" \
    "tb_axi_interconnect_wrap_2x11.m10_wdata_o" \
    "tb_axi_interconnect_wrap_2x11.m10_bvalid_i" \
    "tb_axi_interconnect_wrap_2x11.m10_bresp_i" \
    "tb_axi_interconnect_wrap_2x11.m10_arvalid_o" \
    "tb_axi_interconnect_wrap_2x11.m10_araddr_o" \
    "tb_axi_interconnect_wrap_2x11.m10_rvalid_i" \
    "tb_axi_interconnect_wrap_2x11.m10_rdata_i" \
    "tb_axi_interconnect_wrap_2x11.m10_rresp_i"

# =============================================================================
# GROUP 7 — Interconnect Internal: Arbiter signals (T10 arbitration test)
# What to verify:
#   - grant signals: which master wins access to a shared slave port
#   - request signals: both masters are asking simultaneously
#   - For T10 (both masters target M03), watch:
#       grant[0] and grant[1] never asserted at same time → mutual exclusion
# =============================================================================
add_group "=== GROUP 7: Interconnect Arbiter (for T10 arbitration) ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_wrap_2x11.u_dut.axi_interconnect_inst.s_axi_awvalid" \
    "tb_axi_interconnect_wrap_2x11.u_dut.axi_interconnect_inst.s_axi_awready" \
    "tb_axi_interconnect_wrap_2x11.u_dut.axi_interconnect_inst.m_axi_awvalid" \
    "tb_axi_interconnect_wrap_2x11.u_dut.axi_interconnect_inst.m_axi_awready"

# =============================================================================
# GROUP 8 — DECERR check (T12)
# What to verify:
#   - Master 0 sends a write/read to 0xDEAD_0000 (unmapped)
#   - bresp / rresp must = 2'b11 (DECERR) — observe in master0 B/R channels
#   - No slave's awvalid/arvalid should pulse → traffic absorbed internally
# =============================================================================
add_group "=== GROUP 8: DECERR — unmapped address (T12) ==="

wvAddSignal -win $nWave \
    "tb_axi_interconnect_wrap_2x11.u_master0.awaddr" \
    "tb_axi_interconnect_wrap_2x11.u_master0.awvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master0.bresp" \
    "tb_axi_interconnect_wrap_2x11.u_master0.bvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master0.araddr" \
    "tb_axi_interconnect_wrap_2x11.u_master0.arvalid" \
    "tb_axi_interconnect_wrap_2x11.u_master0.rresp" \
    "tb_axi_interconnect_wrap_2x11.u_master0.rvalid"

# ─── Final formatting ────────────────────────────────────────────────────────
wvZoomAll -win $nWave
wvSelectAll -win $nWave
wvDeselect -win $nWave

puts "\n[Verdi TCL] verdi_wave_interconnect.tcl loaded."
puts "Groups loaded:"
puts "  1. Clock & Reset"
puts "  2. Master BFM 0 Write/Read (s00)"
puts "  3. Master BFM 1 Write/Read (s01)"
puts "  4. DUT m00 → Slave BFM 00"
puts "  5. DUT m01 → Slave BFM 01"
puts "  6. DUT m10 → Slave BFM 10"
puts "  7. Interconnect Arbiter internals"
puts "  8. DECERR (T12) signals"
puts "\nTip: Use Ctrl+A then zoom-fit to see the full simulation.\n"
