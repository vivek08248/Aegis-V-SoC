# run.f — VCS filelist for System Control Status standalone verification
# Top:     tb_system_control_status
# Compile: vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
# Simulate: ./simv -ucli -do "fsdbDumpfile dump_scs.fsdb; fsdbDumpvars 0 tb_system_control_status; run"
# Verdi:   verdi -dbdir simv.daidir -ssf dump_scs.fsdb -nologo &

# --- RTL ---
../rtl/system_control/system_control_status.v

# --- Testbench ---
tb_system_control_status.v
