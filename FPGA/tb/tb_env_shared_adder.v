`timescale 1ns/1ps
module tb_env_shared_adder;
reg clk=0;always #5 clk=~clk;
reg rst=0;wire[15:0]a,b;wire aa,bb;
instrument_env #(.THIRD_TIMBRE(1)) dut(clk,rst,1'b1,1'b0,1'b0,1'b0,1'b0,a,aa,1'b0);
instrument_env_before_share #(.THIRD_TIMBRE(1)) reference(clk,rst,1'b1,1'b0,1'b0,1'b0,1'b0,b,bb,1'b0);
integer state,amp,t,slow,n=0;
initial begin
repeat(2)@(negedge clk);rst=1;
for(state=0;state<5;state=state+1)
for(t=0;t<2;t=t+1)
for(slow=0;slow<2;slow=slow+1)
for(amp=0;amp<32768;amp=amp+1)begin
 @(negedge clk);
 dut.musical.state=state;reference.musical.state=state;
 dut.musical.amplitude=amp;reference.musical.amplitude=amp;
 dut.musical.test=t;reference.musical.test=t;
 dut.musical.slow_release=slow;reference.musical.slow_release=slow;
 dut.musical.divider=0;reference.musical.divider=0;
 @(posedge clk);#1;
 if(a!==b || aa!==bb || dut.musical.state!==reference.musical.state)$fatal(1,"env mismatch state=%d amp=%d test=%d slow=%d",state,amp,t,slow);
 n=n+1;
end
$display("PASS %0d exhaustive envelope next-state comparisons",n);$finish;
end
endmodule
