# =============================================================================
# run.f - Verilog filelist for Aegis-V SoC AXI Interconnect 2x9 Simulation
# Project : 1602-23-735-127 Aegis-V SoC
# Top     : tb_axi_interconnect_wrap_2x9
# Tool    : Synopsys VCS
# =============================================================================

+v2005

# -----------------------------------------------------------------------------
# RTL - AXI4 Interconnect Subsystem
# Compile order: lower-level modules -> interconnect -> wrapper
# -----------------------------------------------------------------------------

../rtl/interconnect/arbiter.v
../rtl/interconnect/priority_encoder.v
../rtl/interconnect/axi_interconnect.v
../rtl/interconnect/axi_interconnect_wrap_2x9.v

# -----------------------------------------------------------------------------
# Testbench - AXI4 BFMs and Top-Level Testbench
# -----------------------------------------------------------------------------

../tb/axi_master_bfm.v
../tb/axi_slave_bfm.v
../tb/tb_axi_interconnect_wrap_2x9.v
