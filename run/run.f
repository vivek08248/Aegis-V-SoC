# =============================================================================
# run.f  —  Verilog/SystemVerilog filelist for Aegis-V SoC Simulation
# Project  : 1602-23-735-127 Aegis-V SoC
# Tool     : Synopsys VCS U-2023.03
#
# ─── Full SoC Address Map ────────────────────────────────────────────────────
#   0x0000_0000  256 MB  – External SRAM / Boot ROM (M00)
#   0x1000_0000    4 KB  – UART            (M01)
#   0x2000_0000    4 KB  – AES-128         (M02)
#   0x3000_0000    4 KB  – I2C             (M03)
#   0x4000_0000    4 KB  – PWM             (M04)
#   0x5000_0000    4 KB  – SHA-256         (M05)
#   0x6000_0000    4 KB  – GPIO-32         (M06)
#   0x7000_0000    4 KB  – WDT (EF_WDT32) (M07)
#   0x8000_0000    4 KB  – AXI DMA CSR    (M08)
#   0x9000_0000    4 KB  – Sys Ctrl/Status (M09)
#   0xA000_0000    4 KB  – rv_timer/mtime  (M10)
#
# ─── Compile (from run/ directory) ───────────────────────────────────────────
#   Full SoC (TARGET C):
#     export RV_ROOT=../rtl/Cores-VeeR-EL2
#     vcs -full64 -sverilog -ntb_opts uvm                           \
#         -timescale=1ns/1ps -debug_access+all -kdb                 \
#         +define+RV_BUILD_AXI4                                     \
#         +incdir+$RV_ROOT/design/include                           \
#         +incdir+../rtl/axi-lite_uart-ipcore-develop/src/include   \
#         +incdir+../rtl/i2c-master/rtl/verilog                     \
#         +incdir+../rtl/axi_dma/rggen-verilog-rtl                  \
#         -f run.f -l compile.log
#
#   NOTE: VeeR EL2 requires two auto-generated header files:
#           common_defines.vh  and  el2_param.vh
#         Generate with:  cd $RV_ROOT && python3 configs/veer_config_gen.py
# =============================================================================

+v2005

# =============================================================================
# Include paths
# =============================================================================
+incdir+../rtl/axi-lite_uart-ipcore-develop/src/include
+incdir+../rtl/i2c-master/rtl/verilog

# =============================================================================
# RTL — AXI4 Interconnect (compile bottom-up)
# =============================================================================
../rtl/interconnect/priority_encoder.v
../rtl/interconnect/arbiter.v
../rtl/interconnect/axi_interconnect.v
../rtl/interconnect/axi_interconnect_wrap_2x13.v
../rtl/interconnect/axi64_to_axi32_read_adapter.sv
../rtl/interconnect/axi64_to_axi32_write_adapter.sv

# =============================================================================
# RTL — AXI4-to-AXI4-Lite Bridge
# =============================================================================
../rtl/interconnect/axi4_to_axilite_bridge.v

# =============================================================================
# RTL — Wishbone-to-AXI-Lite Bridge  (for I2C)
# =============================================================================
../rtl/interconnect/wb_to_axilite_bridge.v

# =============================================================================
# RTL — AXI-Lite UART IP Core
# =============================================================================
../rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_internal_fifo.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_parity_bit_compute.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_controller.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_transmitter.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_receiver.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v

# =============================================================================
# RTL — AES Core  (AXI-Lite slave)
# =============================================================================
../rtl/aes_core-master/rtl/verilog/timescale.v
../rtl/aes_core-master/rtl/verilog/aes_rcon.v
../rtl/aes_core-master/rtl/verilog/aes_sbox.v
../rtl/aes_core-master/rtl/verilog/aes_inv_sbox.v
../rtl/aes_core-master/rtl/verilog/aes_key_expand_128.v
../rtl/aes_core-master/rtl/verilog/aes_cipher_top.v
../rtl/aes_core-master/rtl/verilog/aes_inv_cipher_top.v
../rtl/aes_core-master/rtl/verilog/aes_axi_slave.v

# =============================================================================
# RTL — I2C Master  (Wishbone slave)
# =============================================================================
../rtl/i2c-master/rtl/verilog/i2c_master_defines.v
../rtl/i2c-master/rtl/verilog/i2c_master_bit_ctrl.v
../rtl/i2c-master/rtl/verilog/i2c_master_byte_ctrl.v
../rtl/i2c-master/rtl/verilog/i2c_master_top.v

