# Aegis-V SoC UVM Verification Test Plan

## 1. Purpose and scope

This document defines a UVM-based verification plan for the design instantiated by `rtl/interconnect/aegis_v_soc.v`. It is a test plan, not a claim that a complete UVM environment already exists. Test names below are proposed UVM sequences; test implementation, simulator setup, and final expected values must be aligned to the checked-in RTL and selected configuration.

The plan covers the VeeR EL2 core and its local memories, the 2-initiator/13-target AXI4 interconnect, the AXI4-to-AXI4-Lite bridges, UART, AES-128, Wishbone-to-AXI-Lite bridge, I2C master, PWM, and instruction/data memory IPs. The top also has reset, interrupt, JTAG, and external AXI memory interfaces; these are included as integration interfaces.

Repository RTL includes other IPs (for example SHA-256, watchdog, GPIO, system-control/status, and `rv_timer`) that are not instantiated in this SoC top and are therefore outside this SoC-level plan. The separately-used `axi_uart_subsystem` is also not a block instance in `aegis_v_soc`.

## 2. Design inventory and interfaces

| Block / instance | Interface and role | Plan focus |
|---|---|---|
| VeeR EL2 / `u_veer` | CPU; LSU and IFU AXI4 initiators, JTAG, interrupts | reset/boot, instruction execution, load/store, exceptions, interrupt/debug smoke |
| EL2 local memory / `u_el2_mem` | Core ICCM/DCCM and memory interface | local fetch/data access, bounds/configuration, initialization and error behavior |
| AXI crossbar / `u_interconnect` (`axi_interconnect_wrap_2x13`) | Two AXI4 initiators, thirteen targets | address decode, arbitration, IDs, independent channels, routing, backpressure, unmapped accesses |
| AXI4-to-AXI4-Lite / `u_bridge_uart`, `u_bridge_aes`, `u_bridge_i2c`, `u_bridge_pwm` | AXI4 target to peripheral AXI-Lite initiator | transaction conversion, response/ID handling, stalls, reset recovery |
| UART / `u_uart` | AXI-Lite register slave, serial RX/TX, IRQ | register access, framing, FIFOs, loopback, errors, interrupts |
| AES / `u_aes` | AXI-Lite register slave and AES-128 engine | register protocol, key/data load, encrypt known-answer and status |
| Wishbone bridge / `u_wb_bridge` | AXI-Lite request to I2C Wishbone bus | address/data/control mapping, ACK/error, wait states, reset |
| I2C master / `u_i2c` | Wishbone register slave and open-drain SCL/SDA | register programming, START/STOP, transfers, ACK/NACK, clock stretching, arbitration |
| PWM / `u_pwm` | AXI-Lite register slave and `pwm_out` | register access, duty/frequency behavior, reset and boundary values |
| Instruction memory / `u_imem` | AXI-Lite read-only memory | read/init/address behavior, rejected writes, response stability |
| Data memory / `u_dmem` | AXI-Lite read/write memory | byte strobes, read/write, address alias/bounds, independent channels |
| SoC shell | reset synchronizer, external AXI memory, ext interrupts, JTAG | reset sequencing, memory handshakes, connectivity, interrupt/debug integration |

Confirm target mapping and parameters against the elaborated top before signoff. The source contains reserved/unimplemented crossbar targets; accesses to them should follow the configured decode response and are not assumed to reach a peripheral.

## 3. Verification objectives

1. Prove each connected IP responds correctly through its native interface and, for memory-mapped peripherals, through the full CPU-master → crossbar → bridge → peripheral path.
2. Check AXI and Wishbone protocol rules, including independent address/data channels, legal response sequencing, stable payload under backpressure, and no dropped/duplicated transactions.
3. Check reset assertion/release and recovery while idle and during outstanding work where supported by the RTL.
4. Check data integrity, register side effects, interrupt behavior, and serial bus behavior against independent reference models or protocol monitors.
5. Exercise simultaneous CPU IFU/LSU traffic and peripheral traffic, contention, and target backpressure.
6. Track functional coverage and close all mandatory bins or document justified exclusions/RTL limitations.

## 4. Proposed UVM environment

### 4.1 Agents

