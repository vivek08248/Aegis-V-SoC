#!/usr/bin/env bash
# =============================================================================
# run.sh  —  Aegis-V SoC  |  I2C Master simulation launcher
# Module : i2c-master (OpenCores Wishbone I2C Master)
#
# Always run from the run/ directory:
#   cd /home/student/Documents/1602-23-735-127/Aegis-V-SoC/rtl/i2c-master/run
#
# ─── Direct VCS terminal commands ────────────────────────────────────────────
#
#   COMPILE:
#     vcs -full64 -sverilog                                              \
#         -timescale=1ns/1ps -debug_access+all -kdb                     \
#         -P ${VERDI_HOME}/share/PLI/VCS/linux64/novas.tab ${VERDI_HOME}/share/PLI/VCS/linux64/pli.a \
#         -f run.f -l compile.log
#
#   SIMULATE:
#     ./simv -l sim.log
#
#   OPEN VERDI:
#     verdi -dbdir simv.daidir -ssf dump.fsdb \
#           -nologo -tcl verdi_wave_i2c.tcl &
#
# ─── Script commands ─────────────────────────────────────────────────────────
#   bash run.sh compile
#   bash run.sh sim
#   bash run.sh wave
#   bash run.sh all
#   bash run.sh clean
# =============================================================================

set -e
cd "$(dirname "$0")"

# =============================================================================
# Tool paths
# =============================================================================
VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1

export VCS_HOME VERDI_HOME
export PATH=${VCS_HOME}/bin:${VERDI_HOME}/bin:${PATH}
export VCS_ARCH_OVERRIDE=linux   # Rocky Linux 8 — suppress unsupported-OS warning

# PLI — needed because tst_bench_top has $fsdbDumpfile("dump.fsdb") hardcoded
PLI_TAB=${VERDI_HOME}/share/PLI/VCS/linux64/novas.tab
PLI_LIB=${VERDI_HOME}/share/PLI/VCS/linux64/pli.a

# FSDB name is hardcoded in the testbench as "dump.fsdb"
FSDB=dump.fsdb

# =============================================================================
# Commands
# =============================================================================
case "${1:-help}" in

  # ──────────────────────────────────────────────────────────────────────────
  compile)
    echo "[run.sh] ── VCS Compile: I2C Master tst_bench_top ──"
    vcs -full64 -sverilog          \
        -timescale=1ns/1ps         \
        -debug_access+all          \
        -kdb                       \
        -P ${PLI_TAB} ${PLI_LIB}   \
        -f run.f                   \
        -l compile.log
    echo "[run.sh] Compile OK → compile.log"
    ;;

  # ──────────────────────────────────────────────────────────────────────────
  sim)
    echo "[run.sh] ── Simulation ──"
    [ ! -x ./simv ] && { echo "ERROR: simv not found. Run: bash run.sh compile"; exit 1; }
    ./simv -l sim.log
    echo ""
    echo "[run.sh] Simulation done → sim.log"
    echo ""
    echo "─── Verification status ──────────────────────────────"
    grep -E "ERROR|status:|Testbench" sim.log || true
    echo "──────────────────────────────────────────────────────"
    [ -f "${FSDB}" ] && echo "[run.sh] FSDB: ${FSDB} ($(du -sh ${FSDB} | cut -f1))" \
                     || echo "[run.sh] WARNING: ${FSDB} not found — check sim.log"
    ;;

  # ──────────────────────────────────────────────────────────────────────────
  wave)
    echo "[run.sh] ── Verdi waveform ──"
    [ ! -f "${FSDB}" ] && { echo "ERROR: ${FSDB} not found. Run: bash run.sh all"; exit 1; }
    verdi -dbdir simv.daidir \
          -ssf  "${FSDB}"    \
          -nologo            \
          -tcl  verdi_wave_i2c.tcl &
    echo "[run.sh] Verdi launched (PID $!)"
    ;;

  # ──────────────────────────────────────────────────────────────────────────
  all)
    echo "[run.sh] ══ Full flow: compile → sim → wave ══"
    bash "$0" compile
    bash "$0" sim
    bash "$0" wave
    ;;

  # ──────────────────────────────────────────────────────────────────────────
  clean)
    echo "[run.sh] ── Clean ──"
    rm -rf simv simv.daidir csrc
    rm -f  ucli.key vc_hdrs.h verdi_config_file
    rm -f  compile.log sim.log novas_dump.log novas.rc novas.conf
    rm -f  "${FSDB}" *.vcd *.shm
    rm -rf verdiLog
    echo "[run.sh] Done."
    ;;

  # ──────────────────────────────────────────────────────────────────────────
  help|*)
    echo ""
    echo "  Usage: bash run.sh <command>"
    echo ""
    echo "  compile    VCS compile  (writes simv)"
    echo "  sim        ./simv run   (writes ${FSDB}, prints verification status)"
    echo "  wave       verdi open   (loads verdi_wave_i2c.tcl)"
    echo "  all        compile + sim + wave"
    echo "  clean      remove all outputs"
    echo ""
    echo "  Direct VCS terminal commands:"
    echo ""
    echo "  COMPILE:"
    echo "    vcs -full64 -sverilog -timescale=1ns/1ps \\"
    echo "        -debug_access+all -kdb \\"
    echo "        -P ${PLI_TAB} ${PLI_LIB} \\"
    echo "        -f run.f -l compile.log"
    echo ""
    echo "  SIMULATE:"
    echo "    ./simv -l sim.log"
    echo ""
    echo "  VERDI:"
    echo "    verdi -dbdir simv.daidir -ssf ${FSDB} \\"
    echo "          -nologo -tcl verdi_wave_i2c.tcl &"
    echo ""
    ;;
esac
