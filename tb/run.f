// =============================================================================
// tb/run.f  —  VCS / Questa / Xcelium filelist
// Two simulation targets — toggle by commenting/uncommenting the TB at the end.
//
// TARGET A (default): interconnect-only verification
//   Top: tb_axi_interconnect_wrap_2x11
//
// TARGET B: full UART integration
//   Top: tb_axi_interconnect_uart
//
// Compile from tb/ directory:
//   vcs -f run.f -o simv -timescale=1ns/1ps && ./simv
// =============================================================================

+incdir+../rtl/axi-lite_uart-ipcore-develop/src/include

// ---- Interconnect RTL ----
../rtl/interconnect/priority_encoder.v
../rtl/interconnect/arbiter.v
../rtl/interconnect/axi_interconnect.v
../rtl/interconnect/axi_interconnect_wrap_2x11.v

// ---- Bridge + UART (needed for TARGET B) ----
../rtl/interconnect/axi4_to_axilite_bridge.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_internal_fifo.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_parity_bit_compute.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_controller.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_transmitter.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_receiver.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v
../rtl/interconnect/axi_uart_subsystem.v

// ---- BFMs (shared) ----
axi_master_bfm.v
axi_slave_bfm.v

// ---- TARGET A: interconnect verification (default ON) ----
//tb_axi_interconnect_wrap_2x11.v

// ---- TARGET B: UART integration (default OFF — swap comments) ----
tb_axi_interconnect_uart.v