- **AXI4 master agent (active):** drive independent AW/W/B and AR/R channels with configurable delay, bursts, IDs, and backpressure. Instantiate two agents for crossbar-focused block tests; for full-SoC tests use the core as the initiator where the boot-capable configuration is available.
- **AXI4 slave/memory agent (active):** model external memory on the SoC M00 interface; support programmable latency, response errors, and AXI bursts.
- **AXI-Lite agent (active/passive):** active for isolated peripheral/bridge tests; passive monitors at the peripheral-side bus during SoC tests.
- **UART agent:** serial line driver and decoder with configurable baud, parity, stop bits, noise/framing faults, and loopback option.
- **I2C agent:** open-drain slave responder/monitor supporting ACK/NACK, clock stretching, and arbitration contention.
- **Wishbone agent (active/passive):** drive bridge block tests and monitor bridge-to-I2C transactions.
- **JTAG and interrupt agents:** drive TAP/debug transactions and external interrupt pins when supported by the selected core build.
- **PWM monitor:** sample output and derive period/high-time/duty cycle.
- **Scoreboards/reference models:** AXI transaction routing, memory, UART register/FIFO model, AES register and encryption model, I2C transfer model, PWM waveform model, Wishbone mapping, and expected reset state.

### 4.2 Testbench structure

Suggested hierarchy: `aegis_v_soc_tb` → `aegis_v_soc_env` → per-protocol agents, block scoreboards, coverage collector, and virtual sequencer. Use configuration objects for address windows, widths, reset polarity/latency, baud and I2C timing, AES mode, and memory initialization. Virtual sequences coordinate concurrent masters and peripheral line agents. Add protocol assertions/checkers independently of scoreboards.

### 4.3 Reference data

- Load an instruction image for core execution tests; compare architectural state/retirement or externally visible memory signatures.
- AES-128 encrypt known-answer test: FIPS-197 Appendix B vector already cited in the project README. Add decrypt test if the RTL wrapper exposes decrypt control.
- Memory scoreboards use byte-addressed reference storage and AXI write strobes.
- UART/I2C serial monitors decode pin-level behavior rather than trusting DUT internal state.

## 5. Test matrix

Priority: **P0** = required smoke/signoff; **P1** = feature and corner cases; **P2** = extended stress/configuration. Every test has a pass condition of no protocol checker/scoreboard errors, no unexpected X/Z on observed outputs, and completion before its timeout.

### 5.1 Reset, SoC shell, and core

| ID / priority | Scenario and stimulus | Checks / coverage |
|---|---|---|
| SOC_RST_001 / P0 | Power-on reset held for multiple clocks, release synchronously; repeat reset | Reset values, no spurious AXI/WB requests, peripherals quiescent, reset-domain polarity and release latency |
| SOC_RST_002 / P1 | Assert reset during idle, peripheral transfer, and outstanding external memory request | No stale response/IRQ; clean recovery; document unsupported in-flight abort behavior |
| CORE_BOOT_001 / P0 | Boot initialized minimal program from configured reset vector; perform arithmetic and signature store | Fetches, retirement/signature, no unexpected trap; requires functional core build/config headers |
| CORE_MEM_001 / P0 | Instruction fetch plus aligned byte/halfword/word/doubleword loads/stores supported by configuration | Correct data, strobes, sign/zero extension, ordering, IFU/LSU routing |
| CORE_EXC_001 / P1 | Illegal instruction, misalignment, access fault, and privilege/PMP cases enabled by configuration | Correct trap cause/PC/status and return behavior |
| CORE_IRQ_001 / P1 | Pulse and hold selected `extintsrc_req`; software enables/clears interrupt | Core takes expected interrupt and returns; no lost/duplicate event |
| CORE_DBG_001 / P2 | JTAG TAP reset/IDCODE and halt/resume/register access if debug build is enabled | TAP response, halt/resume, debug request handling |
| LOCAL_MEM_001 / P0 | Exercise ICCM/DCCM initialized and uninitialized regions, boundary and configured size | Correct local data/fetch and no unintended alias; check configuration-specific protection |

### 5.2 AXI crossbar and external memory

