`timescale 1ns/1ps
module tb_chart_pixels_v14;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg[10:0] x=0;reg[9:0] y=0;reg[127:0] state=0;reg[39:0] preview=0;
 wire[23:0] rgb;
 video_game_view #(.CUSTOM_CHART(1)) dut(clk,rst,x,y,state,8'd0,8'd0,9'sd0,1'b0,1'b0,1'b0,1'b0,rgb,preview,1'b1,1'b0,80'd0);
 integer pos,q,lane,checks=0;reg[7:0] mask;reg[23:0] expected;
 function[7:0] chartmask;input integer i;begin chartmask=i<32?((8'h01<<(i%8))|(8'h01<<((i+3)%8))):0;end endfunction
 initial begin
 repeat(3)@(negedge clk);rst=1;state[30]=1;state[31]=1;
 for(pos=0;pos<32;pos=pos+1)begin
  @(negedge clk);state[21:16]=pos;state[15:0]=2500+pos*500;
  for(q=0;q<5;q=q+1)preview[q*8+:8]=chartmask(pos+q);
  repeat(6)@(negedge clk);
  for(q=1;q<5;q=q+1)begin
   x=0;y=602-(q-1)*125;repeat(2)@(negedge clk);
   mask=chartmask(pos+q);
   if(dut.row_notes!==mask)$fatal(1,"row masks pos=%d lookahead=%d",pos,q);
   for(lane=0;lane<8;lane=lane+1)begin
    x=(dut.edge_x[lane]+dut.edge_x[lane+1])/2;repeat(2)@(negedge clk);
    if(mask[lane] && rgb!==24'hffbf55)$fatal(1,"missing custom note pixel pos=%d q=%d lane=%d rgb=%h",pos,q,lane,rgb);
    if(!mask[lane] && rgb===24'hffbf55)$fatal(1,"phantom custom note pixel");checks=checks+1;
   end
  end
 end
 $display("PASS %0d custom chart lane pixels: all32 positions, four visible lookaheads, end-of-chart no phantom notes",checks);$finish;
 end
endmodule
