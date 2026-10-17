# Aegis-V SoC Test Execution Guide

**Project:** 1602-23-735-127/Aegis-V-SoC  
**Tool:** Synopsys VCS U-2023.03 + UVM 1.2  
**Purpose:** Step-by-step guide for compiling and executing all verification tests

---

## Quick Start (3 Commands)

```bash
cd /home/student/Documents/1602-23-735-127/Aegis-V-SoC/run

# 1. Compile simulation
bash compile_soc.sh compile

# 2. Run UVM peripheral tests
bash compile_soc.sh sim

# 3. Run C boot test
bash compile_soc.sh ctest
```

Expected result: All three commands complete with `AEGIS_UVM_RESULT=PASS`

---

## Detailed Compilation Guide

### Step 1: Environment Verification

Before compilation, verify tools are installed:

```bash
# Check VCS installation
which vcs
echo $VCS_HOME

# Check RISC-V GCC (for C test)
which riscv64-unknown-elf-gcc
riscv64-unknown-elf-gcc --version

# Expected GCC version: 11.x or 12.x with multilib support
```

If VCS is not found, set environment:
```bash
export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1
export PATH=${VCS_HOME}/bin:${VERDI_HOME}/bin:$PATH
export LD_LIBRARY_PATH=${VCS_HOME}/linux64/lib:${VERDI_HOME}/share/PLI/VCS/LINUX64:${LD_LIBRARY_PATH}
```

### Step 2: Compile VCS Simulation

```bash
cd /home/student/Documents/1602-23-735-127/Aegis-V-SoC/run
bash compile_soc.sh compile
```

**What happens:**
1. Auto-generates VeeR EL2 configuration headers:
   - `rtl/Cores-VeeR-EL2/design/include/common_defines.vh`
   - `rtl/Cores-VeeR-EL2/design/include/el2_param.vh`
2. Invokes VCS with options:
   - `-full64` — 64-bit mode
   - `-sverilog` — SystemVerilog + UVM
   - `-ntb_opts uvm-1.2` — Enable UVM 1.2
   - `-debug_access+all` — Full debug capability
   - `-kdb` — Verdi KDB format
   - `+define+RV_BUILD_AXI4` — VeeR AXI4 bus mode
3. Compiles file list from `run_soc.f`:
   - Interconnect (arbiter, crossbar, bridges)
   - 13 IP blocks (UART, AES, I2C, PWM, SHA256, GPIO, WDT, DMA, SCS, Timer, IMEM, DMEM)
   - VeeR EL2 core (all submodules)
   - UVM testbench (`tb/tb_aegis_v_soc_uvm.sv`)
4. Links and creates `simv_soc` executable

**Expected Duration:** 2-5 minutes (depends on system performance)

**Success Indicators:**
```
[compile_soc.sh] Compilation complete. Log: compile_soc.log
=== Error / Warning Summary ===
[PASS] Compilation SUCCEEDED — 0 errors.
```

**Check for executable:**
```bash
ls -lh simv_soc
# Expected: ~15-20 MB executable
```

**Troubleshooting Compilation Errors:**

| Error | Cause | Solution |
|-------|-------|----------|
| `common_defines.vh: No such file` | VeeR headers not generated | Run: `cd rtl/Cores-VeeR-EL2 && python3 configs/veer_config_gen.py` |
| `UVM_ERROR: package not found` | UVM not enabled | Add `-ntb_opts uvm-1.2` to VCS command |
| `timescale.v: file not found` | Include path missing | Check `+incdir+` paths in `run_soc.f` |
| `License error` | VCS license not available | Contact system admin or use `compile_soc.sh` (skips license check) |

---

## UVM Peripheral Test Execution

### Run All Peripheral Tests (Recommended First Run)

```bash
cd /home/student/Documents/1602-23-735-127/Aegis-V-SoC/run
bash compile_soc.sh sim
```

**What happens:**
1. Executes `simv_soc` with `+UVM_TESTNAME=aegis_soc_full_test`
2. Runs 12 sequential tests (one per IP):
   - UART loopback test
   - AES-128 known-answer test
   - I2C prescaler test
   - PWM duty cycle test
   - SHA-256 identity test
   - GPIO set/clear test
   - WDT load test
   - DMA CSR test
   - SCS scratch test
   - Timer increment test
   - IMEM write reject test
   - DMEM read/write test
3. VeeR core held in reset (peripherals accessed via AXI BFM)
4. Reports pass/fail for each IP

**Expected Duration:** 30-60 seconds

