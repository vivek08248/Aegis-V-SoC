#!/usr/bin/env bash
# =============================================================================
# run.sh  —  Quick simulation launcher for the UART-interconnect testbench
# Run from the tb/ directory:
#     cd tb && bash run.sh
#
# Supports VCS (default), Questa/ModelSim, and Xcelium.
# Override the simulator with:  SIM=questa bash run.sh
# =============================================================================

set -e
SIM=${SIM:-vcs}
TB_TOP=tb_axi_interconnect_uart

case "$SIM" in
  vcs)
    echo "[run.sh] Compiling with VCS..."
    vcs -sverilog -timescale=1ns/1ps \
        +define+SIMULATION \
        -f run.f \
        -top "$TB_TOP" \
        -o simv
    echo "[run.sh] Running simulation..."
    ./simv
    ;;

  questa|modelsim)
    echo "[run.sh] Compiling with Questa/ModelSim..."
    vlib work
    vlog -timescale 1ns/1ps -f run.f
    echo "[run.sh] Running simulation..."
    vsim -c "$TB_TOP" -do "run -all; quit"
    ;;

  xcelium|xrun)
    echo "[run.sh] Running with Xcelium xrun..."
    xrun -timescale 1ns/1ps \
         +define+SIMULATION \
         -f run.f \
         -top "$TB_TOP"
    ;;

  *)
    echo "Unknown simulator: $SIM"
    echo "Set SIM to one of: vcs, questa, xcelium"
    exit 1
    ;;
esac

echo "[run.sh] Done."
