`timescale 1ns/1ps
// Actual RTL renderer/font. Deterministic audio fixtures, not a board capture.
module tb_game_render;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg[10:0] x=0;reg[9:0] y=0;reg[127:0] state=0;
 reg[7:0] pressed=0,mag=0;reg signed[8:0] wave=0;reg dot=0;
 wire[23:0] rgb,out;wire ho,vo,de;
 video_game_view view(clk,rst,x,y,state,pressed,mag,wave,1'b1,1'b1,1'b1,dot,rgb,40'd0,1'b0,1'b0,80'd0);
 reg[10:0] lx=0;reg[9:0] ly=0;
 always @(posedge clk)begin lx<=x;ly<=y;end
 video_labels labels(state,clk,rst,lx,ly,1'b0,1'b0,1'b1,rgb,ho,vo,de,out,1'b0,22'd0,64'd0,9'd0,1'b0,24'd0);
 integer xx,yy,f,n,s;real angle;
 task render;input[255:0] filename;begin
 f=$fopen(filename,"wb");$fwrite(f,"P6\n1280 720\n255\n");
 for(yy=0;yy<720;yy=yy+1)for(xx=0;xx<1280;xx=xx+1)begin
  @(negedge clk);x=xx;y=yy;
  wave=$rtoi(60*$sin((xx-1040)*0.10)+20*$sin((xx-1040)*0.20));
  mag=((xx>=1050 && xx<1055)?150:((xx>=1080 && xx<1085)?105:((xx>=1110 && xx<1115)?60:0)));
  angle=(xx-1136)/60.0;
  dot=((xx-1136)*(xx-1136)*2+(yy-520)*(yy-520)>2500 && (xx-1136)*(xx-1136)*2+(yy-520)*(yy-520)<2700);
  // Streaming pixel cadence: font pipeline emits the preceding input pixel.
  @(posedge clk);#1;
  if(^out===1'bx)$fatal(1,"unknown pixel");
  if(xx+yy*1280>=4)$fwrite(f,"%c%c%c",out[23:16],out[15:8],out[7:0]);
 end
 repeat(4)begin @(posedge clk);#1;$fwrite(f,"%c%c%c",out[23:16],out[15:8],out[7:0]);end
 $fclose(f);end endtask
 initial begin
 repeat(3)@(negedge clk);rst=1;state[30]=1;
 state[109:102]=200;state[100]=1;state[31]=1;state[15:0]=10550;state[21:16]=18;
 state[51:36]=20000;state[59:52]=20;state[67:60]=20;state[75:68]=20;state[35:33]=1;pressed=8'h22;
 render("game_play.ppm");
 $display("PASS actual RTL render: streaming 1280x720 play frame, no unknown RGB");$finish;
 end
endmodule