| ID / priority | Scenario and stimulus | Checks / coverage |
|---|---|---|
| XBAR_DECODE_001 / P0 | Single reads/writes to each implemented target window and unmapped/reserved windows | Correct target select; no cross-target leakage; expected DECERR/error response for unmapped region |
| XBAR_ARB_001 / P0 | LSU and IFU issue simultaneous requests to same and different targets | Arbitration fairness/priority as specified, no starvation, independent target progress |
| XBAR_CHAN_001 / P0 | AW and W arrive independently and in either order; concurrent read and write | AXI channel independence, no response before acceptance, matching ID/response |
| XBAR_BURST_001 / P1 | INCR bursts with legal lengths, sizes, lane alignment, and boundary cases to memory target | Beat count, address progression, WLAST/RLAST, ID preservation, response routing |
| XBAR_STALL_001 / P1 | Random target READY delays and master response backpressure | Payload stability, no loss/duplication, eventual completion under bounded ready |
| XBAR_ERR_001 / P1 | Inject SLVERR/DECERR from target and malformed/unmapped access where legal to drive | Error routed to requester with correct ID and no deadlock |
| XBAR_STRESS_001 / P2 | Constrained-random concurrent traffic from two initiators across multiple targets | Scoreboard consistency, no starvation/deadlock, coverage of contention and channel overlap |
| EXT_MEM_001 / P0 | External memory model supports reads/writes and bursts with zero and variable latency | Address/data/strobe/ID correctness and architectural signature |
| EXT_MEM_002 / P1 | Backpressure and injected SLVERR/DECERR on M00 | Core/initiator handles response per architecture; fabric drains cleanly |

### 5.3 AXI4-to-AXI4-Lite bridges

Run one bridge block suite per peripheral bridge and a cross-target suite through the SoC.

| ID / priority | Scenario and stimulus | Checks / coverage |
|---|---|---|
| BRIDGE_BASIC_001 / P0 | Single read/write, AW-before-W and W-before-AW, address/data delays | One Lite transaction per accepted AXI transaction; correct address/data/strobes and response |
| BRIDGE_RESP_001 / P0 | OKAY, SLVERR, and decode/error response; vary AXI IDs | Response and ID return correctly; no invented success response |
| BRIDGE_STALL_001 / P1 | Stall Lite AW/W/B/AR/R independently; stall AXI B/R ready | Stable valid/payload, correct sequencing, no deadlock or duplicate Lite request |
| BRIDGE_RESET_001 / P1 | Reset while idle and during each channel phase | Outputs return to idle; no phantom post-reset response; documented transaction cancellation semantics |
| BRIDGE_STRESS_001 / P2 | Randomized legal traffic and concurrent read/write attempts | Throughput, ID bookkeeping, ordering, and coverage across all channel stall combinations |

### 5.4 UART

| ID / priority | Scenario and stimulus | Checks / coverage |
|---|---|---|
| UART_REG_001 / P0 | Read/write implemented registers; reset defaults; DLAB/divisor programming | Register decode, writable/read-only behavior, reset values, reserved bits |
| UART_TXRX_001 / P0 | Configure common frame (8N1), transmit known bytes, receive known serial frames | Decoded start/data/parity/stop bits, byte order, baud tolerance, RX data readback |
| UART_LOOP_001 / P0 | Internal/external loopback and back-to-back bytes | No loss/duplication; status flags and TX/RX ordering |
| UART_FIFO_001 / P1 | Empty/full/threshold, FIFO clear, bursts, simultaneous TX/RX | FIFO occupancy/status and overflow/underflow behavior |
| UART_FMT_001 / P1 | Supported word lengths, parity modes, stop-bit settings, divisor extremes | Correct waveform and receive decode; unsupported modes handled as documented |
| UART_ERR_001 / P1 | Parity, framing, break, overrun, and noise injection | LSR/error status and IRQ cause/clear behavior |
| UART_IRQ_001 / P1 | Enable/disable RX, TX, line-status, modem interrupts if implemented | IRQ assertion, priority/cause reporting, deassertion after service |
| UART_STRESS_001 / P2 | Random serial timing within tolerance plus concurrent software register access | Scoreboard and coverage closure under traffic |

### 5.5 AES-128

