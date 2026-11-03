`timescale 1ns/1ps
module tb_game_hud;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[127:0] s=0;reg[10:0] x=0;reg[9:0] y=0;
wire on;wire[3:0] row;wire[2:0] col;wire[7:0] letter;
video_game_text dut(clk,rst,x,y,s,on,row,col,letter);
integer i,j,v;
function[19:0] bcd;input integer value;integer k,t;begin t=value;bcd=0;for(k=0;k<5;k=k+1)begin bcd[k*4+:4]=t%10;t=t/10;end end endfunction
initial begin
repeat(3)@(negedge clk);rst=1;
for(i=0;i<25;i=i+1)begin
v=i*2000;s[51:36]=v;s[59:52]=i*2;s[75:68]=i;s[83:76]=24-i;s[91:84]=i;s[99:92]=255-i;s[67:60]=48;
repeat(240)@(negedge clk);
if(dut.digits[0]!==bcd(v) || dut.digits[1]!==bcd(i*2) || dut.digits[2]!==bcd(i) || dut.digits[3]!==bcd(24-i) || dut.digits[4]!==bcd(i) || dut.digits[5]!==bcd(255-i) || dut.digits[6]!==20'h00048)$fatal(1,"BCD cached fields");
end
s[30]=1;s[100]=0;s[31]=0;x=432;y=296;repeat(3)@(negedge clk);#1;if(letter!="T" || !on)$fatal(1,"ready caption");
s[100]=1;repeat(3)@(negedge clk);#1;if(letter!="P")$fatal(1,"paused caption");
s[32]=1;repeat(3)@(negedge clk);#1;if(letter!="C")$fatal(1,"result caption");
$display("PASS HUD: 175 BCD field conversions, score 0..48000, counts up to255, ready/pause/result captions");$finish;
end
endmodule
