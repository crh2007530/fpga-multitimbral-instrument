`timescale 1ns/1ps
`include "tb/video_labels_reference.v"
module tb_pluck_display_regression;
reg clk=0;always #5 clk=~clk;
reg rst=0;reg[127:0]game=0;reg[63:0]mix=0;reg[10:0]x=0;reg[9:0]y=0;
wire[23:0]a,b;wire ha,va,da,hb,vb,db;
video_labels dut(game,clk,rst,x,y,1'b0,1'b0,1'b1,24'h123456,ha,va,da,a,1'b0,22'd0,mix,9'sd10,1'b1,24'h000169);
video_labels_reference refdut(game,clk,rst,x,y,1'b0,1'b0,1'b1,24'h123456,hb,vb,db,b,1'b0,22'd0,mix,9'sd10,1'b1);
reg[3:0]ignore_pipe=15;integer n=0,scene,xx,yy;
always @(posedge clk)ignore_pipe<={ignore_pipe[2:0],dut.pluck_row || !rst};
always @(posedge clk)begin #1;
 if(rst && !ignore_pipe[3])begin
  if({ha,va,da,a}!=={hb,vb,db,b})$fatal(1,"unrelated label changed scene=%d x=%d y=%d actual=%h ref=%h",scene,x,y,a,b);
  n=n+1;
 end
end
initial begin
repeat(8)@(negedge clk);rst=1;
for(scene=0;scene<6;scene=scene+1)begin
game=0;mix=0;game[116:110]=75;game[124:118]=7'h55;
case(scene)
1:game[30]=1;
2:game[100]=1;
3:game[127]=1;
4:game[127:126]=3;
5:begin mix[33]=1;mix[37:34]=7;end
endcase
// Allow scene flags to propagate before checking pixels.
rst=0;repeat(8)@(negedge clk);rst=1;
// Bounded grid regression; full new-HUD glyph raster is tested separately.
for(yy=0;yy<720;yy=yy+8)for(xx=0;xx<1280;xx=xx+8)begin
@(negedge clk);x=xx;y=yy;
end
end
$display("PASS unchanged label RGB and sync outside new status rows: %0d grid samples (8 pixel stride) across play/game/practice/test4/test64/mixer",n);$finish;
end
endmodule
