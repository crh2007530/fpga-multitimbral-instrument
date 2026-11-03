`timescale 1ns/1ps
module tb_v28_render;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[127:0]game=0;reg[10:0]x=0;reg[9:0]y=0;reg[63:0]mix=0;reg signed[8:0]wave=0;wire[23:0]rgb;integer i,j,f;
video_labels dut(game,clk,rst,x,y,1'b0,1'b0,1'b1,24'hf0f5fa,,,,rgb,1'b0,22'd0,mix,wave,1'b1,24'd0);
initial begin repeat(3)@(negedge clk);rst=1;
mix[32:0]={2'd1,2'd1,5'd6,3'd4,2'd1,5'd6,2'd1,2'd1,5'd7,5'd16};mix[33]=1;mix[37:34]=2;mix[40:38]=7;mix[42:41]=2;mix[44:43]=1;mix[55:49]=75;
f=$fopen("checks/v28_mixer.ppm","wb");$fwrite(f,"P6\n1280 720\n255\n");
for(j=0;j<720;j=j+1)for(i=0;i<1280;i=i+1)begin
@(negedge clk);x=i;y=j;wave=$rtoi(90.0*$sin(i*0.045));repeat(5)@(posedge clk);#1;
if(^rgb===1'bx)$fatal(1,"unknown UI pixel");$fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);end
$fclose(f);$display("PASS mixer RTL raster with simulated waveform stimulus");$finish;end
endmodule
