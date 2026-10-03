#!/bin/bash
# =============================================================================
# run_all.sh — Compile & Simulate all Aegis-V-SoC IP modules (VCS + Verdi)
#
# Usage:
#   ./run_all.sh              # Run all 9 modules
#   ./run_all.sh pwm          # PWM Controller
#   ./run_all.sh sha256       # SHA-256 hash engine
#   ./run_all.sh wdt          # EF_WDT32 Watchdog Timer
#   ./run_all.sh dma          # AXI DMA CSR
#   ./run_all.sh timer        # rv_timer (timer_core)
#   ./run_all.sh gpio         # GPIO AXI4-Lite
#   ./run_all.sh scs          # System Control & Status
#   ./run_all.sh imem         # Instruction Memory
#   ./run_all.sh dmem         # Data Memory
#
# Requirements: Synopsys VCS + Verdi with FSDB support
# =============================================================================

SOC_ROOT="/home/student/Documents/1602-23-735-127/Aegis-V-SoC"
PASS=0
FAIL=0

run_module() {
    local NAME="$1"
    local DIR="$2"
    local TOP="$3"
    local FSDB="$4"

    echo ""
    echo "============================================================"
    echo "  MODULE : $NAME"
    echo "  DIR    : $DIR"
    echo "  TOP    : $TOP"
    echo "  FSDB   : $FSDB"
    echo "============================================================"

    cd "$DIR" || { echo "  ERROR: Cannot cd to $DIR"; FAIL=$((FAIL+1)); return; }

    # Compile
    echo "  [COMPILE] vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log"
    vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "  [FAIL] Compilation failed for $NAME — see $DIR/compile.log"
        FAIL=$((FAIL+1))
        return
    fi
    echo "  [OK] Compilation successful"

    # Simulate
    echo "  [SIM] ./simv -ucli -do \"fsdbDumpfile $FSDB; fsdbDumpvars 0 $TOP; run\""
    ./simv -ucli -do "fsdbDumpfile $FSDB; fsdbDumpvars 0 $TOP; run" -l sim.log
    echo "  [OK] Simulation done  →  FSDB: $DIR/$FSDB"
    PASS=$((PASS+1))
}

TARGET="${1:-all}"

case "$TARGET" in
  all|pwm)
    run_module "PWM Controller" \
        "$SOC_ROOT/rtl/AXI4-Lite-PWM-Controller-IP-Zynq-PYNQ--main/run" \
        "tb_pwm" "dump_pwm.fsdb"
    ;;&
  all|sha256)
    run_module "SHA-256" \
        "$SOC_ROOT/rtl/sha256/run" \
        "tb_sha256" "dump_sha256.fsdb"
    ;;&
  all|wdt)
    run_module "EF_WDT32 Watchdog Timer" \
        "$SOC_ROOT/rtl/EF_WDT32/run" \
        "tb_wdt" "dump_wdt.fsdb"
    ;;&
  all|dma)
    run_module "AXI DMA CSR" \
        "$SOC_ROOT/rtl/axi_dma/run" \
        "tb_dma" "dump_dma.fsdb"
    ;;&
  all|timer)
    run_module "rv_timer / timer_core" \
        "$SOC_ROOT/rtl/rv_timer/run" \
        "tb_timer_core" "dump_rv_timer.fsdb"
    ;;&
  all|gpio)
    run_module "GPIO AXI4-Lite" \
        "$SOC_ROOT/rtl/gpio/run" \
        "tb_gpio" "dump_gpio.fsdb"
    ;;&
  all|scs)
    run_module "System Control & Status" \
        "$SOC_ROOT/rtl/System-Control-Status-IP/run" \
        "tb_system_control_status" "dump_scs.fsdb"
    ;;&
  all|imem)
    run_module "Instruction Memory" \
        "$SOC_ROOT/rtl/Instruction-Memory-IP/run" \
        "tb_instruction_memory" "dump_imem.fsdb"
    ;;&
  all|dmem)
    run_module "Data Memory" \
        "$SOC_ROOT/rtl/Data-Memory-IP/run" \
        "tb_data_memory" "dump_dmem.fsdb"
    ;;&
esac

echo ""
echo "============================================================"
echo "  FINAL SUMMARY:  PASSED=$PASS   FAILED=$FAIL"
echo "============================================================"
