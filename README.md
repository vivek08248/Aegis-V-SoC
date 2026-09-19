# Aegis‑V SoC

![Project](https://img.shields.io/badge/Project-Aegis--V-blue)

**Aegis‑V — Compact, secure RISC‑V edge-node SoC with hardware SHA‑256, high‑precision PWM, and windowed watchdog**

RISC‑V based secure edge-control System-on-Chip (RV32I, Verilog)

## Project
**Aegis-V** — Design and Verification of a RISC-V Secure Edge Node SoC with Hardware SHA-256 Engine, High-Precision PWM, and Windowed Watchdog

## Author
- Name: Vivek Chakali  
- Roll Number: 1602-23-735-127

## Highlights
- AXI interconnect fabric present and verified for **2 AXI4 initiators × 11 AXI4 target ports**
- UART integration path implemented: **AXI4 master port M10 → AXI4-to-AXI4-Lite bridge → AXI-Lite UART IP**
- Standalone interconnect verification with BFMs, arbitration tests, concurrent traffic tests, and DECERR checks
- Full UART-subsystem integration testbench with loopback, IRQ, FIFO/back-to-back traffic, and LSR polling
- Simulation collateral centered on Synopsys VCS + Verdi (with alternate tb/ flow for Questa/Xcelium)

## Architecture (short)
- `axi_interconnect_wrap_2x11` wraps `axi_interconnect` for 2 slave-side masters (`s00`,`s01`) and 11 master-side outputs (`m00`..`m10`)
- `axi_uart_subsystem` maps M10 to UART via `axi4_to_axilite_bridge` and `axi_uart_top`
- M00/M01 are exposed externally in subsystem; M02–M09 are currently stubbed in subsystem integration

## Block Diagram
<p align="center"><img src="doc/block_diagram.png" alt="Aegis-V block diagram" width="650"/></p>

## Memory Map (summary)
- `0x0000_0000` – `0x00FF_FFFF` : M00 window (default 16 MB in subsystem/testbenches)
- `0x0100_0000` – `0x01FF_FFFF` : M01 window
- `0x0200_0000` – `0x09FF_FFFF` : M02–M09 windows (defined; subsystem currently stubs M02–M09)
- `0x1000_0000` – `0x1000_0FFF` : M10 UART window in `axi_uart_subsystem` (4 KB, `UART_ADDR_WIN_BITS=12`)

---

## 1) Project overview and current goals
The currently integrated, runnable RTL in this repository is focused on validating a reusable AXI4 interconnect backbone and a UART integration path rather than a complete RV32I SoC with all peripherals described in the short project tagline.

The active implementation and verification center on:
1. AXI interconnect behavior (decode, arbitration, routing, response propagation)
2. End-to-end UART memory-mapped access through an AXI4-to-AXI4-Lite bridge
3. Reproducible simulation/debug flows with VCS/Verdi and waveform scripts

## 2) Implemented vs planned/stubbed blocks
### Implemented/integrated in visible top-level subsystem RTL
- `rtl/interconnect/axi_interconnect.v`
- `rtl/interconnect/axi_interconnect_wrap_2x11.v`
- `rtl/interconnect/axi4_to_axilite_bridge.v`
- `rtl/interconnect/axi_uart_subsystem.v`
- UART IP path:
  - `rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v`
  - `.../uart_controller.v`, `.../uart_transmitter.v`, `.../uart_receiver.v`, `.../axi_internal_fifo.v`

### Exposed but not fully integrated in subsystem
- `m00`, `m01` interfaces are exposed by `axi_uart_subsystem` for external attachment
- `m02`..`m09` are tied off with passive no-response stubs in `axi_uart_subsystem`

### Imported but not wired into `axi_uart_subsystem`
- AES IP under `rtl/aes_core-master/`
- I2C IP under `rtl/i2c-master/`

## 3) Detailed architecture and data/control flow
1. Two AXI4 initiators drive interconnect slave-side ports:
   - `s00` (primary master)
   - `s01` (secondary master)
2. `arbiter.v` + `priority_encoder.v` support request/grant selection inside `axi_interconnect.v`.
3. Address decode in `axi_interconnect.v` compares address against packed `M_BASE_ADDR`/`M_ADDR_WIDTH` windows.
4. If decode hits:
   - request is routed to exactly one `mXX` port
   - write/read channels are forwarded, response returned to requesting slave-side master
5. If decode misses:
   - write returns `BRESP=2'b11` (DECERR)
   - read returns `RRESP=2'b11` (DECERR)
6. In `axi_uart_subsystem.v`, M10 is dedicated to UART:
   - interconnect M10 AXI4 signals (`ic_m10_*`) enter `axi4_to_axilite_bridge`
   - bridge truncates address to 5 bits for AXI-Lite UART (`LITE_ADDR_W=5`)
   - UART IP (`axi_uart_top`) services register transactions
7. UART loopback in integration testbench:
   - `uart_rx = uart_tx`
   - write THR → serial TX → loopback RX → RX FIFO
   - LSR `DATA_READY` polled, then RBR read back

## 4) Repository layout (current)
```text
Aegis-V-SoC/
├── README.md
├── .gitignore
├── doc/
│   ├── Aegis_V_Architecture_Specs.docx
│   └── block_diagram.png
├── rtl/
│   ├── interconnect/
│   │   ├── priority_encoder.v
│   │   ├── arbiter.v
│   │   ├── axi_interconnect.v
│   │   ├── axi_interconnect_wrap_2x11.v
│   │   ├── axi4_to_axilite_bridge.v
│   │   ├── axi_uart_subsystem.v
│   │   └── tb_axi_interconnect_uart.v
│   ├── axi-lite_uart-ipcore-develop/
│   │   ├── src/include/*.vh
│   │   ├── src/rtl/*.v
│   │   ├── src/run/run.f
│   │   ├── README.md / Makefile / project.config
│   │   └── .github/workflows/*.yml
│   ├── aes_core-master/
│   │   ├── rtl/verilog/*.v
│   │   ├── bench/verilog/*.v
│   │   ├── sim/rtl_sim/run/*
│   │   ├── aes_core.core
│   │   └── .github/workflows/fusesoc.yml
│   └── i2c-master/
│       ├── rtl/verilog/*.v
│       ├── rtl/vhdl/*
│       ├── bench/verilog/*.v
│       ├── sim/i2c_verilog/run/*
│       ├── i2c.core
│       └── .github/workflows/ci.yml
├── tb/
│   ├── axi_master_bfm.v
│   ├── axi_slave_bfm.v
│   ├── tb_axi_interconnect_wrap_2x11.v
│   ├── tb_axi_interconnect_uart.v
│   ├── run.f
│   ├── run.sh
│   └── *.png waveform/screenshots
├── run/
│   ├── run.f
│   ├── run.sh
│   ├── verdi_wave_interconnect.tcl
│   ├── verdi_wave_uart.tcl
│   ├── axi_interconnect_wrap.py
│   ├── vc_hdrs.h
│   └── verdi_config_file
└── scripts/
    └── axi_interconnect_wrap.py
```

## 5) Module/file responsibility table
| File | Responsibility |
|---|---|
| `rtl/interconnect/priority_encoder.v` | Generic priority encoder used by arbiter |
| `rtl/interconnect/arbiter.v` | Configurable arbitration (fixed/round-robin options) |
| `rtl/interconnect/axi_interconnect.v` | Core 2D AXI routing/decode/arbitration/response FSM |
| `rtl/interconnect/axi_interconnect_wrap_2x11.v` | Port-expanded wrapper for 2 slave-side + 11 master-side AXI ports |
| `rtl/interconnect/axi4_to_axilite_bridge.v` | AXI4 single-beat adaptation to AXI4-Lite UART interface |
| `rtl/interconnect/axi_uart_subsystem.v` | Top integration: interconnect + bridge + UART, with M02–M09 stubs |
| `tb/axi_master_bfm.v` | Active AXI master BFM tasks (`do_write`, `do_read`) with response checks |
| `tb/axi_slave_bfm.v` | Memory-backed AXI slave BFM for standalone interconnect verification |
| `tb/tb_axi_interconnect_wrap_2x11.v` | Standalone interconnect functional/route/arbitration/DECERR tests |
| `tb/tb_axi_interconnect_uart.v` | UART integration/loopback/IRQ/FIFO/back-to-back tests |
| `run/run.f` | Main VCS filelist selecting interconnect-only or UART integration target |
| `run/run.sh` | High-level compile/sim/wave launcher for both targets |
| `tb/run.f`, `tb/run.sh` | Alternate local TB-centric compile/run flow (VCS/Questa/Xcelium) |
| `run/verdi_wave_interconnect.tcl` | nWave signal groups for interconnect debug |
| `run/verdi_wave_uart.tcl` | nWave signal groups for UART subsystem debug |
| `scripts/axi_interconnect_wrap.py` | Jinja2 wrapper generator (`-p`, `-n`, `-o`) |

## 6) Address map and UART register map used in RTL/testbenches
### Interconnect windows used by active subsystem/tests
`axi_uart_subsystem.v` defaults:
- M00 `0x0000_0000`, width `24` (16 MB)
- M01 `0x0100_0000`, width `24`
- M02..M09 `0x0200_0000`..`0x0900_0000`, width `24` each
- M10 `UART_BASE_ADDR=0x1000_0000`, width `UART_ADDR_WIN_BITS=12` (4 KB)

### Wrapper-generation defaults (important distinction)
`axi_interconnect_wrap_2x11.v` default params are `M00_BASE_ADDR=32'd0`, `M01_BASE_ADDR=32'd2`, ... `M10_BASE_ADDR=32'd20` with width 24; practical integrations (subsystem/testbenches) override with full 32-bit addresses.

### UART register map (from `axi_uart.vh` and integration TB)
Absolute addresses in integration TB:
- `0x1000_0000` : THR (write) / RBR (read)
- `0x1000_0004` : IER
- `0x1000_0008` : BAUD_DIVISOR (when `LCR[7]=DLAB=1`)
- `0x1000_000C` : LCR
- `0x1000_0014` : LSR

LSR bits used by tests:
- bit0 `DATA_READY`
- bit5 `THRE`
- bit6 `TEMT`

## 7) Simulation prerequisites and exact flows
### Prerequisites
- Synopsys VCS + Verdi expected for primary flow
- `run/run.sh` hardcodes:
  - `VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03`
  - `VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1`
- Verdi PLI paths are hardcoded in filelists/scripts

### Main flow (`run/`)
```bash
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/run
bash run.sh compile_a   # standalone interconnect target
bash run.sh compile_b   # UART integration target
bash run.sh sim
bash run.sh wave_a
bash run.sh wave_b
```
Also available:
- `bash run.sh all_a`
- `bash run.sh all_b`
- `bash run.sh clean`

Generated artifacts include `simv`, `simv.daidir/`, `compile.log`, `sim.log`, and FSDBs (`dump_interconnect.fsdb` or `dump_uart.fsdb`).

### TB-local flow (`tb/`)
```bash
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/tb
bash run.sh                 # default VCS
SIM=questa  bash run.sh     # Questa/ModelSim
SIM=xcelium bash run.sh     # Xcelium/xrun
```

### Note on active target in filelists
- `run/run.sh` can toggle `run.f` lines for target A/B.
- Current checked-in `run/run.f` has `tb_axi_interconnect_uart.v` active and standalone TB commented.

## 8) Verification strategy and covered scenarios
### Standalone interconnect TB (`tb_axi_interconnect_wrap_2x11.v`)
Covers:
- reset/idle sanity
- directed read/write via M00/M01
- routing across M02..M10
- concurrent accesses from both masters
- arbitration when both masters target same slave (M03)
- unmapped address DECERR (`0xDEAD_0000`) for both B and R channels
- FSDB dump: `dump_interconnect.fsdb`

BFM behavior:
- `axi_master_bfm.v` enforces timeouts and decodes OKAY/SLVERR/DECERR
- `axi_slave_bfm.v` memory-backed single-beat slave model returns OKAY and logs transactions

### UART integration TB (`tb_axi_interconnect_uart.v`)
Covers:
- UART configuration sequence: DLAB, baud divisor, 8N1, IER enable
- loopback bytes from both s00 and s01 paths (`0xA5`, `0x3C`)
- LSR polling until `DATA_READY`
- IRQ de-assertion after RBR drain
- back-to-back TX writes (`0x11`,`0x22`,`0x33`) and readback verification
- LSR TX-empty flags (`THRE`,`TEMT`)
- FSDB dump: `dump_uart.fsdb`

## 9) Wrapper generator usage (`scripts/axi_interconnect_wrap.py`)
The repository contains identical generator scripts in:
- `scripts/axi_interconnect_wrap.py`
- `run/axi_interconnect_wrap.py`

Dependency:
- Python package `jinja2` (script imports `Template`)

Usage:
```bash
python /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/scripts/axi_interconnect_wrap.py -p 2 11 -n axi_interconnect_wrap_2x11 -o axi_interconnect_wrap_2x11.v
```

`-p` accepts one value (same master/slave count) or two values (`m n`).

## 10) Imported IP notes (AES/I2C/UART)
### UART IP (`rtl/axi-lite_uart-ipcore-develop/`)
- Includes RTL, headers, testbench, Makefile-based flow, CI configs, and license
- This IP **is integrated** in `axi_uart_subsystem.v`

### AES IP (`rtl/aes_core-master/`)
- Includes AES RTL, AXI slave wrapper (`aes_axi_slave.v`), docs, core file, workflow, sim/syn collateral
- Contains generated simulation artifacts (e.g., `sim.out.daidir/` hierarchy)
- **Not connected** to `axi_uart_subsystem.v` in currently visible top-level integration

### I2C IP (`rtl/i2c-master/`)
- Includes Verilog and VHDL implementations, benches, FuseSoC core, docs, and CI
- **Not connected** to `axi_uart_subsystem.v` in currently visible top-level integration

## 11) Known limitations and current integration status
- The README tagline references a broader SoC feature set (CPU/SHA/PWM/watchdog), but the visible top-level integrated RTL in this repo primarily demonstrates interconnect + UART path validation.
- In `axi_uart_subsystem.v`, M02–M09 are intentionally stubbed and do not represent active peripheral integrations.
- Interconnect wrapper default base parameters (small decimal constants) are template defaults; practical system maps rely on override values from subsystem/testbench instantiations.
- Commit history appears shallow in this clone (only two visible commits).

## 12) Commit-history / project evolution (visible in this clone)
Visible commits (date: 2026-09-19):
1. `8e03649` — “Update README”
   - Large initial repository population: interconnect RTL, UART/AES/I2C imported collateral, testbenches, run scripts, docs, and media
2. `378e9e6` — “feat: integrated AXI4-to-AXI-Lite bridge for UART subsystem”
   - UART integration-focused updates and waveform/output artifacts

> Note: this summary is constrained to commits available in the current checkout.

## 13) Contribution/dev guidance and provenance notes
- Keep generated artifacts out of source control where possible; root `.gitignore` already excludes common VCS/Verdi/xrun/Vivado/Quartus/python build outputs.
- For this repository, prefer modifying source under `rtl/interconnect/`, `tb/`, `run/`, and root docs while treating imported third-party IP trees as vendored unless intentionally updating them.
- License/provenance signals in-tree:
  - Alex Forencich license headers in interconnect-related sources
  - MIT license file in UART IP subtree
  - FuseSoC/core metadata and historical notices in AES/I2C subtrees
- No top-level `LICENSE` file is currently present at repository root.

## 14) Quick reference commands
All commands below use repository-absolute paths.

```bash
# Main flow
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/run
bash run.sh compile_a
bash run.sh compile_b
bash run.sh sim
bash run.sh wave_a
bash run.sh wave_b

# TB-local flow
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/tb
bash run.sh
SIM=questa  bash run.sh
SIM=xcelium bash run.sh

# Wrapper generation (requires jinja2)
python /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/scripts/axi_interconnect_wrap.py -p 2 11 -n axi_interconnect_wrap_2x11 -o axi_interconnect_wrap_2x11.v
```
