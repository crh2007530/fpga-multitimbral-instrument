`timescale 1ns/1ps
module tb_chart_preview_v14;
 reg sc=0,pc=0;always #10 sc=~sc;always #7 pc=~pc;
 reg rst=0;reg[127:0] game=0;reg[255:0] chart=0;wire hs,vs,de;wire[7:0] r,g,b;
 video_dashboard #(.CUSTOM_CHART(1)) dut(game,pc,rst,sc,rst,1'b0,1'b0,10'd0,24'd0,24'd0,1'b0,16'd0,8'd0,8'd0,hs,vs,de,r,g,b,chart,1'b1,64'hffffffffffffffff,6'd0,1'b0,1'b0,40'd0,80'd0,64'd0,61'd0,1'b0,9'd0,8'd0,1'b0,22'd0,64'd0,24'd0);
 integer i,j,pos,checked=0;
 initial begin
  for(i=0;i<32;i=i+1)chart[i*8+:8]=i*7+1;
  repeat(4)@(negedge sc);rst=1;game[30]=1;
  force dut.frame_start=1'b1;
  for(i=0;i<128;i=i+1)begin @(negedge sc);game[21:16]=i%32;repeat(27)@(negedge sc);end
  repeat(60)@(negedge pc);if(checked<100)$fatal(1,"too few snapshots");
  $display("PASS %0d coherent 5-note lookahead snapshots: rapid position changes, CDC clock ratio, final out-of-range zero masks",checked);$finish;
 end
 always @(negedge pc)if(rst && dut.snapshot[184])begin
  pos=dut.snapshot[37:32];
  for(j=0;j<5;j=j+1)begin
   if(pos+j<32)begin if(dut.snapshot[144+j*8+:8]!==chart[(pos+j)*8+:8])$fatal(1,"mixed position/preview");end
   else if(dut.snapshot[144+j*8+:8]!==0)$fatal(1,"lookahead out of bounds");
  end
  checked=checked+1;
 end
endmodule
