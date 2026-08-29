# Aegis-V SoC

Aegis-V is a RISC-V based System-on-Chip (SoC) architecture designed for secure edge computing and real-time control applications.

The system integrates an RV32I RISC-V processor, AXI4 interconnect, DMA controller, memories, cryptographic acceleration, communication interfaces, timing, GPIO, PWM actuation, watchdog supervision, interrupt handling, and system control/status logic.

---

## 1. Project Overview

Aegis-V is built around a 32-bit RV32I RISC-V processor with a 3-stage execution pipeline and a memory-mapped AXI4-based SoC architecture.

The architecture contains:

- RV32I RISC-V CPU
- AXI4 interconnect
- DMA controller
- Instruction memory
- Data memory
- UART
- 32-bit system timer
- 16-bit GPIO
- SHA-256 cryptographic accelerator
- 4-channel PWM controller
- Windowed watchdog timer
- System control and status block
- Interrupt and NMI handling
- Error and fault supervision

The design is intended to provide a modular architecture suitable for FPGA/ASIC implementation and RTL-level verification.

---

## 2. System Architecture

The Aegis-V SoC uses an AXI4-based 2-master / 9-slave architecture.

### AXI4 Masters

| Master | Module | Function |
|---|---|---|
| M0 | RV32I RISC-V CPU | Processor instruction, data and peripheral transactions |
| M1 | DMA Controller | Autonomous data movement between memory and AXI4 peripherals |

### AXI4 Slaves

| Slave | Module | Base Address | Size |
|---|---|---:|---:|
| S0 | Instruction Memory | `0x0000_0000` | 32 KB |
| S1 | Data Memory | `0x2000_0000` | 32 KB |
| S2 | UART | `0x4000_0000` | 4 KB |
| S3 | System Timer | `0x4000_1000` | 4 KB |
| S4 | GPIO | `0x4000_2000` | 4 KB |
| S5 | SHA-256 | `0x4000_3000` | 4 KB |
| S6 | PWM | `0x4000_4000` | 4 KB |
| S7 | Windowed Watchdog | `0x4000_5000` | 4 KB |
| S8 | System Control & Status | `0x4000_E000` | 4 KB |

---

## 3. High-Level Block Diagram

```text
                         +----------------------+
                         |    RV32I RISC-V CPU  |
                         |       AXI4 M0        |
                         +----------+-----------+
                                    |
                                    |
                         +----------v-----------+
                         |                      |
                         |    AXI4 INTERCONNECT |
                         |       2 x 9          |
                         |                      |
                         +----------+-----------+
                                    |
          +-------------------------+--------------------------+
          |            |            |            |              |
          v            v            v            v              v
     Instruction   Data Memory    UART        Timer           GPIO
       Memory
       S0            S1           S2           S3              S4

          +-------------------------+--------------------------+
          |            |            |            |
          v            v            v            v
       SHA-256        PWM        W-WDT       SYSCTRL
         S5             S6          S7           S8


                    +----------------------+
                    |    DMA CONTROLLER    |
                    |       AXI4 M1        |
                    +----------+-----------+
                               |
                               +------> AXI4 Interconnect