| ID / priority | Scenario and stimulus | Checks / coverage |
|---|---|---|
| AES_REG_001 / P0 | Reset defaults, ID/version/status reads, legal key/data/control writes | Register map, access permissions, byte enables, status transitions |
| AES_KAT_001 / P0 | FIPS-197 AES-128 known-answer encryption vector | Ciphertext matches independent reference; done/status timing and result stability |
| AES_RELOAD_001 / P1 | Re-key and run multiple plaintexts; randomized keys/data | Correct independent reference results; no stale key/data leakage between transactions |
| AES_BUSY_001 / P1 | Access/control writes while operation is active | Defined busy/ignored/accepted behavior; no corruption or false completion |
| AES_RESET_001 / P1 | Reset during idle and active operation | Status/output reset behavior and successful next operation |
| AES_STRESS_001 / P2 | Random legal programming, polling and response stalls | Transaction integrity and control/status coverage |

### 5.6 Wishbone bridge and I2C master

| ID / priority | Scenario and stimulus | Checks / coverage |
|---|---|---|
| WB_BRIDGE_001 / P0 | AXI-Lite reads/writes to each mapped Wishbone register; vary AXI channel ordering | Correct WB address/data/select/write-enable mapping and AXI response |
| WB_BRIDGE_WAIT_001 / P1 | Insert WB ACK delay and supported error/stall conditions | AXI request held until completion; no early response, duplicate cycle, or deadlock |
| WB_BRIDGE_RESET_001 / P1 | Reset during WB idle and active cycle | WB controls idle after reset; no stale AXI response |
| I2C_REG_001 / P0 | Program prescaler, control, TX/RX registers; read back supported fields | Register semantics and reset values |
| I2C_WRITE_001 / P0 | Master START, address + write bytes, slave ACK, STOP | Open-drain line behavior, bit order, SCL frequency, ACK sampling, command completion/IRQ |
| I2C_READ_001 / P1 | Address + read bytes, ACK intermediate byte and NACK final byte, STOP | Received bytes, ACK/NACK sequencing, status and IRQ |
| I2C_NACK_001 / P1 | NACK address and data phases | Arbitration/status flags, transaction termination and software-visible status |
| I2C_STRETCH_001 / P1 | Slave holds SCL low during transfer | Clock stretching honored and transaction resumes without data corruption |
| I2C_ARB_001 / P2 | Competing master pulls SDA low during a released-high bit | Arbitration loss detection and bus release if implemented/configured |
| I2C_RESTART_001 / P1 | Repeated START and multi-byte command sequences | Correct bus sequence and command engine status |
| I2C_RESET_STRESS_001 / P2 | Reset at multiple bus phases and random timing stress | Safe line release, no phantom completion, protocol scoreboard clean |

### 5.7 PWM

| ID / priority | Scenario and stimulus | Checks / coverage |
|---|---|---|
| PWM_REG_001 / P0 | Read/write control and duty registers; reset defaults; byte strobes | Register readback and output enable/control behavior |
| PWM_DUTY_001 / P0 | Minimum, zero, midpoint, maximum duty and period settings | Measured period/high-time/duty match documented RTL semantics (including endpoint behavior) |
| PWM_UPDATE_001 / P1 | Change configuration during active period | Update timing/glitch behavior matches RTL specification |
| PWM_RESET_001 / P1 | Reset while output high and low | Output reset level and clean restart |
| PWM_STRESS_001 / P2 | Random legal settings over many periods | Waveform scoreboard and configuration cross coverage |

### 5.8 Instruction and data memories

