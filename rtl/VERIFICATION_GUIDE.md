# Aegis-V-SoC IP Module Verification Guide

## Project Location
`/home/student/Documents/1602-23-735-127/Aegis-V-SoC`

## Tool Requirements
- **VCS** (Synopsys) with `-full64 -sverilog` support
- **Verdi** for waveform viewing (FSDB format)
- **FSDB** libraries must be in `$LD_LIBRARY_PATH` / `$VCS_HOME`

---

## Module Overview and AXI-Lite Status

| Module | Top Module | AXI-Lite | Interface |
|--------|-----------|----------|-----------|
| PWM | `myip_v1_0` | ✅ Yes | 4-bit addr, 32-bit data |
| SHA256 | `sha256_axi4` | ✅ Yes | 8-bit addr, 32-bit data |
| Watchdog Timer | `EF_WDT32` | ❌ No (bare core) | Direct hardware signals |
| DMA CSR | `csr_dma` | ✅ Yes | 8-bit addr, 64-bit data |
| System Timer | `timer_core` | ❌ No (TileLink at top) | Direct core signals |
| GPIO | `gpio_axi_lite_wrap` | ✅ Yes | 32-bit addr, 32-bit data |
| System Ctrl/Status | `system_control_status` | ✅ Yes | 5-bit addr, 32-bit data |
| Instruction Memory | `instruction_memory` | ✅ Yes | 32-bit addr, 32-bit data |
| Data Memory | `data_memory` | ✅ Yes | 32-bit addr, 32-bit data |

> **Note:** The rv_timer top module uses TileLink-UL (not AXI-Lite). The testbench verifies `timer_core` directly. The WDT is a bare hardware core without a bus interface.

---

## Per-Module Commands

### 1. PWM Controller (`myip_v1_0`)
**Location:** `rtl/AXI4-Lite-PWM-Controller-IP-Zynq-PYNQ--main/run/`

```bash
cd rtl/AXI4-Lite-PWM-Controller-IP-Zynq-PYNQ--main/run

# Compile
vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log

# Simulate
./simv -ucli -do "fsdbDumpfile dump_pwm.fsdb; fsdbDumpvars 0 tb_pwm; run"

# Verdi
verdi -dbdir simv.daidir -ssf dump_pwm.fsdb -nologo &
# Load signals: File → Load Signal File → pwm_signals.rc
```

**Signals to verify:** `PWM_OUT`, `slv_reg0` (duty_cycle), `pwm_counter`, AXI write/read handshakes.

**Tests:** 50% duty (0x80), max duty (0xFF), 0% duty (0x00), register R/W (slv_reg1–3).

---

### 2. SHA-256 (`sha256_axi4`)
**Location:** `rtl/sha256/run/`

```bash
cd rtl/sha256/run

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
./simv -ucli -do "fsdbDumpfile dump_sha256.fsdb; fsdbDumpvars 0 tb_sha256; run"
verdi -dbdir simv.daidir -ssf dump_sha256.fsdb -nologo &
# Load signals: sha256_signals.rc
```

**Signals to verify:** `hash_complete`, `core.ready`, `core.digest_valid`, `core.digest[255:0]`, AXI handshakes.

**Tests:** Read NAME0/NAME1/VERSION, CTRL init, write 16 BLOCK words, CTRL next, read DIGEST.

---

### 3. Watchdog Timer (`EF_WDT32`)
**Location:** `rtl/EF_WDT32/run/`

```bash
cd rtl/EF_WDT32/run

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
./simv -ucli -do "fsdbDumpfile dump_wdt.fsdb; fsdbDumpvars 0 tb_wdt; run"
verdi -dbdir simv.daidir -ssf dump_wdt.fsdb -nologo &
# Load signals: wdt_signals.rc
```

**Signals to verify:** `WDTMR` (counter), `WDTTO` (timeout), `WDTEN` (enable), `WDTLOAD` (load value).

**Tests:** Load=100 decrement+timeout, disable reload, new load=50.

---

### 4. AXI DMA CSR (`csr_dma`)
**Location:** `rtl/axi_dma/run/`

