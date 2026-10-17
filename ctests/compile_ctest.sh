#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
PROJ=..
RV_ROOT=${PROJ}/rtl/Cores-VeeR-EL2
VCS_HOME=${VCS_HOME:-/home/student/snps_tools_target/vcs/U-2023.03}
VERDI_HOME=${VERDI_HOME:-/home/student/snps_tools_target/verdi/U-2023.03-SP1}
VCS=${VCS:-${VCS_HOME}/bin/vcs}
SIMV=./simv_soc_ctest

export VCS_HOME VERDI_HOME
export PATH=${VCS_HOME}/bin:${VERDI_HOME}/bin:${PATH}
export LD_LIBRARY_PATH=${VCS_HOME}/linux64/lib:${VERDI_HOME}/share/PLI/VCS/LINUX64:${LD_LIBRARY_PATH:-}

build_image() {
    RISCV_PREFIX=${RISCV_PREFIX:-riscv64-unknown-elf-} \
        bash "${PROJ}/ctests/build_soc_c_test.sh"
}

compile() {
    "${VCS}" -full64 -sverilog \
        -timescale=1ns/1ps -debug_access+all -kdb \
        +define+DUMP_FSDB \
        +define+RV_BUILD_AXI4 +define+SIMULATION \
        +incdir+${RV_ROOT}/design/include \
        +incdir+${PROJ}/rtl/axi-lite_uart-ipcore-develop/src/include \
        +incdir+${PROJ}/rtl/i2c-master/rtl/verilog \
        +incdir+${PROJ}/rtl/axi_dma/rggen-verilog-rtl \
        -P ${VERDI_HOME}/share/PLI/VCS/LINUX64/novas.tab \
        ${VERDI_HOME}/share/PLI/VCS/LINUX64/pli.a \
        -f run_ctest.f -top tb_aegis_soc_ctest -o "${SIMV}" \
        -l compile_ctest.log
}

simulate() {
    "${SIMV}" -l sim_ctest.log +C_IMAGE=${PROJ}/ctests/soc_c_test.memh +FSDB
    grep -q 'SOC_CTEST_RESULT=PASS' sim_ctest.log || {
        echo '[FAIL] C-test did not report SOC_CTEST_RESULT=PASS; see sim_ctest.log.' >&2
        return 1
    }
    echo '[PASS] Core-VeeR C-test simulation completed successfully.'
}

case "${1:-all}" in
    compile)
        build_image
        compile
        ;;
    sim)
        [[ -f ${PROJ}/ctests/soc_c_test.memh ]] || build_image
        [[ -x ${SIMV} ]] || { echo "${SIMV} missing; run compile first." >&2; exit 1; }
        simulate
        ;;
    all)
        build_image
        compile
        simulate
        ;;
    *)
        echo "Usage: $0 [compile|sim|all]" >&2
        exit 2
        ;;
esac
