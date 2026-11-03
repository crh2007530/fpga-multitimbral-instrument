`timescale 1ns/1ps
// Sample actual RTL output on a 320x180 grid. Scripted inputs, not a board capture.
module tb_game_motion;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[10:0]x=0;reg[9:0]y=0;reg[127:0]s=0;
reg[7:0]pressed=0;wire[23:0]rgb,out;wire h,v,de;
video_game_view view(clk,rst,x,y,s,pressed,8'd70,9'sd0,1'b1,1'b1,1'b1,1'b0,rgb,40'd0,1'b0,1'b0,80'd0);
 reg[10:0] lx=0;reg[9:0] ly=0;
 always @(posedge clk)begin lx<=x;ly<=y;end
video_labels labels(s,clk,rst,lx,ly,1'b0,1'b0,1'b1,rgb,h,v,de,out,1'b0,22'd0,64'd0,9'd0,1'b0,24'd0);
integer n,xx,yy,f;reg[511:0]name;
initial begin repeat(4)@(negedge clk);rst=1;s[30]=1;s[31]=1;s[100]=1;s[21:16]=18;
for(n=0;n<8;n=n+1)begin
s[15:0]=10500+n*60;s[51:36]=20000;s[59:52]=20;s[67:60]=20;
s[109:102]=n*32;pressed=n>=4?8'h44:0;s[35:33]=n>=4?1:0;
$sformat(name,"motion_%0d.ppm",n);f=$fopen(name,"wb");$fwrite(f,"P6\n320 180\n255\n");
for(yy=0;yy<180;yy=yy+1)for(xx=0;xx<320;xx=xx+1)begin
@(negedge clk);x=xx*4;y=yy*4;repeat(5)@(posedge clk);#1;
if(^out===1'bx)$fatal(1,"unknown motion pixel");
$fwrite(f,"%c%c%c",out[23:16],out[15:8],out[7:0]);end
$fclose(f);$display("motion frame %0d",n);
end
$display("PASS eight actual RTL motion frames, scripted time/pressure inputs");$finish;end
endmodule
