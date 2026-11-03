`timescale 1ns/1ps
module tb_v23_ship_render;
reg clk=0;always #5 clk=~clk;
reg rst=0,active=1,running=1;reg[10:0]x=0;reg[9:0]y=0;reg[7:0]keys=0;
wire hit;wire[23:0]rgb;reg[23:0]out;
video_ship dut(clk,rst,x,y,active,running,keys,hit,rgb);
integer mode,i,j,f,origin;reg[511:0]name;
task frame;begin @(negedge clk);x=0;y=1;@(negedge clk);x=1;y=0;end endtask
initial begin
repeat(3)@(negedge clk);rst=1;
for(mode=0;mode<5;mode=mode+1)begin
 case(mode)
 0:begin keys=1;name="checks/ship_lane1.ppm";end
 1:begin keys=128;name="checks/ship_lane8.ppm";end
 2:begin keys=129;name="checks/ship_two_keys.ppm";end
 3:begin keys=255;name="checks/ship_all8.ppm";end
 4:begin keys=0;name="checks/ship_release.ppm";end
 endcase
 repeat(70)frame();origin=mode==3?288:dut.center-320;
 f=$fopen(name,"wb");$fwrite(f,"P6\n640 192\n255\n");
 for(j=436;j<628;j=j+1)begin
 @(negedge clk);x=0;y=j;@(negedge clk);
 for(i=0;i<640;i=i+1)begin
  @(negedge clk);x=origin+i;y=j;@(posedge clk);#1;
  if(hit && ^rgb===1'bx)$fatal(1,"unknown ship pixel");
  out=hit?rgb:24'h0e1d32;$fwrite(f,"%c%c%c",out[23:16],out[15:8],out[7:0]);
 end
 end
 $fclose(f);
end
$display("PASS five production aircraft raster scenes: Z1, Z8, two keys, all8, release");$finish;
end
endmodule

