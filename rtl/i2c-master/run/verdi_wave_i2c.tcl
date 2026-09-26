# =============================================================================
# verdi_wave_i2c.tcl
# Verdi nWave signal-loading script for I2C Master verification
#
#   Top module : tst_bench_top
#   DUT        : i2c_master_top  (instance: i2c_top / i2c_top2)
#   FSDB       : dump.fsdb   (hardcoded in tst_bench_top via $fsdbDumpfile)
#
# Usage (from run/ directory):
#   verdi -dbdir simv.daidir \
#         -ssf  dump.fsdb   \
#         -nologo            \
#         -tcl  verdi_wave_i2c.tcl &
#
# ─── Signal groups ───────────────────────────────────────────────────────────
#   GROUP 1  : Clock & Reset
#   GROUP 2  : Wishbone Bus (master → DUT)
#   GROUP 3  : I2C Bus Lines (physical SCL / SDA)
#   GROUP 4  : I2C Master Top — internal registers & status
#   GROUP 5  : Byte Controller — state machine & shift register
#   GROUP 6  : Bit Controller  — state machine & clock divider
#   GROUP 7  : I2C Slave model — for transfer verification
# =============================================================================

set top tst_bench_top

# Open a new waveform window and keep its handle
set nWave [wvCreateWindow]

# Helper: insert a visible group label (comment divider)
proc grp {label} {
    global nWave
    wvAddComment -win $nWave $label
}

# =============================================================================
# GROUP 1 — Clock & Reset
# Why: Confirm reset de-assertion and stable 10 ns clock before any bus activity
# =============================================================================
grp "========== GROUP 1 : Clock & Reset =========="

wvAddSignal -win $nWave \
    "${top}.clk" \
    "${top}.rstn"

# =============================================================================
# GROUP 2 — Wishbone Bus (Software / BFM → DUT)
# Why: Verify every register write/read issued by the wb_master_model.
#      Key checks:
#        - cyc+stb asserted together for valid bus cycle
#        - ack arrives 1 cycle after stb (single-cycle acknowledge)
#        - adr[2:0] selects correct register:
#            000=PRER_LO  001=PRER_HI  010=CTR  011=TXR/RXR  100=CR/SR
#        - dat_o carries correct write value; dat_i returns correct read value
#        - we distinguishes write (1) from read (0)
# =============================================================================
grp "========== GROUP 2 : Wishbone Bus =========="

wvAddSignal -win $nWave \
    "${top}.clk" \
    "${top}.rstn" \
    "${top}.cyc" \
    "${top}.stb" \
    "${top}.we" \
    "${top}.adr" \
    "${top}.dat_o" \
    "${top}.dat_i" \
    "${top}.ack" \
    "${top}.inta"

# =============================================================================
# GROUP 3 — Physical I2C Bus Lines
# Why: Core verification — the actual START, STOP, address byte, data bytes
#      and ACK/NACK as they appear on SCL/SDA.
#      Key checks:
#        - START  : SDA falls while SCL is HIGH
#        - STOP   : SDA rises  while SCL is HIGH
#        - Data   : SDA stable while SCL HIGH (data valid window)
#        - ACK    : 9th bit SDA = 0 (ACK) or 1 (NACK)
#        - Clock stretch: SCL held low by slave (check slave_wait in bit_ctrl)
# =============================================================================
grp "========== GROUP 3 : I2C Bus Lines (SCL / SDA) =========="

wvAddSignal -win $nWave \
    "${top}.scl" \
    "${top}.sda" \
    "${top}.i2c_top.scl_pad_i" \
    "${top}.i2c_top.scl_pad_o" \
    "${top}.i2c_top.scl_padoen_o" \
    "${top}.i2c_top.sda_pad_i" \
    "${top}.i2c_top.sda_pad_o" \
    "${top}.i2c_top.sda_padoen_o"

# =============================================================================
# GROUP 4 — I2C Master Top: Internal Registers & Status
# Why: Confirm software-visible register programming and status flags.
#      Key checks:
#        - prer   = 16'h008F (prescaler loaded for correct SCL frequency)
#        - ctr[7] = 1 (core_en asserted after CTR write)
#        - ctr[6] = 1 (ien — interrupt enable)
#        - txr    = address byte (7-bit addr + R/W bit) then data byte
#        - rxr    = data byte read back from slave
#        - cr[7]  = sta (START)
#        - cr[6]  = sto (STOP)
#        - cr[5]  = rd
#        - cr[4]  = wr
#        - cr[3]  = ack
#        - sr[7]  = rxack (0 = slave ACKed)
#        - sr[6]  = i2c_busy
#        - sr[5]  = al   (arbitration lost — should stay 0)
#        - sr[1]  = tip  (transfer in progress)
#        - sr[0]  = irq_flag
#        - wb_inta_o pulses after each command completes
# =============================================================================
grp "========== GROUP 4 : I2C Top — Registers & Status =========="

wvAddSignal -win $nWave \
    "${top}.i2c_top.prer" \
    "${top}.i2c_top.ctr" \
    "${top}.i2c_top.txr" \
    "${top}.i2c_top.rxr" \
    "${top}.i2c_top.cr" \
    "${top}.i2c_top.sr" \
    "${top}.i2c_top.core_en" \
    "${top}.i2c_top.ien" \
    "${top}.i2c_top.sta" \
    "${top}.i2c_top.sto" \
    "${top}.i2c_top.rd" \
    "${top}.i2c_top.wr" \
    "${top}.i2c_top.ack" \
    "${top}.i2c_top.done" \
    "${top}.i2c_top.irxack" \
    "${top}.i2c_top.rxack" \
    "${top}.i2c_top.tip" \
    "${top}.i2c_top.irq_flag" \
    "${top}.i2c_top.i2c_busy" \
    "${top}.i2c_top.i2c_al" \
    "${top}.i2c_top.al" \
    "${top}.wb_inta_o"

