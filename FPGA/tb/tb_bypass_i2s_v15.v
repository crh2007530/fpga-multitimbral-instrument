`timescale 1ns/1ps
module tb_bypass_i2s_v15;
 reg clk=0;always #5 clk=~clk;reg rst=0;reg[63:0] raw=0;reg[3:0] cfg=0;
 wire b0,l0,d0,b1,l1,d1;wire[15:0] u0,u1;
 pcm_pressure_poly32 #(.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.WARMUP_FRAMES(1),.CUSTOM_MAP(1),.MULTIFX(0)) baseline(
 .clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.voice_modes(16'd0),.chord_mode(1'b1),.test_mode(1'b0),.test32(1'b0),.test_mask(4'hf),.mask32(~64'd0),.expression_config(cfg),.map_enabled(1'b1),.keymap({8{7'd69}}),.extra_fx(2'd0),.bclk(b0),.lrclk(l0),.din(d0),.underruns(u0));
 pcm_pressure_poly32 #(.EXPRESSION(1),.FRAME_CONTROL(1),.INSTRUMENTS(1),.WARMUP_FRAMES(1),.CUSTOM_MAP(1),.MULTIFX(1)) extended(
 .clk(clk),.rst_n(rst),.pressure_valid(8'hff),.pressure_raw(raw),.voice_modes(16'd0),.chord_mode(1'b1),.test_mode(1'b0),.test32(1'b0),.test_mask(4'hf),.mask32(~64'd0),.expression_config(cfg),.map_enabled(1'b1),.keymap({8{7'd69}}),.extra_fx(2'd0),.bclk(b1),.lrclk(l1),.din(d1),.underruns(u1));
 integer i;
 always @(negedge clk)if(rst && {b0,l0,d0}!=={b1,l1,d1})$fatal(1,"new bypass changed physical I2S cadence/data");
 initial begin repeat(4)@(negedge clk);rst=1;
 for(i=0;i<512;i=i+1)begin
 repeat(512)@(negedge clk);raw=i%100<70?64'h8070605040302018:0;cfg=i[7:4];
 end
 if(u0!=0 || u1!=0)$fatal(1,"underrun");
 $display("PASS 512 frames bit-for-bit I2S equivalence: bypass adds no output frame latency and preserves original audio");$finish;
 end
endmodule
