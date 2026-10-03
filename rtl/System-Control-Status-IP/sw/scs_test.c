#include <stdint.h>

#define SCS_BASE       0x40000000UL
#define SYS_CTRL       (*(volatile uint32_t *)(SCS_BASE + 0x00))
#define SYS_STATUS     (*(volatile uint32_t *)(SCS_BASE + 0x04))
#define IRQ_ENABLE     (*(volatile uint32_t *)(SCS_BASE + 0x08))
#define IRQ_STATUS     (*(volatile uint32_t *)(SCS_BASE + 0x0C))
#define SCRATCH        (*(volatile uint32_t *)(SCS_BASE + 0x10))
#define SYS_ID         (*(volatile uint32_t *)(SCS_BASE + 0x14))
#define VERSION        (*(volatile uint32_t *)(SCS_BASE + 0x18))
#define COUNTER        (*(volatile uint32_t *)(SCS_BASE + 0x1C))

int main(void)
{
    SYS_CTRL = 0x00000015;       /* enable + debug + global IRQ */
    IRQ_ENABLE = 0x00000007;
    SCRATCH = 0xA5A55A5A;

    volatile uint32_t id = SYS_ID;
    volatile uint32_t ver = VERSION;
    volatile uint32_t status = SYS_STATUS;
    volatile uint32_t count = COUNTER;

    (void)id; (void)ver; (void)status; (void)count;

    while (1) {
        if (IRQ_STATUS)
            IRQ_STATUS = IRQ_STATUS;
    }
    return 0;
}
