# =============================================================================
# run.f  —  Verilog filelist for Aegis-V SoC Simulation
# Project  : 1602-23-735-127 Aegis-V SoC
# Tool     : Synopsys VCS U-2023.03
#
# ─── Simulation Targets ───────────────────────────────────────────────────────
#   TARGET A (default ON)  : axi_interconnect_wrap_2x11 standalone verification
#                            Top  : tb_axi_interconnect_wrap_2x11
#                            FSDB : dump_interconnect.fsdb
#                            TCL  : verdi_wave_interconnect.tcl
#
#   TARGET B (default OFF) : Full UART integration (axi_uart_subsystem)
#                            Top  : tb_axi_interconnect_uart
#                            FSDB : dump_uart.fsdb
#                            TCL  : verdi_wave_uart.tcl
#
# ─── Compile (from run/ directory) ───────────────────────────────────────────
#   vcs -full64 -sverilog -ntb_opts uvm                          \
#       -timescale=1ns/1ps -debug_access+all -kdb                \
#       +incdir+../rtl/axi-lite_uart-ipcore-develop/src/include  \
#       -f run.f -l compile.log
#
#   NOTE: -debug_access+all -kdb are REQUIRED for FSDB dumping via Verdi PLI.
#         $fsdbDumpfile / $fsdbDumpvars calls are embedded in both TBs.
#
# ─── Simulate ────────────────────────────────────────────────────────────────
#   ./simv                    # produces dump_interconnect.fsdb (or dump_uart.fsdb)
#
# ─── Open Verdi waveform ─────────────────────────────────────────────────────
#   TARGET A:
#     verdi -dbdir simv.daidir -ssf dump_interconnect.fsdb \
#           -nologo -tcl verdi_wave_interconnect.tcl &
#
#   TARGET B:
#     verdi -dbdir simv.daidir -ssf dump_uart.fsdb \
#           -nologo -tcl verdi_wave_uart.tcl &
#
#   Shortcut: use run.sh
#     bash run.sh compile_a    compile TARGET A
#     bash run.sh sim          run simulation
#     bash run.sh wave_a       open Verdi for TARGET A
#     bash run.sh wave_b       open Verdi for TARGET B
#     bash run.sh all_a        compile + sim + wave (TARGET A)
#     bash run.sh all_b        compile + sim + wave (TARGET B)
# =============================================================================

+v2005

# ─── Include path for UART IP headers (axi_uart_defines.vh, axi_uart.vh) ────
+incdir+../rtl/axi-lite_uart-ipcore-develop/src/include

# =============================================================================
# RTL — AXI4 Interconnect (compile bottom-up)
# =============================================================================
../rtl/interconnect/priority_encoder.v
../rtl/interconnect/arbiter.v
../rtl/interconnect/axi_interconnect.v
../rtl/interconnect/axi_interconnect_wrap_2x11.v

# =============================================================================
# RTL — AXI4-to-AXI4-Lite Bridge  (TARGET B)
# =============================================================================
../rtl/interconnect/axi4_to_axilite_bridge.v

# =============================================================================
# RTL — AXI-Lite UART IP Core  (TARGET B)
# =============================================================================
../rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_internal_fifo.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_parity_bit_compute.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_controller.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_transmitter.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_receiver.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v

# =============================================================================
# RTL — UART subsystem integration wrapper  (TARGET B)
# =============================================================================
../rtl/interconnect/axi_uart_subsystem.v

# =============================================================================
# Testbench BFMs — shared by both targets
# =============================================================================
../tb/axi_master_bfm.v
../tb/axi_slave_bfm.v

# =============================================================================
# TARGET A  (default ON) — Interconnect standalone verification
#   Dumps : dump_interconnect.fsdb
#   Verdi : verdi_wave_interconnect.tcl
# =============================================================================
# ../tb/tb_axi_interconnect_wrap_2x11.v

# =============================================================================
# TARGET B  (default OFF) — Full UART integration
#   To switch: comment line above, uncomment line below, recompile.
#   Dumps : dump_uart.fsdb
#   Verdi : verdi_wave_uart.tcl
# =============================================================================
../tb/tb_axi_interconnect_uart.v
