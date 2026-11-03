`timescale 1ns/1ps
`include "tb/game_led_fx_reference.v"
module tb_v30_led_equivalence;
reg clk=0;always #5 clk=~clk;reg rst=0,active=0,running=0,done=0;reg[2:0]ev=0;reg[7:0]mask=0;reg[4:0]pixel=0;
wire[23:0]old_color,new_color;
game_led_fx #(.TICK_CYCLES(32)) dut(clk,rst,active,running,done,ev,mask,pixel,new_color);
game_led_fx_reference #(.TICK_CYCLES(32)) refdut(clk,rst,active,running,done,ev,mask,pixel,old_color);
integer n;
initial begin
repeat(3)@(negedge clk);rst=1;
for(n=0;n<30000;n=n+1)begin
 @(negedge clk);pixel=n%30;ev=0;
 active=n>=100;running=(n%4000)>200;done=n>25000;
 if(n<20000 && n%137==0)begin ev=(n/137)%5;mask=(n/137)*17;end
 #1;if(old_color!==new_color)$fatal(1,"color mismatch n=%d old=%h new=%h",n,old_color,new_color);
end
$display("PASS 30000 raster samples: bounded-width balanced evaluator equals original across wave/flash/pause/finish states");$finish;
end
endmodule
