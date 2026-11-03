`timescale 1ns/1ps
`include "tb/touch_command_guard_v155.v"
module tb_touch_vote;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fv=0,slow=0;reg[7:0] raw=0;
 wire valid,ov;wire[7:0] keys,oldkeys;
 touch_command_guard #(.TIMEOUT_CYCLES(100)) dut(clk,rst,fv,slow,raw,valid,keys);
 touch_command_guard_v155 #(.TIMEOUT_CYCLES(100)) old(clk,rst,fv,slow,raw,ov,oldkeys);
 task frames;input[7:0] k;input integer n;integer j;begin
 for(j=0;j<n;j=j+1)begin @(negedge clk);raw=k;fv=1;@(negedge clk);fv=0;repeat(2)@(negedge clk);end
 end endtask
 task check;input[7:0] k;begin if(keys!==k)$fatal(1,"expected %h got %h",k,keys);end endtask
 integer i,j;reg[7:0] k;
 initial begin
 repeat(4)@(negedge clk);rst=1;
 frames(1,20);check(0);frames(0,6);
 // One erroneous key between good samples: 4/5 succeeds; 4 consecutive fails.
 frames(64,2);frames(1,1);check(0);frames(64,2);check(64);
 if(oldkeys!=0)$fatal(1,"v15.5 comparison must reject interrupted candidate");
 $display("REPRO 40,40,01,40,40: v15.5 has no accepted key; v15.6 accepts T7, never T1");
 for(i=0;i<30;i=i+1)begin frames(1,1);check(64);frames(64,3);frames(0,1);check(64);frames(64,3);end
 // Persistent conflicting T4 clears, never becomes a new command.
 frames(8,2);check(64);frames(8,1);check(0);frames(8,30);check(0);
 frames(64,30);check(0);frames(0,3);frames(64,4);check(64);
 frames(0,2);check(64);frames(0,1);check(0);
 // A conflict followed by only two zero frames is NOT a confirmed release.
 frames(64,4);check(64);frames(1,1);frames(0,2);check(0);
 frames(1,10);check(0);frames(0,3);
 // Alternating one-hot bits and overlapping keys must not manufacture a key.
 for(i=0;i<30;i=i+1)begin frames(1,1);frames(2,1);frames(3,1);frames(4,1);check(0);end
 frames(0,6);
 // Game T5 needs 3 qualified windows (6 clean frames), not just one vote.
 frames(16,4);check(0);frames(16,1);check(0);frames(16,1);check(16);
 frames(16,100);check(16);frames(0,3);check(0);
 // Two-frame bursts cannot pause; all 8 legitimate keys remain available.
 for(i=0;i<100;i=i+1)begin frames(16,2);frames(0,6);check(0);end
 for(i=0;i<8;i=i+1)begin k=8'b1<<i;frames(0,6);frames(k,8);check(k);frames(0,3);check(0);end
 // Cover a wrong single-key sample in every position of the voting window.
 for(i=0;i<5;i=i+1)begin
 frames(0,6);
 for(j=0;j<5;j=j+1)begin if(j==i)frames(1,1);else frames(64,1);end
 // If the current sample is wrong, one more real sample must finish voting.
 frames(64,1);check(64);frames(0,3);check(0);
 end
 // Deliberate automatic test still demands 360 uninterrupted raw T5 frames.
 slow=1;frames(16,200);frames(0,1);frames(16,359);check(0);frames(16,1);check(16);
 // Escape remains possible without an ordinary release; requires cancel+vote.
 frames(128,8);check(128);frames(0,3);check(0);
 frames(1,4);check(1);repeat(120)@(negedge clk);check(0);frames(1,20);check(0);
 frames(0,6);frames(1,4);check(1);
 $display("PASS vote, 30 wrong/dropout holds, persistent conflict lockout, no synthetic bits, 100 short bursts, all8 keys, critical T5, long test, escape, scanner loss");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