**Expected Output:**
```
============================================================
 Aegis-V SoC — VCS Simulation
============================================================
UVM_INFO @ 0: reporter [RNTST] Running test aegis_soc_full_test...

[UART TEST] Configuring baud=1, LCR=8N1
[UART TEST] Transmitting byte 0x41...
[UART TEST] Received byte 0x41 (loopback OK)
[PASS] UART loopback test passed

[AES TEST] Loading key: 0x00010203_04050607_08090A0B_0C0D0E0F
[AES TEST] Loading plaintext: 0x00112233_44556677_8899AABB_CCDDEEFF
[AES TEST] Starting encryption...
[AES TEST] Ciphertext: 0x69C4E0D8_6A7B0430_D8CDB780_70B4C55A
[PASS] AES-128 known-answer test passed

[I2C TEST] Writing prescaler_lo=0xF9...
[I2C TEST] Readback prescaler_lo=0xF9
[PASS] I2C prescaler test passed

[PWM TEST] Writing duty=0x80...
[PWM TEST] Readback duty=0x80
[PASS] PWM duty cycle test passed

[SHA256 TEST] Reading NAME=0x73686132 ("sha2")
[SHA256 TEST] Reading VERSION=0x2D323536 ("-256")
[SHA256 TEST] Reading RELEASE=0x312E3830 ("1.80")
[PASS] SHA-256 identity test passed

[GPIO TEST] Writing output=0xAA...
[GPIO TEST] Writing set=0xFF00, clear=0xAA...
[GPIO TEST] Readback output=0xFF00
[PASS] GPIO set/clear test passed

[WDT TEST] Writing load=0x00FFFFFF...
[WDT TEST] Readback load=0x00FFFFFF
[PASS] WDT load test passed

[DMA TEST] Writing src=0x1000, dst=0x2000, len=0x100...
[DMA TEST] Readback src=0x1000, dst=0x2000, len=0x100
[PASS] DMA CSR test passed

[SCS TEST] Writing scratch=0xDEADBEEF...
[SCS TEST] Readback scratch=0xDEADBEEF
[PASS] SCS scratch test passed

[TIMER TEST] Enabling timer...
[TIMER TEST] mtime before=0x00000000
[TIMER TEST] mtime after=0x00000123 (incrementing)
[PASS] Timer increment test passed

[IMEM TEST] Attempting write to read-only IMEM...
[IMEM TEST] Received SLVERR response (expected)
[IMEM TEST] Readback unchanged data
[PASS] IMEM write reject test passed

[DMEM TEST] Writing 0x12345678 to DMEM[0x100]...
[DMEM TEST] Readback 0x12345678
[PASS] DMEM read/write test passed

--- UVM Report Summary ---
UVM_INFO :   48
UVM_WARNING :    0
UVM_ERROR :      0
UVM_FATAL :      0

AEGIS_UVM_RESULT=PASS
$finish at time 500000 ns
```

**Log File:** `sim_soc.log` (full transcript with timestamps)

### Run Individual IP Tests

To debug a specific IP, run its test in isolation:

```bash
# UART test only
./simv_soc +UVM_TESTNAME=aegis_soc_uart_test +UVM_VERBOSITY=UVM_HIGH -l sim_uart.log

# AES test only
./simv_soc +UVM_TESTNAME=aegis_soc_aes_test +UVM_VERBOSITY=UVM_MEDIUM -l sim_aes.log

# I2C test only
./simv_soc +UVM_TESTNAME=aegis_soc_i2c_test -l sim_i2c.log

# PWM test only
./simv_soc +UVM_TESTNAME=aegis_soc_pwm_test -l sim_pwm.log

# SHA256 test only
./simv_soc +UVM_TESTNAME=aegis_soc_sha256_test -l sim_sha256.log

# GPIO test only
./simv_soc +UVM_TESTNAME=aegis_soc_gpio_test -l sim_gpio.log

# Watchdog test only
./simv_soc +UVM_TESTNAME=aegis_soc_wdt_test -l sim_wdt.log

# DMA test only
./simv_soc +UVM_TESTNAME=aegis_soc_dma_test -l sim_dma.log

# System Control/Status test only
./simv_soc +UVM_TESTNAME=aegis_soc_scs_test -l sim_scs.log

# Timer test only
./simv_soc +UVM_TESTNAME=aegis_soc_timer_test -l sim_timer.log

# Instruction Memory test only
./simv_soc +UVM_TESTNAME=aegis_soc_imem_test -l sim_imem.log

# Data Memory test only
./simv_soc +UVM_TESTNAME=aegis_soc_dmem_test -l sim_dmem.log

# Reset/sanity test only
./simv_soc +UVM_TESTNAME=aegis_soc_sanity_test -l sim_sanity.log
```