```bash
cd rtl/axi_dma/run

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
./simv -ucli -do "fsdbDumpfile dump_dma.fsdb; fsdbDumpvars 0 tb_dma; run"
verdi -dbdir simv.daidir -ssf dump_dma.fsdb -nologo &
# Load signals: dma_signals.rc
```

**Signals to verify:** `i_awaddr/o_awready`, `i_wdata/o_wready`, `o_bvalid`, `o_rdata`, `o_dma_control_go`, `o_dma_desc_src_addr_src_addr`, `o_dma_desc_dst_addr_dst_addr`.

**Tests:** Read version (0xCAFE), write/read src_addr (0x1000), dst_addr (0x2000), num_bytes (0x100), control go=1.

---

### 5. System Timer / rv_timer (`timer_core`)
**Location:** `rtl/rv_timer/run/`

```bash
cd rtl/rv_timer/run

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
./simv -ucli -do "fsdbDumpfile dump_rv_timer.fsdb; fsdbDumpvars 0 tb_timer_core; run"
verdi -dbdir simv.daidir -ssf dump_rv_timer.fsdb -nologo &
# Load signals: rv_timer_signals.rc
```

**Signals to verify:** `active`, `prescaler`, `step`, `tick`, `mtime`, `mtime_d`, `mtimecmp[0]`, `intr[0]`.

**Tests:** mtime increment by step, tick assertion with prescaler=0, interrupt at mtime≥mtimecmp, intr deassert when active=0, prescaler behavior.

---

### 6. GPIO AXI4-Lite (`gpio_axi_lite_wrap`)
**Location:** `rtl/gpio/run/`

```bash
cd rtl/gpio/run

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
./simv -ucli -do "fsdbDumpfile dump_gpio.fsdb; fsdbDumpvars 0 tb_gpio_flat; run"
verdi -dbdir simv.daidir -ssf dump_gpio.fsdb -nologo &
# Load signals: gpio_signals.rc
```

**Signals to verify:** `gpio_in`, `gpio_out`, `gpio_tx_en_o`, `gpio_in_sync_o`, `global_interrupt_o`, AXI handshakes.

**Tests:** Read GPIO_INFO, write/read GPIO_GPIO_OUT (0xFF), verify gpio_out port, GPIO_MODE_0, drive gpio_in (0xA5A5A5A5) → read GPIO_GPIO_IN, gpio_in_sync_o, GPIO_SET, GPIO_CLEAR, GPIO_TOGGLE.

---

### 7. System Control & Status (`system_control_status`)
**Location:** `rtl/System-Control-Status-IP/run/`

```bash
cd rtl/System-Control-Status-IP/run

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
./simv -ucli -do "fsdbDumpfile dump_scs.fsdb; fsdbDumpvars 0 tb_system_control_status; run"
verdi -dbdir simv.daidir -ssf dump_scs.fsdb -nologo &
# Load signals: scs_signals.rc
```

**Signals to verify:** `sys_enable`, `soft_reset`, `debug_enable`, `low_power`, `irq_global_enable`, `irq`, `sys_ctrl`, `irq_status`, `counter`.

**Tests:** Read IP_ID (0xAE615001), VERSION (0x00010000), write SYS_CTRL, write SCRATCH, verify output pins, IRQ test with security_error, write-1-to-clear IRQ_STATUS, SYS_STATUS with inputs, COUNTER increment.

---

### 8. Instruction Memory (`instruction_memory`)
**Location:** `rtl/Instruction-Memory-IP/run/`

```bash
cd rtl/Instruction-Memory-IP/run

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
./simv -ucli -do "fsdbDumpfile dump_imem.fsdb; fsdbDumpvars 0 tb_instruction_memory; run"
verdi -dbdir simv.daidir -ssf dump_imem.fsdb -nologo &
# Load signals: instruction_memory_signals.rc
```

**Signals to verify:** `s_axi_araddr/arvalid/arready`, `s_axi_rdata/rresp/rvalid`, `s_axi_bresp` (write → SLVERR), `u_imem.mem`.