# =============================================================================
# RTL — PWM Controller  (AXI4-Lite slave, 4-bit address)
# =============================================================================
../rtl/AXI4-Lite-PWM-Controller-IP-Zynq-PYNQ--main/myip_v1_0_S00_AXI.v
../rtl/AXI4-Lite-PWM-Controller-IP-Zynq-PYNQ--main/myip_v1_0.v

# =============================================================================
# RTL — SHA256 Core + AXI4-Lite Wrapper  (M05 @ 0x5000_0000)
# =============================================================================
../rtl/sha256/src/rtl/sha256_k_constants.v
../rtl/sha256/src/rtl/sha256_w_mem.v
../rtl/sha256/src/rtl/sha256_core.v
../rtl/sha256/src/rtl/sha256.v
../rtl/sha256/sha256_axi4.v

# =============================================================================
# RTL — GPIO (AXI4-Lite flat wrapper)  (M06 @ 0x6000_0000)
# =============================================================================
../rtl/gpio/run/gpio_axilite_wrap_flat.sv

# =============================================================================
# RTL — EF_WDT32 Watchdog + AXI4-Lite Wrapper  (M07 @ 0x7000_0000)
# =============================================================================
../rtl/EF_WDT32/hdl/rtl/EF_WDT32.v
../rtl/EF_WDT32/EF_WDT32_AXI.v

# =============================================================================
# RTL — AXI DMA CSR + Flat Wrapper  (M08 @ 0x8000_0000)
# =============================================================================
+incdir+../rtl/axi_dma/rggen-verilog-rtl
../rtl/axi_dma/rggen-verilog-rtl/rggen_rtl_macros.vh
../rtl/axi_dma/rggen-verilog-rtl/rggen_bit_field.v
../rtl/axi_dma/rggen-verilog-rtl/rggen_default_register.v
../rtl/axi_dma/rggen-verilog-rtl/rggen_axi4lite_adapter.v
../rtl/axi_dma/csr_out/csr_dma.v
../rtl/axi_dma/dma_axi_flat.v

# =============================================================================
# RTL — System Control & Status IP  (M09 @ 0x9000_0000)
# =============================================================================
../rtl/System-Control-Status-IP/rtl/system_control/system_control_status.v

# =============================================================================
# RTL — rv_timer AXI4-Lite Wrapper  (M10 @ 0xA000_0000)
# =============================================================================
../rtl/rv_timer/rv_timer_axi.v

# =============================================================================
# RTL — Instruction Memory IP  (M11 @ 0xB000_0000)
# =============================================================================
../rtl/Instruction-Memory-IP/rtl/instruction_memory/instruction_memory.v

# =============================================================================
# RTL — Data Memory IP  (M12 @ 0xC000_0000)
# =============================================================================
../rtl/Data-Memory-IP/rtl/data_memory/data_memory.v

# =============================================================================
# RTL — UART subsystem integration wrapper  (TARGET B standalone)
# =============================================================================
../rtl/interconnect/axi_uart_subsystem.v

# =============================================================================
# RTL — Cores-VeeR-EL2 Design Files
#
# NOTE: These are SystemVerilog files. Requires:
#   +define+RV_BUILD_AXI4
#   +incdir+../rtl/Cores-VeeR-EL2/design/include
#   The auto-generated headers common_defines.vh and el2_param.vh must exist
#   in ../rtl/Cores-VeeR-EL2/design/include/ before compilation.
#
# Compile order: packages/defines first, then lib, then sub-modules, then top.
# =============================================================================

# --- VeeR EL2: assertion suppression (optional, include only if available) ---
# +incdir+../rtl/Cores-VeeR-EL2/design/include

# --- VeeR EL2: Packages and defines ---
../rtl/Cores-VeeR-EL2/design/el2_mubi_pkg.sv
../rtl/Cores-VeeR-EL2/design/el2_lockstep_pkg.sv
../rtl/Cores-VeeR-EL2/design/include/el2_def.sv

# --- VeeR EL2: Library primitives ---
../rtl/Cores-VeeR-EL2/design/lib/el2_assert.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_prim_buf.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_prim_generic_buf.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_lib.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_mem_if.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_regfile_if.sv
-v ../rtl/Cores-VeeR-EL2/design/lib/beh_lib.sv
-v ../rtl/Cores-VeeR-EL2/design/lib/mem_lib.sv
../rtl/Cores-VeeR-EL2/design/lib/ahb_to_axi4.sv
../rtl/Cores-VeeR-EL2/design/lib/axi4_to_ahb.sv

