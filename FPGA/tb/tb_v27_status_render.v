`timescale 1ns/1ps
module tb_v27_status_render;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[127:0]s=0;reg[10:0]x=0;reg[9:0]y=0;wire[23:0]rgb;
video_labels dut(s,clk,rst,x,y,1'b0,1'b0,1'b1,24'heaf3fa,,,,rgb,1'b0,22'd0,64'd0,9'd0,1'b0,24'd0);
integer scene,i,j,f;reg[511:0]name;
initial begin repeat(3)@(negedge clk);rst=1;
for(scene=0;scene<3;scene=scene+1)begin
s=0;s[116:110]=75;
case(scene)
0:begin name="checks/v27_status_off.ppm";end
1:begin name="checks/v27_status_on.ppm";s[118]=1;s[119]=1;s[124]=1;end
2:begin name="checks/v27_status_bypass.ppm";s[117]=1;end
endcase
f=$fopen(name,"wb");$fwrite(f,"P6\n1280 32\n255\n");
for(j=624;j<656;j=j+1)for(i=0;i<1280;i=i+1)begin
@(negedge clk);x=i;y=j;repeat(5)@(posedge clk);#1;
if(^rgb===1'bx)$fatal(1,"unknown HUD pixel");$fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);end
$fclose(f);end
$display("PASS actual status pixels for off/on/proximity bypass");$finish;end
endmodule
