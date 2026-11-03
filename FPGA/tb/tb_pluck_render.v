`timescale 1ns/1ps
module tb_pluck_render;
reg clk=0;always #5 clk=~clk;reg rst=0;reg[127:0]s=0;reg[7:0]keys=0;reg[335:0] snap=0;reg[115:0] details=0;reg[63:0] mix=0;
wire hs,vs,de;wire[7:0]r,g,b;
video_dashboard dut(s,clk,rst,1'b0,rst,1'b0,1'b0,10'd0,24'sd0,24'sd0,1'b0,16'sd0,keys,8'd0,hs,vs,de,r,g,b,256'd0,1'b0,64'hffffffffffffffff,6'd9,1'b0,1'b0,40'd0,80'd0,64'd0,61'd0,1'b0,9'd0,8'd0,1'b0,22'd0,64'd0,24'd0);
wire signed[8:0] displacement=$signed({1'b0,dut.dx[6:0],1'b0})-9'sd128;
wire[7:0] mag={1'b0,dut.dx[6:0]} ^ 8'h6c;
wire dot=((dut.dx[6:0]^dut.dy[6:0])<3);
integer f,mode,pixels,cycles,selected;reg[511:0]name;
initial begin
force dut.pluck_data=24'h001275;force dut.detail=details;force dut.mixer_data=mix;
$readmemh("tb/title_preview.hex",dut.identity.title_mem);
force dut.raw_displacement=displacement;force dut.snapshot=snap;force dut.wave_visible=1;force dut.wave_displacement=displacement;
force dut.visible=1;force dut.magnitude_draw=mag;force dut.xy_visible_draw=1;force dut.xy_draw=dot;
repeat(5)@(negedge clk);rst=1;
selected=-1;if($value$plusargs("MODE=%d",selected))begin end
for(mode=(selected<0?0:selected);mode<(selected<0?2:selected+1);mode=mode+1)begin
mix=0;s=0;s[103:102]=1;s[116:110]=75;s[124:122]=7;s[119:118]=3;keys=8'h10;
case(mode)
0:name="checks/pluck_play.ppm";
1,2:begin name=mode==1?"checks/pluck_game.ppm":"checks/pluck_pause.ppm";
s[30]=1;s[31]=mode==1;s[100]=1;s[15:0]=1800;s[51:36]=18000;s[59:52]=18;s[67:60]=24;s[75:68]=18;s[35:33]=1;s[29:22]=16;end
3:begin name="checks/pluck_test.ppm";s[127:126]=3;end
4:begin name="checks/pluck_practice.ppm";s[100]=1;s[31]=1;end
5:begin name="checks/pluck_mixer.ppm";
mix[32:0]={2'd1,2'd1,5'd6,3'd4,2'd1,5'd6,2'd1,2'd1,5'd7,5'd16};
mix[33]=1;mix[37:34]=2;mix[40:38]=7;mix[42:41]=2;mix[44:43]=1;mix[55:49]=75;end
endcase
details={1'b0,1'b1,7'd32,7'd64,7'd96,7'd48,64'h00001800cc000000};
if(mode==0 || mode==1)begin s[104]=1;details[93]=1;end
details[115:94]={4'd8,16'h5555,2'b00};
if(mode==0)begin s[119]=0;s[123]=0;end
snap={81'd0,64'hfffffffffffffdff,6'd9,41'd0,s,8'd2,keys};
// Prime pipelines in vertical blank, then release the real raster counter.
force dut.x=1649;force dut.y=749;
repeat(256)@(negedge clk);release dut.x;release dut.y;
wait(dut.x==0 && dut.y==0);@(negedge clk);
f=$fopen(name,"wb");$fwrite(f,"P6\n1280 720\n255\n");pixels=0;cycles=0;
// Output DE is delayed by the real compositing pipeline. At x=1 it
// is still blank from the previous frame, so the next DE starts row0.
while(pixels<1280*720)begin @(posedge clk);#1;cycles=cycles+1;
if(de)begin if(^{r,g,b}===1'bx)$fatal(1,"unknown raster pixel");$fwrite(f,"%c%c%c",r,g,b);pixels=pixels+1;end
if(cycles>1650*751)$fatal(1,"missing output pixels");end
$fclose(f);
end
$display("PASS selected full production-compositor raster frame; synthetic signal stimulus, not board capture");$finish;end
endmodule