# --- VeeR EL2: DMI (JTAG debug) ---
../rtl/Cores-VeeR-EL2/design/dmi/dmi_jtag_to_core_sync.v
../rtl/Cores-VeeR-EL2/design/dmi/dmi_mux.v
../rtl/Cores-VeeR-EL2/design/dmi/dmi_wrapper.v
../rtl/Cores-VeeR-EL2/design/dmi/rvjtag_tap.v

# --- VeeR EL2: Debug ---
../rtl/Cores-VeeR-EL2/design/dbg/el2_dbg.sv

# --- VeeR EL2: Decode (DEC) ---
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_gpr_ctl.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_ib_ctl.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_pmp_ctl.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_trigger.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_decode_ctl.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec_tlu_ctl.sv
../rtl/Cores-VeeR-EL2/design/dec/el2_dec.sv

# --- VeeR EL2: Execute (EXU) ---
../rtl/Cores-VeeR-EL2/design/exu/el2_exu_alu_ctl.sv
../rtl/Cores-VeeR-EL2/design/exu/el2_exu_mul_ctl.sv
../rtl/Cores-VeeR-EL2/design/exu/el2_exu_div_ctl.sv
../rtl/Cores-VeeR-EL2/design/exu/el2_exu.sv

# --- VeeR EL2: Load/Store Unit (LSU) ---
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_clkdomain.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_addrcheck.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_trigger.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_ecc.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_dccm_mem.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_dccm_ctl.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_stbuf.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_lsc_ctl.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_bus_buffer.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu_bus_intf.sv
../rtl/Cores-VeeR-EL2/design/lsu/el2_lsu.sv

# --- VeeR EL2: Instruction Fetch Unit (IFU) ---
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_compress_ctl.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_aln_ctl.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_ifc_ctl.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_bp_ctl.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_ic_mem.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_iccm_mem.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu_mem_ctl.sv
../rtl/Cores-VeeR-EL2/design/ifu/el2_ifu.sv

# --- VeeR EL2: PMP, PIC, DMA ---
../rtl/Cores-VeeR-EL2/design/el2_pmp.sv
../rtl/Cores-VeeR-EL2/design/el2_pic_ctrl.sv
../rtl/Cores-VeeR-EL2/design/el2_dma_ctrl.sv

# --- VeeR EL2: Top-level ---
../rtl/Cores-VeeR-EL2/design/el2_veer.sv
../rtl/Cores-VeeR-EL2/design/el2_veer_lockstep.sv
../rtl/Cores-VeeR-EL2/design/el2_mem.sv
../rtl/Cores-VeeR-EL2/design/el2_veer_wrapper.sv

# =============================================================================
# RTL — Aegis-V SoC Top-Level  (TARGET C)
# =============================================================================
../rtl/interconnect/aegis_v_soc.v

# =============================================================================
# Testbench BFMs — shared by both TARGET A and TARGET B
# =============================================================================
../tb/axi_master_bfm.v
../tb/axi_slave_bfm.v

# =============================================================================
# TARGET A  (default ON) — Interconnect standalone verification
#   Top    : tb_axi_interconnect_wrap_2x11
#   Dumps  : dump_interconnect.fsdb
#   Verdi  : verdi_wave_interconnect.tcl
# =============================================================================
# ../tb/tb_axi_interconnect_wrap_2x11.v

# =============================================================================
# TARGET B  (default OFF) — Full UART integration
#   To switch: comment TARGET A line above, uncomment TARGET B line below.
#   Top    : tb_axi_interconnect_uart
#   Dumps  : dump_uart.fsdb
#   Verdi  : verdi_wave_uart.tcl
# =============================================================================
# ../tb/tb_axi_interconnect_uart.v

# =============================================================================
# TARGET C  (default OFF) — Full Aegis-V SoC with VeeR EL2
#   To switch: comment TARGET A/B lines, uncomment TARGET C line below,
#              and add +define+RV_BUILD_AXI4 and VeeR include dirs to vcs cmd.
#   Top    : tb_aegis_v_soc
#   FSDB   : dump_soc.fsdb
# =============================================================================
../tb/tb_aegis_v_soc.v

# =============================================================================
# TARGET D  (default OFF) — VeeR ↔ Interconnect ↔ IP connection verification
#   To switch: comment all other TARGET lines, uncomment TARGET D line below.
#   Top    : tb_veer_interconnect_ip
#   FSDB   : dump_veer_ic.fsdb
#   Verdi  : verdi_wave_veer_ic.tcl
# =============================================================================
# ../tb/tb_veer_interconnect_ip.v
