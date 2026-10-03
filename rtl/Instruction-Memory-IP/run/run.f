# run.f — VCS filelist for Instruction Memory standalone verification
# Top: tb_instruction_memory
# Compile: vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
# Simulate: ./simv -ucli -do "fsdbDumpfile dump_imem.fsdb; fsdbDumpvars 0 tb_instruction_memory; run"
# Verdi: verdi -dbdir simv.daidir -ssf dump_imem.fsdb -nologo &

# DUT RTL
../rtl/instruction_memory/instruction_memory.v

# Testbench
tb_instruction_memory.v
