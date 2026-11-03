`timescale 1ns/1ps
module tb_exp3_oled;
reg clk=0;always #5 clk=~clk;reg rst=0;tri1 sda;
reg[319:0] points={64{5'd16}};
oled_status #(.EXTENDED(1),.EXPANSION(1),.EXPRESSION(1),.WAVEFORM(1)) dut(
 .clk(clk),.rst_n(rst),.sda(sda),.visual_mode(2'd0),.spectrum_bars(75'd0),.wave_points(points),.expression_config(4'd0),
 .octave(2'd0),.keys(11'd0),.history(112'd0),.history_valid(4'd0),.event_count(16'd0),
 .voice_modes(16'd0),.selected(4'd8),.test_mask(4'd0),.test_mode(1'b0),.chord_mode(1'b0),
 .test32(1'b0),.selected_test(5'd0),.mask32(32'd0));
integer x,y,b;reg[7:0] expected;
reg[319:0] shape;
initial begin
 #1;#10;rst=1;
 for(x=0;x<64;x=x+1)shape[5*x+:5]=x%32;
 @(negedge clk);dut.state=7;dut.timer=999999;points=shape;
 @(negedge clk);
 if(dut.frame_wave!==shape)$fatal(1,"frame snapshot");
 points=0;force dut.state=4;dut.frame_history=0;
 for(y=4;y<8;y=y+1)for(x=0;x<128;x=x+1)begin
  dut.page=y;dut.byte_index=x+2;repeat(4)@(negedge clk);#1;expected=0;
  for(b=0;b<8;b=b+1)begin
   if(((y-4)*8+b>=shape[(x/2)*5+:5] && (y-4)*8+b<=shape[(x/2==0?0:x/2-1)*5+:5]) ||
      ((y-4)*8+b<=shape[(x/2)*5+:5] && (y-4)*8+b>=shape[(x/2==0?0:x/2-1)*5+:5]))expected[b]=1;
   if((y-4)*8+b==16 && x%8==0)expected[b]=1;
  end
  if(dut.pixels!==expected)$fatal(1,"raster x%0d page%0d got%h wanted%h",x,y,dut.pixels,expected);
 end
 if(dut.frame_wave!==shape)$fatal(1,"torn frame");
 $display("PASS OLED atomic waveform snapshot and all 512 raster bytes including connected segments and zero axis");$finish;
end
endmodule
