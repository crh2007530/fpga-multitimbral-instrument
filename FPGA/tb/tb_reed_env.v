`timescale 1ns/1ps
module tb_reed_env;
reg clk=0;always #5 clk=~clk;
reg rst=0,ce=0,on=0,off=0;wire[15:0]level;wire active;
instrument_env #(.THIRD_TIMBRE(1)) dut(clk,rst,ce,on,off,1'b0,1'b0,level,active,1'b0);
task tick;begin @(negedge clk);ce=1;@(negedge clk);ce=0;end endtask
integer i;
initial begin
repeat(3)@(negedge clk);rst=1;on=1;@(negedge clk);on=0;
repeat(64)tick;if(level!=32767)$fatal(1,"reed attack");
repeat(128)tick;if(level!=28672)$fatal(1,"reed settling");
for(i=0;i<48000;i=i+1)begin tick;if(level!=28672 || !active)$fatal(1,"held reed unexpectedly decayed");end
off=1;@(negedge clk);off=0;repeat(224)tick;
if(level!=0 || active)$fatal(1,"reed note stuck");
repeat(500)tick;if(level!=0)$fatal(1,"idle audio");
$display("PASS harmonica 64 sample attack, one second stable sustain, bounded release and silence");$finish;
end
endmodule
