`timescale 1ns/1ps
module tb_touch_guard_defaults_v15_3;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fv=0;reg[7:0] raw=0;wire valid;wire[7:0] keys;
 touch_command_guard dut(clk,rst,fv,1'b1,raw,valid,keys);
 task frames;input[7:0] k;input integer n;integer j;begin
 for(j=0;j<n;j=j+1)begin
 @(negedge clk);fv=1;raw=k;@(negedge clk);fv=0;repeat(2)@(negedge clk);
 end end endtask
 integer i;
 initial begin
 repeat(4)@(negedge clk);rst=1;
 frames(16,500);if(keys!=0)$fatal(1,"boot key accepted");
 frames(0,8);
 for(i=0;i<100;i=i+1)begin
 frames(16,2);frames(0,8);if(keys!=0)$fatal(1,"noise accepted");end
 frames(16,359);if(keys!=0)$fatal(1,"test entry before 360 frames");
 frames(16,1);if(keys!=16)$fatal(1,"360-frame test entry absent");
 frames(16,100);if(keys!=16)$fatal(1,"hold lost");
 frames(128,8);if(keys!=128)$fatal(1,"escape blocked");
 frames(0,8);frames(1,7);if(keys!=0)$fatal(1,"short ordinary key accepted");
 frames(1,1);if(keys!=1)$fatal(1,"8-frame ordinary key absent");
 $display("PASS production defaults: 8-frame release/debounce, exact 360-frame T5, 100 short-noise bursts, startup stuck T5, T8 escape");$finish;
 end
endmodule
