`timescale 1ns/1ps
module tb_v27_intro_render;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[10:0]x=1;reg[9:0]y=0;reg[127:0]s=0;
wire[23:0]rgb;
video_game_view dut(clk,rst,x,y,s,8'd0,8'd0,9'sd0,1'b0,1'b0,1'b0,1'b0,rgb,40'd0,1'b0,1'b0,80'd0);
integer scene,frames,i,j,f,target,trace;reg[511:0]name;
task frame;begin @(negedge clk);x=0;y=1;@(negedge clk);x=1;y=0;frames=frames+1;end endtask
initial begin repeat(3)@(negedge clk);rst=1;frames=0;s[30]=1;
trace=$fopen("checks/v27_entry_trace.csv","w");$fwrite(trace,"scene,frame,ship_top_y\n");
for(scene=0;scene<6;scene=scene+1)begin
case(scene)
0:begin target=8;name="checks/v27_entry_0.ppm";end
1:begin target=16;name="checks/v27_entry_1.ppm";end
2:begin target=24;name="checks/v27_entry_2.ppm";end
3:begin target=32;name="checks/v27_entry_3.ppm";end
4:begin target=48;name="checks/v27_entry_4.ppm";end
5:begin target=64;name="checks/v27_entry_5.ppm";end
endcase
while(frames<target)frame();
$fwrite(trace,"%0d,%0d,%0d\n",scene,frames,dut.plane.entry_y);
f=$fopen(name,"wb");$fwrite(f,"P6\n384 288\n255\n");
for(j=416;j<704;j=j+1)begin
@(negedge clk);x=0;y=j;@(negedge clk);x=1;@(negedge clk);x=2;repeat(4)@(negedge clk);
for(i=416;i<800;i=i+1)begin
@(negedge clk);x=i;y=j;@(posedge clk);#1;
if(^rgb===1'bx)$fatal(1,"unknown entry raster");
$fwrite(f,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);end end
$fclose(f);end
$fclose(trace);$display("PASS six actual game-view entry raster scenes; frame ticks compressed, no gameplay clock changes");$finish;end
endmodule
