import re

with open('./rtl/interconnect/aegis_v_soc.v', 'r') as f:
    content = f.read()

# 1. Add pwm_out to ports
port_str = """
    // -------------------------------------------------------------------------
    // PWM output
    // -------------------------------------------------------------------------
    output wire        pwm_out,
"""
content = re.sub(r'(// -------------------------------------------------------------------------[\r\n]+    // JTAG \(for VeeR debug\))', port_str + r'\1', content)

# 2. Add ic_m04_* wires
ic_m04_str = """
    // -------------------------------------------------------------------------
    // Interconnect M04 (PWM)
    // -------------------------------------------------------------------------
    wire [AXI_ID_WIDTH-1:0]   ic_m04_awid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m04_awaddr;
    wire [7:0]  ic_m04_awlen;  wire [2:0] ic_m04_awsize; wire [1:0] ic_m04_awburst;
    wire        ic_m04_awlock; wire [3:0] ic_m04_awcache; wire [2:0] ic_m04_awprot;
    wire [3:0]  ic_m04_awqos;  wire [3:0] ic_m04_awregion;
    wire        ic_m04_awvalid, ic_m04_awready;
    wire [AXI_DATA_WIDTH-1:0] ic_m04_wdata;
    wire [3:0]  ic_m04_wstrb;  wire ic_m04_wlast; wire ic_m04_wvalid; wire ic_m04_wready;
    wire [AXI_ID_WIDTH-1:0]   ic_m04_bid;
    wire [1:0]  ic_m04_bresp;  wire ic_m04_bvalid; wire ic_m04_bready;
    wire [AXI_ID_WIDTH-1:0]   ic_m04_arid;
    wire [AXI_ADDR_WIDTH-1:0] ic_m04_araddr;
    wire [7:0]  ic_m04_arlen;  wire [2:0] ic_m04_arsize; wire [1:0] ic_m04_arburst;
    wire        ic_m04_arlock; wire [3:0] ic_m04_arcache; wire [2:0] ic_m04_arprot;
    wire [3:0]  ic_m04_arqos;  wire [3:0] ic_m04_arregion;
    wire        ic_m04_arvalid, ic_m04_arready;
    wire [AXI_ID_WIDTH-1:0]   ic_m04_rid;
    wire [AXI_DATA_WIDTH-1:0] ic_m04_rdata;
    wire [1:0]  ic_m04_rresp;  wire ic_m04_rlast; wire ic_m04_rvalid; wire ic_m04_rready;
"""
content = re.sub(r'(    wire m04_awrdy=1\'b0, m04_wrdy=1\'b0)', ic_m04_str + r'\1', content)

# 3. Add m_axil_pwm_* wires
m_axil_pwm_str = """
    // -------------------------------------------------------------------------
    // AXI-Lite PWM
    // -------------------------------------------------------------------------
    wire [31:0] m_axil_pwm_awaddr;  wire [2:0] m_axil_pwm_awprot;
    wire        m_axil_pwm_awvalid; wire       m_axil_pwm_awready;
    wire [31:0] m_axil_pwm_wdata;   wire [3:0] m_axil_pwm_wstrb;
    wire        m_axil_pwm_wvalid;  wire       m_axil_pwm_wready;
    wire [1:0]  m_axil_pwm_bresp;   wire       m_axil_pwm_bvalid;
    wire        m_axil_pwm_bready;
    wire [31:0] m_axil_pwm_araddr;  wire [2:0] m_axil_pwm_arprot;
    wire        m_axil_pwm_arvalid; wire       m_axil_pwm_arready;
    wire [31:0] m_axil_pwm_rdata;   wire [1:0] m_axil_pwm_rresp;
    wire        m_axil_pwm_rvalid;  wire       m_axil_pwm_rready;
"""
content = re.sub(r'(    // =========================================================================[\r\n]+    // Module Instantiations)', m_axil_pwm_str + r'\1', content)

