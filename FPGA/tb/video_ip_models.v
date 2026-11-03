// Functional stubs ONLY for control/audio top-level regressions.
// They do not validate PLL frequency, TMDS serialization or physical HDMI.
// Raster and CDC are separately exercised by tb_video_dashboard.
module video_pll(input clkin,mdclk,output clkout0,clkout1,lock);
 assign clkout0=clkin;assign clkout1=clkin;assign lock=1'b1;
endmodule
module DVI_TX_Top(input I_rst_n,I_serial_clk,I_rgb_clk,I_rgb_vs,I_rgb_hs,I_rgb_de,
 input[7:0] I_rgb_r,I_rgb_g,I_rgb_b,
 output O_tmds_clk_p,O_tmds_clk_n,output[2:0] O_tmds_data_p,O_tmds_data_n);
 assign O_tmds_clk_p=I_rgb_clk;assign O_tmds_clk_n=~I_rgb_clk;
 assign O_tmds_data_p=3'b0;assign O_tmds_data_n=3'b111;
endmodule

// Gate functional stub for top-level control regressions only.
module DHCE(input CLKIN,CEN,output CLKOUT);
 reg[3:0] enabled=0;
 always @(negedge CLKIN) enabled<={enabled[2:0],~CEN};
 assign CLKOUT=CLKIN & enabled[3];
endmodule