| ID / priority | Scenario and stimulus | Checks / coverage |
|---|---|---|
| IMEM_INIT_001 / P0 | Initialize image, read first/last words and selected patterns | Correct initialization and word address mapping |
| IMEM_WRITE_001 / P0 | Attempt writes with varied data/strobes | SLVERR response and memory remains unchanged |
| IMEM_BOUND_001 / P1 | Address alignment, aliasing, configured depth boundary | Defined index mapping; verify top-level decode prevents invalid accesses or record RTL limitation |
| DMEM_RW_001 / P0 | Full-word and random word write/read across addresses | Data integrity and OKAY response |
| DMEM_STRB_001 / P0 | Each single-byte lane, all lane combinations, zero strobe | Byte-lane update semantics; unaffected bytes preserved |
| DMEM_BOUND_001 / P1 | First/last valid word, unaligned and out-of-range addresses | Defined address truncation/error behavior; no accidental alias beyond spec |
| MEM_BACKPRESSURE_001 / P1 | Hold BREADY/RREADY low; issue read/write traffic | Response valid/data stable until accepted; no lost accesses |
| MEM_CONCURRENT_001 / P2 | Concurrent reads/writes where AXI-Lite implementation permits | Deterministic ordering and no protocol violations |

### 5.9 SoC integration scenarios

| ID / priority | Scenario and stimulus | Checks / coverage |
|---|---|---|
| SOC_PERIPH_001 / P0 | Access each mapped peripheral via the crossbar and its bridge | Correct target, register result, no address alias; UART/AES/I2C/PWM paths |
| SOC_CPU_PERIPH_001 / P0 | Boot software configures UART/PWM, runs AES KAT, accesses I2C registers, stores a signature | CPU path through LSU/crossbar/bridges; end-to-end result |
| SOC_CONCURRENT_001 / P1 | IFU fetches while LSU performs memory/peripheral traffic; peripheral pins active | No crossbar starvation, corruption, or response misrouting |
| SOC_IRQ_001 / P1 | Cause UART/I2C/peripheral IRQ if connected, and external interrupt request | Interrupt wiring/polarity and core response; identify disconnected IRQ paths as integration gaps |
| SOC_ADDR_001 / P1 | Probe base, last byte, adjacent window, reserved targets | Decode windows, response type, no unintended peripheral side effects |
| SOC_LONG_001 / P2 | Long mixed workload with randomized target/serial delays and periodic reset only at safe boundaries | No leaks/deadlock, stable scoreboards, end-of-test outstanding count zero |

## 6. Functional coverage plan

Collect covergroups at monitors/scoreboards; sample only accepted transactions or completed protocol events.

- **AXI:** initiator × target × read/write × burst length/size × response × ID class × stall location; AW-before-W/W-before-AW; same/different target contention; simultaneous read/write.
- **Address decode:** every implemented target, reserved target, below/at/inside/last/above each window; aligned and misaligned address classes.
- **Bridge:** AXI ID × response × Lite wait-state class × reset phase.
- **UART:** baud class × frame format × parity × TX/RX/FIFO state × interrupt cause × injected error.
- **AES:** operation × key/data pattern class × busy/reset phase × completion status.
- **I2C:** read/write × byte count × ACK/NACK phase × repeated START × stretch × arbitration outcome × prescaler class.
- **PWM:** enable × duty boundary class × period class × update phase × reset output state.
- **Memories:** address region × access type × byte strobe mask × response/backpressure class × initialization state.
- **Core:** instruction class × privilege/configuration × exception/interrupt class × memory target; close only for features enabled by the build.
- **Reset/integration:** reset phase × active block/transaction × recovery outcome.

Cross coverage should emphasize AXI target × concurrent initiator × backpressure and reset phase × outstanding channel. Avoid unconstrained full Cartesian crosses; use targeted crosses and documented exclusions.

## 7. Assertions and protocol checks

- AXI4/AXI-Lite: VALID remains asserted and payload stable while VALID && !READY; legal response only after request acceptance; response ID matches request; burst length/LAST consistency; no X/Z on valid control/data.
- Wishbone: request/control stable until ACK or error; no duplicate completion; bridge translates byte address consistently.
- I2C: open-drain outputs never actively drive high; START/STOP timing and data stability while SCL high; ACK/NACK sampled on the correct clock phase.
- UART: frame timing within configured tolerance; start/data/parity/stop sequencing; FIFO/status/IRQ consistency.
- PWM: measured output period and high-time remain within configured count relationship.
- Reset: protocol outputs inactive during reset; no unsolicited completion immediately after release.

Bind/assertions should avoid relying on implementation-private state except for diagnostic checks. Use protocol VIP where licensed and available; otherwise implement equivalent lightweight monitors.

## 8. Regression and completion criteria

### Regression tiers

