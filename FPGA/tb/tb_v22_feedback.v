`timescale 1ns/1ps
module tb_v22_feedback;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[10:0]x=10;reg[9:0]y=10;reg[127:0]s=0;reg[7:0]keys=0;wire[23:0]rgb;
video_game_view dut(clk,rst,x,y,s,keys,8'd0,9'sd0,1'b0,1'b0,1'b0,1'b0,rgb,40'd0,1'b0,1'b0,80'd0);
task frame;begin @(negedge clk);x=0;y=1;@(negedge clk);x=10;y=10;end endtask
integer i;
initial begin repeat(3)@(negedge clk);rst=1;s[30]=1;s[31]=1;
keys=1;frame;if(dut.hit_age[0]!=0)$fatal(1,"raw wrong press must not award hit flash");
s[51:36]=1000;s[35:33]=1;s[29:22]=1;frame;
if(dut.hit_age[0]!=10 || dut.judge_age!=12)$fatal(1,"correct hit feedback missing");
frame;if(dut.hit_age[0]!=9)$fatal(1,"held key retriggers");
keys=3;s[51:36]=2000;s[29:22]=3;frame;
if(dut.hit_age[1]!=10 || dut.hit_age[0]!=8)$fatal(1,"chord fingers not independent");
keys=7;s[35:33]=4;frame;if(dut.hit_age[2]!=0)$fatal(1,"wrong hit flashed as success");
s[31]=0;frame;for(i=0;i<8;i=i+1)if(dut.hit_age[i]!=0)$fatal(1,"pause feedback stale");
s[31]=1;keys=0;s[29:22]=0;frame;keys=8;s[51:36]=3000;s[35:33]=1;frame;
if(dut.hit_age[3]!=10)$fatal(1,"immediate chart advance loses hit feedback");
repeat(12)frame;for(i=0;i<8;i=i+1)if(dut.hit_age[i]!=0)$fatal(1,"hit animation never ends");
$display("PASS score-qualified visual hit, chord independence, wrong/hold rejection, pause clearing, final note and decay");$finish;end
endmodule
