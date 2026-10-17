#!/usr/bin/env bash
# =============================================================================
# compile_soc.sh  —  VCS compile + simulate for Aegis-V SoC (TARGET C)
#
# Builds the SoC peripheral map and UVM testbench with Synopsys VCS U-2023.03.
#
# Usage (from run/ directory):
#   bash compile_soc.sh             # compile + run full SoC TB
#   bash compile_soc.sh compile     # compile only
#   bash compile_soc.sh sim         # run existing simv
#   bash compile_soc.sh ctest       # build C image and boot VeeR
#
# Address Map:
#   0x0000_0000  256 MB  External SRAM / Boot ROM  (M00)
#   0x1000_0000    4 KB  UART AXI-Lite              (M01)
#   0x2000_0000    4 KB  AES-128 AXI-Lite           (M02)
#   0x3000_0000    4 KB  I2C Master (WB)            (M03)
#   0x4000_0000    4 KB  PWM Controller             (M04)
#   0x5000_0000  256 B   SHA-256 AXI-Lite           (M05)
#   0x6000_0000    4 KB  GPIO-32 AXI-Lite           (M06)
#   0x7000_0000    4 KB  EF_WDT32 Watchdog          (M07)
#   0x8000_0000    4 KB  AXI DMA CSR                (M08)
#   0x9000_0000    4 KB  System Control & Status    (M09)
#   0xA000_0000    4 KB  rv_timer / mtime           (M10)
#   0xB000_0000   64 KB  Instruction Memory (IMEM)  (M11)
#   0xC000_0000   64 KB  Data Memory (DMEM)         (M12)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Tool path — Synopsys VCS U-2023.03
# ---------------------------------------------------------------------------
VCS_HOME=${VCS_HOME:-/home/student/snps_tools_target/vcs/U-2023.03}
VCS=${VCS_HOME}/bin/vcs
VERDI_HOME=${VERDI_HOME:-/home/student/snps_tools_target/verdi/U-2023.03-SP1}

export VCS_HOME VERDI_HOME
export PATH=${VCS_HOME}/bin:${VERDI_HOME}/bin:${PATH}
export LD_LIBRARY_PATH=${VCS_HOME}/linux64/lib:${VERDI_HOME}/share/PLI/VCS/LINUX64:${LD_LIBRARY_PATH:-}

# ---------------------------------------------------------------------------
# Project root (relative to run/)
# ---------------------------------------------------------------------------
PROJ=..
RV_ROOT=${PROJ}/rtl/Cores-VeeR-EL2
TB_TOP=tb_aegis_v_soc_uvm
SIMV=./simv_soc
LOG_COMPILE=compile_soc.log
LOG_SIM=sim_soc.log

# ---------------------------------------------------------------------------
# Generate VeeR EL2 config headers if missing
# ---------------------------------------------------------------------------
gen_veer_headers() {
    INCDIR="${RV_ROOT}/design/include"
    if [ ! -f "${INCDIR}/common_defines.vh" ] || [ ! -f "${INCDIR}/el2_param.vh" ]; then
        echo "[compile_soc.sh] Generating VeeR EL2 config headers..."
        (cd "${RV_ROOT}" && python3 configs/veer_config_gen.py -unset=iccm_enable 2>&1 | tail -5) || \
        (cd "${RV_ROOT}" && python3 configs/veer_config_gen.py 2>&1 | tail -5) || true
        if [ ! -f "${INCDIR}/common_defines.vh" ]; then
            echo "[compile_soc.sh] WARNING: Could not auto-generate VeeR headers."
            echo "                          Run manually: cd ${RV_ROOT} && python3 configs/veer_config_gen.py"
        else
            echo "[compile_soc.sh] VeeR headers generated OK."
        fi
    else
        echo "[compile_soc.sh] VeeR EL2 headers already present."
    fi
}

