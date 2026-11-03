`timescale 1ns/1ps
module tb_adjustable_adsr;
reg clk=0;always #5 clk=~clk;reg rst=0,gate=0,en=1;
reg[14:0]a=8192,d=4096,s=8192,r=2048;wire[15:0]level;wire active;
adjustable_adsr dut(clk,rst,1'b1,gate,en,a,d,s,r,level,active);
task tick;begin @(negedge clk);end endtask
integer n;
initial begin repeat(3)tick;rst=1;gate=1;tick;
for(n=0;n<4;n=n+1)tick;
if(level!=32767)$fatal(1,"attack peak %d",level);
repeat(6)tick;if(level!=8192)$fatal(1,"decay %d",level);
repeat(10)tick;if(level!=8192)$fatal(1,"sustain");
gate=0;tick;repeat(4)tick;if(level!=0 || active)$fatal(1,"release");
a=32767;s=0;d=32767;gate=1;tick;tick;tick;if(level!=0)$fatal(1,"zero sustain");
en=0;tick;if(active || level!=0)$fatal(1,"disable");
$display("PASS independent A D S R ramps, sustain, release, zero sustain, disable");$finish;
end
endmodule