1. **Smoke (P0):** reset, external memory read/write, implemented-target decode, peripheral register smoke, UART loopback, AES KAT, I2C register access/transfer, PWM endpoints, IMEM write rejection, DMEM byte strobes, core boot when configured.
2. **Feature (P0 + P1):** all directed tests, protocol stall/error cases, interrupts, reset recovery, address boundaries, peripheral error cases.
3. **Stress (P2):** seeded random multi-master traffic, serial timing variation, long mixed software workloads, coverage-driven reruns.

### Exit criteria

- All P0 tests pass with reproducible seeds and no unexplained checker/scoreboard errors.
- P1 tests pass or have a reviewed, RTL-backed waiver with an owner and issue reference.
- No outstanding transactions at test end; all global/per-sequence watchdogs pass.
- Functional coverage goals met for all required features; all exclusions justified.
- Assertion/protocol checker failures are resolved or formally waived.
- Known RTL constraints (including missing generated VeeR configuration artifacts, tied-off interfaces, reserved targets, or unsupported reset-abort semantics) are recorded in the verification report and not mistaken for passing coverage.

## 9. Repository-specific risks and assumptions to resolve

- The README says the core is held in reset in the existing SoC testbench because generated VeeR headers/configuration are absent. CPU boot and software-driven end-to-end tests are conditional until the supported core configuration is generated and compiled.
- The SoC top and documentation have evolved; use the elaborated `aegis_v_soc.v` and exact parameters as authority for instance and address mapping. Verify the actual instantiated crossbar width/target connections and mapped IMEM/DMEM path before testbench configuration.
- The top-level port list includes JTAG, external memory, and PWM. Confirm each path is connected and not tied off in the current elaboration.
- Some third-party IP supports only a subset of AXI/Wishbone features. Constrain stimulus to supported protocol behavior and treat unsupported cases as negative tests only where response behavior is defined.
- Register reset values, reserved-bit rules, interrupt routing, and PWM duty endpoint semantics should be taken from the RTL/register documentation, not assumed from generic IP names.

## 10. Traceability

The test IDs in this plan are intended to map to UVM tests/sequences and coverage points. Maintain a verification matrix with columns `test_id`, `RTL instance`, `requirement/feature`, `sequence`, `checker/scoreboard`, `coverage`, `result`, `seed`, and `waiver/issue`. The project’s existing standalone benches can seed directed scenarios, but they do not by themselves demonstrate UVM coverage closure.

## 11. Signal-level sequence recipes

These recipes specify the intended order of pin activity for directed UVM sequences. A driver should change master-driven signals away from the active sampling edge (normally on the falling edge) and sample handshakes on the rising edge. Keep VALID and its payload stable until a rising edge with READY high. Signal names below use standard AXI naming; bind them to the exact instance port names in the RTL. `X` means don't care for that phase, not an unknown driven value.

### 11.1 SoC reset and external AXI memory

| Phase | Driven signals / event | Expected observation |
|---|---|---|
| Reset assert | Drive `rst_n=0`; hold UART/I2C inputs inactive; deassert external `mem_axi_*ready/valid` activity | Reset synchronizer asserts internal reset domains; request VALID signals and peripheral outputs reach their reset/idle values |
| Reset hold | Keep `rst_n=0` for at least several `clk` cycles | No new AXI/WB transactions; serial outputs and PWM are at documented reset levels |
| Reset release | Drive `rst_n=1` away from rising edge | Internal reset releases only after synchronizer latency; monitor all active-low/active-high domains separately |
| External write address | Driver waits for `mem_axi_awvalid`; model asserts `mem_axi_awready`; sample `awid/awaddr/awlen/awsize/awburst` on handshake | Address/control captured once |
| External write data | For each beat, wait for `mem_axi_wvalid`; model asserts `mem_axi_wready`; sample `wdata/wstrb/wlast` | Exactly `awlen+1` accepted beats; WLAST only on final beat |
| External write response | Model drives matching `mem_axi_bid`, `mem_axi_bresp`, `mem_axi_bvalid=1`; hold until `mem_axi_bready` | Initiator accepts one response; ID and response match request |
| External read | On `mem_axi_arvalid && mem_axi_arready`, capture AR controls; return `mem_axi_rid/rdata/rresp/rlast/rvalid` per beat, holding each beat until `mem_axi_rready` | Correct data/ID/response and RLAST on final beat; response backpressure does not change payload |