**UVM Verbosity Levels:**
- `UVM_NONE` — Errors only (default, fastest)
- `UVM_LOW` — Major checkpoints
- `UVM_MEDIUM` — Transaction-level detail
- `UVM_HIGH` — Full sequence/driver debug
- `UVM_FULL` — Maximum debug (very verbose)

---

## C Test Execution (VeeR Boot)

### Step 1: Build C Test Program

```bash
cd /home/student/Documents/1602-23-735-127/Aegis-V-SoC
RISCV_PREFIX=riscv64-unknown-elf- bash ctests/build_soc_c_test.sh
```

**What happens:**
1. Compiles `ctests/soc_c_test.c` with RISC-V GCC:
   - `-march=rv32imc` — RV32I + M (multiply) + C (compressed)
   - `-mabi=ilp32` — 32-bit integer ABI
   - `-nostartfiles` — Use custom startup (`soc_c_start.S`)
   - `-ffreestanding` — No hosted environment
   - `-O2` — Optimization level 2
2. Links with `ctests/soc_c_test.ld` (places code at 0x00000000)
3. Generates:
   - `ctests/soc_c_test.elf` — ELF executable
   - `ctests/soc_c_test.ihex` — Intel HEX format
   - `ctests/soc_c_test.memh` — Verilog memory initialization (word-addressed)

**Expected Duration:** 5-10 seconds

**Expected Output:**
```
[build_soc_c_test.sh] Compiling soc_c_test.c ...
riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -O2 -Wall ...
[build_soc_c_test.sh] Linking soc_c_test.elf ...
riscv64-unknown-elf-gcc -T ctests/soc_c_test.ld -nostartfiles ...
[build_soc_c_test.sh] Generating soc_c_test.ihex ...
riscv64-unknown-elf-objcopy -O ihex soc_c_test.elf soc_c_test.ihex
[build_soc_c_test.sh] Converting to soc_c_test.memh ...
python3 ctests/ihex_to_memh.py soc_c_test.ihex soc_c_test.memh
[build_soc_c_test.sh] C test build complete.
  ELF:  ctests/soc_c_test.elf  (6128 bytes)
  HEX:  ctests/soc_c_test.ihex (3838 bytes)
  MEMH: ctests/soc_c_test.memh (3070 bytes)
```

**Verify files exist:**
```bash
ls -lh run/soc_c_test.*
```

### Step 2: Run C Test Simulation

```bash
cd /home/student/Documents/1602-23-735-127/Aegis-V-SoC/run
bash compile_soc.sh ctest
```

**What happens:**
1. Executes `simv_soc` with `+UVM_TESTNAME=aegis_soc_ctest_test`
2. Test sequence `aegis_soc_ctest_test`:
   - Loads `soc_c_test.memh` into external SRAM model (M00 @ 0x00000000)
   - Releases VeeR core from reset
   - Core boots from reset vector 0x00000000
   - Core executes C `main()` function
   - C program tests all 13 IPs via LSU AXI master
   - C program writes completion signature to mailbox (0x0003_FFFC)
3. UVM test polls mailbox:
   - If `0x600DC0DE` → reports PASS
   - If `0xBAD000NN` → reports FAIL (NN = failed IP index)
   - If timeout → reports TIMEOUT

**Expected Duration:** 1-2 minutes (CPU executing ~10,000 instructions)

**Expected Output:**
```
============================================================
 Aegis-V SoC — VCS C Test
============================================================
UVM_INFO @ 0: reporter [RNTST] Running test aegis_soc_ctest_test...

[CTEST] Loading C image: ./soc_c_test.memh into SRAM model
[CTEST] Loaded 1536 words (6144 bytes)
[CTEST] Releasing VeeR core reset...
[CTEST] Waiting for instruction fetch...
[CTEST] IFU fetch detected at PC=0x00000000
[CTEST] CPU running...

[CTEST] Checking M11 IMEM... OK
[CTEST] Checking M12 DMEM... OK
[CTEST] Checking M01 UART... OK (loopback passed)
[CTEST] Checking M02 AES... OK (KAT passed)
[CTEST] Checking M03 I2C... OK (prescaler readback)
[CTEST] Checking M04 PWM... OK (duty register)
[CTEST] Checking M05 SHA256... OK (identity match)
[CTEST] Checking M06 GPIO... OK (set/clear)
[CTEST] Checking M07 WDT... OK (load register)
[CTEST] Checking M08 DMA... OK (CSR programming)
[CTEST] Checking M09 SCS... OK (scratch register)
[CTEST] Checking M10 Timer... OK (mtime increment)

[CTEST] Polling mailbox at 0x0003FFFC...
[CTEST] Mailbox value detected: 0x600DC0DE
[CTEST] Completion signature PASS (0x600DC0DE)

--- UVM Report Summary ---
UVM_INFO :   24
UVM_WARNING :    0
UVM_ERROR :      0
UVM_FATAL :      0

AEGIS_UVM_RESULT=PASS
$finish at time 5000000 ns
```