# =============================================================================
# GROUP 5 — Byte Controller: State Machine & Shift Register
# Why: Trace each 8-bit transfer (address / data / ACK).
#      Key checks:
#        - c_state (byte_controller.c_state) cycles:
#            ST_IDLE → ST_START → ST_WRITE (×8 bits) → ST_ACK → ST_STOP
#        - dcnt counts down 7→0 for each bit in the byte
#        - sr (shift register) shifts out TXR MSB-first
#        - core_cmd drives bit_controller: NOP/START/STOP/WRITE/READ
#        - core_ack pulses when bit_controller completes one bit
#        - ack_out captured after 9th bit (slave ACK bit)
# =============================================================================
grp "========== GROUP 5 : Byte Controller — FSM & Shift Register =========="

wvAddSignal -win $nWave \
    "${top}.i2c_top.byte_controller.c_state" \
    "${top}.i2c_top.byte_controller.dcnt" \
    "${top}.i2c_top.byte_controller.sr" \
    "${top}.i2c_top.byte_controller.core_cmd" \
    "${top}.i2c_top.byte_controller.core_txd" \
    "${top}.i2c_top.byte_controller.core_rxd" \
    "${top}.i2c_top.byte_controller.core_ack" \
    "${top}.i2c_top.byte_controller.ack_out" \
    "${top}.i2c_top.byte_controller.shift" \
    "${top}.i2c_top.byte_controller.ld" \
    "${top}.i2c_top.byte_controller.go"

# =============================================================================
# GROUP 6 — Bit Controller: State Machine & Clock Divider
# Why: Lowest-level timing verification — one SCL period per state group.
#      Key checks:
#        - c_state (bit_controller.c_state) one-hot encoding:
#            idle / start_a–e / wr_a–d / rd_a–d / stop_a–d
#        - cnt counts down from clk_cnt to 0 (quarter-period timer)
#        - scl_oen_master / sda_oen_master drive the open-drain output enables
#        - al (arbitration lost) must stay 0 for normal single-master operation
#        - slave_wait indicates clock stretching by slave
# =============================================================================
grp "========== GROUP 6 : Bit Controller — FSM & Clock Divider =========="

wvAddSignal -win $nWave \
    "${top}.i2c_top.byte_controller.bit_controller.c_state" \
    "${top}.i2c_top.byte_controller.bit_controller.cnt" \
    "${top}.i2c_top.byte_controller.bit_controller.cmd_ack" \
    "${top}.i2c_top.byte_controller.bit_controller.scl_oen_master" \
    "${top}.i2c_top.byte_controller.bit_controller.sda_oen_master" \
    "${top}.i2c_top.byte_controller.bit_controller.al" \
    "${top}.i2c_top.byte_controller.bit_controller.slave_wait" \
    "${top}.i2c_top.byte_controller.bit_controller.sSCL" \
    "${top}.i2c_top.byte_controller.bit_controller.sSDA" \
    "${top}.i2c_top.byte_controller.bit_controller.dSCL" \
    "${top}.i2c_top.byte_controller.bit_controller.dSDA"

# =============================================================================
# GROUP 7 — I2C Slave Model (reference / golden checker)
# Why: Cross-check that the slave receives the correct address and data bytes.
#      Key checks:
#        - i2c_slave.adr  = 7'b010_0000 (SADR from testbench)
#        - i2c_slave.sr   shifts in bits from SDA (compare with DUT txr)
#        - i2c_slave.id   verifies address recognition
#        - sta/sto        slave detects start/stop conditions correctly
# =============================================================================
grp "========== GROUP 7 : I2C Slave Model =========="

wvAddSignal -win $nWave \
    "${top}.i2c_slave.scl" \
    "${top}.i2c_slave.sda" \
    "${top}.i2c_slave.adr" \
    "${top}.i2c_slave.sr" \
    "${top}.i2c_slave.busy" \
    "${top}.i2c_slave.cnt" \
    "${top}.i2c_slave.debug"

# =============================================================================
# Zoom fit and set radix for buses
# =============================================================================
wvZoomAll -win $nWave

# Set hex radix on address/data/register buses
wvSetRadix -win $nWave -radix hex \
    "${top}.adr" \
    "${top}.dat_o" \
    "${top}.dat_i" \
    "${top}.i2c_top.prer" \
    "${top}.i2c_top.ctr" \
    "${top}.i2c_top.txr" \
    "${top}.i2c_top.rxr" \
    "${top}.i2c_top.cr" \
    "${top}.i2c_top.sr" \
    "${top}.i2c_top.byte_controller.c_state" \
    "${top}.i2c_top.byte_controller.sr" \
    "${top}.i2c_top.byte_controller.core_cmd" \
    "${top}.i2c_top.byte_controller.bit_controller.c_state" \
    "${top}.i2c_top.byte_controller.bit_controller.cnt" \
    "${top}.i2c_slave.adr" \
    "${top}.i2c_slave.sr"