### 11.2 AXI4 and AXI-Lite transaction handshakes

**AXI write (independent AW and W channels):**

1. Drive `AWADDR/AWID/AWLEN/AWSIZE/AWBURST` and assert `AWVALID`; hold them until an `AWVALID && AWREADY` rising edge.
2. Independently drive each `WDATA/WSTRB/WLAST` beat and assert `WVALID`; hold each beat until `WVALID && WREADY`. Randomize whether AW or W is presented first, while keeping each channel stable until accepted.
3. Deassert `AWVALID`/`WVALID` after their final handshakes. Slave presents `BID/BRESP/BVALID`; requester may delay `BREADY`. Check response remains stable until `BVALID && BREADY`.

**AXI read:**

1. Drive `ARADDR/ARID/ARLEN/ARSIZE/ARBURST`, assert `ARVALID`, and hold through `ARVALID && ARREADY`.
2. Requester asserts `RREADY` immediately or after randomized delay. For each beat, check `RID/RDATA/RRESP/RLAST` remain stable while `RVALID && !RREADY`.
3. Count only `RVALID && RREADY` beats; require the expected beat count and final `RLAST`.

**AXI-Lite write:** Drive `AWADDR/AWVALID` and `WDATA/WSTRB/WVALID` independently; wait for both handshakes (either may complete first); then assert/hold `BREADY` as configured and consume one `BVALID/BRESP`. Never assume AW and W handshake in the same cycle.

**AXI-Lite read:** Drive `ARADDR/ARVALID` through its handshake, then accept `RVALID/RDATA/RRESP` with `RREADY`; check stable response under backpressure. For the simple IMEM/DMEM implementations, AW/W are accepted together when both VALID and READY are high; write sequences should match this implementation behavior at those blocks.

### 11.3 AXI4-to-AXI-Lite bridge sequence

1. AXI requester sends one legal single-beat access using the AXI write/read recipe above, with a selected ID.
2. Monitor the bridge's `m_axil_*` request pins. For writes, observe Lite AW and W handshakes and then provide B response; for reads, observe AR and provide R response.
3. Insert independent delays on Lite READY and response VALID. During every stall, check VALID and payload stability on the stalled channel.
4. Check that exactly one peripheral-side transaction occurred and the AXI-side response has the right ID and mapped response code. Repeat for UART, AES, I2C, and PWM bridge instances.
5. Reset variant: assert reset during request or response wait; check documented cancellation behavior, idle outputs, and no stale response after release.

### 11.4 UART register and serial signal sequences

**Register programming and transmit:**

1. AXI-Lite write LCR with DLAB set; write DLL and DLM divisor registers; write LCR for desired frame format (for example 8N1); write IER as required.
2. Write a byte to THR. Monitor `uart_tx`: idle high, start bit low, data bits least-significant bit first, optional parity, then configured stop bit(s) high.
3. Decode the frame using the programmed baud divisor and check bit periods within the IP's tolerance. Poll/read LSR for transmit-empty status according to the register definition.

**Receive and loopback:**

1. Drive `uart_rx` high while idle for at least one bit period.
2. Drive start low for one bit, then each data bit LSB-first for one bit period, optional parity, and stop high.
3. Poll LSR until data-ready; read RBR and compare the received byte. For loopback, configure the DUT loopback control and confirm transmitted bytes appear in the receive path.
4. Error variant: alter parity/stop timing or hold break low; check the corresponding LSR error bits and interrupt behavior.

### 11.5 AES register/control sequence

1. Read reset/status or ID registers over AXI-Lite; check reset state.
2. Write key words to the key register addresses and plaintext words to the data input addresses in the RTL-defined word order, honoring `WSTRB`.
3. Write control with key-load (`KLD`) as defined by the wrapper; poll status until key processing completes (`KDONE`) or the specified completion indication appears.
4. Write control with data-load/encrypt (`LD`) as defined; poll status until `DONE`.
5. Read each ciphertext output word; concatenate in documented order and compare to the reference vector. Check status clears/changes only as specified by the RTL.
6. Busy variant: start a second operation or access control while busy; check documented acceptance/ignore behavior without corrupting the first result.

