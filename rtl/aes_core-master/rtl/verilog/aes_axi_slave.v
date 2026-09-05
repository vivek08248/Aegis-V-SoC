`timescale 1ns/1ps

// ============================================================================
// AES AXI4-LITE SLAVE + CSR
//
// Register Map
//
// 0x00 CTRL_STATUS
//
// STATUS [31:16]
//   bit 16 = DONE
//   bit 17 = KDONE
//   bit 31:18 = RESERVED
//
// CONTROL [15:0]
//   bit 0 = LD
//   bit 1 = KLD
//   bit 2 = RST
//   bit 3 = DEC_EN
//   bit 15:4 = RESERVED
//
// 0x04 KEY0   = KEY[127:96]
// 0x08 KEY1   = KEY[95:64]
// 0x0C KEY2   = KEY[63:32]
// 0x10 KEY3   = KEY[31:0]
//
// 0x14 TEXT0  = TEXT_IN[127:96]
// 0x18 TEXT1  = TEXT_IN[95:64]
// 0x1C TEXT2  = TEXT_IN[63:32]
// 0x20 TEXT3  = TEXT_IN[31:0]
//
// 0x24 OUT0   = TEXT_OUT[127:96]
// 0x28 OUT1   = TEXT_OUT[95:64]
// 0x2C OUT2   = TEXT_OUT[63:32]
// 0x30 OUT3   = TEXT_OUT[31:0]
//
// DEC_EN:
//   0 = Encryption
//   1 = Decryption
//
// AES reset:
//   CSR RST = 1 -> AES reset
//   CSR RST = 0 -> AES operating
//
// AES core rst:
//   0 -> reset
//   1 -> operating
//
// ============================================================================

module aes_axi_slave (

    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    // AXI WRITE ADDRESS
    input  wire [5:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,

    // AXI WRITE DATA
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,

    // AXI WRITE RESPONSE
    output reg [1:0]   s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    // AXI READ ADDRESS
    input  wire [5:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,

    // AXI READ DATA
    output reg [31:0]  s_axi_rdata,
    output reg [1:0]   s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready

);

    // ========================================================================
    // CSR REGISTERS
    // ========================================================================

    reg        reg_dec_en;
    reg        reg_rst;

    reg [31:0] reg_key0;
    reg [31:0] reg_key1;
    reg [31:0] reg_key2;
    reg [31:0] reg_key3;

    reg [31:0] reg_text0;
    reg [31:0] reg_text1;
    reg [31:0] reg_text2;
    reg [31:0] reg_text3;

    // ========================================================================
    // STATUS
    // ========================================================================

    reg done_status;
    reg kdone_status;

    // ========================================================================
    // AES CONTROL PULSES
    // ========================================================================

    reg enc_ld_pulse;
    reg dec_ld_pulse;
    reg kld_pulse;

    // ========================================================================
    // DECRYPTION KEY-LOAD STATE
    // ========================================================================

    reg [4:0] kld_counter;
    reg       kld_active;

    // ========================================================================
    // AXI WRITE CONTROL
    // ========================================================================

    reg [5:0] aw_addr_lat;
    reg       aw_addr_valid;
    reg       write_done;

    // ========================================================================
    // AES SIGNALS
    // ========================================================================

    wire [127:0] aes_key;
    wire [127:0] aes_text_in;

    wire [127:0] encrypt_text_out;
    wire [127:0] decrypt_text_out;

    wire encrypt_done;
    wire decrypt_done;

    reg [127:0] latched_encrypt_text_out;
    reg [127:0] latched_decrypt_text_out;

    // ========================================================================
    // KEY MAPPING
    // ========================================================================

    assign aes_key = {
        reg_key0,
        reg_key1,
        reg_key2,
        reg_key3
    };

    // ========================================================================
    // TEXT MAPPING
    // ========================================================================

    assign aes_text_in = {
        reg_text0,
        reg_text1,
        reg_text2,
        reg_text3
    };

    // ========================================================================
    // AES RESET
    //
    // This is intentionally COMBINATIONAL.
    //
    // AXI reset active-low:
    //     s_axi_aresetn = 0 -> reset
    //
    // CSR reset:
    //     reg_rst = 1 -> reset
    //
    // AES reset:
    //     rst = 0 -> reset
    //
    // ========================================================================

    wire aes_rst_n;

    assign aes_rst_n = s_axi_aresetn && !reg_rst;

    // ========================================================================
    // ENCRYPTION CORE
    // ========================================================================

    aes_cipher_top u_aes_cipher (

        .clk      (s_axi_aclk),
        .rst      (aes_rst_n),
        .ld       (enc_ld_pulse),
        .done     (encrypt_done),
        .key      (aes_key),
        .text_in  (aes_text_in),
        .text_out (encrypt_text_out)

    );

    // ========================================================================
    // DECRYPTION CORE
    //
    // IMPORTANT:
    //
    // KLD and LD are separate operations.
    //
    // KLD:
    //     Generates inverse round-key table.
    //
    // LD:
    //     Loads ciphertext and starts decryption.
    //
    // ========================================================================

    aes_inv_cipher_top u_aes_inv_cipher (

        .clk      (s_axi_aclk),
        .rst      (aes_rst_n),
        .kld      (kld_pulse),
        .ld       (dec_ld_pulse),
        .done     (decrypt_done),
        .key      (aes_key),
        .text_in  (aes_text_in),
        .text_out (decrypt_text_out)

    );

    // ========================================================================
    // AXI WRITE PROCESS
    // ========================================================================

    always @(posedge s_axi_aclk) begin

        if (!s_axi_aresetn) begin

            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;

            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;

            aw_addr_lat   <= 6'h00;
            aw_addr_valid <= 1'b0;
            write_done    <= 1'b0;

            reg_dec_en    <= 1'b0;
            reg_rst       <= 1'b1;

            reg_key0      <= 32'h00000000;
            reg_key1      <= 32'h00000000;
            reg_key2      <= 32'h00000000;
            reg_key3      <= 32'h00000000;

            reg_text0     <= 32'h00000000;
            reg_text1     <= 32'h00000000;
            reg_text2     <= 32'h00000000;
            reg_text3     <= 32'h00000000;

            done_status   <= 1'b0;
            kdone_status  <= 1'b0;

            latched_encrypt_text_out <= 128'h0;
            latched_decrypt_text_out <= 128'h0;

            enc_ld_pulse  <= 1'b0;
            dec_ld_pulse  <= 1'b0;
            kld_pulse     <= 1'b0;

            kld_counter   <= 5'd0;
            kld_active    <= 1'b0;

        end

        else begin

            // =================================================================
            // DEFAULTS
            // =================================================================

            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;

            // All AES controls are pulses.
            enc_ld_pulse <= 1'b0;
            dec_ld_pulse <= 1'b0;
            kld_pulse    <= 1'b0;

            // =================================================================
            // AES DONE
            // =================================================================

            if (encrypt_done) begin
                done_status <= 1'b1;
                latched_encrypt_text_out <= encrypt_text_out;
            end

            if (decrypt_done) begin
                done_status <= 1'b1;
                latched_decrypt_text_out <= decrypt_text_out;
            end

            // =================================================================
            // DECRYPTION KEY EXPANSION
            //
            // aes_inv_cipher_top internally needs 11 round keys.
            //
            // kcnt starts at 10 and reaches zero after the key expansion.
            //
            // We therefore use 12 clocks as a safe completion indication.
            // =================================================================

            if (kld_active) begin

                if (kld_counter != 0) begin

                    kld_counter <= kld_counter - 5'd1;

                end

                else begin

                    kld_active   <= 1'b0;
                    kdone_status <= 1'b1;

                end

            end

            // =================================================================
            // WRITE ADDRESS
            // =================================================================

            if (s_axi_awvalid &&
                !aw_addr_valid &&
                !write_done) begin

                s_axi_awready <= 1'b1;

                aw_addr_lat   <= s_axi_awaddr;
                aw_addr_valid <= 1'b1;

            end

            // =================================================================
            // WRITE DATA
            // =================================================================

            if (s_axi_wvalid &&
                aw_addr_valid &&
                !write_done) begin

                s_axi_wready <= 1'b1;
                write_done   <= 1'b1;

                case (aw_addr_lat)

                    // =========================================================
                    // CTRL_STATUS
                    // =========================================================

                    6'h00: begin

                        if (s_axi_wstrb[0]) begin

                            // -------------------------------------------------
                            // RST
                            // -------------------------------------------------

                            if (s_axi_wdata[2]) begin

                                reg_rst       <= 1'b1;

                                done_status  <= 1'b0;
                                kdone_status <= 1'b0;

                                kld_counter  <= 5'd0;
                                kld_active   <= 1'b0;

                            end

                            else begin

                                reg_rst <= 1'b0;
                            end

                            // -------------------------------------------------
                            // DEC_EN
                            // -------------------------------------------------

                            reg_dec_en <= s_axi_wdata[3];

                            // -------------------------------------------------
                            // LD
                            // -------------------------------------------------

                            if (s_axi_wdata[0]) begin

                                done_status <= 1'b0;

                                if (s_axi_wdata[3]) begin

                                    // -----------------------------------------
                                    // DECRYPTION LOAD
                                    // -----------------------------------------

                                    dec_ld_pulse <= 1'b1;

                                end

                                else begin

                                    // -----------------------------------------
                                    // ENCRYPTION LOAD
                                    // -----------------------------------------

                                    enc_ld_pulse <= 1'b1;

                                end

                            end

                            // -------------------------------------------------
                            // KLD
                            // -------------------------------------------------

                            if (s_axi_wdata[1]) begin

                                kld_pulse    <= 1'b1;

                                kdone_status <= 1'b0;

                                // 12 cycles:
                                //
                                // KLD launches key expansion.
                                // aes_inv_cipher_top stores the generated
                                // round keys while kcnt counts down.
                                //
                                kld_counter  <= 5'd12;
                                kld_active   <= 1'b1;

                            end

                        end

                    end

                    // =========================================================
                    // KEY0
                    // =========================================================

                    6'h04: begin

                        if (s_axi_wstrb[3])
                            reg_key0[31:24] <= s_axi_wdata[31:24];

                        if (s_axi_wstrb[2])
                            reg_key0[23:16] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[1])
                            reg_key0[15:8] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[0])
                            reg_key0[7:0] <= s_axi_wdata[7:0];

                    end

                    // =========================================================
                    // KEY1
                    // =========================================================

                    6'h08: begin

                        if (s_axi_wstrb[3])
                            reg_key1[31:24] <= s_axi_wdata[31:24];

                        if (s_axi_wstrb[2])
                            reg_key1[23:16] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[1])
                            reg_key1[15:8] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[0])
                            reg_key1[7:0] <= s_axi_wdata[7:0];

                    end

                    // =========================================================
                    // KEY2
                    // =========================================================

                    6'h0C: begin

                        if (s_axi_wstrb[3])
                            reg_key2[31:24] <= s_axi_wdata[31:24];

                        if (s_axi_wstrb[2])
                            reg_key2[23:16] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[1])
                            reg_key2[15:8] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[0])
                            reg_key2[7:0] <= s_axi_wdata[7:0];

                    end

                    // =========================================================
                    // KEY3
                    // =========================================================

                    6'h10: begin

                        if (s_axi_wstrb[3])
                            reg_key3[31:24] <= s_axi_wdata[31:24];

                        if (s_axi_wstrb[2])
                            reg_key3[23:16] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[1])
                            reg_key3[15:8] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[0])
                            reg_key3[7:0] <= s_axi_wdata[7:0];

                    end

                    // =========================================================
                    // TEXT0
                    // =========================================================

                    6'h14: begin

                        if (s_axi_wstrb[3])
                            reg_text0[31:24] <= s_axi_wdata[31:24];

                        if (s_axi_wstrb[2])
                            reg_text0[23:16] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[1])
                            reg_text0[15:8] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[0])
                            reg_text0[7:0] <= s_axi_wdata[7:0];

                    end

                    // =========================================================
                    // TEXT1
                    // =========================================================

                    6'h18: begin

                        if (s_axi_wstrb[3])
                            reg_text1[31:24] <= s_axi_wdata[31:24];

                        if (s_axi_wstrb[2])
                            reg_text1[23:16] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[1])
                            reg_text1[15:8] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[0])
                            reg_text1[7:0] <= s_axi_wdata[7:0];

                    end

                    // =========================================================
                    // TEXT2
                    // =========================================================

                    6'h1C: begin

                        if (s_axi_wstrb[3])
                            reg_text2[31:24] <= s_axi_wdata[31:24];

                        if (s_axi_wstrb[2])
                            reg_text2[23:16] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[1])
                            reg_text2[15:8] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[0])
                            reg_text2[7:0] <= s_axi_wdata[7:0];

                    end

                    // =========================================================
                    // TEXT3
                    // =========================================================

                    6'h20: begin

                        if (s_axi_wstrb[3])
                            reg_text3[31:24] <= s_axi_wdata[31:24];

                        if (s_axi_wstrb[2])
                            reg_text3[23:16] <= s_axi_wdata[23:16];

                        if (s_axi_wstrb[1])
                            reg_text3[15:8] <= s_axi_wdata[15:8];

                        if (s_axi_wstrb[0])
                            reg_text3[7:0] <= s_axi_wdata[7:0];

                    end

                    default: begin
                    end

                endcase

            end

            // =================================================================
            // WRITE RESPONSE
            // =================================================================

            if (write_done && !s_axi_bvalid) begin

                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;

            end

            if (s_axi_bvalid && s_axi_bready) begin

                s_axi_bvalid  <= 1'b0;
                aw_addr_valid <= 1'b0;
                write_done    <= 1'b0;

            end

        end

    end

    // ========================================================================
    // AXI READ PROCESS
    // ========================================================================

    always @(posedge s_axi_aclk) begin

        if (!s_axi_aresetn) begin

            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'h00000000;

        end

        else begin

            s_axi_arready <= 1'b0;

            // ================================================================
            // READ REQUEST
            // ================================================================

            if (s_axi_arvalid && !s_axi_rvalid) begin

                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                case (s_axi_araddr)

                    // ========================================================
                    // CTRL_STATUS
                    // ========================================================

                    6'h00: begin

                        s_axi_rdata <= {

                            14'b0,          // [31:18]
                            kdone_status,   // [17]
                            done_status,    // [16]
                            12'b0,          // [15:4]
                            reg_dec_en,     // [3]
                            reg_rst,        // [2]
                            1'b0,           // [1] KLD pulse
                            1'b0            // [0] LD pulse

                        };

                    end

                    // ========================================================
                    // KEY
                    // ========================================================

                    6'h04:
                        s_axi_rdata <= reg_key0;

                    6'h08:
                        s_axi_rdata <= reg_key1;

                    6'h0C:
                        s_axi_rdata <= reg_key2;

                    6'h10:
                        s_axi_rdata <= reg_key3;

                    // ========================================================
                    // TEXT
                    // ========================================================

                    6'h14:
                        s_axi_rdata <= reg_text0;

                    6'h18:
                        s_axi_rdata <= reg_text1;

                    6'h1C:
                        s_axi_rdata <= reg_text2;

                    6'h20:
                        s_axi_rdata <= reg_text3;

                    // ========================================================
                    // OUTPUT
                    // ========================================================

                    6'h24: begin

                        if (reg_dec_en)
                            s_axi_rdata <= latched_decrypt_text_out[127:96];
                        else
                            s_axi_rdata <= latched_encrypt_text_out[127:96];

                    end

                    6'h28: begin

                        if (reg_dec_en)
                            s_axi_rdata <= latched_decrypt_text_out[95:64];
                        else
                            s_axi_rdata <= latched_encrypt_text_out[95:64];

                    end

                    6'h2C: begin

                        if (reg_dec_en)
                            s_axi_rdata <= latched_decrypt_text_out[63:32];
                        else
                            s_axi_rdata <= latched_encrypt_text_out[63:32];

                    end

                    6'h30: begin

                        if (reg_dec_en)
                            s_axi_rdata <= latched_decrypt_text_out[31:0];
                        else
                            s_axi_rdata <= latched_encrypt_text_out[31:0];

                    end

                    default:
                        s_axi_rdata <= 32'h00000000;

                endcase

            end

            // ================================================================
            // READ RESPONSE
            // ================================================================

            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;

        end

    end

endmodule
