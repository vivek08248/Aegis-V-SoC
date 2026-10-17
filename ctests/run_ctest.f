# Standalone Core-VeeR C-test RTL file list.
# =============================================================================
# run_soc.f  —  VCS Filelist for Aegis-V SoC Full Integration (TARGET C)
# Project  : 1602-23-735-127 Aegis-V SoC
# Tool     : Synopsys VCS U-2023.03
#
# Compile command (from ctests/ directory):
#   export VCS=/home/student/snps_tools_target/vcs/U-2023.03/bin/vcs
#   export RV_ROOT=../rtl/Cores-VeeR-EL2
#   ${VCS} -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb  \
#       +define+RV_BUILD_AXI4 +define+SIMULATION                         \
#       +incdir+$RV_ROOT/design/include                                   \
#       +incdir+../rtl/axi-lite_uart-ipcore-develop/src/include           \
#       +incdir+../rtl/i2c-master/rtl/verilog                             \
#       +incdir+../rtl/axi_dma/rggen-verilog-rtl                          \
#       -f run_ctest.f -top tb_aegis_soc_ctest -o simv_soc_ctest -l compile_ctest.log
#
# ─── Full SoC Address Map ────────────────────────────────────────────────────
#   0x0000_0000  256 MB  External SRAM / Boot ROM  (M00)
#   0x1000_0000    4 KB  UART AXI-Lite              (M01)
#   0x2000_0000    4 KB  AES-128 AXI-Lite           (M02)
#   0x3000_0000    4 KB  I2C Master (WB)            (M03)
#   0x4000_0000    4 KB  PWM Controller             (M04)
#   0x5000_0000  256 B   SHA-256 AXI-Lite           (M05)
#   0x6000_0000    4 KB  GPIO-32 AXI-Lite           (M06)
#   0x7000_0000    4 KB  EF_WDT32 Watchdog          (M07)
#   0x8000_0000    4 KB  AXI DMA CSR                (M08)
#   0x9000_0000    4 KB  System Control & Status    (M09)
#   0xA000_0000    4 KB  rv_timer / mtime           (M10)
#   0xB000_0000   64 KB  Instruction Memory (IMEM)  (M11)
#   0xC000_0000   64 KB  Data Memory (DMEM)         (M12)
# =============================================================================

# =============================================================================
# Include Paths
# =============================================================================
+incdir+../rtl/axi-lite_uart-ipcore-develop/src/include
+incdir+../rtl/aes_core-master/rtl/verilog
+incdir+../rtl/i2c-master/rtl/verilog
+incdir+../rtl/axi_dma/rggen-verilog-rtl
+incdir+../rtl/Cores-VeeR-EL2/design/include
+incdir+../rtl/Cores-VeeR-EL2/snapshots/default

# =============================================================================
# RTL — AXI4 Interconnect  (compile bottom-up: leaves first)
# =============================================================================
../rtl/interconnect/priority_encoder.v
../rtl/interconnect/arbiter.v
../rtl/interconnect/axi_interconnect.v
../rtl/interconnect/axi_interconnect_wrap_2x13.v
../rtl/interconnect/axi64_to_axi32_read_adapter.sv
../rtl/interconnect/axi64_to_axi32_write_adapter.sv

# =============================================================================
# RTL — Protocol Bridges
# =============================================================================
../rtl/interconnect/axi4_to_axilite_bridge.v
../rtl/interconnect/wb_to_axilite_bridge.v
../rtl/interconnect/axilite_to_wb_bridge.v

# =============================================================================
# RTL — IP: UART  (AXI-Lite, M01 @ 0x1000_0000)
# =============================================================================
../rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_internal_fifo.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_parity_bit_compute.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_controller.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_transmitter.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/uart_receiver.v
../rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v

# =============================================================================
# RTL — IP: AES-128  (AXI-Lite slave, M02 @ 0x2000_0000)
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
# RTL — IP: I2C Master  (Wishbone slave, M03 @ 0x3000_0000)
# =============================================================================
../rtl/i2c-master/rtl/verilog/i2c_master_defines.v
../rtl/i2c-master/rtl/verilog/i2c_master_bit_ctrl.v
../rtl/i2c-master/rtl/verilog/i2c_master_byte_ctrl.v
../rtl/i2c-master/rtl/verilog/i2c_master_top.v

# =============================================================================
# RTL — IP: PWM Controller  (AXI4-Lite, 4-bit addr, M04 @ 0x4000_0000)
# =============================================================================
../rtl/AXI4-Lite-PWM-Controller-IP-Zynq-PYNQ--main/myip_v1_0_S00_AXI.v
../rtl/AXI4-Lite-PWM-Controller-IP-Zynq-PYNQ--main/myip_v1_0.v

