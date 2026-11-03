`timescale 1ns/1ps
module tb_pluck_hud_pixels;
reg clk=0;always #5 clk=~clk;
reg rst=0;reg[127:0]game=0;reg[10:0]x=0;reg[9:0]y=0;
reg[23:0]status=0;wire[23:0]rgb;
video_labels dut(game,clk,rst,x,y,1'b0,1'b0,1'b1,24'hf5f9fd,,,,rgb,1'b0,22'd0,64'd0,9'sd0,1'b0,status);
integer f,scene,xx,yy,ink;
initial begin
repeat(3)@(negedge clk);rst=1;
f=$fopen("checks/pluck_status_rows.ppm","wb");$fwrite(f,"P6\n1024 96\n255\n");
for(scene=0;scene<6;scene=scene+1)begin
 case(scene)
  0:status=24'h000000;
  1:status=24'h000009;
  2:status=24'h000135;
  3:status=24'h000169;
  4:status=24'h000245;
  5:status=24'h000203;
 endcase
 ink=0;
 for(yy=560;yy<576;yy=yy+1)for(xx=128;xx<1152;xx=xx+1)begin
  x=xx;y=yy;repeat(5)@(negedge clk);
  if(^rgb===1'bx)$fatal(1,"unknown glyph pixel");
  if(rgb!=24'heaf3fa)ink=ink+1;
  $fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
 end
 if(ink<300)$fatal(1,"empty HUD row");
end
$fclose(f);
game[30]=1;x=448;y=168;repeat(6)@(negedge clk);
if(!dut.pluck_row || !dut.footer1)$fatal(1,"game row not selected");
game[127]=1;#1;if(dut.pluck_row)$fatal(1,"test screen overwritten");
$display("PASS real label pipeline six diagnostic states glyph ROM pixels and game/test isolation; synthetic diagnostic inputs");$finish;
end
endmodule