# ---------------------------------------------------------------------------
# Compile function
# ---------------------------------------------------------------------------
do_compile() {
    echo "============================================================"
    echo " Aegis-V SoC — VCS Compilation (TARGET C: Full SoC)"
    echo "============================================================"
    gen_veer_headers

    ${VCS} -full64 -sverilog                    \
        -timescale=1ns/1ps                      \
        -debug_access+all                       \
        -kdb                                    \
        -ntb_opts uvm-1.2                       \
        +define+RV_BUILD_AXI4                   \
        +define+SIMULATION                      \
        +incdir+${RV_ROOT}/design/include                               \
        +incdir+${PROJ}/rtl/axi-lite_uart-ipcore-develop/src/include    \
        +incdir+${PROJ}/rtl/i2c-master/rtl/verilog                      \
        +incdir+${PROJ}/rtl/axi_dma/rggen-verilog-rtl                   \
        -f run_soc.f                            \
        -top ${TB_TOP}                          \
        -o ${SIMV}                              \
        -l ${LOG_COMPILE}                       \
        2>&1 | tee /dev/stderr

    if [ ! -x "${SIMV}" ]; then
        echo "[compile_soc.sh] ERROR: VCS did not produce ${SIMV}. See ${LOG_COMPILE}." >&2
        return 1
    fi

    echo ""
    echo "[compile_soc.sh] Compilation complete. Log: ${LOG_COMPILE}"

    # Print any errors/warnings summary
    echo ""
    echo "=== Error / Warning Summary ==="
    grep -E "^Error|^Warning|\*Error|\*Warning|ERROR:|WARNING:" ${LOG_COMPILE} | head -50 || true
    # Count actual errors (not warnings)
    ERR_CNT=$(grep -cE "^Error|\*Error|ERROR:" ${LOG_COMPILE} 2>/dev/null | head -1 || echo "0")
    # Clean up any trailing newlines/spaces
    ERR_CNT=$(echo "${ERR_CNT}" | tr -d ' \n\r')
    echo ""
    if [ "${ERR_CNT}" = "0" ]; then
        echo "[PASS] Compilation SUCCEEDED — 0 errors."
    else
        echo "[FAIL] Compilation found ${ERR_CNT} error(s). See ${LOG_COMPILE} for details."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Simulation function
# ---------------------------------------------------------------------------
do_sim() {
    echo ""
    echo "============================================================"
    echo " Aegis-V SoC — VCS Simulation"
    echo "============================================================"
    if [ ! -x ${SIMV} ]; then
        echo "[compile_soc.sh] ERROR: ${SIMV} not found. Run compilation first."
        exit 1
    fi

    ${SIMV}                         \
        -l ${LOG_SIM}               \
        +ntb_random_seed=1          \
        +UVM_TESTNAME=aegis_soc_full_test \
        +UVM_VERBOSITY=UVM_NONE     \
        2>&1 | tee /dev/stderr

    echo ""
    echo "[compile_soc.sh] Simulation complete. Log: ${LOG_SIM}"

    # Print pass/fail summary
    echo ""
    echo "=== Test Result Summary ==="
    grep -E "AEGIS_UVM_RESULT=|\[PASS\]|\[FAIL\]|PASSED|FAILED|ALL TESTS" ${LOG_SIM} | tail -30 || true
    grep -q "AEGIS_UVM_RESULT=PASS" ${LOG_SIM} || {
        echo "[FAIL] UVM regression did not report PASS. See ${LOG_SIM}." >&2
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Boot VeeR with the compiled C image; the UVM sequence waits on the SRAM
# completion mailbox and returns nonzero unless it observes the success code.
do_ctest() {
    if [ ! -f ./soc_c_test.memh ]; then
        bash "${PROJ}/scripts/build_soc_c_test.sh"
    fi
    if [ ! -x ${SIMV} ]; then
        echo "[compile_soc.sh] ERROR: ${SIMV} not found. Run compilation first."
        exit 1
    fi
    ${SIMV} -l sim_ctest.log +ntb_random_seed=1 \
        +UVM_TESTNAME=aegis_soc_ctest_test +CORE_BOOT \
        +C_IMAGE=./soc_c_test.memh +UVM_VERBOSITY=UVM_NONE 2>&1 | tee /dev/stderr
    grep -q "AEGIS_UVM_RESULT=PASS" sim_ctest.log || {
        echo "[FAIL] C test did not report a passing signature. See sim_ctest.log." >&2
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
CMD=${1:-all}

case "${CMD}" in
    compile)
        do_compile
        ;;
    sim)
        do_sim
        ;;
    ctest)
        do_ctest
        ;;
    all|"")
        do_compile
        do_sim
        ;;
    *)
        echo "Usage: $0 [compile|sim|ctest|all]"
        exit 1
        ;;
esac

echo ""
echo "[compile_soc.sh] Done."