**Log File:** `sim_ctest.log`

### C Test Failure Diagnostics

If C test reports `0xBAD000NN`:

| NN | IP | Failed Check | Debug Action |
|----|-----|-------------|--------------|
| 00 | M00 | External SRAM execution | Check memory model initialization |
| 01 | M01 | UART loopback | Check UART RX→TX connection, baud config |
| 02 | M02 | AES-128 KAT | Check AES key/data registers, encryption logic |
| 03 | M03 | I2C prescaler | Check Wishbone bridge, I2C register addressing |
| 04 | M04 | PWM duty | Check PWM register decode |
| 05 | M05 | SHA-256 ID | Check SHA-256 register map |
| 06 | M06 | GPIO set/clear | Check GPIO output register |
| 07 | M07 | WDT load | Check watchdog register |
| 08 | M08 | DMA CSR | Check DMA register decode |
| 09 | M09 | SCS scratch | Check SCS register |
| 10 | M10 | Timer mtime | Check timer enable and counter |
| 11 | M11 | IMEM read | Check IMEM initialization |
| 12 | M12 | DMEM write/read | Check DMEM byte strobes |

**Debug Steps:**
1. Increase UVM verbosity: `+UVM_VERBOSITY=UVM_HIGH`
2. Check log for last successful message before failure
3. Generate waveform (see next section)
4. Inspect AXI transactions to failed IP

---

## Waveform Debug

### Generate FSDB (Verdi)

```bash
cd /home/student/Documents/1602-23-735-127/Aegis-V-SoC/run

# For full test
./simv_soc +UVM_TESTNAME=aegis_soc_full_test \
  -ucli -do "fsdbDumpfile dump_soc.fsdb; fsdbDumpvars 0 tb_aegis_v_soc_uvm; run" \
  -l sim_fsdb.log

# For C test
./simv_soc +UVM_TESTNAME=aegis_soc_ctest_test +CORE_BOOT \
  -ucli -do "fsdbDumpfile dump_ctest.fsdb; fsdbDumpvars 0 tb_aegis_v_soc_uvm; run" \
  -l sim_ctest_fsdb.log
```

**View with Verdi:**
```bash
verdi -ssf dump_soc.fsdb &
```

**Key Signal Groups:**

| Signal Path | Description |
|-------------|-------------|
| `tb_aegis_v_soc_uvm.u_dut.u_veer.lsu_axi_*` | CPU LSU data bus (writes/reads to IPs) |
| `tb_aegis_v_soc_uvm.u_dut.u_veer.ifu_axi_*` | CPU IFU instruction fetch |
| `tb_aegis_v_soc_uvm.u_dut.u_interconnect.s00_axi_*` | Interconnect LSU slave port |
| `tb_aegis_v_soc_uvm.u_dut.u_interconnect.m01_axi_*` | UART master port (from crossbar) |
| `tb_aegis_v_soc_uvm.u_dut.u_bridge_uart.m_axil_*` | UART AXI-Lite (after bridge) |
| `tb_aegis_v_soc_uvm.u_dut.u_uart.axi_*` | UART registers |
| `tb_aegis_v_soc_uvm.u_dut.uart_tx` | UART serial output |
| `tb_aegis_v_soc_uvm.u_mem_model.mem[*]` | External SRAM contents (C program) |

### Generate VCD (Faster, Larger File)

VCD dump is enabled by default. File: `tb_aegis_v_soc_uvm.vcd`

```bash
gtkwave tb_aegis_v_soc_uvm.vcd &
```

---

## Test Summary Matrix

| Test | Command | Duration | Checks | Pass Criteria |
|------|---------|----------|--------|---------------|
| **Compile** | `compile_soc.sh compile` | 2-5 min | RTL syntax, UVM linking | 0 errors |
| **Peripheral** | `compile_soc.sh sim` | 30-60 sec | 12 IP register tests | `AEGIS_UVM_RESULT=PASS` |
| **C Boot** | `compile_soc.sh ctest` | 1-2 min | 13 IP functional tests | Mailbox = `0x600DC0DE` |
| **Individual** | `./simv_soc +UVM_TESTNAME=<test>` | 10-30 sec | 1 IP | No UVM_ERROR |

