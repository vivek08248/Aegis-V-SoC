# SoC UVM regression and C test

The SoC simulation top is `tb_aegis_v_soc_uvm` in `tb/`. Peripheral UVM tests
drive single-beat AXI requests at the VeeR LSU master boundary; the real AXI
crossbar, address decoder, conversion bridges, and selected peripheral remain
in the transaction path. The testbench holds the core in reset for these
bus-driven tests. `aegis_soc_full_test` runs the directed checks for UART,
AES, I2C, PWM, SHA-256, GPIO, watchdog, DMA CSRs, system control/status, timer,
IMEM, and DMEM.

## Build and run with Synopsys VCS

From `run/`:

```sh
bash compile_soc.sh compile
bash compile_soc.sh sim
```

`compile_soc.sh` selects the configured VCS U-2023.03 installation, enables
UVM 1.2, and compiles `run_soc.f`. The script does not perform a license check.
The testbench uses VCD by default; FSDB calls are compiled only when
`DUMP_FSDB` is defined and the VCS FSDB PLI is configured.

## Standalone non-UVM C test

Set `RISCV_PREFIX` if the RISC-V GCC toolchain uses a different prefix. The
default is `riscv64-unknown-elf-`.

```sh
cd /home/student/Documents/1602-23-735-127/Aegis-V-SoC
RISCV_PREFIX=riscv64-unknown-elf- bash ctests/build_soc_c_test.sh
cd ctests
bash compile_ctest.sh all
```

The build creates `ctests/soc_c_test.elf`, `.ihex`, and `.memh`. The standalone
testbench in `ctests/` loads the word-addressed image into its external SRAM
model before reset release, boots Core-VeeR, and polls the firmware mailbox at
SRAM address `0x0003_FFFC`. It checks external SRAM, IMEM, DMEM, UART, AES-128,
I2C, PWM, SHA-256, GPIO, watchdog, DMA CSRs, system-control scratch, and timer
progress. `0x600D_C0DE` means all checks passed; `0xBAD0_00NN` identifies a
failed IP check (`NN` is its map index). This standalone C test uses no UVM.
Its VCS build artifacts and FSDB waveform are written under `ctests/`.

To open the C-test waveform with the preconfigured signal groups, run Verdi
from `ctests/` with `-ssf soc_c_test.fsdb -play soc_ctest.rc`.

## Integration status represented by the RTL

- The testbench checks peripheral access through the LSU-to-crossbar path and
  reports `AEGIS_UVM_RESULT=PASS` only if UVM has no errors.
- The I2C window now uses an AXI-Lite-to-Wishbone adapter in the correct
  direction for the Wishbone register slave on `i2c_master_top`.
- Peripheral address offset width is 16 bits so the CPU path can reach the
  complete 64-KiB IMEM/DMEM windows and SHA-256 registers. Narrow IP address
  ports are explicitly truncated at their instances.
- The vendored `dma_axi_flat` wrapper in this repository has its DMA master
  interface tied inactive. The SoC currently integrates and tests its AXI-Lite
  CSR programming interface; it cannot perform memory-to-memory DMA transfers
  until the functional DMA engine and its required bus packages are supplied
  and connected to an AXI initiator port.
- The testbench does not claim a passing result until you compile and run it
  with your VCS/UVM installation. No VCS compile or simulation was run while
  preparing this handoff.
