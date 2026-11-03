`timescale 1ns/1ps
module tb_optical_pluck;
reg clk=0;always #5 clk=~clk;reg rst=0,en=0,pol=1,raw=1;
wire pulse,blocked,armed;wire[15:0] count;
optical_pluck #(.FILTER_CYCLES(3),.REARM_CYCLES(5)) dut(clk,rst,en,pol,raw,pulse,blocked,armed,count);
task waitcycles;input integer n;begin repeat(n)@(negedge clk);end endtask
initial begin
waitcycles(3);rst=1;en=1;waitcycles(20);if(count!=0 || armed)$fatal(1,"startup blocked triggered");
raw=0;waitcycles(20);if(!armed)$fatal(1,"clear not armed");
raw=1;waitcycles(1);raw=0;waitcycles(10);if(count!=0)$fatal(1,"glitch triggered");
raw=1;waitcycles(20);if(count!=1)$fatal(1,"missing pluck");
waitcycles(30);if(count!=1)$fatal(1,"held repeat");
raw=0;waitcycles(20);if(count!=1)$fatal(1,"return triggered");
raw=1;waitcycles(20);if(count!=2)$fatal(1,"second pluck");
en=0;pol=0;raw=0;waitcycles(20);en=1;waitcycles(20);if(count!=2)$fatal(1,"polarity enable triggered");
raw=1;waitcycles(20);raw=0;waitcycles(20);if(count!=3)$fatal(1,"low polarity");
$display("PASS optical both polarities, startup blocked, glitch filtering, no held/return repeat, rearm");$finish;
end
endmodule