# 4. Map m04_axi_* in interconnect
m04_map_str = """        // Master port 4: PWM
        .m04_axi_awid    (ic_m04_awid),    .m04_axi_awaddr  (ic_m04_awaddr),
        .m04_axi_awlen   (ic_m04_awlen),   .m04_axi_awsize  (ic_m04_awsize),
        .m04_axi_awburst (ic_m04_awburst), .m04_axi_awlock  (ic_m04_awlock),
        .m04_axi_awcache (ic_m04_awcache), .m04_axi_awprot  (ic_m04_awprot),
        .m04_axi_awqos   (ic_m04_awqos),   .m04_axi_awvalid (ic_m04_awvalid),
        .m04_axi_awready (ic_m04_awready),
        .m04_axi_wdata   (ic_m04_wdata),   .m04_axi_wstrb   (ic_m04_wstrb),
        .m04_axi_wlast   (ic_m04_wlast),   .m04_axi_wvalid  (ic_m04_wvalid),
        .m04_axi_wready  (ic_m04_wready),
        .m04_axi_bid     (ic_m04_bid),     .m04_axi_bresp   (ic_m04_bresp),
        .m04_axi_bvalid  (ic_m04_bvalid),  .m04_axi_bready  (ic_m04_bready),
        .m04_axi_arid    (ic_m04_arid),    .m04_axi_araddr  (ic_m04_araddr),
        .m04_axi_arlen   (ic_m04_arlen),   .m04_axi_arsize  (ic_m04_arsize),
        .m04_axi_arburst (ic_m04_arburst), .m04_axi_arlock  (ic_m04_arlock),
        .m04_axi_arcache (ic_m04_arcache), .m04_axi_arprot  (ic_m04_arprot),
        .m04_axi_arqos   (ic_m04_arqos),   .m04_axi_arvalid (ic_m04_arvalid),
        .m04_axi_arready (ic_m04_arready),
        .m04_axi_rid     (ic_m04_rid),     .m04_axi_rdata   (ic_m04_rdata),
        .m04_axi_rresp   (ic_m04_rresp),   .m04_axi_rlast   (ic_m04_rlast),
        .m04_axi_rvalid  (ic_m04_rvalid),  .m04_axi_rready  (ic_m04_rready),
"""
# Need to replace the stub block for M04
stub_m04_pattern = r'        \.m04_axi_awvalid\(\).*?\.m04_axi_rlast\(1\'b1\),'
content = re.sub(stub_m04_pattern, m04_map_str, content, flags=re.DOTALL)

