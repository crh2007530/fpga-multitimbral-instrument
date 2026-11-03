`timescale 1ns/1ps
module tb_v23_ship;
reg clk=0;always #5 clk=~clk;reg rst=0,active=1,running=1;reg[10:0] x=0;reg[9:0]y=0;reg[7:0] keys=0;wire hit;wire[23:0]rgb;
video_ship dut(clk,rst,x,y,active,running,keys,hit,rgb);
task frame;begin @(negedge clk);x=0;y=1;@(negedge clk);x=1;y=0;end endtask
task pixel;input[10:0]px;input[9:0]py;begin @(negedge clk);x=px;y=py;@(posedge clk);#1;end endtask
integer i;reg[10:0] saved;
initial begin repeat(3)@(negedge clk);rst=1;
keys=4;frame();repeat(40)frame();if(dut.center!=501 || dut.lane!=2)$fatal(1,"Z3 tracking");
for(i=520;i<608;i=i+1)begin pixel(501,i);if(!hit || rgb==0)$fatal(1,"gap in rectangular tail %d",i);end
saved=dut.center;keys=18;repeat(4)frame();if(dut.center!=saved)$fatal(1,"chord jumps");
keys=255;frame();pixel(501,480);if(dut.sprite_q)$fatal(1,"all keys leaves aircraft visible");
pixel(608,504);if(hit)$fatal(1,"ring outside bounds");pixel(868,570);if(!hit)$fatal(1,"missing ring");
pixel(608,537);if(!hit)$fatal(1,"ring top not closed");pixel(608,603);if(!hit)$fatal(1,"ring bottom not closed");
keys=128;frame();running=0;repeat(10)frame();if(dut.center!=saved)$fatal(1,"moves when paused");running=1;repeat(60)frame();if(dut.center!=856)$fatal(1,"Z8 tracking");
keys=0;repeat(20)frame();pixel(856,596);if(hit)$fatal(1,"released tail not faded");
active=0;frame();if(dut.center!=572)$fatal(1,"mode reset");
$display("PASS ship lane/color, chord hold, all8 ring, continuous tail, pause, release, mode reset");$finish;end
endmodule

