#!/usr/bin/env bash
# =============================================================================
# run.sh  —  Aegis-V SoC simulation launcher
# Run from the run/ directory:   bash run.sh <command>
#
# Commands:
#   compile_a   Compile TARGET A (tb_axi_interconnect_wrap_2x11)
#   compile_b   Compile TARGET B (tb_axi_interconnect_uart)
#   sim         Run simulation  (produces .fsdb in run/)
#   wave_a      Open Verdi for TARGET A  (dump_interconnect.fsdb)
#   wave_b      Open Verdi for TARGET B  (dump_uart.fsdb)
#   all_a       compile_a + sim + wave_a  (full flow TARGET A)
#   all_b       compile_b + sim + wave_b  (full flow TARGET B)
#   clean       Remove build artifacts
# =============================================================================

set -e
cd "$(dirname "$0")"     # always execute from the run/ directory

# =============================================================================
# Tool paths — hardcoded for this installation
# =============================================================================
VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1

export VCS_HOME
export VERDI_HOME
export PATH=${VCS_HOME}/bin:${VERDI_HOME}/bin:${PATH}
export LD_LIBRARY_PATH=${VERDI_HOME}/share/PLI/VCS/LINUX64:${LD_LIBRARY_PATH}

# Verdi PLI tab/archive — required so $fsdbDumpfile/$fsdbDumpvars work at runtime
PLI_TAB=${VERDI_HOME}/share/PLI/VCS/LINUX64/novas.tab
PLI_LIB=${VERDI_HOME}/share/PLI/VCS/LINUX64/pli.a

INCDIR="+incdir+../rtl/axi-lite_uart-ipcore-develop/src/include"

# =============================================================================
# VCS compile flags
#   -full64            64-bit compile
#   -sverilog          enable SystemVerilog
#   -ntb_opts uvm      include UVM library
#   -timescale         global timescale
#   -debug_access+all  full debug visibility (needed for KDB + waveform)
#   -kdb               generate KDB database for Verdi source navigation
#   -P <tab>:<lib>     link Verdi PLI so $fsdbDumpfile resolves at runtime
# =============================================================================
VCS_FLAGS="-full64 -sverilog -ntb_opts uvm \
           -timescale=1ns/1ps \
           -debug_access+all \
           -kdb \
           -P ${PLI_TAB}:${PLI_LIB}"

# =============================================================================
# Helper: swap the active TB in run.f
# =============================================================================
switch_target() {
    local enable="$1"
    local disable="$2"
    # Disable: add "# " prefix if not already commented
    sed -i "s|^${disable}|# ${disable}|" run.f
    # Enable: remove "# " prefix
    sed -i "s|^# ${enable}$|${enable}|" run.f
    echo "[run.sh] Active TB → ${enable}"
}