# =============================================================================
# RTL — IP: SHA-256 Core + AXI4-Lite Wrapper  (M05 @ 0x5000_0000)
# =============================================================================
../rtl/sha256/src/rtl/sha256_k_constants.v
../rtl/sha256/src/rtl/sha256_w_mem.v
../rtl/sha256/src/rtl/sha256_core.v
../rtl/sha256/src/rtl/sha256.v
../rtl/sha256/sha256_axi4.v

# =============================================================================
# RTL — IP: GPIO-32  (AXI4-Lite flat wrapper, M06 @ 0x6000_0000)
# =============================================================================
../rtl/gpio/run/gpio_standalone.v
../rtl/gpio/run/gpio_axilite_wrap_flat.sv

# =============================================================================
# RTL — IP: EF_WDT32 Watchdog + AXI4-Lite Wrapper  (M07 @ 0x7000_0000)
# =============================================================================
../rtl/EF_WDT32/hdl/rtl/EF_WDT32.v
../rtl/EF_WDT32/EF_WDT32_AXI.v

# =============================================================================
# RTL — IP: AXI DMA CSR + Flat Wrapper  (M08 @ 0x8000_0000)
# =============================================================================
../rtl/axi_dma/rggen-verilog-rtl/rggen_bit_field.v
../rtl/axi_dma/rggen-verilog-rtl/rggen_default_register.v
../rtl/axi_dma/rggen-verilog-rtl/rggen_axi4lite_adapter.v
../rtl/axi_dma/csr_out/csr_dma.v
../rtl/axi_dma/dma_axi_flat.v

# =============================================================================
# RTL — IP: System Control & Status  (M09 @ 0x9000_0000)
# =============================================================================
../rtl/System-Control-Status-IP/rtl/system_control/system_control_status.v

# =============================================================================
# RTL — IP: rv_timer / mtime AXI4-Lite Wrapper  (M10 @ 0xA000_0000)
# =============================================================================
../rtl/rv_timer/rv_timer_axi.v

# =============================================================================
# RTL — IP: Instruction Memory  (AXI4-Lite, M11 @ 0xB000_0000, 64 KB)
# =============================================================================
../rtl/Instruction-Memory-IP/rtl/instruction_memory/instruction_memory.v

# =============================================================================
# RTL — IP: Data Memory  (AXI4-Lite, M12 @ 0xC000_0000, 64 KB)
# =============================================================================
../rtl/Data-Memory-IP/rtl/data_memory/data_memory.v

# =============================================================================
# RTL — Cores-VeeR-EL2  (RISC-V core)
# Requires: +define+RV_BUILD_AXI4
#           +incdir+../rtl/Cores-VeeR-EL2/design/include
#           Headers: common_defines.vh, el2_param.vh (auto-generated)
# Compile order: assertion defines → packages → lib → sub-modules → top
# =============================================================================

# --- VeeR EL2: Assertions and defines ---
../rtl/Cores-VeeR-EL2/design/lib/el2_assert.sv
../rtl/Cores-VeeR-EL2/design/include/el2_def.sv
../rtl/Cores-VeeR-EL2/design/el2_mubi_pkg.sv
../rtl/Cores-VeeR-EL2/design/el2_lockstep_pkg.sv

# --- VeeR EL2: Library primitives ---
../rtl/Cores-VeeR-EL2/design/lib/el2_prim_buf.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_prim_generic_buf.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_lib.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_mem_if.sv
../rtl/Cores-VeeR-EL2/design/lib/el2_regfile_if.sv
-v ../rtl/Cores-VeeR-EL2/design/lib/beh_lib.sv
-v ../rtl/Cores-VeeR-EL2/design/lib/mem_lib.sv
../rtl/Cores-VeeR-EL2/design/lib/ahb_to_axi4.sv
../rtl/Cores-VeeR-EL2/design/lib/axi4_to_ahb.sv

# --- VeeR EL2: DMI / JTAG debug ---
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
# RTL — Aegis-V SoC Top-Level Integration Module
#        Instantiates: VeeR EL2 core, axi_interconnect_wrap_2x13, all 12 IPs
# =============================================================================
../rtl/interconnect/aegis_v_soc.v

# =============================================================================
# Testbench — Standalone Core-VeeR C firmware boot test
#        SRAM model loads soc_c_test.memh and watches the firmware mailbox.
#        The firmware tests the mapped SRAM and SoC IPs:
#          M00-External SRAM, M01-UART, M02-AES, M03-I2C, M04-PWM,
#          M05-SHA256, M06-GPIO, M07-WDT, M08-DMA CSR, M09-SCS,
#          M10-rv_timer, M11-IMEM, and M12-DMEM.
# =============================================================================
tb_aegis_soc_ctest.sv
