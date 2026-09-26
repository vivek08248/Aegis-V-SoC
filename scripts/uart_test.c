#include <stdint.h>

#define UART_BASE   0x10000000UL
#define UART_RBR    (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_THR    (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_LSR    (*(volatile uint32_t *)(UART_BASE + 0x14))

#define RX_READY    (1 << 0)
#define TX_EMPTY    (1 << 5)

int main(void)
{
    uint32_t rx;

    /* ==========================================
     * WRITE TRANSACTION
     * ========================================== */

    while ((UART_LSR & TX_EMPTY) == 0)
        ;

    UART_THR = 'A';

    /* ==========================================
     * READ TRANSACTION
     * ========================================== */

    while ((UART_LSR & RX_READY) == 0)
        ;

    rx = UART_RBR;

    /* Echo received data */
    while ((UART_LSR & TX_EMPTY) == 0)
        ;

    UART_THR = rx;

    while (1)
        ;

    return 0;
}
