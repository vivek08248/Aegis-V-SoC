all:
	iverilog -g2012 -o scs_sim -s tb_system_control_status $(shell cat FILELIST.f)
	vvp scs_sim

clean:
	rm -f scs_sim
