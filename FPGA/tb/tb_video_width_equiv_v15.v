`timescale 1ns/1ps
`include "tb/video_game_view_reference.vh"
module tb_video_width_equiv_v15;
reg clk=0;always #5 clk=~clk;
reg rst=0;reg[10:0] x=0;reg[9:0] y=0;reg[127:0] state=0;
reg[7:0] pressed=0,magnitude=0;reg signed[8:0] displacement=0;
reg wv=0,fv=0,xv=0,xd=0,enabled=0;reg[39:0] preview=0;
wire[23:0] actual,expected;
video_game_view #(.CUSTOM_CHART(1)) uut(clk,rst,x,y,state,pressed,magnitude,displacement,wv,fv,xv,xd,actual,preview,enabled,1'b0,80'd0);
video_game_view_reference #(.CUSTOM_CHART(1)) refview(clk,rst,x,y,state,pressed,magnitude,displacement,wv,fv,xv,xd,expected,preview,enabled);
integer i,j,seed=24680,count=0;
task check;begin
 @(posedge clk);#1;
 if(actual!==expected)$fatal(1,"RGB differs x=%0d y=%0d actual=%h expected=%h",x,y,actual,expected);
 count=count+1;
end endtask
initial begin
 repeat(4)@(negedge clk);rst=1;
 for(i=0;i<100000;i=i+1)begin
  @(negedge clk);
  x=i%64==0?0:($unsigned($random(seed))%1650);
  y=$unsigned($random(seed))%750;
  state={$random(seed),$random(seed),$random(seed),$random(seed)};
  pressed=$random(seed);magnitude=$random(seed);displacement=$random(seed);
  {wv,fv,xv,xd,enabled}=$random(seed);preview={$random(seed),$random(seed)};
  check();
 end
 state=0;state[30]=1;state[31]=1;state[15:0]=4000;preview=40'h8142241881;enabled=1;
 for(j=0;j<750;j=j+1)for(i=0;i<1650;i=i+1)begin
  @(negedge clk);x=i;y=j;displacement=(i%512)-256;magnitude=i;pressed=8'ha5;wv=1;fv=1;xv=1;xd=i[2];
  check();
 end
 $display("PASS %0d game RGB comparisons: random legal raster inputs plus full 1650x750 frame exactly equal original arithmetic",count);
 $finish;
end
initial begin #20000000;$fatal(1,"timeout");end
endmodule