# =============================================================================
# Commands
# =============================================================================
case "${1:-help}" in

  compile_a)
    echo "[run.sh] ── Compiling TARGET A: tb_axi_interconnect_wrap_2x11 ──"
    switch_target \
        "../tb/tb_axi_interconnect_wrap_2x11.v" \
        "../tb/tb_axi_interconnect_uart.v"
    vcs ${VCS_FLAGS} ${INCDIR} -f run.f -l compile.log
    echo "[run.sh] Compile OK  →  compile.log"
    ;;

  compile_b)
    echo "[run.sh] ── Compiling TARGET B: tb_axi_interconnect_uart ──"
    switch_target \
        "../tb/tb_axi_interconnect_uart.v" \
        "../tb/tb_axi_interconnect_wrap_2x11.v"
    vcs ${VCS_FLAGS} ${INCDIR} -f run.f -l compile.log
    echo "[run.sh] Compile OK  →  compile.log"
    ;;

  sim)
    echo "[run.sh] ── Running simulation ──"
    if [ ! -x ./simv ]; then
        echo "[run.sh] ERROR: simv not found. Run compile_a or compile_b first."
        exit 1
    fi
    ./simv | tee sim.log
    echo ""
    echo "[run.sh] Simulation done  →  sim.log"
    echo "[run.sh] FSDB files produced:"
    ls -lh dump_*.fsdb 2>/dev/null || echo "  (none found — check sim.log for errors)"
    ;;

  wave_a)
    echo "[run.sh] ── Opening Verdi: dump_interconnect.fsdb ──"
    if [ ! -f dump_interconnect.fsdb ]; then
        echo "[run.sh] ERROR: dump_interconnect.fsdb not found."
        echo "         Run:  bash run.sh all_a"
        exit 1
    fi
    verdi -dbdir simv.daidir \
          -ssf  dump_interconnect.fsdb \
          -nologo \
          -tcl  verdi_wave_interconnect.tcl &
    echo "[run.sh] Verdi launched (PID $!)"
    ;;

  wave_b)
    echo "[run.sh] ── Opening Verdi: dump_uart.fsdb ──"
    if [ ! -f dump_uart.fsdb ]; then
        echo "[run.sh] ERROR: dump_uart.fsdb not found."
        echo "         Run:  bash run.sh all_b"
        exit 1
    fi
    verdi -dbdir simv.daidir \
          -ssf  dump_uart.fsdb \
          -nologo \
          -tcl  verdi_wave_uart.tcl &
    echo "[run.sh] Verdi launched (PID $!)"
    ;;

  all_a)
    echo "[run.sh] ══ Full flow: TARGET A ══"
    bash "$0" compile_a
    bash "$0" sim
    bash "$0" wave_a
    ;;

  all_b)
    echo "[run.sh] ══ Full flow: TARGET B ══"
    bash "$0" compile_b
    bash "$0" sim
    bash "$0" wave_b
    ;;

  compile_d)
    echo "[run.sh] ── Compiling TARGET D: tb_veer_interconnect_ip ──"
    # Disable all other TBs, enable TARGET D
    sed -i 's|^\.\./tb/tb_axi_interconnect_wrap_2x11\.v|# ../tb/tb_axi_interconnect_wrap_2x11.v|' run.f
    sed -i 's|^\.\./tb/tb_axi_interconnect_uart\.v|# ../tb/tb_axi_interconnect_uart.v|'           run.f
    sed -i 's|^# \.\./tb/tb_veer_interconnect_ip\.v$|../tb/tb_veer_interconnect_ip.v|'            run.f
    vcs ${VCS_FLAGS} ${INCDIR} \
        +incdir+../rtl/i2c-master/rtl/verilog \
        -f run.f -l compile.log
    echo "[run.sh] Compile OK  →  compile.log"
    ;;

  wave_d)
    echo "[run.sh] ── Opening Verdi: dump_veer_ic.fsdb ──"
    if [ ! -f dump_veer_ic.fsdb ]; then
        echo "[run.sh] ERROR: dump_veer_ic.fsdb not found."
        echo "         Run:  bash run.sh all_d"
        exit 1
    fi
    verdi -dbdir simv.daidir \
          -ssf  dump_veer_ic.fsdb \
          -nologo \
          -tcl  verdi_wave_veer_ic.tcl &
    echo "[run.sh] Verdi launched (PID $!)"
    ;;

  all_d)
    echo "[run.sh] ══ Full flow: TARGET D ══"
    bash "$0" compile_d
    bash "$0" sim
    bash "$0" wave_d
    ;;

  clean)
    echo "[run.sh] ── Cleaning build artifacts ──"
    rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h
    rm -f  compile.log sim.log novas_dump.log
    rm -f  dump_interconnect.fsdb dump_uart.fsdb dump_veer_ic.fsdb dump_soc.fsdb
    rm -f  verdi_config_file *.vcd
    echo "[run.sh] Clean done."
    ;;

  help|*)
    echo ""
    echo "  Usage: bash run.sh <command>"
    echo ""
    echo "  compile_a   Compile TARGET A  (interconnect standalone)"
    echo "  compile_b   Compile TARGET B  (UART integration)"
    echo "  compile_d   Compile TARGET D  (VeeR ↔ Interconnect ↔ IP verification)"
    echo "  sim         Run simulation    (FSDB written to run/)"
    echo "  wave_a      Open Verdi: dump_interconnect.fsdb"
    echo "  wave_b      Open Verdi: dump_uart.fsdb"
    echo "  all_a       compile_a + sim + wave_a"
    echo "  all_b       compile_b + sim + wave_b"
    echo "  clean       Remove all build/sim outputs"
    echo ""
    echo "  Tool paths used:"
    echo "    VCS    : ${VCS_HOME}/bin/vcs"
    echo "    VERDI  : ${VERDI_HOME}/bin/verdi"
    echo "    PLI tab: ${PLI_TAB}"
    echo "    PLI lib: ${PLI_LIB}"
    echo ""
    ;;
esac
