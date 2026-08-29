simSetSimulator "-vcssv" -exec \
           "/home/student/Documents/1602-23-735-127/proj-dir/run/simv" -args
debImport "-dbdir" \
          "/home/student/Documents/1602-23-735-127/proj-dir/run/simv.daidir"
debLoadSimResult /home/student/Documents/1602-23-735-127/proj-dir/run/dump.fsdb
wvCreateWindow
verdiWindowResize -win $_Verdi_1 "0" "0" "900" "700"
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
debLoadSimResult /home/student/Documents/1602-23-735-127/proj-dir/run/dump.fsdb
verdiSetActWin -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/_vcs_msglog"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9"
wvAddAllSignals -win $_nWave2
verdiDockWidgetMaximize -dock windowDock_nWave_2
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 22
wvScrollDown -win $_nWave2 17
wvScrollDown -win $_nWave2 26
wvScrollDown -win $_nWave2 28
wvScrollDown -win $_nWave2 20
wvScrollDown -win $_nWave2 19
wvScrollDown -win $_nWave2 17
wvScrollDown -win $_nWave2 23
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 6
wvScrollDown -win $_nWave2 3
wvScrollDown -win $_nWave2 3
wvScrollDown -win $_nWave2 28
wvScrollDown -win $_nWave2 25
wvScrollDown -win $_nWave2 54
wvScrollDown -win $_nWave2 45
wvScrollDown -win $_nWave2 51
wvScrollDown -win $_nWave2 57
wvScrollDown -win $_nWave2 45
wvScrollDown -win $_nWave2 51
wvScrollDown -win $_nWave2 51
wvScrollDown -win $_nWave2 51
wvScrollDown -win $_nWave2 56
wvScrollDown -win $_nWave2 48
wvScrollDown -win $_nWave2 51
wvScrollDown -win $_nWave2 63
wvScrollDown -win $_nWave2 33
wvScrollDown -win $_nWave2 40
wvScrollDown -win $_nWave2 34
wvScrollDown -win $_nWave2 28
wvScrollDown -win $_nWave2 26
wvScrollDown -win $_nWave2 28
wvScrollDown -win $_nWave2 25
wvScrollDown -win $_nWave2 29
wvScrollDown -win $_nWave2 20
wvScrollDown -win $_nWave2 22
wvScrollDown -win $_nWave2 20
wvScrollDown -win $_nWave2 37
wvScrollDown -win $_nWave2 19
wvScrollDown -win $_nWave2 20
wvScrollDown -win $_nWave2 17
wvScrollDown -win $_nWave2 20
wvScrollDown -win $_nWave2 23
wvScrollDown -win $_nWave2 19
wvScrollDown -win $_nWave2 20
wvScrollDown -win $_nWave2 17
wvScrollDown -win $_nWave2 17
wvScrollDown -win $_nWave2 17
wvScrollDown -win $_nWave2 26
wvScrollDown -win $_nWave2 17
wvScrollDown -win $_nWave2 14
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 9
wvScrollDown -win $_nWave2 8
wvScrollDown -win $_nWave2 9
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 6
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 20
wvScrollDown -win $_nWave2 17
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 9
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 9
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 14
wvScrollDown -win $_nWave2 11
wvScrollDown -win $_nWave2 12
wvScrollDown -win $_nWave2 17
wvScrollDown -win $_nWave2 39
wvScrollDown -win $_nWave2 23
wvScrollDown -win $_nWave2 3
wvScrollUp -win $_nWave2 5
wvScrollUp -win $_nWave2 9
wvScrollUp -win $_nWave2 6
wvScrollUp -win $_nWave2 2
wvScrollUp -win $_nWave2 9
wvScrollUp -win $_nWave2 6
wvScrollUp -win $_nWave2 5
wvScrollUp -win $_nWave2 3
wvScrollUp -win $_nWave2 3
wvScrollUp -win $_nWave2 3
wvScrollUp -win $_nWave2 28
wvScrollUp -win $_nWave2 28
wvScrollUp -win $_nWave2 29
wvScrollUp -win $_nWave2 53
wvScrollUp -win $_nWave2 77
wvScrollUp -win $_nWave2 107
wvScrollUp -win $_nWave2 119
wvScrollUp -win $_nWave2 124
wvScrollUp -win $_nWave2 108
wvScrollUp -win $_nWave2 107
wvScrollUp -win $_nWave2 105
wvScrollUp -win $_nWave2 138
wvScrollUp -win $_nWave2 79
wvScrollUp -win $_nWave2 77
wvScrollUp -win $_nWave2 68
wvScrollUp -win $_nWave2 48
wvScrollUp -win $_nWave2 37
wvScrollUp -win $_nWave2 48
wvScrollUp -win $_nWave2 34
wvScrollUp -win $_nWave2 39
wvScrollUp -win $_nWave2 37
wvScrollUp -win $_nWave2 42
wvScrollUp -win $_nWave2 46
wvScrollUp -win $_nWave2 19
wvScrollUp -win $_nWave2 31
wvScrollUp -win $_nWave2 23
wvScrollUp -win $_nWave2 23
wvScrollUp -win $_nWave2 19
wvScrollUp -win $_nWave2 20
wvScrollUp -win $_nWave2 23
wvScrollUp -win $_nWave2 3
wvSelectGroup -win $_nWave2 {G1}
wvSetCursor -win $_nWave2 30080.504638 -snap {("G1" 11)}
wvSelectAll -win $_nWave2
wvCut -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSelectGroup -win $_nWave2 {G2}
wvCut -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSelectGroup -win $_nWave2 {G1}
wvCut -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 0)}
wvGetSignalOpen -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_axi_interconnect_wrap_2x9/m0_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arburst\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arlen\[7:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arqos\[3:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arready} \
{/tb_axi_interconnect_wrap_2x9/m0_arvalid} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 )} 
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_axi_interconnect_wrap_2x9/m0_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arburst\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arlen\[7:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arqos\[3:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arready} \
{/tb_axi_interconnect_wrap_2x9/m0_arvalid} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 )} 
wvSetPosition -win $_nWave2 {("G1" 6)}
wvGetSignalClose -win $_nWave2
wvZoomAll -win $_nWave2
wvSelectGroup -win $_nWave2 {G2}
wvSelectGroup -win $_nWave2 {G2}
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/_vcs_msglog"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9/u_master0"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9"
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_axi_interconnect_wrap_2x9/m0_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arburst\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arlen\[7:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arqos\[3:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arready} \
{/tb_axi_interconnect_wrap_2x9/m0_arvalid} \
{/tb_axi_interconnect_wrap_2x9/m0_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_awburst\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_awlen\[7:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_awready} \
{/tb_axi_interconnect_wrap_2x9/m0_awsize\[2:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_awvalid} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 7 8 9 10 11 12 )} 
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvSetPosition -win $_nWave2 {("G1" 12)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_axi_interconnect_wrap_2x9/m0_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arburst\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arlen\[7:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arqos\[3:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_arready} \
{/tb_axi_interconnect_wrap_2x9/m0_arvalid} \
{/tb_axi_interconnect_wrap_2x9/m0_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_awburst\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_awlen\[7:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_awready} \
{/tb_axi_interconnect_wrap_2x9/m0_awsize\[2:0\]} \
{/tb_axi_interconnect_wrap_2x9/m0_awvalid} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 7 8 9 10 11 12 )} 
wvSetPosition -win $_nWave2 {("G1" 12)}
wvGetSignalClose -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/_vcs_msglog"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9"
wvSelectGroup -win $_nWave2 {G2}
wvSelectAll -win $_nWave2
wvCut -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 0)}
wvSelectGroup -win $_nWave2 {G2}
wvCut -win $_nWave2
wvSetPosition -win $_nWave2 {("G1" 0)}
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/_vcs_msglog"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9"
wvGetSignalSetScope -win $_nWave2 "/_vcs_msglog"
wvGetSignalSetScope -win $_nWave2 "/_vcs_unit__3635444054"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9"
wvGetSignalSetScope -win $_nWave2 "/uvm_custom_install_recording"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9/dut"
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_rresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_wdata\[31:0\]} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 )} 
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvSetPosition -win $_nWave2 {("G1" 6)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_rresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_wdata\[31:0\]} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 1 2 3 4 5 6 )} 
wvSetPosition -win $_nWave2 {("G1" 6)}
wvGetSignalClose -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvZoomAll -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/_vcs_msglog"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9"
wvGetSignalSetScope -win $_nWave2 "/tb_axi_interconnect_wrap_2x9/dut"
wvSetPosition -win $_nWave2 {("G1" 58)}
wvSetPosition -win $_nWave2 {("G1" 58)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_rresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m01_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m01_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m01_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m01_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m01_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_rresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m03_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m03_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m03_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m03_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m03_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m04_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m04_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m04_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m04_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m04_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m05_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m05_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m05_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m05_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m05_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m06_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m06_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m06_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m06_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m06_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m07_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m07_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m07_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m07_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m07_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m08_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m08_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m08_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m08_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m08_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_rresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s01_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s01_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s01_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s01_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s01_axi_wdata\[31:0\]} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 \
           22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 \
           44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 )} 
