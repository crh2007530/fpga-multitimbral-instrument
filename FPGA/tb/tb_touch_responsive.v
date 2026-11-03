`timescale 1ns/1ps
`include "tb/touch_command_guard_old.v"
module tb_touch_responsive;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fv=0,slow=1;reg[7:0] raw=0;
 wire valid,old_valid;wire[7:0] keys,old_keys;
 touch_command_guard #(.TIMEOUT_CYCLES(100)) dut(clk,rst,fv,slow,raw,valid,keys);
 touch_command_guard_old #(.TIMEOUT_CYCLES(100)) old(clk,rst,fv,slow,raw,old_valid,old_keys);
 integer i,old_drops=0;
 task frames;input[7:0] k;input integer n;integer j;begin
 for(j=0;j<n;j=j+1)begin @(negedge clk);raw=k;fv=1;@(negedge clk);fv=0;repeat(2)@(negedge clk);end
 end endtask
 initial begin
 repeat(4)@(negedge clk);rst=1;
 frames(16,500);if(keys!=0)$fatal(1,"boot-stuck T5");
 frames(0,8);
 for(i=0;i<100;i=i+1)begin frames(16,2);frames(0,8);if(keys!=0)$fatal(1,"noise enters test");end
 frames(16,359);if(keys!=0)$fatal(1,"test entered early");
 frames(16,1);if(keys!=16)$fatal(1,"deliberate test unavailable");
 frames(0,3);if(keys!=16)$fatal(1,"short dropout released key");
 frames(0,1);if(keys!=0)$fatal(1,"release stuck");
 frames(64,8);
 for(i=0;i<40;i=i+1)begin
 frames(0,1);if(keys!=64)$fatal(1,"missed frame cancels T7");
 if(old_keys==0)old_drops=old_drops+1;
 frames(64,12);if(keys!=64)$fatal(1,"held key lost");
 end
 if(old_drops!=40)$fatal(1,"legacy counterexample absent");
 $display("REPRO v15.4 drops T7 on all 40 isolated missed frames; v15.5 preserves hold");
 frames(65,3);if(keys!=64)$fatal(1,"brief overlap cancels hold");
 frames(64,2);frames(65,4);if(keys!=0)$fatal(1,"sustained overlap not rejected");
 frames(16,400);if(keys!=0)$fatal(1,"rollover armed T5");
 frames(128,5);if(keys!=128)$fatal(1,"T8 escape");
 frames(0,6);frames(1,3);if(keys!=0)$fatal(1,"ordinary debounce too short");
 frames(1,1);if(keys!=1)$fatal(1,"ordinary debounce boundary");
 frames(0,6);slow=0;frames(16,4);if(keys!=16)$fatal(1,"game T5 latency");
 repeat(120)@(negedge clk);if(keys!=0)$fatal(1,"scanner timeout stuck");
 $display("PASS production thresholds, boot key, 100 noise bursts, 360-frame test, 4-frame press/release, dropout grace, overlap, rollover, escape, timeout");$finish;
 end
endmodule
