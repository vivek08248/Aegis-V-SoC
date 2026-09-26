# =============================================================================
# run.f  —  Verilog filelist for I2C Master Controller Simulation
# Project  : 1602-23-735-127 Aegis-V SoC
# Module   : i2c-master (OpenCores Wishbone I2C Master)
# Tool     : Synopsys VCS U-2023.03
#
# ─── Design Under Test ───────────────────────────────────────────────────────
#   RTL top   : i2c_master_top
#   Bench top : tst_bench_top
#   FSDB dump : dump_i2c.fsdb
#
# ─── Compile (from run/ directory) ───────────────────────────────────────────
#   vcs -full64 -sverilog                           \
#       -timescale=1ns/1ps -debug_access+all -kdb   \
#       -f run.f -l compile.log
#
# ─── Simulate ────────────────────────────────────────────────────────────────
#   ./simv                    # produces dump_i2c.fsdb
#
# ─── Open Verdi waveform ─────────────────────────────────────────────────────
#   verdi -dbdir simv.daidir -ssf dump_i2c.fsdb -nologo &
#
#   Shortcut: use run.sh
#     bash run.sh compile     compile the design
#     bash run.sh sim         run simulation
#     bash run.sh wave        open Verdi
#     bash run.sh all         compile + sim + wave
#     bash run.sh clean       remove all build/sim outputs
# =============================================================================

# ─── Include paths ───────────────────────────────────────────────────────────
+incdir+../rtl/verilog
+incdir+../bench/verilog

# =============================================================================
# RTL — I2C Master (compile bottom-up)
# =============================================================================
../rtl/verilog/i2c_master_defines.v
../rtl/verilog/i2c_master_bit_ctrl.v
../rtl/verilog/i2c_master_byte_ctrl.v
../rtl/verilog/i2c_master_top.v

# =============================================================================
# Bench — Slave model + WB BFM + Testbench top
# =============================================================================
../bench/verilog/i2c_slave_model.v
../bench/verilog/wb_master_model.v
../bench/verilog/tst_bench_top.v