wvSetPosition -win $_nWave2 {("G1" 58)}
wvSetPosition -win $_nWave2 {("G1" 58)}
wvSetPosition -win $_nWave2 {("G1" 58)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_rresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m00_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m01_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m01_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m01_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m01_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m01_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_rresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m02_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m03_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m03_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m03_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m03_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m03_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m04_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m04_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m04_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m04_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m04_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m05_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m05_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m05_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m05_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m05_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m06_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m06_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m06_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m06_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m06_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m07_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m07_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m07_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m07_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m07_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m08_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m08_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m08_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m08_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/m08_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_rresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s00_axi_wdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s01_axi_araddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s01_axi_awaddr\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s01_axi_bresp\[1:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s01_axi_rdata\[31:0\]} \
{/tb_axi_interconnect_wrap_2x9/dut/s01_axi_wdata\[31:0\]} \
}
wvAddSignal -win $_nWave2 -group {"G2" \
}
wvSelectSignal -win $_nWave2 {( "G1" 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 \
           22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 \
           44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 )} 
wvSetPosition -win $_nWave2 {("G1" 58)}
wvGetSignalClose -win $_nWave2
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 0
wvScrollDown -win $_nWave2 2
wvScrollDown -win $_nWave2 16
wvScrollDown -win $_nWave2 2
wvScrollDown -win $_nWave2 6
wvScrollDown -win $_nWave2 2
wvScrollUp -win $_nWave2 1
wvScrollDown -win $_nWave2 1
wvZoomAll -win $_nWave2
wvScrollDown -win $_nWave2 2
wvScrollUp -win $_nWave2 3
wvScrollDown -win $_nWave2 2
debExit
