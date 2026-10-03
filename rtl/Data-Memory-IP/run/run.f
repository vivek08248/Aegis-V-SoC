# run.f — VCS filelist for Data Memory standalone verification
# Top:     tb_data_memory
# Compile: vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
# Simulate: ./simv -ucli -do "fsdbDumpfile dump_dmem.fsdb; fsdbDumpvars 0 tb_data_memory; run"
# Verdi:   verdi -dbdir simv.daidir -ssf dump_dmem.fsdb -nologo &

# --- RTL ---
../rtl/data_memory/data_memory.v

# --- Testbench ---
tb_data_memory.v
