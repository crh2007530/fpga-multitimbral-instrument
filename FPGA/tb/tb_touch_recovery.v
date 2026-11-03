`timescale 1ns/1ps
`include "tb/touch_command_guard_v156.v"
module tb_touch_recovery;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fv=0,slow=0;reg[7:0] raw=0;
 wire valid,ov;wire[7:0] keys,oldkeys;
 touch_command_guard #(.TIMEOUT_CYCLES(100)) dut(clk,rst,fv,slow,raw,valid,keys);
 touch_command_guard_v156 #(.TIMEOUT_CYCLES(100)) old(clk,rst,fv,slow,raw,ov,oldkeys);
 task frames;input[7:0] k;input integer n;integer j;begin
 for(j=0;j<n;j=j+1)begin @(negedge clk);raw=k;fv=1;@(negedge clk);fv=0;repeat(2)@(negedge clk);end
 end endtask
 task check;input[7:0] k;begin if(keys!==k)$fatal(1,"expected %h got %h",k,keys);end endtask
 integer i,j;reg[7:0] k;
 initial begin
 repeat(4)@(negedge clk);rst=1;frames(0,6);
 frames(8,8);check(8);frames(3,3);check(0);
 frames(64,20);check(64);
 if(oldkeys!==0)$fatal(1,"v15.6 lockout not reproduced");
 $display("REPRO T4 -> ambiguous -> T7 without zero: v15.6 locked at zero, v15.7 recovers T7");
 // All different-key rollovers, including T8, without clean zero release.
 for(i=0;i<8;i=i+1)begin k=8'b1<<i;frames(k,12);check(k);end
 frames(0,6);
 frames(64,2);frames(1,1);check(0);frames(64,2);check(64);
 for(i=0;i<30;i=i+1)begin frames(1,1);check(64);frames(64,3);frames(0,1);check(64);frames(64,3);end
 frames(0,3);check(0);
 // Game T5: one press only even after a prolonged invalid patch. New other keys remain usable.
 frames(16,6);check(16);frames(16,100);check(16);
 frames(3,4);check(0);frames(16,100);check(0);
 frames(128,8);check(128);frames(0,6);
 // Same key can be pressed again after real release.
 frames(16,6);check(16);frames(0,3);check(0);frames(16,6);check(16);frames(0,6);
 for(i=0;i<100;i=i+1)begin frames(16,2);frames(0,6);check(0);end
 for(i=0;i<30;i=i+1)begin frames(1,1);frames(2,1);frames(3,1);frames(4,1);check(0);end
 frames(0,6);
 slow=1;frames(16,200);frames(0,1);frames(16,359);check(0);frames(16,1);check(16);
 frames(128,8);check(128);frames(0,6);
 frames(1,4);check(1);repeat(120)@(negedge clk);check(0);
 frames(2,8);check(2);
 $display("PASS recovery, all8 rollover, glitch hold, no repeated T5 after conflict, release/repress, short bursts, long test, timeout recovery");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
