`timescale 1ns/1ps
`include "tb/instrument_env_v18_reference.v"
module tb_env_equivalence;
reg clk=0;always #5 clk=~clk;
reg rst=0,ce=0,on=0,off=0,guitar=0,diag=0,piano=0;
wire[15:0]a,b;wire aa,bb;
instrument_env #(.THIRD_TIMBRE(1)) dut(clk,rst,ce,on,off,guitar,diag,a,aa,piano);
instrument_env_v18_reference #(.THIRD_TIMBRE(1)) refdut(clk,rst,ce,on,off,guitar,diag,b,bb,piano);
integer mode,state,value,n,seed=180025;
task check;begin
 if(a!==b || aa!==bb || dut.musical.state!==refdut.musical.state || dut.musical.divider!==refdut.musical.divider)
  $fatal(1,"envelope mismatch mode=%d state=%d amplitude=%d new=%d old=%d",mode,state,value,a,b);
end endtask
initial begin
repeat(4)@(negedge clk);rst=1;ce=1;
// Exhaustive reachable amplitude domain, every state and both latched flags.
for(mode=0;mode<4;mode=mode+1)
for(state=0;state<5;state=state+1)
for(value=0;value<32768;value=value+1)begin
 @(negedge clk);
 dut.musical.state=state;refdut.musical.state=state;
 dut.musical.amplitude=value;refdut.musical.amplitude=value;
 dut.musical.divider=0;refdut.musical.divider=0;
 dut.musical.test=mode[0];refdut.musical.test=mode[0];
 dut.musical.slow_release=mode[1];refdut.musical.slow_release=mode[1];
 @(posedge clk);#1;check;
end
@(negedge clk);rst=0;repeat(4)@(negedge clk);rst=1;
// Sequential retrigger, priority, mode changes, sample stalls and release divider.
for(n=0;n<200000;n=n+1)begin
 @(negedge clk);ce=(n%4==0);on=($random(seed)&255)==0;off=($random(seed)&127)==0;
 guitar=$random(seed);piano=$random(seed);diag=$random(seed);
 @(posedge clk);#1;check;
end
$display("PASS compact envelope bit-exact versus approved v18: 655360 state/amplitude/flag combinations plus 200000 sequential cycles, retrigger, release divider and diagnostic ADSR");$finish;
end
endmodule
