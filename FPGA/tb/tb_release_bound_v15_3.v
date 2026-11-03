`timescale 1ns/1ps
module tb_release_bound_v15_3;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,on=0,off=0,flute=0,diagnostic=0;
 wire[15:0] level;wire active;
 instrument_env dut(clk,rst,1'b1,on,off,flute,diagnostic,level,active,1'b0);
 integer i,n;reg[15:0] previous;
 task release_check;input integer bound;begin
 @(negedge clk);on=1;@(negedge clk);on=0;
 // Catch the peak so this checks the longest release for each preset.
 wait(level==32767);@(negedge clk);off=1;@(negedge clk);off=0;
 n=0;previous=level;
 while(active && n<=bound)begin
 @(negedge clk);n=n+1;
 if(level>previous)$fatal(1,"release amplitude grew");previous=level;
 end
 if(active || level!=0)$fatal(1,"release did not terminate within %0d samples",bound);
 repeat(10)@(negedge clk);if(level!=0 || active)$fatal(1,"release restarted itself");
 $display("PASS release diagnostic=%0d flute=%0d ended in %0d samples",diagnostic,flute,n);
 end endtask
 initial begin
 repeat(4)@(negedge clk);rst=1;
 release_check(130);flute=1;release_check(514);
 diagnostic=1;release_check(3644);
 $display("PASS all envelope tails terminate, no autonomous restart; diagnostic upper bound 3644/48046.875 <76ms");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
