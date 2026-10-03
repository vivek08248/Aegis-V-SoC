# run.f — VCS filelist for PWM standalone verification
# Top: tb_pwm
# Compile: vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
# Simulate: ./simv -ucli -do "fsdbDumpfile dump_pwm.fsdb; fsdbDumpvars 0 tb_pwm; run" 
# Verdi: verdi -dbdir simv.daidir -ssf dump_pwm.fsdb -nologo &

# --- RTL files ---
../myip_v1_0.v
../myip_v1_0_S00_AXI.v

# --- Testbench ---
tb_pwm.v
