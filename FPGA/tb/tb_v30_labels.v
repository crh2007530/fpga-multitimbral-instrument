`timescale 1ns/1ps
module tb_v30_labels;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[127:0]game=0;reg[10:0]x=448;reg[9:0]y=96;
video_labels dut(game,clk,rst,x,y,1'b0,1'b0,1'b1,24'hf0f5fa,,,,,1'b0,22'd0,64'd0,9'sd0,1'b0,24'd0);
initial begin
repeat(3)@(negedge clk);rst=1;#1;
if(dut.letter==0)$fatal(1,"free play editing target lost");
game[100]=1;#1;if(dut.letter!=0)$fatal(1,"practice shows editing target as score target");
x=256;#1;if(dut.letter==0)$fatal(1,"built-in speed hint missing");
game[104]=1;#1;if(dut.letter!=0)$fatal(1,"uploaded timing falsely shows speed keys");
game[30]=1;x=448;y=152;#1;if(dut.letter!=0)$fatal(1,"uploaded game speed hint");
game[104]=0;#1;if(dut.letter==0)$fatal(1,"built-in game speed hint missing");
$display("PASS normal editing target retained, practice target ambiguity removed, uploaded timing hides unsupported speed hint");$finish;
end
endmodule
