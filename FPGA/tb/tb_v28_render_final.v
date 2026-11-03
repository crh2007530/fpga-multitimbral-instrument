`timescale 1ns/1ps
module tb_v28_render_final;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[127:0]game=0;reg[10:0]x=0;reg[9:0]y=0;reg[63:0]mix=0;reg signed[8:0]wave=0;wire[23:0]rgb,labeled;integer i,j,f;
video_labels dut(game,clk,rst,x,y,1'b0,1'b0,1'b1,24'hf0f5fa,,,,labeled,1'b0,22'd0,mix,wave,1'b1,24'd0);
video_brand_title brand(.clk(clk),.rst_n(rst),.sys_clk(clk),.sys_rst_n(rst),.title_write(1'b0),.title_address(9'd0),.title_data(8'd0),.title_show(1'b0),.game_active(1'b0),.test_mode(1'b0),.x(x),.y(y),.hi(1'b0),.vi(1'b0),.di(1'b1),.rgb_in(labeled),.rgb_out(rgb));
integer n;
initial begin repeat(3)@(negedge clk);rst=1;
mix[32:0]={2'd1,2'd1,5'd6,3'd4,2'd1,5'd6,2'd1,2'd1,5'd7,5'd16};mix[33]=1;mix[37:34]=2;mix[40:38]=7;mix[42:41]=2;mix[44:43]=1;mix[55:49]=75;
f=$fopen("checks/v28_mixer_final.ppm","wb");$fwrite(f,"P3\n1280 720\n255\n");
for(n=0;n<1280*720+4;n=n+1)begin
@(negedge clk);x=n%1280;y=n/1280;wave=$rtoi(90.0*$sin((n%1280)*0.045));@(posedge clk);#1;
if(n>=4)begin if(^rgb===1'bx)$fatal(1,"unknown UI pixel");$fwrite(f,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);end end

$fclose(f);$display("PASS mixer RTL raster with simulated waveform stimulus");$finish;end
endmodule
