# Aegis-V System Control & Status IP

AXI4-Lite peripheral for the Aegis-V SoC.

## Base address

`0x4000_0000` (M04)

## Register map

| Offset | Register | Description |
|---|---|---|
| 0x00 | SYS_CTRL | System control bits |
| 0x04 | SYS_STATUS | Live system/peripheral status |
| 0x08 | IRQ_ENABLE | Interrupt enable |
| 0x0C | IRQ_STATUS | Interrupt status / W1C |
| 0x10 | SCRATCH | Software read/write |
| 0x14 | SYS_ID | IP identification |
| 0x18 | VERSION | IP version |
| 0x1C | COUNTER | Free-running cycle counter |

## SYS_CTRL

bit 0: SYS_ENABLE  
bit 1: SOFT_RESET  
bit 2: DEBUG_ENABLE  
bit 3: LOW_POWER  
bit 4: IRQ_GLOBAL_ENABLE

## SYS_STATUS

bit 0: UART_READY  
bit 1: AES_READY  
bit 2: I2C_READY  
bit 3: WATCHDOG_ACTIVE  
bit 4: IRQ_PENDING  
bit 5: SECURITY_ERROR  
bit 6: BUS_ERROR  
bit 7: DEBUG_ACTIVE

## IRQ sources

bit 0: security error  
bit 1: bus error  
bit 2: watchdog active

## Notes

The integration snippet assumes the existing M04 AXI4-Lite signals are already produced by the Aegis-V interconnect/bridge. Adapt signal names to the exact top-level declarations in your checkout.
