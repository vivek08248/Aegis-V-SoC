/*
 * Connect these signals to the existing Aegis-V M04 AXI4-Lite bridge.
 * Address seen by this IP is the low 5 bits of the M04 peripheral address.
 *
 * Base address: 0x4000_0000
 */

wire scs_irq;

system_control_status u_scs_m04 (
    .aclk               (clk),
    .aresetn            (rst_n),

    .s_axi_awaddr       (m04_awaddr[4:0]),
    .s_axi_awvalid      (m04_awvalid),
    .s_axi_awready      (m04_awready),
    .s_axi_wdata        (m04_wdata),
    .s_axi_wstrb        (m04_wstrb),
    .s_axi_wvalid       (m04_wvalid),
    .s_axi_wready       (m04_wready),
    .s_axi_bresp        (m04_bresp),
    .s_axi_bvalid       (m04_bvalid),
    .s_axi_bready       (m04_bready),

    .s_axi_araddr       (m04_araddr[4:0]),
    .s_axi_arvalid      (m04_arvalid),
    .s_axi_arready      (m04_arready),
    .s_axi_rdata        (m04_rdata),
    .s_axi_rresp        (m04_rresp),
    .s_axi_rvalid       (m04_rvalid),
    .s_axi_rready       (m04_rready),

    .uart_ready         (uart_ready),
    .aes_ready          (aes_ready),
    .i2c_ready          (i2c_ready),
    .watchdog_active    (watchdog_active),
    .security_error     (security_error),
    .bus_error          (bus_error),
    .debug_active       (debug_active),

    .sys_enable         (),
    .soft_reset         (),
    .debug_enable       (),
    .low_power          (),
    .irq_global_enable  (),
    .irq                (scs_irq)
);
