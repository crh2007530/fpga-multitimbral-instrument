`timescale 1ns/1ps
module tb_v27_entry;
reg clk=0;always #5 clk=~clk;reg rst=0,active=0,running=0;reg[10:0]x=1;reg[9:0]y=0;wire hit;wire[23:0]rgb;
video_ship dut(clk,rst,x,y,active,running,8'd0,hit,rgb);
integer n,prior;
task frame;begin @(negedge clk);x=0;y=1;@(negedge clk);x=1;y=0;end endtask
initial begin repeat(3)@(negedge clk);rst=1;frame();
if(dut.entry_y!=720)$fatal(1,"inactive origin");active=1;prior=720;
for(n=0;n<100;n=n+1)begin frame();if(dut.entry_y>prior || dut.entry_y<456)$fatal(1,"nonmonotonic entry");prior=dut.entry_y;end
if(dut.entry_y!=456)$fatal(1,"entry never lands");
running=1;repeat(2)frame();running=0;repeat(2)frame();if(dut.entry_y!=456)$fatal(1,"pause must not replay entry");
active=0;frame();active=1;frame();if(dut.entry_y<=456)$fatal(1,"reenter must replay");running=1;frame();if(dut.entry_y!=456)$fatal(1,"start must immediately restore playable position");
$display("PASS monotonic frame-paced entry, lands, no replay on pause, replay on re-entry, immediate start bypass");$finish;end
endmodule
