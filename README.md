# Aegis‑V SoC

[![Project](https://img.shields.io/badge/Project-Aegis--V-blue)](https://github.com/vivek08248/Aegis-V-SoC)

**Aegis‑V — RISC‑V (VeeR EL2) edge-node SoC with AXI4 interconnect, AXI‑Lite UART, AXI‑Lite AES‑128, and a Wishbone I2C master bridged onto AXI‑Lite**

Repository: [github.com/vivek08248/Aegis-V-SoC](https://github.com/vivek08248/Aegis-V-SoC)

RISC‑V based secure edge-control System-on-Chip (RV32/RV64 VeeR EL2 core, Verilog/SystemVerilog)

## Project
**Aegis-V** — Design and Verification of a RISC-V Secure Edge Node SoC with an Integrated VeeR EL2 Core, Hardware AES‑128 Engine, AXI‑Lite UART, and Wishbone I2C Master

## Author
- Name: Vivek Chakali
- Roll Number: 1602-23-735-127

## Highlights
- **Full SoC top-level (`aegis_v_soc.v`)** now instantiates and wires a **VeeR EL2 RISC‑V core**, the AXI4 interconnect, and three peripherals (UART, AES‑128, I2C) into one integrated design
- AXI interconnect fabric present and verified for **2 AXI4 initiators × 11 AXI4 target ports**, now carrying the VeeR EL2 core's LSU (data) and IFU (instruction) AXI4 masters on `s00`/`s01`
- Peripheral integration paths: **M01 → UART** (AXI4→AXI4‑Lite bridge → `axi_uart_top`), **M02 → AES‑128** (AXI4→AXI4‑Lite bridge → `aes_axi_slave`), **M03 → I2C** (AXI4→AXI4‑Lite bridge → new `wb_to_axilite_bridge` → `i2c_master_top`)
- New top-level SoC testbench (`tb_aegis_v_soc.v`) exercises SRAM read/write, UART config + TX/RX loopback, AES‑128 encryption against a NIST FIPS‑197 test vector, and I2C Wishbone register access in one run
- Standalone interconnect verification with BFMs, arbitration tests, concurrent traffic tests, and DECERR checks (unchanged)
- Full UART-subsystem integration testbench with loopback, IRQ, FIFO/back-to-back traffic, and LSR polling (unchanged)
- I2C master IP now has its own standalone VCS/Verdi simulation flow (`rtl/i2c-master/run/`) in addition to being wired into the SoC
- Simulation collateral centered on Synopsys VCS + Verdi (with alternate `tb/` flow for Questa/Xcelium)

## Architecture (short)
- `aegis_v_soc.v` is the new top-level module: VeeR EL2 core (`el2_veer_wrapper` + `el2_mem`) → `axi_interconnect_wrap_2x11` → three `axi4_to_axilite_bridge` instances → `axi_uart_top`, `aes_axi_slave`, and (via `wb_to_axilite_bridge`) `i2c_master_top`
- `axi_interconnect_wrap_2x11` wraps `axi_interconnect` for 2 slave-side masters (`s00`,`s01`) and 11 master-side outputs (`m00`..`m10`)
- `axi_uart_subsystem` still exists as the standalone M10-based UART integration target (`TARGET B`) used by its own testbench; it is separate from the M01-based UART instance inside `aegis_v_soc`
- M00 is exposed externally from `aegis_v_soc` as an off-chip SRAM/boot-ROM AXI4 port; M04–M10 are reserved for future peripherals

## Block Diagram
<p align="center"><img src="doc/block_diagram.png" alt="Aegis-V block diagram" width="650"/></p>

## Memory Map (summary)
### `aegis_v_soc` top-level SoC address map (32-bit physical)
- `0x0000_0000` – `0x0FFF_FFFF` : External SRAM / boot ROM, 256 MB, exposed as the M00 AXI4 port
- `0x1000_0000` – `0x1000_0FFF` : UART (M01), 4 KB
- `0x2000_0000` – `0x2000_0FFF` : AES‑128 (M02), 4 KB
- `0x3000_0000` – `0x3000_0FFF` : I2C master, bridged from Wishbone (M03), 4 KB
- M04–M10 : reserved for future peripherals

### Legacy interconnect windows (standalone/UART-only targets, unchanged)
- `0x0000_0000` – `0x00FF_FFFF` : M00 window (default 16 MB in subsystem/testbenches)
- `0x0100_0000` – `0x01FF_FFFF` : M01 window
- `0x0200_0000` – `0x09FF_FFFF` : M02–M09 windows (defined; `axi_uart_subsystem` currently stubs M02–M09)
- `0x1000_0000` – `0x1000_0FFF` : M10 UART window in `axi_uart_subsystem` (4 KB, `UART_ADDR_WIN_BITS=12`)

---

## 1) Project overview and current goals
The repository now contains a fully wired top-level SoC (`rtl/interconnect/aegis_v_soc.v`) that integrates a VeeR EL2 RISC‑V core with the AXI4 interconnect and three peripherals, alongside the previously validated interconnect/UART building blocks.

The active implementation and verification center on:
1. Top-level SoC integration: VeeR EL2 core + AXI4 interconnect + UART + AES‑128 + I2C, all instantiated in `aegis_v_soc.v`
2. AXI interconnect behavior (decode, arbitration, routing, response propagation) — verified standalone
3. End-to-end UART memory-mapped access through an AXI4-to-AXI4-Lite bridge — verified standalone and inside the SoC
4. AES‑128 encryption correctness against a known NIST test vector, exercised through the SoC's AXI‑Lite path
5. I2C Wishbone-register connectivity through the new `wb_to_axilite_bridge`, both standalone and inside the SoC
6. Reproducible simulation/debug flows with VCS/Verdi and waveform scripts

## 2) Implemented vs planned/stubbed blocks
### Implemented/integrated in the new top-level SoC (`aegis_v_soc.v`)
- `rtl/interconnect/aegis_v_soc.v` — top-level integration
- `rtl/Cores-VeeR-EL2/design/...` — VeeR EL2 RISC‑V core (`el2_veer_wrapper`, `el2_mem`, and supporting DEC/EXU/LSU/IFU/PMP/PIC/DMA/DMI blocks)
- `rtl/interconnect/axi_interconnect_wrap_2x11.v` (shared with the standalone target)
- `rtl/interconnect/axi4_to_axilite_bridge.v` — instantiated 3× (UART, AES, I2C)
- `rtl/interconnect/wb_to_axilite_bridge.v` — **new**, bridges the I2C core's Wishbone slave interface onto the AXI‑Lite side of the interconnect
- UART path: `rtl/axi-lite_uart-ipcore-develop/src/rtl/axi_uart_top.v` and its sub-blocks
- AES path: `rtl/aes_core-master/rtl/verilog/aes_axi_slave.v` and its sub-blocks — **now wired in**, previously only imported
- I2C path: `rtl/i2c-master/rtl/verilog/i2c_master_top.v` and its sub-blocks — **now wired in**, previously only imported

### Implemented/integrated in the standalone subsystem target (unchanged from before)
- `rtl/interconnect/axi_interconnect.v`
- `rtl/interconnect/axi_uart_subsystem.v` (`m00`, `m01` exposed externally; `m02`..`m09` tied off with passive no-response stubs)

### Known gaps in the SoC-level integration
- The VeeR EL2 core is **held in reset** in `tb_aegis_v_soc.v`; the testbench drives BFM-style writes directly onto the peripheral AXI‑Lite buses and the external SRAM model rather than having the CPU fetch/execute instructions, because the two VeeR-generated headers (`common_defines.vh`, `el2_param.vh`) are not checked into the repo (see §7 and §11)
- `run/run.sh` does not yet have a `compile_c`/`all_c`/`wave_c` target for the new SoC-level testbench; TARGET C must currently be compiled by hand per the instructions embedded in `run/run.f`

## 3) Detailed architecture and data/control flow
### Top-level SoC (`aegis_v_soc.v`)
1. VeeR EL2 core (`el2_veer_wrapper`, compiled with `+define+RV_BUILD_AXI4`) drives two AXI4 masters:
   - LSU AXI4 (data) → interconnect slave-side port `s00`
   - IFU AXI4 (instruction fetch) → interconnect slave-side port `s01`
   - The core's SB (debug system bus) and DMA AXI ports are tied off — not used in this SoC
   - VeeR's 64-bit data bus is truncated to the interconnect's 32-bit data width for peripheral accesses
2. `axi_interconnect_wrap_2x11` decodes/arbitrates/routes to `m00` (external SRAM, exposed at the top level) and `m01`/`m02`/`m03` (UART/AES/I2C)
3. Each of M01–M03 passes through its own `axi4_to_axilite_bridge` instance (`LITE_ADDR_W=5`) before reaching its peripheral
4. I2C is a Wishbone slave, not an AXI‑Lite slave, so its AXI‑Lite bridge output is fed into `wb_to_axilite_bridge`, which converts single-outstanding AXI‑Lite transactions into Wishbone B4 cycles (`wb_adr_i[2:0]`, `wb_dat_i/o[7:0]`, `wb_we_i`, `wb_stb_i`, `wb_cyc_i`, `wb_ack_o`) for `i2c_master_top`
5. A two-stage synchronous reset (`rst_sync1`/`rst_sync2`) derives the active-high VeeR reset, the active-low AXI/UART/AES/I2C reset, and the active-high reset used by `axi4_to_axilite_bridge`, all from the single active-low `rst_n` input

### Standalone interconnect / UART targets (unchanged)
1. Two AXI4 initiators drive interconnect slave-side ports: `s00` (primary master), `s01` (secondary master)
2. `arbiter.v` + `priority_encoder.v` support request/grant selection inside `axi_interconnect.v`
3. Address decode in `axi_interconnect.v` compares address against packed `M_BASE_ADDR`/`M_ADDR_WIDTH` windows
4. On a decode hit, the request is routed to exactly one `mXX` port and the response is returned to the requesting slave-side master; on a decode miss, `BRESP`/`RRESP` return `2'b11` (DECERR)
5. In `axi_uart_subsystem.v`, M10 is dedicated to UART via `axi4_to_axilite_bridge` → `axi_uart_top`
6. UART loopback (`uart_rx = uart_tx`): write THR → serial TX → loopback RX → RX FIFO; LSR `DATA_READY` polled, then RBR read back

## 4) Repository layout (current)
```text
Aegis-V-SoC/
├── README.md
├── .gitignore
├── doc/
│   ├── Aegis_V_Architecture_Specs.docx
│   ├── block_diagram.png
│   ├── Cores-Veer-EL2/
│   │   └── RISC-V_VeeR_EL2_PRM.pdf
│   ├── aes_core-master/
│   │   └── aes.pdf
│   ├── axi-lite_uart-ipcore-develop/
│   │   ├── axi-uart.png
│   │   └── axi-uart.vsdx
│   └── i2c-master/
│       └── i2c_specs.pdf
├── reg/                                 # reserved for future register-map docs (currently empty)
├── rtl/
│   ├── interconnect/
│   │   ├── priority_encoder.v
│   │   ├── arbiter.v
│   │   ├── axi_interconnect.v
│   │   ├── axi_interconnect_wrap_2x11.v
│   │   ├── axi4_to_axilite_bridge.v
│   │   ├── wb_to_axilite_bridge.v       # NEW: Wishbone <-> AXI-Lite bridge for I2C
│   │   ├── axi_uart_subsystem.v
│   │   ├── aegis_v_soc.v                # NEW: top-level SoC (VeeR EL2 + interconnect + peripherals)
│   │   └── tb_axi_interconnect_uart.v
│   ├── Cores-VeeR-EL2/                  # NEW: imported VeeR EL2 RISC-V core (Western Digital, Apache-2.0)
│   │   ├── design/ (el2_veer_wrapper.sv, el2_veer.sv, el2_mem.sv, dec/, exu/, lsu/, ifu/, dbg/, dmi/, lib/, ...)
│   │   ├── configs/ (veer.config, veer_config_gen.py — generates required headers, not yet run in-repo)
│   │   ├── testbench/, verification/, tools/, third_party/, docs/
│   │   └── LICENSE, MAINTAINERS.md, release-notes.md
│   ├── axi-lite_uart-ipcore-develop/
│   │   ├── src/include/*.vh
│   │   ├── src/rtl/*.v
│   │   ├── src/run/run.f
│   │   ├── README.md / Makefile / project.config
│   │   └── .github/workflows/*.yml
│   ├── aes_core-master/
│   │   ├── rtl/verilog/*.v              # now wired into aegis_v_soc.v via M02
│   │   ├── bench/verilog/*.v
│   │   ├── sim/rtl_sim/run/*
│   │   ├── aes_core.core
│   │   └── .github/workflows/fusesoc.yml
│   └── i2c-master/
│       ├── rtl/verilog/*.v              # now wired into aegis_v_soc.v via M03 + wb_to_axilite_bridge
│       ├── rtl/vhdl/*
│       ├── bench/verilog/*.v
│       ├── sim/i2c_verilog/run/*
│       ├── run/                         # NEW: standalone VCS/Verdi flow (run.f, run.sh, verdi_wave_i2c.tcl)
│       ├── i2c.core
│       └── .github/workflows/ci.yml
├── tb/
│   ├── axi_master_bfm.v
│   ├── axi_slave_bfm.v
│   ├── tb_axi_interconnect_wrap_2x11.v
│   ├── tb_axi_interconnect_uart.v
│   ├── tb_aegis_v_soc.v                 # NEW: top-level SoC testbench (SRAM/UART/AES/I2C)
│   ├── run.f
│   ├── run.sh
│   └── *.png waveform/screenshots (interconnect, UART, and now I2C)
├── run/
│   ├── run.f                            # now lists TARGET A/B/C (C = SoC w/ VeeR EL2, commented out by default)
│   ├── run.sh                           # still only automates TARGET A/B (compile_a/compile_b, wave_a/wave_b)
│   ├── verdi_wave_interconnect.tcl
│   ├── verdi_wave_uart.tcl
│   ├── axi_interconnect_wrap.py
│   ├── vc_hdrs.h
│   └── verdi_config_file
└── scripts/
    ├── axi_interconnect_wrap.py
    └── hello.c                          # NEW: minimal C sample (int add(a,b)), not yet part of a build flow
```

## 5) Module/file responsibility table
| File | Responsibility |
|---|---|
| `rtl/interconnect/priority_encoder.v` | Generic priority encoder used by arbiter |
| `rtl/interconnect/arbiter.v` | Configurable arbitration (fixed/round-robin options) |
| `rtl/interconnect/axi_interconnect.v` | Core 2D AXI routing/decode/arbitration/response FSM |
| `rtl/interconnect/axi_interconnect_wrap_2x11.v` | Port-expanded wrapper for 2 slave-side + 11 master-side AXI ports |
| `rtl/interconnect/axi4_to_axilite_bridge.v` | AXI4 single-beat adaptation to AXI4-Lite (instantiated 3× in `aegis_v_soc.v`) |
| `rtl/interconnect/wb_to_axilite_bridge.v` | **New.** Wishbone B4 (8‑bit) ↔ AXI4‑Lite bridge, single outstanding transaction, used to attach the I2C master |
| `rtl/interconnect/axi_uart_subsystem.v` | Standalone integration: interconnect + bridge + UART, with M02–M09 stubs |
| `rtl/interconnect/aegis_v_soc.v` | **New.** Top-level SoC: VeeR EL2 core + interconnect + UART/AES/I2C bridges and peripherals |
| `rtl/Cores-VeeR-EL2/design/el2_veer_wrapper.sv` | **New.** VeeR EL2 RISC‑V core top wrapper (AXI4 LSU/IFU/SB/DMA ports) |
| `rtl/Cores-VeeR-EL2/design/el2_mem.sv` | **New.** ICCM/DCCM on-chip memory for the VeeR core |
| `rtl/aes_core-master/rtl/verilog/aes_axi_slave.v` | AXI‑Lite AES‑128 register/core wrapper, now wired to M02 |
| `rtl/i2c-master/rtl/verilog/i2c_master_top.v` | Wishbone I2C master, now wired to M03 via `wb_to_axilite_bridge` |
| `tb/axi_master_bfm.v` | Active AXI master BFM tasks (`do_write`, `do_read`) with response checks |
| `tb/axi_slave_bfm.v` | Memory-backed AXI slave BFM for standalone interconnect verification |
| `tb/tb_axi_interconnect_wrap_2x11.v` | Standalone interconnect functional/route/arbitration/DECERR tests |
| `tb/tb_axi_interconnect_uart.v` | UART integration/loopback/IRQ/FIFO/back-to-back tests |
| `tb/tb_aegis_v_soc.v` | **New.** Top-level SoC testbench: SRAM read/write, UART config + loopback, AES‑128 vs. NIST test vector, I2C Wishbone register read, reset/connectivity checks |
| `run/run.f` | Main VCS filelist; now documents TARGET A (interconnect), TARGET B (UART), and TARGET C (full SoC, commented out) |
| `run/run.sh` | High-level compile/sim/wave launcher — currently automates TARGET A/B only |
| `tb/run.f`, `tb/run.sh` | Alternate local TB-centric compile/run flow (VCS/Questa/Xcelium) |
| `rtl/i2c-master/run/` | **New.** Standalone VCS/Verdi compile/sim/wave flow for the I2C master IP alone |
| `run/verdi_wave_interconnect.tcl` | nWave signal groups for interconnect debug |
| `run/verdi_wave_uart.tcl` | nWave signal groups for UART subsystem debug |
| `rtl/i2c-master/run/verdi_wave_i2c.tcl` | **New.** nWave signal groups for standalone I2C debug |
| `scripts/axi_interconnect_wrap.py` | Jinja2 wrapper generator (`-p`, `-n`, `-o`) |
| `scripts/hello.c` | **New.** Minimal C snippet (`add(a,b)`); not yet wired into any build/boot flow |

## 6) Address map and register maps used in RTL/testbenches
### `aegis_v_soc` SoC-level map (see §Memory Map above for the summary)
- M00 (external SRAM/boot ROM): `0x0000_0000`, 256 MB, exposed directly at the top level
- M01 (UART): `UART_BASE_ADDR = 32'h1000_0000`, 4 KB window (`PERIPH_ADDR_WIN = 12`)
- M02 (AES‑128): `AES_BASE_ADDR = 32'h2000_0000`, 4 KB window
- M03 (I2C, via `wb_to_axilite_bridge`): `I2C_BASE_ADDR (WB_BASE_ADDR) = 32'h3000_0000`, 4 KB window; the 3‑bit Wishbone register address is mapped to `WB_BASE_ADDR + {wb_adr, 2'b00}`

### UART register map (from `axi_uart.vh` and both integration TBs)
- `+0x00` : THR (write) / RBR (read)
- `+0x04` : IER
- `+0x08` : BAUD_DIVISOR (when `LCR[7]=DLAB=1`)
- `+0x0C` : LCR
- `+0x14` : LSR — bit0 `DATA_READY`, bit5 `THRE`, bit6 `TEMT`

### AES‑128 register map (from `tb_aegis_v_soc.v`, offsets relative to `AES_BASE_ADDR`)
- `+0x00` : CTRL/STATUS — bit0 `LD` (start encrypt), bit1 `KLD` (load key), bit2 (core reset), bit16 `DONE`, bit17 `KDONE`
- `+0x04`..`+0x10` : KEY[127:96] .. KEY[31:0] (4 × 32-bit words, MSB word first)
- `+0x14`..`+0x20` : PLAINTEXT[127:96] .. PLAINTEXT[31:0]
- `+0x24`..`+0x30` : CIPHERTEXT[127:96] .. CIPHERTEXT[31:0]
- Verified in `tb_aegis_v_soc.v` against the NIST FIPS‑197 Appendix B vector (key `2B7E1516…09CF4F3C`, plaintext `3243F6A8…E0370734`, expected ciphertext `3925841D…196A0B32`)

### I2C register map (Wishbone, via `wb_to_axilite_bridge`)
- Register 0 (`PRER_LO`) verified in `tb_aegis_v_soc.v` by forcing a Wishbone read directly on `u_wb_bridge`; reset default `0xFF`

### Legacy standalone interconnect windows (unchanged)
`axi_uart_subsystem.v` defaults:
- M00 `0x0000_0000`, width `24` (16 MB); M01 `0x0100_0000`, width `24`; M02..M09 `0x0200_0000`..`0x0900_0000`, width `24` each; M10 `UART_BASE_ADDR=0x1000_0000`, width `UART_ADDR_WIN_BITS=12` (4 KB)

`axi_interconnect_wrap_2x11.v` default params remain template values (`M00_BASE_ADDR=32'd0`, `M01_BASE_ADDR=32'd2`, ... width 24); practical integrations override with full 32-bit addresses.

## 7) Simulation prerequisites and exact flows
### Prerequisites
- Synopsys VCS + Verdi expected for primary flow
- `run/run.sh` hardcodes `VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03` and `VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1`
- Verdi PLI paths are hardcoded in filelists/scripts
- **For TARGET C (full SoC)**: the VeeR EL2 core requires two auto-generated header files that are **not checked into this repo**:
  - `common_defines.vh` (generated by `configs/veer.config`)
  - `el2_param.vh` (generated by `configs/veer_config_gen.py`)
  - Generate them first: `cd rtl/Cores-VeeR-EL2 && python3 configs/veer_config_gen.py`, then compile with `+define+RV_BUILD_AXI4` and `+incdir+$RV_ROOT/design/include`

### Main flow (`run/`) — TARGETS A and B (automated)
```bash
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/run
bash run.sh compile_a   # standalone interconnect target
bash run.sh compile_b   # UART integration target
bash run.sh sim
bash run.sh wave_a
bash run.sh wave_b
```
Also available: `bash run.sh all_a`, `bash run.sh all_b`, `bash run.sh clean`.

### TARGET C (full SoC with VeeR EL2) — manual, not yet in `run.sh`
```bash
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/rtl/Cores-VeeR-EL2
python3 configs/veer_config_gen.py        # generates common_defines.vh / el2_param.vh

cd ../../run
# In run.f: comment out the TARGET A/B testbench lines, uncomment ../tb/tb_aegis_v_soc.v
export RV_ROOT=../rtl/Cores-VeeR-EL2
vcs -full64 -sverilog -ntb_opts uvm \
    -timescale=1ns/1ps -debug_access+all -kdb \
    +define+RV_BUILD_AXI4 \
    +incdir+$RV_ROOT/design/include \
    +incdir+../rtl/axi-lite_uart-ipcore-develop/src/include \
    +incdir+../rtl/i2c-master/rtl/verilog \
    -f run.f -l compile.log
./simv
# FSDB: dump_soc.fsdb (dumped by tb_aegis_v_soc.v itself)
```

### I2C standalone flow (`rtl/i2c-master/run/`) — new
```bash
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/rtl/i2c-master/run
bash run.sh compile
bash run.sh sim
bash run.sh wave
bash run.sh all
bash run.sh clean
```

### TB-local flow (`tb/`)
```bash
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/tb
bash run.sh                 # default VCS
SIM=questa  bash run.sh     # Questa/ModelSim
SIM=xcelium bash run.sh     # Xcelium/xrun
```

### Note on active target in filelists
- Current checked-in `run/run.f` has `tb_axi_interconnect_uart.v` active (TARGET B); the standalone interconnect TB and the new `tb_aegis_v_soc.v` (TARGET C) lines are present but commented out.

## 8) Verification strategy and covered scenarios
### Standalone interconnect TB (`tb_axi_interconnect_wrap_2x11.v`) — unchanged
Covers reset/idle sanity; directed read/write via M00/M01; routing across M02..M10; concurrent accesses from both masters; arbitration when both masters target the same slave (M03); unmapped-address DECERR (`0xDEAD_0000`) on B and R channels. FSDB: `dump_interconnect.fsdb`.

### UART integration TB (`tb_axi_interconnect_uart.v`) — unchanged
Covers UART configuration (DLAB, baud divisor, 8N1, IER); loopback bytes from both s00 and s01 paths (`0xA5`, `0x3C`); LSR polling until `DATA_READY`; IRQ de-assertion after RBR drain; back-to-back TX writes (`0x11`,`0x22`,`0x33`) with readback; LSR TX-empty flags. FSDB: `dump_uart.fsdb`.

### Top-level SoC TB (`tb_aegis_v_soc.v`) — new
Instantiates the full `aegis_v_soc` and exercises every integrated IP in one run; the VeeR core is held in reset (see §2/§11), so stimulus is injected directly via AXI‑Lite BFM tasks and a behavioral SRAM model rather than CPU-fetched instructions:
- **TEST 1 — SRAM model**: direct write/read-back sanity on the M00-side memory model
- **TEST 2 — UART configuration**: DLAB/baud-divisor sequence, LCR readback = 8N1, IER RX-interrupt enable
- **TEST 3 — UART TX/RX loopback**: write THR (`0xA5`), poll LSR `DATA_READY`, verify RBR readback
- **TEST 4 — AES‑128 encryption**: reset core, load key + plaintext, trigger key load (`KLD`) and encrypt (`LD`), poll `KDONE`/`DONE`, verify all four ciphertext words against the NIST FIPS‑197 Appendix B vector
- **TEST 5 — I2C register access**: forced Wishbone read of `PRER_LO` on `u_wb_bridge`, verifies reset default `0xFF`
- **TEST 6 — Connectivity/hierarchy check**: interconnect, UART, AES, and I2C reset signals all correctly de-asserted after SoC reset release
- Pass/fail counters (`pass_count`/`fail_count`) and a global timeout watchdog; FSDB: `dump_soc.fsdb`

### I2C standalone TB (`rtl/i2c-master/bench/verilog/tst_bench_top.v`) — new simulation flow
Now has its own VCS/Verdi compile/sim/wave flow (`rtl/i2c-master/run/`) independent of the SoC-level test, with waveform screenshots captured under `tb/i2c-verify*.png` and `tb/i2c_waveform*.png`.

## 9) Wrapper generator usage (`scripts/axi_interconnect_wrap.py`)
Unchanged. Identical generator scripts in `scripts/axi_interconnect_wrap.py` and `run/axi_interconnect_wrap.py`. Dependency: Python package `jinja2`.
```bash
python /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/scripts/axi_interconnect_wrap.py -p 2 11 -n axi_interconnect_wrap_2x11 -o axi_interconnect_wrap_2x11.v
```
`-p` accepts one value (same master/slave count) or two values (`m n`).

## 10) Imported IP notes (VeeR EL2 / AES / I2C / UART)
### VeeR EL2 core (`rtl/Cores-VeeR-EL2/`) — new
- Western Digital's open-source RISC‑V VeeR EL2 core (Apache License 2.0), imported in full: `design/`, `testbench/`, `verification/`, `configs/`, `tools/`, `third_party/`, `docs/`
- **Is integrated** in `aegis_v_soc.v` via `el2_veer_wrapper` + `el2_mem`, compiled with `+define+RV_BUILD_AXI4`
- Requires generated headers (`common_defines.vh`, `el2_param.vh`) not present in-repo; core is held in reset in the current SoC testbench (see §2, §7, §11)

### UART IP (`rtl/axi-lite_uart-ipcore-develop/`) — unchanged
Includes RTL, headers, testbench, Makefile-based flow, CI configs, and license. **Is integrated** in both `axi_uart_subsystem.v` (standalone, M10) and `aegis_v_soc.v` (M01).

### AES IP (`rtl/aes_core-master/`) — status changed
Includes AES RTL, AXI slave wrapper (`aes_axi_slave.v`), docs, core file, workflow, sim/syn collateral. **Now integrated** in `aegis_v_soc.v` at M02 and exercised end-to-end in `tb_aegis_v_soc.v` against a known-answer test vector (previously imported but not connected).

### I2C IP (`rtl/i2c-master/`) — status changed
Includes Verilog and VHDL implementations, benches, FuseSoC core, docs, and CI. **Now integrated** in `aegis_v_soc.v` at M03 via the new `wb_to_axilite_bridge`, exercised in `tb_aegis_v_soc.v`, and also has its own new standalone VCS/Verdi simulation flow under `rtl/i2c-master/run/` (previously imported but not connected, no standalone sim flow).

## 11) Known limitations and current integration status
- `aegis_v_soc.v` wires up the full CPU + interconnect + peripheral set, but the VeeR EL2 core is **held in reset** in `tb_aegis_v_soc.v` because the two VeeR-generated headers (`common_defines.vh`, `el2_param.vh`) are not checked into the repo; the testbench validates the peripherals and interconnect via direct AXI‑Lite BFM stimulus rather than actual CPU-fetched/executed instructions, so the core's ability to boot and run code through the full SoC memory map is not yet demonstrated in simulation
- `run/run.sh` automates TARGET A (interconnect) and TARGET B (UART) only; TARGET C (the new full SoC) must currently be compiled by hand using the instructions embedded as comments in `run/run.f` — no `compile_c`/`wave_c`/`all_c` shortcuts exist yet
- `reg/` is an empty, reserved directory — no register-map documentation has been added there yet
- `scripts/hello.c` is a minimal, unbuilt C sample; it is not yet wired into a toolchain, linker script, or boot flow for the VeeR core
- `axi_uart_subsystem.v` (the standalone M10-based UART target) still intentionally stubs M02–M09 and remains separate from the M01-based UART path used inside `aegis_v_soc.v`
- Interconnect wrapper default base parameters (small decimal constants) are template defaults; practical system maps rely on override values from subsystem/SoC/testbench instantiations
- VeeR EL2's 64-bit AXI data bus is truncated to the interconnect's 32-bit width for peripheral accesses in `aegis_v_soc.v`; only the lower 32 bits of `wdata`/`wstrb` are used and reads are zero-extended

## 12) Commit-history / project evolution (visible in this clone)
Visible commits, oldest to newest:
1. `1fc9062` — "Initial Aegis-V AXI4 SoC implementation"
2. `0b840a1` — "Reorganize Aegis-V SoC project to repository root"
3. `15c377a` — "Revise README for clarity and structure"
4. `f398afd` — "Add author info (Vivek Chakali, Roll No. 1602-23-735-127), project badge, and block diagram placeholder"
5. `8c9c119` — "Move Project and Author sections below Summary, restore original top layout"
6. `22a0026` — "Embed doc/block_diagram.png in README (replace placeholder)"
7. `d79e5c3` — "Center and resize block diagram in README (use HTML img tag, width=650)"
8. `46d054a` — "Add short repo description into README and preserve existing content"
9. `0de539f` — "Update project with latest AES modules CSR AXI Slave and testbench"
10. `ead293c` — "Added and verified the UART AXI Modules including the Testbench"
11. `396d4da` — "Update .gitignore"
12. `1261dfb` / `378e9e6` — "feat: integrated AXI4-to-AXI-Lite bridge for UART subsystem"
13. `8e03649` — "Update README"
14. `53713d6` / `324d8ab` (merged via `80b7398`) — "docs: draft/expand repository README"
15. `ce576d1` — "rtl/i2c-master: add VCS/Verdi simulation flow with testbench files" (latest on `origin/main`)

**Not yet committed (working tree, this update):** `rtl/interconnect/aegis_v_soc.v`, `rtl/interconnect/wb_to_axilite_bridge.v`, `rtl/Cores-VeeR-EL2/` (full VeeR EL2 import), `tb/tb_aegis_v_soc.v`, `scripts/hello.c`, `doc/Cores-Veer-EL2/`, `doc/aes_core-master/`, `doc/axi-lite_uart-ipcore-develop/`, `doc/i2c-master/`, plus the expanded `run/run.f`.

> Note: this summary is constrained to commits available in the current checkout plus the untracked changes present at the time this README was generated.

## 13) Contribution/dev guidance and provenance notes
- Keep generated artifacts out of source control where possible; root `.gitignore` already excludes common VCS/Verdi/xrun/Vivado/Quartus/python build outputs
- For this repository, prefer modifying source under `rtl/interconnect/`, `tb/`, `run/`, and root docs while treating imported third-party IP trees (`Cores-VeeR-EL2/`, `axi-lite_uart-ipcore-develop/`, `aes_core-master/`, `i2c-master/`) as vendored unless intentionally updating them
- License/provenance signals in-tree:
  - Apache License 2.0 — `rtl/Cores-VeeR-EL2/LICENSE` (Western Digital VeeR EL2 core)
  - Alex Forencich license headers in interconnect-related sources
  - MIT license file in UART IP subtree
  - FuseSoC/core metadata and historical notices in AES/I2C subtrees
- No top-level `LICENSE` file is currently present at repository root

## 14) Quick reference commands
All commands below use repository-absolute paths.

```bash
# Main flow — TARGET A / TARGET B (automated)
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/run
bash run.sh compile_a
bash run.sh compile_b
bash run.sh sim
bash run.sh wave_a
bash run.sh wave_b

# TARGET C — full SoC with VeeR EL2 (manual; see §7)
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/rtl/Cores-VeeR-EL2
python3 configs/veer_config_gen.py

# I2C standalone flow (new)
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/rtl/i2c-master/run
bash run.sh all

# TB-local flow
cd /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/tb
bash run.sh
SIM=questa  bash run.sh
SIM=xcelium bash run.sh

# Wrapper generation (requires jinja2)
python /home/runner/work/Aegis-V-SoC/Aegis-V-SoC/scripts/axi_interconnect_wrap.py -p 2 11 -n axi_interconnect_wrap_2x11 -o axi_interconnect_wrap_2x11.v
```