---

## Advanced Options

### Randomization Seeds

```bash
# Run with specific seed for reproducibility
./simv_soc +UVM_TESTNAME=aegis_soc_full_test +ntb_random_seed=12345

# Random seed (time-based)
./simv_soc +UVM_TESTNAME=aegis_soc_full_test +ntb_random_seed_automatic
```

### Coverage Collection

```bash
# Enable functional coverage
./simv_soc +UVM_TESTNAME=aegis_soc_full_test -cm line+cond+fsm+tgl+branch \
  -cm_dir simv.vdb -cm_name full_test
```

### Regression Run (All Tests)

```bash
#!/bin/bash
# run_regression.sh — Run all tests and collect results

TESTS="sanity_test uart_test aes_test i2c_test pwm_test sha256_test \
       gpio_test wdt_test dma_test scs_test timer_test imem_test dmem_test full_test"

for TEST in $TESTS; do
    echo "Running aegis_soc_${TEST}..."
    ./simv_soc +UVM_TESTNAME=aegis_soc_${TEST} +UVM_VERBOSITY=UVM_NONE \
      -l sim_${TEST}.log > /dev/null 2>&1
    if grep -q "AEGIS_UVM_RESULT=PASS" sim_${TEST}.log; then
        echo "  [PASS] $TEST"
    else
        echo "  [FAIL] $TEST"
    fi
done

# C test
./simv_soc +UVM_TESTNAME=aegis_soc_ctest_test +CORE_BOOT \
  -l sim_ctest.log > /dev/null 2>&1
if grep -q "AEGIS_UVM_RESULT=PASS" sim_ctest.log; then
    echo "  [PASS] ctest"
else
    echo "  [FAIL] ctest"
fi

echo "Regression complete. Check sim_*.log for details."
```

---

## Troubleshooting

### Simulation Hangs

**Symptom:** Simulation runs but never completes  
**Causes:**
1. AXI deadlock (VALID without READY)
2. Infinite loop in C code
3. Mailbox polling timeout

**Debug:**
1. Add timeout: `timeout 60s ./simv_soc ...`
2. Check waveform for stuck handshakes
3. Increase UVM_VERBOSITY to see last transaction

### UVM_FATAL Errors

**Symptom:** Simulation aborts with `UVM_FATAL`  
**Common causes:**
| Fatal Message | Cause | Fix |
|---------------|-------|-----|
| `NO_VIF` | Virtual interface not found | Check `uvm_config_db` setup in test |
| `AXIL_TIMEOUT` | AXI-Lite handshake timeout | Check target IP READY signals |
| `REG_MISMATCH` | Register read != expected | Check IP register implementation |

### No PASS Result

**Symptom:** Simulation completes but no `AEGIS_UVM_RESULT=PASS`  
**Debug:**
```bash
# Check for UVM errors
grep "UVM_ERROR" sim_soc.log

# Check test completion
grep "Report Summary" sim_soc.log

# Check mailbox (C test only)
grep "Mailbox" sim_ctest.log
```

---

## Success Criteria Checklist

### ✅ Compilation Success
- [ ] `compile_soc.sh compile` exits with status 0
- [ ] `compile_soc.log` reports 0 errors
- [ ] `simv_soc` executable created (15-20 MB)
- [ ] No licensing errors

### ✅ Peripheral Test Success
- [ ] `compile_soc.sh sim` exits with status 0
- [ ] `sim_soc.log` shows all 12 IP tests passed
- [ ] `AEGIS_UVM_RESULT=PASS` appears in log
- [ ] UVM summary shows 0 errors, 0 warnings

### ✅ C Test Success
- [ ] `build_soc_c_test.sh` creates `.elf`, `.ihex`, `.memh`
- [ ] `compile_soc.sh ctest` exits with status 0
- [ ] `sim_ctest.log` shows mailbox value `0x600DC0DE`
- [ ] `AEGIS_UVM_RESULT=PASS` appears in log
- [ ] All 13 IP checks passed

---

## Next Steps After Successful Tests

1. **Coverage Analysis:** Review functional coverage reports
2. **Timing:** Synthesize and check timing constraints
3. **Power:** Run power analysis with switching activity
4. **Additional Tests:** Add stress tests, random sequences, corner cases
5. **Documentation:** Update verification closure report

---

**End of Execution Guide**