**Tests:** Write rejected (SLVERR bresp=2'b10), read address 0x0, 0x4, 0x8 (all OKAY).

---

### 9. Data Memory (`data_memory`)
**Location:** `rtl/Data-Memory-IP/run/`

```bash
cd rtl/Data-Memory-IP/run

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f run.f -l compile.log
./simv -ucli -do "fsdbDumpfile dump_dmem.fsdb; fsdbDumpvars 0 tb_data_memory; run"
verdi -dbdir simv.daidir -ssf dump_dmem.fsdb -nologo &
# Load signals: data_memory_signals.rc
```

**Signals to verify:** `s_axi_awaddr/wdata/wstrb`, `s_axi_araddr/rdata`, `s_axi_bresp/rresp`, `u_dmem.mem`.

**Tests:** Word write/read (0x12345678, 0xA5A55A5A), byte-write (byte0=0xBB, byte3=0xCC), halfword-write, sequential DEPTH-words write+read, bresp/rresp = OKAY.

---

## Run All Modules at Once

```bash
cd rtl
./run_all.sh              # run all 9 modules
./run_all.sh pwm          # run only PWM
./run_all.sh sha256       # run only SHA256
./run_all.sh wdt          # run only WDT
./run_all.sh dma          # run only DMA
./run_all.sh timer        # run only rv_timer
./run_all.sh gpio         # run only GPIO
./run_all.sh scs          # run only System Control Status
./run_all.sh imem         # run only Instruction Memory
./run_all.sh dmem         # run only Data Memory
```

---

## Loading .rc Files in Verdi

After opening Verdi with the FSDB file:
1. In the waveform window: **File → Load Signal File** → select the `.rc` file
2. Or via command: `verdi -dbdir simv.daidir -ssf dump_XXX.fsdb -rcFile XXX_signals.rc -nologo &`

---

## Key Signals to Verify Per Module

### AXI4-Lite Handshake Signals (common to AXI modules)
| Signal | Direction | Description |
|--------|-----------|-------------|
| `s_axi_awvalid` | Master→Slave | Write address valid |
| `s_axi_awready` | Slave→Master | Write address ready |
| `s_axi_wvalid` | Master→Slave | Write data valid |
| `s_axi_wready` | Slave→Master | Write data ready |
| `s_axi_bvalid` | Slave→Master | Write response valid |
| `s_axi_bready` | Master→Slave | Write response ready |
| `s_axi_bresp` | Slave→Master | Write response (00=OK, 10=SLVERR) |
| `s_axi_arvalid` | Master→Slave | Read address valid |
| `s_axi_arready` | Slave→Master | Read address ready |
| `s_axi_rvalid` | Slave→Master | Read data valid |
| `s_axi_rready` | Master→Slave | Read data ready |
| `s_axi_rdata` | Slave→Master | Read data |
| `s_axi_rresp` | Slave→Master | Read response (00=OK) |

### Module-Specific Signals
| Module | Key Signals |
|--------|-------------|
| PWM | `PWM_OUT`, `duty_cycle`, `pwm_counter` |
| SHA256 | `hash_complete`, `core.ready`, `core.digest_valid`, `core.digest` |
| WDT | `WDTMR`, `WDTTO`, `WDTEN`, `WDTLOAD` |
| DMA | `o_dma_control_go`, `o_dma_desc_src_addr`, `o_dma_done_o`, `o_dma_error_o` |
| rv_timer | `tick`, `mtime`, `mtime_d`, `intr[0]`, `active`, `prescaler` |
| GPIO | `gpio_in`, `gpio_out`, `gpio_tx_en_o`, `gpio_in_sync_o`, `global_interrupt_o` |
| SCS | `sys_enable`, `soft_reset`, `irq`, `irq_status`, `counter` |
| IMEM | `s_axi_rdata`, `s_axi_bresp` (SLVERR on write), `mem` |
| DMEM | `s_axi_wstrb`, `s_axi_rdata`, `s_axi_bresp`, `mem` |
