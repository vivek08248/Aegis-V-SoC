// =============================================================================
// run.f
//
// AES-128 + AXI4-Lite CSR simulation
//
// TOP:
//     tb_aes_axi_slave
//
// DUT:
//     aes_axi_slave
//
// AES:
//     aes_cipher_top
//     aes_inv_cipher_top
//
// IMPORTANT:
//     aes_con.v is NOT included because it does not exist.
//     test_bench_top.v is NOT included.
// =============================================================================

+v2k

+define+RUDIS_TB

// =============================================================================
// INCLUDE DIRECTORIES
// =============================================================================

+incdir+../../../rtl/verilog
+incdir+../../../bench/verilog

// =============================================================================
// VERDI FSDB PLI
// =============================================================================

-P /home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/LINUX64/novas.tab
/home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/LINUX64/pli.a

// =============================================================================
// AES RTL
// =============================================================================

../../../rtl/verilog/timescale.v

../../../rtl/verilog/aes_rcon.v
../../../rtl/verilog/aes_sbox.v
../../../rtl/verilog/aes_inv_sbox.v

../../../rtl/verilog/aes_key_expand_128.v

../../../rtl/verilog/aes_cipher_top.v
../../../rtl/verilog/aes_inv_cipher_top.v

// =============================================================================
// AES AXI4-LITE CSR SLAVE
// =============================================================================

../../../rtl/verilog/aes_axi_slave.v

// =============================================================================
// TESTBENCH
// =============================================================================

../../../bench/verilog/tb_aes_axi_slave.v