# 5. Instantiate bridge and PWM
pwm_inst_str = """
    // =========================================================================
    // PWM Subsystem (M04)
    // =========================================================================
    axi4_to_axilite_bridge #(
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .LITE_ADDR_W    (4)
    ) u_bridge_pwm (
        .clk            (clk),
        .rst            (rst_sync),

        // AXI4 slave interface (from interconnect)
        .s_axi_awid    (ic_m04_awid),
        .s_axi_awaddr  (ic_m04_awaddr),
        .s_axi_awlen   (ic_m04_awlen),
        .s_axi_awsize  (ic_m04_awsize),
        .s_axi_awburst (ic_m04_awburst),
        .s_axi_awlock  (ic_m04_awlock),
        .s_axi_awcache (ic_m04_awcache),
        .s_axi_awprot  (ic_m04_awprot),
        .s_axi_awqos   (ic_m04_awqos),
        .s_axi_awregion(ic_m04_awregion),
        .s_axi_awvalid (ic_m04_awvalid),
        .s_axi_awready (ic_m04_awready),
        .s_axi_wdata   (ic_m04_wdata),
        .s_axi_wstrb   (ic_m04_wstrb),
        .s_axi_wlast   (ic_m04_wlast),
        .s_axi_wvalid  (ic_m04_wvalid),
        .s_axi_wready  (ic_m04_wready),
        .s_axi_bid     (ic_m04_bid),
        .s_axi_bresp   (ic_m04_bresp),
        .s_axi_bvalid  (ic_m04_bvalid),
        .s_axi_bready  (ic_m04_bready),
        .s_axi_arid    (ic_m04_arid),
        .s_axi_araddr  (ic_m04_araddr),
        .s_axi_arlen   (ic_m04_arlen),
        .s_axi_arsize  (ic_m04_arsize),
        .s_axi_arburst (ic_m04_arburst),
        .s_axi_arlock  (ic_m04_arlock),
        .s_axi_arcache (ic_m04_arcache),
        .s_axi_arprot  (ic_m04_arprot),
        .s_axi_arqos   (ic_m04_arqos),
        .s_axi_arregion(ic_m04_arregion),
        .s_axi_arvalid (ic_m04_arvalid),
        .s_axi_arready (ic_m04_arready),
        .s_axi_rid     (ic_m04_rid),
        .s_axi_rdata   (ic_m04_rdata),
        .s_axi_rresp   (ic_m04_rresp),
        .s_axi_rlast   (ic_m04_rlast),
        .s_axi_rvalid  (ic_m04_rvalid),
        .s_axi_rready  (ic_m04_rready),

        // AXI-Lite master interface (to peripheral)
        .m_axil_awaddr (m_axil_pwm_awaddr),
        .m_axil_awprot (m_axil_pwm_awprot),
        .m_axil_awvalid(m_axil_pwm_awvalid),
        .m_axil_awready(m_axil_pwm_awready),
        .m_axil_wdata  (m_axil_pwm_wdata),
        .m_axil_wstrb  (m_axil_pwm_wstrb),
        .m_axil_wvalid (m_axil_pwm_wvalid),
        .m_axil_wready (m_axil_pwm_wready),
        .m_axil_bresp  (m_axil_pwm_bresp),
        .m_axil_bvalid (m_axil_pwm_bvalid),
        .m_axil_bready (m_axil_pwm_bready),
        .m_axil_araddr (m_axil_pwm_araddr),
        .m_axil_arprot (m_axil_pwm_arprot),
        .m_axil_arvalid(m_axil_pwm_arvalid),
        .m_axil_arready(m_axil_pwm_arready),
        .m_axil_rdata  (m_axil_pwm_rdata),
        .m_axil_rresp  (m_axil_pwm_rresp),
        .m_axil_rvalid (m_axil_pwm_rvalid),
        .m_axil_rready (m_axil_pwm_rready)
    );

    myip_v1_0 #(
        .C_S00_AXI_DATA_WIDTH (32),
        .C_S00_AXI_ADDR_WIDTH (4)
    ) u_pwm (
        .s00_axi_aclk    (clk),
        .s00_axi_aresetn (~rst_sync), // IP takes active-low reset
        
        .s00_axi_awaddr  (m_axil_pwm_awaddr[3:0]),
        .s00_axi_awprot  (m_axil_pwm_awprot),
        .s00_axi_awvalid (m_axil_pwm_awvalid),
        .s00_axi_awready (m_axil_pwm_awready),
        
        .s00_axi_wdata   (m_axil_pwm_wdata),
        .s00_axi_wstrb   (m_axil_pwm_wstrb),
        .s00_axi_wvalid  (m_axil_pwm_wvalid),
        .s00_axi_wready  (m_axil_pwm_wready),
        
        .s00_axi_bresp   (m_axil_pwm_bresp),
        .s00_axi_bvalid  (m_axil_pwm_bvalid),
        .s00_axi_bready  (m_axil_pwm_bready),
        
        .s00_axi_araddr  (m_axil_pwm_araddr[3:0]),
        .s00_axi_arprot  (m_axil_pwm_arprot),
        .s00_axi_arvalid (m_axil_pwm_arvalid),
        .s00_axi_arready (m_axil_pwm_arready),
        
        .s00_axi_rdata   (m_axil_pwm_rdata),
        .s00_axi_rresp   (m_axil_pwm_rresp),
        .s00_axi_rvalid  (m_axil_pwm_rvalid),
        .s00_axi_rready  (m_axil_pwm_rready),
        
        .PWM_OUT         (pwm_out)
    );

"""
content = re.sub(r'(endmodule)', pwm_inst_str + r'\1', content)

with open('./rtl/interconnect/aegis_v_soc.v', 'w') as f:
    f.write(content)

