# run.f — VCS filelist for rv_timer (timer_core) standalone verification
# Top: tb_timer_core
# Compile: vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
# Simulate: ./simv -ucli -do "fsdbDumpfile dump_rv_timer.fsdb; fsdbDumpvars 0 tb_timer_core; run"
# Verdi: verdi -dbdir simv.daidir -ssf dump_rv_timer.fsdb -nologo &

# DUT RTL
../rtl/timer_core.sv

# Testbench
tb_timer_core.v