### 11.6 AXI-Lite to Wishbone bridge and I2C bus

**Bridge register access:**

1. Send AXI-Lite read/write to the I2C window. Observe the bridge form Wishbone `cyc/stb`, `we`, `adr`, `dat_w`, and select/control fields as applicable.
2. For reads, responder drives `dat_r`; for writes, sample `dat_w`; delay `ack` for wait-state tests. Hold request/control stable until completion.
3. On Wishbone `ack`, check one AXI-Lite response is returned and read data maps correctly. Check address conversion from peripheral byte offset to the I2C core's word/register address.

**I2C master write transaction:**

1. Program prescaler low/high registers, enable the core, and write the target address/data byte to TXR.
2. Write the command register with START + WRITE. Observe `sda` START while SCL is high, then address/data bits MSB-first on SCL pulses.
3. I2C slave model releases SDA for the ACK bit or pulls it low to ACK; sample ACK on the ninth clock. Repeat TXR + WRITE command for each payload byte.
4. Issue STOP command; observe SDA transition low-to-high while SCL is high. Poll status/IRQ and clear it using documented register semantics.

**I2C read transaction:** issue START + address-with-read; model drives data bits on SDA while SCL is low and holds them through the high phase; DUT ACKs intermediate bytes and NACKs the final byte as commanded; issue STOP or repeated START and compare RXR/status. For clock stretching, hold SCL low as the slave and check the master waits. Model open-drain pins electrically: a participant may pull low or release; no participant actively drives a logic one.

### 11.7 PWM signal sequence

1. After reset release, check `pwm_out` reset level and idle behavior.
2. Program enable/period/duty registers through AXI-Lite; wait for each write response before measuring, unless testing overlapping requests.
3. Sample `pwm_out` on each `clk` edge for multiple full periods. Measure rising-to-rising period and high cycles; compare with the equations and endpoint semantics derived from the PWM RTL.
4. Repeat at zero, midpoint, and maximum duty. Change duty during high and low phases to characterize update timing; assert reset while high and verify the specified reset level.

### 11.8 Instruction/data memory signal sequence

**Instruction memory read:** issue AXI-Lite AR; hold `ARVALID/ARADDR` to handshake; deassert ARVALID; accept `RVALID/RDATA/RRESP` with RREADY. Compare against initialized image. For write-reject, present AW and W according to the DUT's simultaneous acceptance condition, then accept `BRESP=SLVERR`; perform a read to confirm contents unchanged.

**Data memory write/read:** present AW and W with address, data, and `WSTRB`; for the RTL's write-fire condition both channels must handshake in the same cycle. Accept B response, then issue AR and accept R response. Iterate each strobe mask and check only selected byte lanes change. Insert BREADY/RREADY stalls and verify response signals remain stable.

### 11.9 Core and full-SoC virtual sequence

1. Hold SoC reset; preload external memory model with the boot image and initialize local memories as required by the selected VeeR configuration.
2. Release reset and wait for IFU AXI read-address/data handshakes. Return instruction beats with matching IDs and legal `RLAST` from the memory model.
3. Observe LSU AXI transactions generated by the program. For memory writes, check AW/W and return B; for reads, return R data. Maintain a byte-addressed scoreboard.
4. Program UART and transmit/receive a known byte; program PWM and measure output; run AES KAT through memory-mapped registers; configure I2C and observe a modeled slave transaction.
5. Trigger an enabled interrupt and/or external interrupt. Check interrupt entry and software completion signature if the firmware supports it.
6. End only after expected signature and peripheral completions, with no outstanding AXI/Wishbone transactions. Apply a global timeout that reports the last observed channel and signal state.

For tests that inject bus traffic directly instead of running the CPU, use the active AXI master agent on the appropriate testbench boundary and retain the same passive protocol monitors and peripheral pin checkers. Do not drive internal DUT nets as the default SoC-level method; reserve hierarchical forcing for isolated bridge/core tests where no accessible interface exists, and label such tests clearly.
